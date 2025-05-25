library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ButtonDebounce is
    generic (
        DEBOUNCE_DELAY : integer  -- 默认消抖延时
    );
    port (
        clk     : in  std_logic;
        btn_in  : in  std_logic;
        btn_out : out std_logic
    );
end ButtonDebounce;

architecture Behavioral of ButtonDebounce is
    signal btn_sync   : std_logic_vector(1 downto 0) := (others => '0');
    signal btn_stable : std_logic := '0';
    signal btn_prev   : std_logic := '0';
    signal counter    : unsigned(19 downto 0) := (others => '0');
begin

    -- 双触发同�?
    process(clk)
    begin
        if rising_edge(clk) then
            btn_sync <= btn_sync(0) & btn_in;
        end if;
    end process;

    -- 消抖 + 稳定确认
    process(clk)
    begin
        if rising_edge(clk) then
            if btn_sync(1) = btn_sync(0) then
                if counter < DEBOUNCE_DELAY-1 then
                    counter <= counter + 1;
                end if;
            else
                counter <= (others => '0');
            end if;

            if counter = DEBOUNCE_DELAY-1 then
                btn_stable <= btn_sync(1);
            end if;
        end if;
    end process;

    -- 上升沿检测（按下出脉冲）
    process(clk)
    begin
        if rising_edge(clk) then
            btn_prev <= btn_stable;
            if (btn_prev = '0') and (btn_stable = '1') then
                btn_out <= '1';
            else
                btn_out <= '0';
            end if;
        end if;
    end process;

end Behavioral;
