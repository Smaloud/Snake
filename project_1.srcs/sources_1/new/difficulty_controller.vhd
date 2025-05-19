library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity difficulty_controller is
    port (
        clk           : in  std_logic;  -- 系统时钟，假设100MHz
        rst_n         : in  std_logic;
        difficulty    : in  std_logic_vector(1 downto 0);  -- 难度选择：00-简单，01-中等，10-困难
        
        update_signal : out std_logic  -- 输出更新信号
    );
end difficulty_controller;

architecture Behavioral of difficulty_controller is
    -- 不同难度对应的速度分频系数（数值越大，移动越慢）
    constant EASY_SPEED   : integer := 100000000;  -- 1Hz (1秒/格)
    constant MEDIUM_SPEED : integer := 50000000;  -- 2Hz (0.5秒/格)
    constant HARD_SPEED   : integer := 25000000;  -- 4Hz (0.25秒/格)
    
    signal counter : unsigned(31 downto 0) := (others => '0');
    signal divider : unsigned(31 downto 0) := to_unsigned(EASY_SPEED, 32);
begin
    -- 更新分频系数
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            divider <= to_unsigned(EASY_SPEED, 32);
        elsif rising_edge(clk) then
            case difficulty is
                when "00" =>  -- 简单
                    divider <= to_unsigned(EASY_SPEED, 32);
                when "01" =>  -- 中等
                    divider <= to_unsigned(MEDIUM_SPEED, 32);
                when "10" =>  -- 困难
                    divider <= to_unsigned(HARD_SPEED, 32);
                when others =>
                    divider <= to_unsigned(EASY_SPEED, 32);
            end case;
        end if;
    end process;

    -- 生成更新信号
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            counter <= (others => '0');
            update_signal <= '0';
        elsif rising_edge(clk) then
            if counter >= divider then
                counter <= (others => '0');
                update_signal <= not update_signal;  -- 翻转信号，生成时钟
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

end Behavioral; 