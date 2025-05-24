library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity game_fsm is
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;

        -- 移除start_btn，依靠难度按键直接开始游戏
        is_dead       : in  std_logic;  -- 来自 collision_checker 的死亡信号
        is_win        : in  std_logic;  -- 游戏胜利信号
        diff_btn1     : in  std_logic;  -- 难度选择按钮1
        diff_btn2     : in  std_logic;  -- 难度选择按钮2
        diff_btn3     : in  std_logic;  -- 难度选择按钮3
        back_btn      : in  std_logic;  -- 返回按钮
        
        -- 添加方向键输入
        up_btn        : in  std_logic;  -- 上方向键
        down_btn      : in  std_logic;  -- 下方向键
        left_btn      : in  std_logic;  -- 左方向键
        right_btn     : in  std_logic;  -- 右方向键

        current_state : out std_logic_vector(1 downto 0);  -- 状态编码：00-菜单, 01-初始化, 10-游戏中, 11-游戏结束
        difficulty    : out std_logic_vector(1 downto 0)   -- 难度选择：00-简单，01-中等，10-困难
    );
end game_fsm;

architecture Behavioral of game_fsm is
    -- 状态定义
    type state_type is (MENU, INIT_GAME, RUNNING, GAME_OVER);
    signal state_r : state_type := MENU;
    signal diff_r  : std_logic_vector(1 downto 0) := "00";  -- 默认简单难度

begin
    -- 状态控制过程
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state_r <= MENU;
            diff_r <= "00";

        elsif rising_edge(clk) then
            case state_r is
                when MENU =>
                    -- 在菜单状态下处理难度选择并直接开始游戏
                    if diff_btn1 = '1' then
                        diff_r <= "00";  -- 简单
                        state_r <= INIT_GAME;  -- 直接进入初始化状态
                    elsif diff_btn2 = '1' then
                        diff_r <= "01";  -- 中等
                        state_r <= INIT_GAME;  -- 直接进入初始化状态
                    elsif diff_btn3 = '1' then
                        diff_r <= "10";  -- 困难
                        state_r <= INIT_GAME;  -- 直接进入初始化状态
                    end if;

                when INIT_GAME =>
                    -- 等待方向键输入才进入RUNNING状态
                    if up_btn = '1' or down_btn = '1' or left_btn = '1' or right_btn = '1' then
                        state_r <= RUNNING;
                    end if;

                when RUNNING =>
                    if is_dead = '1' or is_win = '1' then
                        state_r <= GAME_OVER;
                    end if;

                when GAME_OVER =>
                    if back_btn = '1' then
                        state_r <= MENU;
                    end if;

                when others =>
                    state_r <= MENU;
            end case;
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
