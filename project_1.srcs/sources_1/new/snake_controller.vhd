library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_controller is
    generic (
        SCREEN_WIDTH  : integer := 640;  -- 屏幕宽度
        SCREEN_HEIGHT : integer := 480;  -- 屏幕高度
        SQUARE_SIZE   : integer := 20;   -- 蛇身方块大小
        MAX_SNAKE_LEN : integer := 3072  -- 最大蛇身长度 = (SCREEN_WIDTH/SQUARE_SIZE) * (SCREEN_HEIGHT/SQUARE_SIZE)
    );
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        general_state : in  std_logic_vector(2 downto 0);  -- 状态码扩展到3位
        move_state    : in  std_logic_vector(4 downto 0);
        flag_update   : in  std_logic;  -- 控制每帧移动
        flag_eat      : in  std_logic;  -- 吃到食物时置位

        snake_length  : out std_logic_vector(11 downto 0);  -- 扩展到12位，支持最大3072
        snake_x       : out std_logic_vector(MAX_SNAKE_LEN*10-1 downto 0);  -- 动态位宽
        snake_y       : out std_logic_vector(MAX_SNAKE_LEN*10-1 downto 0);  -- 动态位宽
        is_win        : out std_logic   -- 游戏胜利信号
    );
end snake_controller;

architecture Behavioral of snake_controller is
    constant LENGTH_INIT  : integer := 3;
    constant GRID_WIDTH   : integer := SCREEN_WIDTH/SQUARE_SIZE;
    constant GRID_HEIGHT  : integer := SCREEN_HEIGHT/SQUARE_SIZE;

    -- 方向常量
    constant STOP        : std_logic_vector(4 downto 0) := "00001";
    constant FACE_UP     : std_logic_vector(4 downto 0) := "00010";
    constant FACE_DOWN   : std_logic_vector(4 downto 0) := "00100";
    constant FACE_LEFT   : std_logic_vector(4 downto 0) := "01000";
    constant FACE_RIGHT  : std_logic_vector(4 downto 0) := "10000";

    type coord_array is array (0 to MAX_SNAKE_LEN-1) of unsigned(9 downto 0);
    type coord_y_array is array (0 to MAX_SNAKE_LEN-1) of unsigned(8 downto 0);

    signal snake_x_buf   : coord_array;
    signal snake_y_buf   : coord_y_array;
    signal snake_len_r   : unsigned(11 downto 0);
    signal current_dir   : std_logic_vector(4 downto 0);
    signal is_win_r      : std_logic;
    
begin
    -- 移动控制
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            snake_len_r <= to_unsigned(LENGTH_INIT, 12);
            current_dir <= STOP;
            is_win_r <= '0';

            -- 初始化蛇的位置，默认横向
            for i in 0 to MAX_SNAKE_LEN-1 loop
                snake_x_buf(i) <= to_unsigned((SCREEN_WIDTH/2) - i*SQUARE_SIZE, 10);
                snake_y_buf(i) <= to_unsigned(SCREEN_HEIGHT/2, 9);
            end loop;

        elsif rising_edge(clk) then
            if general_state = "010" then  -- 游戏初始化
                snake_len_r <= to_unsigned(LENGTH_INIT, 12);
                current_dir <= STOP;
                is_win_r <= '0';
            elsif general_state = "011" then  -- 游戏中
                -- 更新方向（可防止反向移动逻辑）
                if move_state /= STOP then
                    current_dir <= move_state;
                end if;

                -- 每帧更新一次位置
                if flag_update = '1' then
                    -- 整体尾部向头部移动（shift）
                    for i in MAX_SNAKE_LEN-1 downto 1 loop
                        if i < to_integer(snake_len_r) then
                            snake_x_buf(i) <= snake_x_buf(i-1);
                            snake_y_buf(i) <= snake_y_buf(i-1);
                        end if;
                    end loop;

                    -- 根据方向更新头部位置
                    case current_dir is
                        when FACE_UP    => snake_y_buf(0) <= snake_y_buf(0) - to_unsigned(SQUARE_SIZE, 9);
                        when FACE_DOWN  => snake_y_buf(0) <= snake_y_buf(0) + to_unsigned(SQUARE_SIZE, 9);
                        when FACE_LEFT  => snake_x_buf(0) <= snake_x_buf(0) - to_unsigned(SQUARE_SIZE, 10);
                        when FACE_RIGHT => snake_x_buf(0) <= snake_x_buf(0) + to_unsigned(SQUARE_SIZE, 10);
                        when others     => null;
                    end case;

                    -- 吃到食物增加一节
                    if flag_eat = '1' and snake_len_r < to_unsigned(MAX_SNAKE_LEN, 12) then
                        snake_len_r <= snake_len_r + 1;
                        
                        -- 检查是否填满屏幕
                        if snake_len_r + 1 >= to_unsigned(GRID_WIDTH * GRID_HEIGHT, 12) then
                            is_win_r <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- 输出长度和坐标
    snake_length <= std_logic_vector(snake_len_r);
    is_win <= is_win_r;

    -- 输出蛇身坐标
    process(snake_x_buf)
    begin
        for i in 0 to MAX_SNAKE_LEN-1 loop
            snake_x(i*10+9 downto i*10) <= std_logic_vector(snake_x_buf(i));
        end loop;
    end process;

    process(snake_y_buf)
    begin
        for i in 0 to MAX_SNAKE_LEN-1 loop
            snake_y(i*10+9 downto i*10) <= std_logic_vector(resize(snake_y_buf(i), 10));
        end loop;
    end process;

end Behavioral;
