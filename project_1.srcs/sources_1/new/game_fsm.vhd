library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity game_fsm is
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;

        start_btn     : in  std_logic;  -- 开始按钮输入
        is_dead       : in  std_logic;  -- 来自 collision_checker 的死亡信号
        is_win        : in  std_logic;  -- 游戏胜利信号
        diff_btn1     : in  std_logic;  -- 难度选择按钮1
        diff_btn2     : in  std_logic;  -- 难度选择按钮2
        diff_btn3     : in  std_logic;  -- 难度选择按钮3
        back_btn      : in  std_logic;  -- 返回按钮

        current_state : out std_logic_vector(1 downto 0);  -- 状态编码：00-菜单, 01-初始化, 10-游戏中, 11-游戏结束
        difficulty    : out std_logic_vector(1 downto 0)   -- 难度选择：00-简单，01-中等，10-困难
    );
end game_fsm;

architecture Behavioral of game_fsm is
    -- 状态定义
    type state_type is (MENU, INIT_GAME, RUNNING, GAME_OVER);
    signal state_r : state_type := MENU;
    signal diff_r  : std_logic_vector(1 downto 0) := "00";  -- 默认简单难度
    
    -- 消抖计数器
    constant DEBOUNCE_LIMIT : integer := 500000;  -- 5ms@100MHz
    signal debounce_counter : integer range 0 to DEBOUNCE_LIMIT := 0;
    
    -- 按键状态寄存器
    signal diff_btn1_reg : std_logic_vector(1 downto 0) := "11";
    signal diff_btn2_reg : std_logic_vector(1 downto 0) := "11";
    signal diff_btn3_reg : std_logic_vector(1 downto 0) := "11";
    signal start_btn_reg : std_logic_vector(1 downto 0) := "11";
    signal back_btn_reg  : std_logic_vector(1 downto 0) := "11";

begin
    -- 按键消抖和状态控制过程
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state_r <= MENU;
            diff_r <= "00";
            debounce_counter <= 0;
            diff_btn1_reg <= "11";
            diff_btn2_reg <= "11";
            diff_btn3_reg <= "11";
            start_btn_reg <= "11";
            back_btn_reg <= "11";

        elsif rising_edge(clk) then
            -- 移位寄存器采样按键状态
            diff_btn1_reg <= diff_btn1_reg(0) & diff_btn1;
            diff_btn2_reg <= diff_btn2_reg(0) & diff_btn2;
            diff_btn3_reg <= diff_btn3_reg(0) & diff_btn3;
            start_btn_reg <= start_btn_reg(0) & start_btn;
            back_btn_reg <= back_btn_reg(0) & back_btn;
            
            -- 消抖计数
            if debounce_counter = DEBOUNCE_LIMIT then
                debounce_counter <= 0;
                
                case state_r is
                    when MENU =>
                        -- 在菜单状态下处理难度选择
                        if diff_btn1_reg = "00" then
                            diff_r <= "00";  -- 简单
                        elsif diff_btn2_reg = "00" then
                            diff_r <= "01";  -- 中等
                        elsif diff_btn3_reg = "00" then
                            diff_r <= "10";  -- 困难
                        end if;
                        
                        -- 开始游戏
                        if start_btn_reg = "00" then
                            state_r <= INIT_GAME;
                        end if;

                    when INIT_GAME =>
                        state_r <= RUNNING;

                    when RUNNING =>
                        if is_dead = '1' or is_win = '1' then
                            state_r <= GAME_OVER;
                        end if;

                    when GAME_OVER =>
                        if back_btn_reg = "00" then
                            state_r <= MENU;
                        end if;

                    when others =>
                        state_r <= MENU;
                end case;
            else
                debounce_counter <= debounce_counter + 1;
            end if;
        end if;
    end process;

    -- 状态编码为2-bit输出
    current_state <= 
        "00" when state_r = MENU else
        "01" when state_r = INIT_GAME else
        "10" when state_r = RUNNING else
        "11";  -- GAME_OVER

    -- 输出当前难度
    difficulty <= diff_r;

end Behavioral;
