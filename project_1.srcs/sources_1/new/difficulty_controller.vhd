library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity difficulty_controller is
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        difficulty    : in  std_logic_vector(1 downto 0);  -- 难度选择：00-简单，01-中等，10-困难
        
        speed_divider : out std_logic_vector(31 downto 0)  -- 速度分频系数
    );
end difficulty_controller;

architecture Behavioral of difficulty_controller is
    -- 不同难度对应的速度分频系数（数值越大，移动越慢）
    constant EASY_SPEED   : integer := 1000000;  -- 1MHz分频
    constant MEDIUM_SPEED : integer := 500000;   -- 2MHz分频
    constant HARD_SPEED   : integer := 250000;   -- 4MHz分频
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            speed_divider <= std_logic_vector(to_unsigned(EASY_SPEED, 32));
        elsif rising_edge(clk) then
            case difficulty is
                when "00" =>  -- 简单
                    speed_divider <= std_logic_vector(to_unsigned(EASY_SPEED, 32));
                when "01" =>  -- 中等
                    speed_divider <= std_logic_vector(to_unsigned(MEDIUM_SPEED, 32));
                when "10" =>  -- 困难
                    speed_divider <= std_logic_vector(to_unsigned(HARD_SPEED, 32));
                when others =>
                    speed_divider <= std_logic_vector(to_unsigned(EASY_SPEED, 32));
            end case;
        end if;
    end process;
end Behavioral; 