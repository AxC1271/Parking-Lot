library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parking_lot is
    port ( 
        clk : in STD_LOGIC; -- internal clock
        rst : in STD_LOGIC; -- rst pin
        entr : in STD_LOGIC; -- entrance, handled by a debounced switch/button
        ex : in STD_LOGIC; -- exit, handled by a debounced switch/button
        start : in STD_LOGIC; -- manual start flag, handled by a switch
        stop : in STD_LOGIC; -- manual stop flag, handled by a switch
        set_count : in STD_LOGIC_VECTOR(4 downto 0); -- manual override as specified in problem
        set_en : in STD_LOGIC; -- enable pin for the set_count, also handled by a switch
        op : out STD_LOGIC; -- open
        full : out STD_LOGIC; -- full flag from reaching max capacity
        closed : out STD_LOGIC; -- closed flag from stop flag, could also be from full capacity
        anode : out STD_LOGIC_VECTOR(3 downto 0);
        segment : out STD_LOGIC_VECTOR(6 downto 0)
        ); 
end parking_lot;

architecture Behavioral of parking_lot is
    -- we define internal signals for our process logic
    signal count : integer range 0 to 20 := 0;
    signal op_i : STD_LOGIC := '1';
    signal full_i : STD_LOGIC := '0';
    signal closed_i : STD_LOGIC := '0';
    signal debounced_entr : STD_LOGIC;
    signal debounced_ex : STD_LOGIC;
    signal clk_1kHz : STD_LOGIC := '0';
    signal anode_i : STD_LOGIC_VECTOR(3 downto 0) := "1111";
    signal segment_i : STD_LOGIC_VECTOR(6 downto 0) := "1111111";
    
    -- custom defined minimum function
    function minimum(a, b : integer) return integer is
    begin
        if a < b then
            return a;
        else
            return b;
        end if;
    end function;

begin 
    -- define our instantiated debounced button modules to ensure proper behavior
    debounce_entr : entity work.button_debounce 
        port map (
            clk => clk,
            rst => rst,
            btn_in => entr,
            btn_out => debounced_entr
        );
        
    debounce_ex : entity work.button_debounce 
        port map (
            clk => clk,
            rst => rst,
            btn_in => ex,
            btn_out => debounced_ex
        );
    
    -- this is optional but required for the count display process
    clock_divider : process(clk) is
        constant max : integer := (100_000_000 / 1000) / 2;
        variable clk_count : integer range 0 to max := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                clk_count := 0;
                clk_1kHz <= '0';
            elsif clk_count = max then
                clk_count := 0;
                clk_1kHz <= not clk_1kHz;
            else
                clk_count := clk_count + 1;
            end if; 
        end if;
    end process clock_divider;
    
    -- we now handle the explicit definition of our state machine controller
    parking_lot_FSM : process(clk, count) is
    begin
        if rising_edge(clk) then
            -- check the rst case first
            if rst = '1' then
                count <= 0;
                op_i <= '1';
                full_i <= '0';
                closed_i <= '0';
            elsif start = '1' then
                op_i <= '1';
            elsif stop = '1' then
                closed_i <= '1';
            end if;
            -- only check for xor conditions, 00 and 11 do not change state
            -- we also check to see that it's not full yet at 20
            if debounced_entr = '1' and debounced_ex = '0' and full_i = '0' then
                count <= count + 1;
            -- so that we don't decrement when we have count at 0
            elsif debounced_entr = '0' and debounced_ex = '1' and count > 0 then
                count <= count - 1;
            elsif set_en = '1' then
                count <= minimum(to_integer(unsigned(set_count)), 20);
            end if;      
        end if;
        
        case count is
            when 20 =>
                full_i <= '1';
            when others =>
                full_i <= '0';
        end case;
    end process parking_lot_FSM;
    
    anode_selector : process(clk_1kHz) is
        variable clk_count : integer range 0 to 3 := 0;
    begin
        if rising_edge(clk_1kHz) then
            if rst = '1' then
                anode_i <= "1111";
            else
                if clk_count = 3 then
                    clk_count := 0;
                else
                    clk_count := clk_count + 1;
                end if;
            end if;
            
            case clk_count is
                when 0 =>
                    anode_i <= "1110";
                when 1 =>
                    anode_i <= "1101";
                when 2 =>
                    anode_i <= "1011";
                when others =>
                    anode_i <= "0111";
            end case;
        end if;
    end process anode_selector;
    
    -- to visibly see the results, we will do a simple 7-segment driver here
    count_display : process(clk_1kHz) is 
        variable temp : integer range 0 to 9 := 0;
    begin
        if rising_edge(clk_1kHz) then
            if rst = '1' then
                segment_i <= "1111111";
            end if;
            
            case anode_i is
                when "1110" =>
                    temp := count mod 10;
                when "1101" =>
                    temp := (count / 10) mod 10;
                when "1011" =>
                    temp := (count / 100) mod 10;
                when "0111" =>
                    temp := (count / 1000) mod 10;
                when others =>
                    temp := 0;
            end case;
            
            case temp is
                when 0 =>
                    segment_i <= "0000001";
                when 1 =>
                    segment_i <= "1001111";
                when 2 =>
                    segment_i <= "0010010";
                when 3 =>
                    segment_i <= "0000110";
                when 4 =>
                    segment_i <= "1001100";
                when 5 =>
                    segment_i <= "0100100";
                when 6 =>
                    segment_i <= "0100000";
                when 7 =>
                    segment_i <= "0001111";
                when 8 =>
                    segment_i <= "0000000";
                when 9 =>
                    segment_i <= "0000100";
                when others =>
                    segment_i <= "1111111";
            end case;         
        end if;
    end process count_display;

    -- final output assignments
    op <= op_i;
    full <= full_i;
    closed <= closed_i;
    anode <= anode_i;
    segment <= segment_i;

end Behavioral;
