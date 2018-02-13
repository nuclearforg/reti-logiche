library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity project_reti_logiche is
    port (
        i_clk      : in  std_logic;
        i_start    : in  std_logic;
        i_rst      : in  std_logic;
        i_data     : in  std_logic_vector (7 downto 0); --1 byte
        o_address  : out std_logic_vector (15 downto 0); --16 bit addr: max size is 255*255 + 3 more for max x and y and thresh.
        o_done     : out std_logic;
        o_en       : out std_logic;
        o_we       : out std_logic;
        o_data     : out std_logic_vector (7 downto 0)
      );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
    -- FSM status
    type state_t is (S_IDLE, S_START, S_WIDTH, S_HEIGHT, S_THRES, S_IMAGE, S_AREAL, S_AREAH, S_DONE);
    signal state : state_t;
    
    -- Next address register for sequential image reading
    signal next_address : std_logic_vector (15 downto 0);
    
    -- Image header registers
    signal width     : std_logic_vector (7 downto 0);
    signal height    : std_logic_vector (7 downto 0);
    signal threshold : std_logic_vector (7 downto 0);
    
    -- Status registers
    signal x : std_logic_vector (7 downto 0);
    signal y : std_logic_vector (7 downto 0);
    signal left   : std_logic_vector (7 downto 0);
    signal right  : std_logic_vector (7 downto 0);
    signal top    : std_logic_vector (7 downto 0);
    signal bottom : std_logic_vector (7 downto 0);
    signal top_found  : std_logic;
    
    -- Rectangle area
    signal area : std_logic_vector (15 downto 0);
begin
    -- Counters for pixel coordinates
    COUNTERS_PROC: process (i_clk)
    begin
        if falling_edge(i_clk) then
            case state is
                when S_IMAGE =>
                    if unsigned(x) >= (unsigned(width) - 1) then
                        x <= x"00";
                        y <= std_logic_vector(unsigned(y) + 1);
                    else
                        x <= std_logic_vector(unsigned(x) + 1);
                    end if;
                when others =>
                    x <= x"00";
                    y <= x"00";
            end case;
        end if;
    end process COUNTERS_PROC;
    
    -- Box area calculation
    COMPUTE_AREA: process (left, right, bottom, top)
    begin
        if top_found = '0' or state = S_IDLE then
            area <= x"0000";
        else
            area <= std_logic_vector((unsigned(right)-unsigned(left)+1)*(unsigned(bottom)-unsigned(top)+1));
        end if;
    end process COMPUTE_AREA;
    
    -- Bounding box algorithm
    REGS_PROC: process (i_clk)
    begin
        if falling_edge(i_clk) then
            case state is
                when S_IDLE =>
                    right      <= x"00";
                    bottom     <= x"00";
                    top        <= x"00";
                    top_found  <= '0';
                when S_WIDTH =>
                    width      <= i_data;
                    left       <= i_data;
                when S_HEIGHT =>
                    height     <= i_data;
                when S_THRES =>
                    threshold  <= i_data;
                when S_IMAGE =>
                    if unsigned(i_data) >= unsigned(threshold) then
                        if top_found = '0' then
                            top_found  <= '1';
                            top        <= y;
                        end if;
                        if unsigned(y) > unsigned(bottom) then
                            bottom     <= y;
                        end if;
                        if unsigned(x) < unsigned(left) then
                            left       <= x;
                        end if;
                        if unsigned(x) > unsigned(right) then
                            right      <= x;
                        end if;
                    end if;
                when others =>
            end case;
        end if;
    end process REGS_PROC;
    
    -- Output function
    OUTPUT_DECODE: process (i_clk)
    begin
        if falling_edge(i_clk) then
            o_done    <= '0';
            o_we      <= '0';
            o_en      <= '0';
            o_data    <= "--------";
            o_address <= "----------------";
            case state is
                when S_IDLE =>
                    next_address <= x"0002";
                when S_AREAL =>
                    o_en      <= '1';
                    o_we      <= '1';
                    o_data    <= area(7 downto 0);
                    o_address <= x"0000";
                when S_AREAH =>
                    o_en      <= '1';
                    o_we      <= '1';
                    o_data    <= area(15 downto 8);
                    o_address <= x"0001";
                when S_DONE =>
                    o_done    <= '1';
                when others =>
                    o_en      <= '1';
                    o_address <= next_address;
                    next_address <= std_logic_vector(unsigned(next_address) + 1);
            end case;
        end if;
    end process OUTPUT_DECODE;
    
    NEXT_STATE_DECODE: process (i_clk, i_rst)
    begin
        if(i_rst = '1') then
            state <= S_IDLE; -- i_rst is asyncronous and forces status to IDLE
        elsif falling_edge(i_clk) then
            case state is
                when S_IDLE =>
                    if (i_start = '1') then
                        state <= S_START; -- Start reading if i_start is raised (syncronous)
                    end if;
                when S_START =>
                    state <= S_WIDTH;
                when S_WIDTH =>
                    state <= S_HEIGHT;
                when S_HEIGHT =>
                    state <= S_THRES;
                when S_THRES =>
                    state <= S_IMAGE;
                when S_IMAGE =>
                    if unsigned(x) >= (unsigned(width) - 1) and unsigned(y) >= (unsigned(height) - 1) then
                        state <= S_AREAL; -- Write result to RAM if we read the entire image
                    end if;
                when S_AREAL =>
                    state <= S_AREAH;
                when S_AREAH =>
                    state <= S_DONE;
                when S_DONE =>
                    state <= S_IDLE;
                when others =>
                    state <= S_IDLE;
            end case;
        end if;
    end process NEXT_STATE_DECODE;
    
end Behavioral;
