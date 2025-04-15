library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity button_debounce is
    generic (
        COUNTER_SIZE : integer := 10_000
    );
    port ( 
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        btn_in : in STD_LOGIC;
        btn_out : out STD_LOGIC
    );
end button_debounce;

architecture Behavioral of button_debounce is
    signal ff : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal count_flag : STD_LOGIC := '0';
begin
    -- define the initial two flip flops
    input_ff : process(clk) is
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ff(0) <= '0';
                ff(1) <= '0';
            else
                ff(0) <= btn_in;
                ff(1) <= ff(0);
            end if;
        end if;
    end process input_ff;
    
    -- this flag tells the module to check to see if the switch has stabilized first
    count_flag <= ff(0) xor ff(1);
    
    -- the purpose of this process is to ensure the outputs of two our flip flops
    -- have stabilized for enough time (hence why we xor the two outputs)
    pause_counter : process(clk) is
        variable count : integer range 0 to COUNTER_SIZE := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                count := 0;
                ff(2) <= '0';
            else
               -- if the button signal has not yet stabilized yet
                if count_flag = '1' then 
                    count := 0;
                elsif count < COUNTER_SIZE then
                    count := count + 1;
                else
                    ff(2) <= ff(1);
                end if;
            end if;
        end if;
    end process pause_counter;
    
    -- the purpose of the last ff is to create another delay which is one master clk cycle long
    output_ff : process(clk) is
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ff(3) <= '0';
            else
                ff(3) <= ff(2);
            end if;
        end if;
    end process output_ff;
    
    btn_out <= ff(3) xor ff(2) when ff(3) = '1' else '0';

end Behavioral;
