library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_controller is
    generic (
        SCREEN_WIDTH  : integer := 800;  -- 屏幕宽度
        SCREEN_HEIGHT : integer := 600;  -- 屏幕高度
        SQUARE_SIZE   : integer := 40;   -- 蛇身方块大小
        MAX_SNAKE_LEN : integer := 300  -- 最大蛇身长度 = (SCREEN_WIDTH/SQUARE_SIZE) * (SCREEN_HEIGHT/SQUARE_SIZE)
    );
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        general_state : in  std_logic_vector(1 downto 0);  -- 状态码：00-菜单, 01-初始化, 10-运行中, 11-游戏结束
        move_state    : in  std_logic_vector(4 downto 0);
        flag_update   : in  std_logic;  -- 控制每帧移动
        food_x        : in  unsigned(4 downto 0);  -- 食物x坐标
        food_y        : in  unsigned(3 downto 0);   -- 食物y坐标
        flag_food_ready : in std_logic;  -- 食物已准备好的信号

        snake_length  : out std_logic_vector(8 downto 0);  -- 扩展到12位，支持最大300
        snake_map     : out std_logic_vector(299 downto 0);  -- 输出蛇身位置图
        is_win        : out std_logic;   -- 游戏胜利信号
        is_dead       : out std_logic;   -- 游戏失败信号
        flag_eat      : out std_logic   -- 食物被吃掉的信号
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

    type coord_array is array (0 to MAX_SNAKE_LEN-1) of unsigned(4 downto 0);
    type coord_y_array is array (0 to MAX_SNAKE_LEN-1) of unsigned(3 downto 0);

    signal snake_x_buf   : coord_array;
    signal snake_y_buf   : coord_y_array;
    signal snake_len_r   : unsigned(8 downto 0);
    signal current_dir   : std_logic_vector(4 downto 0); --当前方向
    signal is_win_r      : std_logic;
    signal snake_map_r   : std_logic_vector(299 downto 0);  -- 20*15=300位，表示蛇身位置
    signal flag_eat_r    : std_logic := '0';  -- 内部吃食物信号
    
begin
    -- 移动控制
    process(flag_update, rst_n)
    begin
        if rst_n = '0' then
            for i in 0 to LENGTH_INIT-1 loop
                snake_x_buf(i) <= to_unsigned(GRID_WIDTH/2 - i, 5);
                snake_y_buf(i) <= to_unsigned(GRID_HEIGHT/2, 4);
            end loop;
            snake_len_r <= to_unsigned(LENGTH_INIT, 9);
            current_dir <= STOP;
            is_win_r <= '0';
            flag_eat_r <= '0';
        elsif rising_edge(flag_update) then
            if general_state = "01" then  -- 游戏初始化
                snake_len_r <= to_unsigned(LENGTH_INIT, 9);
                current_dir <= STOP;
                is_win_r <= '0';
                flag_eat_r <= '0';
                -- 初始化蛇身位置
                for i in 0 to LENGTH_INIT-1 loop
                    snake_x_buf(i) <= to_unsigned(GRID_WIDTH/2 - i, 5);
                    snake_y_buf(i) <= to_unsigned(GRID_HEIGHT/2, 4);
                end loop;
            elsif general_state = "10" then  -- 游戏中
                -- 更新方向（可防止反向移动逻辑）
                if move_state /= STOP then
                    current_dir <= move_state;
                end if;

                -- 每帧更新一次位置
                -- 吃到食物增加一节
                if flag_eat_r = '1' and flag_food_ready = '1' and snake_len_r < to_unsigned(MAX_SNAKE_LEN, 9) then
                    flag_eat_r <= '0';  -- 食物已处理，重置信号
                end if;
                
                if flag_eat_r = '1' and snake_len_r < to_unsigned(MAX_SNAKE_LEN, 9) then
                    snake_len_r <= snake_len_r + 1;
                
                    -- 检查是否填满屏幕
                    if snake_len_r >= to_unsigned(MAX_SNAKE_LEN, 9) then
                        is_win_r <= '1';
                    end if;
                end if;

                -- 整体尾部向头部移动（shift）
                for i in MAX_SNAKE_LEN-1 downto 1 loop
                    if i < to_integer(snake_len_r) then
                        snake_x_buf(i) <= snake_x_buf(i-1);
                        snake_y_buf(i) <= snake_y_buf(i-1);
                    end if;
                end loop;

                -- 根据方向更新头部位置
                case current_dir is
                    when FACE_UP    => snake_y_buf(0) <= snake_y_buf(0) - 1;
                    when FACE_DOWN  => snake_y_buf(0) <= snake_y_buf(0) + 1;
                    when FACE_LEFT  => snake_x_buf(0) <= snake_x_buf(0) - 1;
                    when FACE_RIGHT => snake_x_buf(0) <= snake_x_buf(0) + 1;
                    when others     => null;
                end case;
                
                -- 检查是否吃到食物
                if food_x = snake_x_buf(0) and food_y = snake_y_buf(0) then
                    flag_eat_r <= '1';
                end if;
            end if;
        end if;
    end process;

    -- 检查是否撞到墙壁或自身
    process(snake_x_buf, snake_y_buf, snake_len_r)
    begin
        is_dead <= '0';
        if snake_x_buf(0) < 1 or snake_x_buf(0) > to_unsigned(GRID_WIDTH, 5) or
           snake_y_buf(0) < 1 or snake_y_buf(0) > to_unsigned(GRID_HEIGHT, 4) or
           snake_map_r(to_integer(snake_x_buf(0)-1) + to_integer(snake_y_buf(0)-1)*GRID_WIDTH) = '1' then
            is_dead <= '1';
        end if;
    end process;

    -- 更新蛇身位置图
    process(snake_x_buf, snake_y_buf, snake_len_r)
    begin
        snake_map_r <= (others => '0');
        for i in 0 to MAX_SNAKE_LEN-1 loop
            if i < to_integer(snake_len_r) then
                snake_map_r(to_integer(snake_x_buf(i)-1) + to_integer(snake_y_buf(i)-1)*GRID_WIDTH) <= '1';
            end if;
        end loop;
    end process;

    -- 输出长度和坐标
    snake_length <= std_logic_vector(snake_len_r);
    is_win <= is_win_r;
    snake_map <= snake_map_r;
    flag_eat <= flag_eat_r;  -- 将内部信号连接到输出端口

end Behavioral;
