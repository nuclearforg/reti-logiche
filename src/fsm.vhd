----------------------------------------------------------------------------------
-- Type definitions
----------------------------------------------------------------------------------
PACKAGE type_defs IS

	TYPE state_t IS (
	S_IDLE,
	S_FETCH,
	S_WIDTH,
	S_HEIGHT,
	S_THRES,
	S_IMAGE,
	S_DIM,
	S_AREA,
	S_AREAL,
	S_AREAH,
	S_DONE
	);

	TYPE header_ctrl_t IS (
	RESET,
	IDLE,
	STORE_WIDTH,
	STORE_HEIGHT,
	STORE_THRES
	);

	TYPE memory_ctrl_t IS (
	IDLE,
	READ,
	WRITE_L,
	WRITE_H
	);

END type_defs;

PACKAGE BODY type_defs IS
END type_defs;

----------------------------------------------------------------------------------
-- Components definitions
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.type_defs.ALL;

PACKAGE component_defs IS
	COMPONENT multiplier IS
		PORT (
			i_clk, i_start, i_rst : IN std_logic;
			i_mplier, i_mcand     : IN std_logic_vector(7 DOWNTO 0);
			o_product             : OUT std_logic_vector(15 DOWNTO 0);
			o_done                : OUT std_logic
		);
	END COMPONENT;
	COMPONENT box_area IS
		PORT (
			i_clk, i_rst, i_start : IN std_logic;
			i_zero                : IN std_logic;
			i_left, i_right       : IN std_logic_vector(7 DOWNTO 0);
			i_top, i_bottom       : IN std_logic_vector(7 DOWNTO 0);
			o_area                : OUT std_logic_vector(15 DOWNTO 0);
			o_done                : OUT std_logic
		);
	END COMPONENT;
	COMPONENT address_counter IS
		PORT (
			i_clk, i_en, i_rst : IN std_logic;
			o_cnt              : OUT std_logic_vector (15 DOWNTO 0)
		);
	END COMPONENT;
	COMPONENT matrix_idx IS
		PORT (
			i_clk, i_en : IN std_logic;
			i_width     : IN unsigned (7 DOWNTO 0);
			i_height    : IN unsigned (7 DOWNTO 0);
			o_stop      : OUT std_logic;
			o_x         : OUT std_logic_vector (7 DOWNTO 0);
			o_y         : OUT std_logic_vector (7 DOWNTO 0)
		);
	END COMPONENT;
	COMPONENT header IS
		PORT (
			i_clk       : IN std_logic;
			i_data      : IN std_logic_vector (7 DOWNTO 0);
			i_ctrl      : IN header_ctrl_t;
			o_width     : OUT unsigned (7 DOWNTO 0);
			o_height    : OUT unsigned (7 DOWNTO 0);
			o_threshold : OUT unsigned (7 DOWNTO 0)
		);
	END COMPONENT;
	COMPONENT bounding_box IS
		PORT (
			i_rst           : IN std_logic;
			i_enable        : IN std_logic;
			i_clk           : IN std_logic;
			i_data          : IN std_logic_vector (7 DOWNTO 0);
			i_thres         : IN unsigned (7 DOWNTO 0);
			i_x, i_y        : IN std_logic_vector (7 DOWNTO 0)  := (OTHERS => '0');
			o_left, o_right : OUT std_logic_vector (7 DOWNTO 0) := (OTHERS => '0');
			o_top, o_bottom : OUT std_logic_vector (7 DOWNTO 0) := (OTHERS => '0');
			o_zero          : OUT std_logic                     := '1'
		);
	END COMPONENT;
	COMPONENT memory IS
		PORT (
			i_clk     : IN std_logic;
			i_ctrl    : IN memory_ctrl_t;
			i_data    : IN std_logic_vector (15 DOWNTO 0);
			i_address : IN std_logic_vector (15 DOWNTO 0);
			o_address : OUT std_logic_vector (15 DOWNTO 0);
			o_en      : OUT std_logic;
			o_we      : OUT std_logic;
			o_data    : OUT std_logic_vector (7 DOWNTO 0)
		);
	END COMPONENT;
	COMPONENT control_unit IS
		PORT (
			i_clk      : IN std_logic;
			i_start    : IN std_logic;
			i_rst      : IN std_logic;
			i_stop     : IN std_logic;
			i_areadone : IN std_logic;
			o_header   : OUT header_ctrl_t;
			o_memory   : OUT memory_ctrl_t;
			o_area     : OUT std_logic;
			o_en_na    : OUT std_logic;
			o_en_bb    : OUT std_logic;
			o_done     : OUT std_logic
		);
	END COMPONENT;
END component_defs;

PACKAGE BODY component_defs IS
END component_defs;

----------------------------------------------------------------------------------
-- Project
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE work.type_defs.ALL;
USE work.component_defs.ALL;

ENTITY project_reti_logiche IS
	PORT (
		i_clk     : IN std_logic;
		i_start   : IN std_logic;
		i_rst     : IN std_logic;
		i_data    : IN std_logic_vector (7 DOWNTO 0);
		o_address : OUT std_logic_vector (15 DOWNTO 0) := x"0000";
		o_done    : OUT std_logic                      := '0';
		o_en      : OUT std_logic                      := '0';
		o_we      : OUT std_logic                      := '0';
		o_data    : OUT std_logic_vector (7 DOWNTO 0)  := x"00"
	);
END project_reti_logiche;

ARCHITECTURE Structural OF project_reti_logiche IS
	-- Wires
	SIGNAL left, right : std_logic_vector (7 DOWNTO 0);
	SIGNAL top, bottom : std_logic_vector (7 DOWNTO 0);
	SIGNAL is_zero : std_logic;
	SIGNAL x, y : std_logic_vector (7 DOWNTO 0);
	SIGNAL width, height : unsigned (7 DOWNTO 0);
	SIGNAL threshold : unsigned (7 DOWNTO 0);
	SIGNAL area : std_logic_vector (15 DOWNTO 0);
	SIGNAL area_done : std_logic;
	SIGNAL header_ctrl : header_ctrl_t;
	SIGNAL memory_ctrl : memory_ctrl_t;
	SIGNAL area_ctrl : std_logic;
	SIGNAL stop : std_logic;
	SIGNAL next_address : std_logic_vector (15 DOWNTO 0);
	SIGNAL enable_next_address : std_logic;
	SIGNAL enable_bounding : std_logic;
BEGIN
	COMPUTE_AREA : box_area
	PORT MAP(
		i_clk    => i_clk,
		i_rst    => i_rst,
		i_start  => area_ctrl,
		i_zero   => is_zero,
		i_left   => left,
		i_right  => right,
		i_top    => top,
		i_bottom => bottom,
		o_area   => area,
		o_done   => area_done
	);

	SCAN_LOGIC : matrix_idx
	PORT MAP(
		i_clk    => i_clk,
		i_en     => enable_bounding,
		i_width  => width,
		i_height => height,
		o_stop   => stop,
		o_x      => x,
		o_y      => y
	);

	ADDR_COUNTER : address_counter
	PORT MAP(
		i_rst => i_rst,
		i_en  => enable_next_address,
		i_clk => i_clk,
		o_cnt => next_address
	);

	BOUNDINGS : bounding_box
	PORT MAP(
		i_rst    => i_rst,
		i_enable => enable_bounding,
		i_clk    => i_clk,
		i_data   => i_data,
		i_thres  => threshold,
		i_x      => x,
		i_y      => y,
		o_left   => left,
		o_right  => right,
		o_top    => top,
		o_bottom => bottom,
		o_zero   => is_zero
	);

	HEADER_STORAGE : header
	PORT MAP(
		i_ctrl      => header_ctrl,
		i_data      => i_data,
		i_clk       => i_clk,
		o_width     => width,
		o_height    => height,
		o_threshold => threshold
	);

	MEMORY_IF : memory
	PORT MAP(
		i_clk     => i_clk,
		i_ctrl    => memory_ctrl,
		i_data    => area,
		i_address => next_address,
		o_address => o_address,
		o_data    => o_data,
		o_en      => o_en,
		o_we      => o_we
	);

	FSM : control_unit
	PORT MAP(
		i_clk      => i_clk,
		i_start    => i_start,
		i_stop     => stop,
		i_rst      => i_rst,
		i_areadone => area_done,
		o_en_na    => enable_next_address,
		o_en_bb    => enable_bounding,
		o_header   => header_ctrl,
		o_memory   => memory_ctrl,
		o_area     => area_ctrl,
		o_done     => o_done
	);
END Structural;

----------------------------------------------------------------------------------
-- Box Area
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE work.component_defs.ALL;

ENTITY box_area IS
	PORT (
		i_clk, i_rst, i_start : IN std_logic;
		i_zero                : IN std_logic;
		i_left, i_right       : IN std_logic_vector (7 DOWNTO 0);
		i_top, i_bottom       : IN std_logic_vector (7 DOWNTO 0);
		o_area                : OUT std_logic_vector (15 DOWNTO 0);
		o_done                : OUT std_logic
	);
END box_area;

ARCHITECTURE Mixed OF box_area IS
	-- Box width & height
	SIGNAL x : std_logic_vector(7 DOWNTO 0);
	SIGNAL y : std_logic_vector(7 DOWNTO 0);
	-- Area
	SIGNAL mult_res : std_logic_vector(15 DOWNTO 0);
	-- Control wires for the multiplier
	SIGNAL mult_start : std_logic := '0';
	SIGNAL mult_done : std_logic;
BEGIN
	MULT1 : multiplier
	PORT MAP(
		i_clk     => i_clk,
		i_start   => mult_start,
		i_rst     => i_rst,
		i_mplier  => x,
		i_mcand   => y,
		o_done    => mult_done,
		o_product => mult_res
	);

	WITH i_zero SELECT o_area <=
		(OTHERS => '0') WHEN '1',
		mult_res WHEN OTHERS;

	PROCESS (i_clk)
	BEGIN
		IF rising_edge(i_clk) THEN
			IF i_zero = '1' THEN
				o_done <= '1';
			ELSE
				o_done <= mult_done;
			END IF;

			IF i_start = '1' AND i_zero = '0' THEN
				mult_start <= '1';
				x <= std_logic_vector (unsigned (i_right) - unsigned(i_left) + 1);
				y <= std_logic_vector (unsigned (i_bottom) - unsigned(i_top) + 1);
			ELSE
				mult_start <= '0';
			END IF;
		END IF;
	END PROCESS;
END Mixed;

----------------------------------------------------------------------------------
-- Matrix scanning logic
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE work.component_defs.ALL;

ENTITY matrix_idx IS
	PORT (
		i_clk, i_en : IN std_logic;
		i_width     : IN unsigned (7 DOWNTO 0);
		i_height    : IN unsigned (7 DOWNTO 0);
		o_stop      : OUT std_logic;
		o_x         : OUT std_logic_vector (7 DOWNTO 0);
		o_y         : OUT std_logic_vector (7 DOWNTO 0)
	);
END matrix_idx;

ARCHITECTURE Mixed OF matrix_idx IS
	-- Counter status
	SIGNAL x_cnt, y_cnt, x_last, y_last : unsigned (7 DOWNTO 0);
BEGIN
	PROCESS (i_clk, i_en)
	BEGIN
		IF i_en = '0' THEN
			x_cnt <= (OTHERS => '0');
			y_cnt <= (OTHERS => '0');
			x_last <= i_width - 1;
			y_last <= i_height - 1;
		ELSIF rising_edge (i_clk) THEN
			IF x_cnt = x_last THEN
				x_cnt <= (OTHERS => '0');
				y_cnt <= y_cnt + 1;
			ELSE
				x_cnt <= x_cnt + 1;
			END IF;
		END IF;
	END PROCESS;

	o_stop <= '1' WHEN x_cnt = x_last AND y_cnt = y_last ELSE '0';

	o_x <= std_logic_vector (x_cnt);
	o_y <= std_logic_vector (y_cnt);
END Mixed;

----------------------------------------------------------------------------------
-- Address
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE work.component_defs.ALL;

ENTITY address_counter IS
	PORT (
		i_clk, i_en, i_rst : IN std_logic;
		o_cnt              : OUT std_logic_vector (15 DOWNTO 0)
	);
END address_counter;

ARCHITECTURE Mixed OF address_counter IS
	-- Counter status
	SIGNAL cnt : unsigned (15 DOWNTO 0);
	SIGNAL cnt_next : unsigned (15 DOWNTO 0);
BEGIN
	PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			cnt <= x"0002";
		ELSIF rising_edge (i_clk) THEN
			cnt <= cnt_next;
		END IF;
	END PROCESS;

	cnt_next <= cnt + 1 WHEN i_en = '1' ELSE
		cnt;
	o_cnt <= std_logic_vector (cnt);
END Mixed;

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE work.type_defs.ALL;

----------------------------------------------------------------------------------
-- Header storage
----------------------------------------------------------------------------------
ENTITY header IS
	PORT (
		i_clk       : IN std_logic;
		i_data      : IN std_logic_vector (7 DOWNTO 0);
		i_ctrl      : IN header_ctrl_t;
		o_width     : OUT unsigned (7 DOWNTO 0);
		o_height    : OUT unsigned (7 DOWNTO 0);
		o_threshold : OUT unsigned (7 DOWNTO 0)
	);
END header;

ARCHITECTURE Behavioral OF header IS
	-- Image header registers
	SIGNAL width, height : unsigned (7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL threshold : unsigned (7 DOWNTO 0) := (OTHERS => '0');
BEGIN
	o_width <= width;
	o_height <= height;
	o_threshold <= threshold;

	PROCESS (i_clk)
	BEGIN
		IF rising_edge (i_clk) THEN
			CASE i_ctrl IS
				WHEN IDLE =>
					NULL;
				WHEN RESET =>
					width <= (OTHERS => '0');
					height <= (OTHERS => '0');
					threshold <= (OTHERS => '0');
				WHEN STORE_WIDTH =>
					width <= unsigned(i_data);
				WHEN STORE_HEIGHT =>
					height <= unsigned(i_data);
				WHEN STORE_THRES =>
					threshold <= unsigned(i_data);
			END CASE;
		END IF;
	END PROCESS;
END Behavioral;

----------------------------------------------------------------------------------
-- Bounding box
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY bounding_box IS
	PORT (
		i_rst           : IN std_logic;
		i_enable        : IN std_logic;
		i_clk           : IN std_logic;
		i_data          : IN std_logic_vector (7 DOWNTO 0);
		i_thres         : IN unsigned (7 DOWNTO 0);
		i_x, i_y        : IN std_logic_vector (7 DOWNTO 0)  := (OTHERS => '0');
		o_left, o_right : OUT std_logic_vector (7 DOWNTO 0) := (OTHERS => '0');
		o_top, o_bottom : OUT std_logic_vector (7 DOWNTO 0) := (OTHERS => '0');
		o_zero          : OUT std_logic                     := '1'
	);
END bounding_box;

ARCHITECTURE Mixed OF bounding_box IS
	SIGNAL top_found : std_logic := '0';
	SIGNAL left, right : std_logic_vector (7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL top, bottom : std_logic_vector (7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL is_on : std_logic;
BEGIN
	o_zero <= NOT top_found;

	o_top <= top;
	o_bottom <= bottom;
	o_left <= left;
	o_right <= right;

	is_on <= '1' WHEN unsigned (i_data) >= i_thres ELSE '0';

	-- Bounding box algorithm
	PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			left <= (OTHERS => '1');
			right <= (OTHERS => '0');
			bottom <= (OTHERS => '0');
			top <= (OTHERS => '0');
			top_found <= '0';
		ELSIF is_on = '1' AND (i_enable = '1' AND rising_edge (i_clk)) THEN
			IF top_found = '0' THEN
				top_found <= '1';
				top <= i_y;
			END IF;
			IF unsigned(i_y) > unsigned(bottom) THEN
				bottom <= i_y;
			END IF;
			IF unsigned(i_x) < unsigned(left) THEN
				left <= i_x;
			END IF;
			IF unsigned(i_x) > unsigned(right) THEN
				right <= i_x;
			END IF;
		END IF;
	END PROCESS;
END Mixed;

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

USE work.type_defs.ALL;

ENTITY memory IS
	PORT (
		i_clk     : IN std_logic;
		i_ctrl    : IN memory_ctrl_t;
		i_data    : IN std_logic_vector (15 DOWNTO 0);
		i_address : IN std_logic_vector (15 DOWNTO 0);
		o_address : OUT std_logic_vector (15 DOWNTO 0);
		o_en      : OUT std_logic;
		o_we      : OUT std_logic;
		o_data    : OUT std_logic_vector (7 DOWNTO 0)
	);
END memory;

ARCHITECTURE Dataflow OF memory IS
BEGIN
	WITH i_ctrl SELECT o_we <=
		'1' WHEN WRITE_L | WRITE_H,
		'0' WHEN OTHERS;

	WITH i_ctrl SELECT o_en <=
		'1' WHEN WRITE_L | WRITE_H | READ,
		'0' WHEN OTHERS;

	WITH i_ctrl SELECT o_data <=
		i_data (7 DOWNTO 0) WHEN WRITE_L,
		i_data (15 DOWNTO 8) WHEN WRITE_H,
		(OTHERS => '0') WHEN OTHERS;

	WITH i_ctrl SELECT o_address <=
		x"0000" WHEN WRITE_L,
		x"0001" WHEN WRITE_H,
		i_address WHEN READ,
		(OTHERS => '0') WHEN OTHERS;
END Dataflow;

----------------------------------------------------------------------------------
-- Control Unit FSM
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

USE work.type_defs.ALL;

ENTITY control_unit IS
	PORT (
		i_clk      : IN std_logic;
		i_start    : IN std_logic;
		i_rst      : IN std_logic;
		i_stop     : IN std_logic;
		i_areadone : IN std_logic;
		o_header   : OUT header_ctrl_t := RESET;
		o_memory   : OUT memory_ctrl_t := IDLE;
		o_area     : OUT std_logic     := '0';
		o_en_na    : OUT std_logic     := '0';
		o_en_bb    : OUT std_logic     := '0';
		o_done     : OUT std_logic     := '0'
	);
END control_unit;

ARCHITECTURE Behavioral OF control_unit IS
	-- FSM status
	SIGNAL state : state_t := S_IDLE;
BEGIN
	OUTPUT_DECODE : PROCESS (i_clk)
	BEGIN
		IF rising_edge (i_clk) THEN
			CASE state IS
				WHEN S_IDLE =>
					o_done <= '0';
					o_en_bb <= '0';
					o_en_na <= '0';
					o_header <= RESET;
					o_area <= '0';
					o_memory <= IDLE;
				WHEN S_FETCH =>
					o_done <= '0';
					o_en_bb <= '0';
					o_en_na <= '1';
					o_header <= IDLE;
					o_area <= '0';
					o_memory <= READ;
				WHEN S_WIDTH =>
					o_done <= '0';
					o_en_bb <= '0';
					o_en_na <= '1';
					o_header <= STORE_WIDTH;
					o_area <= '0';
					o_memory <= READ;
				WHEN S_HEIGHT =>
					o_done <= '0';
					o_en_bb <= '0';
					o_en_na <= '1';
					o_header <= STORE_HEIGHT;
					o_area <= '0';
					o_memory <= READ;
				WHEN S_THRES =>
					o_done <= '0';
					o_en_bb <= '0';
					o_en_na <= '1';
					o_header <= STORE_THRES;
					o_area <= '0';
					o_memory <= READ;
				WHEN S_IMAGE =>
					IF i_stop = '1' THEN
						o_en_bb <= '0';
						o_en_na <= '0';
						o_memory <= IDLE;
						o_area <= '1';
					ELSE
						o_en_bb <= '1';
						o_en_na <= '1';
						o_memory <= READ;
						o_area <= '0';
					END IF;
					o_done <= '0';
					o_header <= IDLE;
				WHEN S_DIM | S_AREA =>
					o_done <= '0';
					o_en_bb <= '0';
					o_en_na <= '0';
					o_header <= IDLE;
					o_area <= '0';
					o_memory <= IDLE;
				WHEN S_AREAL =>
					o_done <= '0';
					o_en_bb <= '0';
					o_en_na <= '0';
					o_header <= IDLE;
					o_area <= '0';
					o_memory <= WRITE_L;
				WHEN S_AREAH =>
					o_done <= '0';
					o_en_bb <= '0';
					o_en_na <= '0';
					o_header <= IDLE;
					o_area <= '0';
					o_memory <= WRITE_H;
				WHEN S_DONE =>
					o_done <= '1';
					o_en_bb <= '0';
					o_en_na <= '0';
					o_header <= IDLE;
					o_area <= '0';
					o_memory <= IDLE;
			END CASE;
		END IF;
	END PROCESS OUTPUT_DECODE;

	NEXT_STATE_DECODE : PROCESS (i_clk, i_rst)
	BEGIN
		IF (i_rst = '1') THEN
			state <= S_IDLE;
		ELSIF rising_edge (i_clk) THEN
			CASE state IS
				WHEN S_IDLE =>
					IF i_start = '1' THEN
						state <= S_FETCH;
					END IF;
				WHEN S_FETCH =>
					state <= S_WIDTH;
				WHEN S_WIDTH =>
					state <= S_HEIGHT;
				WHEN S_HEIGHT =>
					state <= S_THRES;
				WHEN S_THRES =>
					state <= S_IMAGE;
				WHEN S_IMAGE =>
					IF i_stop = '1' THEN
						state <= S_DIM;
					END IF;
				WHEN S_DIM =>
					state <= S_AREA;
				WHEN S_AREA =>
					IF i_areadone = '1' THEN
						state <= S_AREAL;
					END IF;
				WHEN S_AREAL =>
					state <= S_AREAH;
				WHEN S_AREAH =>
					state <= S_DONE;
				WHEN S_DONE =>
					state <= S_IDLE;
				WHEN OTHERS =>
					state <= S_IDLE;
			END CASE;
		END IF;
	END PROCESS NEXT_STATE_DECODE;
END Behavioral;

----------------------------------------------------------------------------------
-- Multiplier
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY multiplier IS
	PORT (
		i_clk, i_start, i_rst : IN std_logic;
		i_mplier, i_mcand     : IN std_logic_vector (7 DOWNTO 0);
		o_product             : OUT std_logic_vector (15 DOWNTO 0);
		o_done                : OUT std_logic
	);
END multiplier;

ARCHITECTURE Behavioral OF multiplier IS
	-- Status
	SIGNAL state : INTEGER RANGE 0 TO 9 := 0;
	-- Accumulator
	SIGNAL acc : std_logic_vector(15 DOWNTO 0) := (OTHERS => '0');
	-- Aliases
	ALIAS q0 : std_logic IS acc(0); -- LSB
BEGIN
	-- Shift & Add multiplier
	PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			state <= 0;
		ELSIF rising_edge (i_clk) THEN
			CASE state IS
				WHEN 0 =>
					IF i_start = '1' THEN
						acc (15 DOWNTO 8) <= (OTHERS => '0');
						acc (7 DOWNTO 0) <= i_mplier;
						state <= 1;
					END IF;
				WHEN 1 TO 8 =>
					state <= state + 1;
					acc (6 DOWNTO 0) <= acc(7 DOWNTO 1);
					IF q0 = '1' THEN
						acc (15 DOWNTO 7) <= std_logic_vector(
						unsigned('0' & acc (15 DOWNTO 8))
						+ unsigned(i_mcand)
						);
					ELSE
						acc (15 DOWNTO 7) <= '0' & acc (15 DOWNTO 8);
					END IF;
				WHEN 9 =>
					state <= 0;
			END CASE;
		END IF;
	END PROCESS;

	o_done <= '1' WHEN state = 9 ELSE '0';
	o_product <= acc;
END Behavioral;
