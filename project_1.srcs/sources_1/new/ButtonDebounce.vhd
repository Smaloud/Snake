library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity ButtonDebounce is
    Port (
        clk : in std_logic;                    -- 系统时钟(100MHz)
        btn_in : in std_logic;                 -- 按键输入
        btn_out : out std_logic                -- 消抖后的按键输出，按键抬起后输出1次
    );
end ButtonDebounce;
architecture Behavioral of ButtonDebounce is
    signal btn_prev : std_logic := '0';        -- 存储上一个稳定状态，用于边沿检测
    signal btn_sync : std_logic_vector(1 downto 0) := "00";  -- 将按键信号同步到时钟信号
    signal counter : std_logic_vector(20 downto 0) := (others => '0');  -- 消抖计数器
    signal btn_stable : std_logic := '0';      -- 消抖后的稳定信号

begin

    -- 将按键信号同步到时钟
    process(clk)
    begin
        if rising_edge(clk) then
            btn_sync <= btn_sync(0) & btn_in;  -- 移位寄存器，btn_in进入低位，低位移动至高位，用以消除亚稳态
        end if;
    end process;
    
    -- 消抖计数器
    process(clk)
    begin
        if rising_edge(clk) then
            if btn_sync(1) /= btn_stable then  -- 当输入与当前稳定状态不同时
                if counter = 2_000_000 then  -- 计数到2,000,000 (20ms)
                    btn_stable <= btn_sync(1);  -- 更新稳定状态为当前输入
                    counter <= (others => '0');
                else
                    counter <= counter + 1;
                end if;
            else
                counter <= (others => '0');  -- 输入按键与稳定状态相同，重置计数器
            end if;
        end if;
    end process;
    
    -- 边沿检测
    process(clk)
    begin
        if rising_edge(clk) then
            btn_prev <= btn_stable;  -- 保存当前稳定状态用于下次比较
            if btn_prev = '0' and btn_stable = '1' then  -- 前一次是0，当前是1，检测到按键按下的上升沿
                btn_out <= '1';   -- 上升沿时输出一个时钟周期的1，其他时候都输出0，保证一次按键只触发一次
            else
                btn_out <= '0';
            end if;
        end if;
    end process;
end Behavioral;
