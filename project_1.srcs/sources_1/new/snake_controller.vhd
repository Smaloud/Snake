library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_controller is
    generic (
        SCREEN_WIDTH  : integer := 800;  -- 屏幕宽度
        SCREEN_HEIGHT : integer := 600;  -- 屏幕高度
        SQUARE_SIZE   : integer := 40;   -- 蛇身方块大小
        MAX_SNAKE_LEN : integer := 300  -- 最大蛇身长度
    );
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        general_state : in  std_logic_vector(1 downto 0);  -- 状态码：00-菜单, 01-初始化, 10-运行中, 11-游戏结束
        move_state    : in  std_logic_vector(4 downto 0);
        flag_update   : in  std_logic;  -- 控制每帧移动
        food_x        : in  unsigned(4 downto 0);  -- 食物x坐标
        food_y        : in  unsigned(3 downto 0);   -- 食物y坐标

        snake_length  : out std_logic_vector(8 downto 0);  -- 蛇的长度
        snake_map     : out std_logic_vector(299 downto 0);  -- 输出蛇身位置图
        is_win        : out std_logic;   -- 游戏胜利信号
        is_dead       : out std_logic;   -- 游戏失败信号
        flag_eat      : out std_logic   -- 食物被吃掉的信号
    );
end snake_controller;

architecture Behavioral of snake_controller is
    constant LENGTH_INIT  : integer := 3;
    constant GRID_WIDTH   : integer := SCREEN_WIDTH/SQUARE_SIZE;   -- 20
    constant GRID_HEIGHT  : integer := SCREEN_HEIGHT/SQUARE_SIZE;  -- 15

    -- 方向常量
    constant STOP        : std_logic_vector(4 downto 0) := "00001";
    constant FACE_UP     : std_logic_vector(4 downto 0) := "00010";
    constant FACE_DOWN   : std_logic_vector(4 downto 0) := "00100";
    constant FACE_LEFT   : std_logic_vector(4 downto 0) := "01000";
    constant FACE_RIGHT  : std_logic_vector(4 downto 0) := "10000";

    -- 蛇身位置类型定义
    type pos_type is record
        x : unsigned(4 downto 0);  -- 1-20
        y : unsigned(3 downto 0);  -- 1-15
    end record;

    -- 循环队列存储蛇身位置
    type pos_array is array (0 to MAX_SNAKE_LEN-1) of pos_type;
    signal snake_pos : pos_array;
    
    -- 队列指针
    signal head_ptr : integer range 0 to MAX_SNAKE_LEN-1 := 0;
    signal tail_ptr : integer range 0 to MAX_SNAKE_LEN-1 := 0;
    
    -- 控制信号
    signal snake_len_r   : unsigned(8 downto 0);
    signal current_dir   : std_logic_vector(4 downto 0);
    signal is_win_r      : std_logic;
    signal snake_map_r   : std_logic_vector(299 downto 0);
    signal flag_eat_r    : std_logic;
    
    -- 辅助函数：将坐标转换为snake_map索引
    function pos_to_index(x : unsigned; y : unsigned) return integer is
    begin
        return to_integer(x-1) + to_integer(y-1) * GRID_WIDTH;
    end function;
    
begin
    -- 移动控制
    process(flag_update, rst_n)
        variable new_head : pos_type;
        variable old_tail : pos_type;
        variable map_index : integer;
        variable head_index : integer;
        variable tail_index : integer;
    begin
        if rst_n = '0' then
            -- 初始化蛇身，确保在有效范围内
            for i in 0 to LENGTH_INIT-1 loop
                snake_pos(i).x <= to_unsigned(10 - i, 5);  -- 从x=10开始，向左延伸
                snake_pos(i).y <= to_unsigned(8, 4);       -- y固定在中间位置
            end loop;
            head_ptr <= LENGTH_INIT-1;  -- 头部指针指向最后一个位置
            tail_ptr <= 0;              -- 尾部指针指向第一个位置
            snake_len_r <= to_unsigned(LENGTH_INIT, 9);
            current_dir <= STOP;
            is_win_r <= '0';
            flag_eat_r <= '0';
            snake_map_r <= (others => '0');  -- 清除蛇身位置图
            
        elsif rising_edge(flag_update) then
            if general_state = "01" then  -- 游戏初始化
                -- 重置蛇身，确保在有效范围内
                for i in 0 to LENGTH_INIT-1 loop
                    snake_pos(i).x <= to_unsigned(10 - i, 5);  -- 从x=10开始，向左延伸
                    snake_pos(i).y <= to_unsigned(8, 4);       -- y固定在中间位置
                end loop;
                head_ptr <= LENGTH_INIT-1;  -- 头部指针指向最后一个位置
                tail_ptr <= 0;              -- 尾部指针指向第一个位置
                snake_len_r <= to_unsigned(LENGTH_INIT, 9);
                current_dir <= STOP;
                is_win_r <= '0';
                flag_eat_r <= '0';
                snake_map_r <= (others => '0');  -- 清除蛇身位置图
                
                -- 设置初始蛇身位置
                for i in 0 to LENGTH_INIT-1 loop
                    head_index := pos_to_index(
                        to_unsigned(10 - i, 5),
                        to_unsigned(8, 4)
                    );
                    snake_map_r(head_index) <= '1';
                end loop;
                
            elsif general_state = "10" then  -- 游戏中
                -- 更新方向
                if move_state /= STOP then
                    current_dir <= move_state;
                end if;

                -- 计算新的头部位置
                new_head := snake_pos(head_ptr);
                case current_dir is
                    when FACE_UP    => new_head.y := new_head.y - 1;
                    when FACE_DOWN  => new_head.y := new_head.y + 1;
                    when FACE_LEFT  => new_head.x := new_head.x - 1;
                    when FACE_RIGHT => new_head.x := new_head.x + 1;
                    when others     => null;
                end case;

                -- 检查是否吃到食物
                if new_head.x = food_x and new_head.y = food_y then
                    flag_eat_r <= '1';
                    -- 增加长度
                    if snake_len_r < to_unsigned(MAX_SNAKE_LEN, 9) then
                        snake_len_r <= snake_len_r + 1;
                        -- 检查是否胜利
                        if snake_len_r + 1 = to_unsigned(MAX_SNAKE_LEN, 9) then
                            is_win_r <= '1';
                        end if;
                    end if;
                else
                    flag_eat_r <= '0';
                    -- 移动尾部指针
                    if tail_ptr = MAX_SNAKE_LEN-1 then
                        tail_ptr <= 0;
                    else
                        tail_ptr <= tail_ptr + 1;
                    end if;
                end if;

                -- 更新头部指针和位置
                if head_ptr = MAX_SNAKE_LEN-1 then
                    head_ptr <= 0;
                else
                    head_ptr <= head_ptr + 1;
                end if;
                snake_pos(head_ptr) <= new_head;

                -- 更新蛇身位置图
                head_index := pos_to_index(new_head.x, new_head.y);
                tail_index := pos_to_index(snake_pos(tail_ptr).x, snake_pos(tail_ptr).y);
                
                -- 更新头部位置
                snake_map_r(head_index) <= '1';
                
                -- 如果不是吃到食物，则清除尾部位置
                if flag_eat_r = '0' then
                    snake_map_r(tail_index) <= '0';
                end if;
            end if;
        end if;
    end process;

    -- 检查是否撞到墙壁或自身
    process(snake_pos, head_ptr, snake_len_r, general_state, snake_map_r)
        variable head_index : integer;
        variable temp_map : std_logic_vector(299 downto 0);
    begin
        is_dead <= '0';
        if general_state = "10" then  -- 只在游戏运行时检查碰撞
            head_index := pos_to_index(snake_pos(head_ptr).x, snake_pos(head_ptr).y);
            
            -- 检查是否撞墙
            if snake_pos(head_ptr).x < 1 or snake_pos(head_ptr).x > to_unsigned(GRID_WIDTH, 5) or
               snake_pos(head_ptr).y < 1 or snake_pos(head_ptr).y > to_unsigned(GRID_HEIGHT, 4) then
                is_dead <= '1';
            -- 检查是否撞到自身(排除蛇头位置)
            else
                -- 创建临时地图,排除蛇头位置
                temp_map := snake_map_r;
                temp_map(head_index) := '0';
                -- 如果蛇头位置在临时地图中为1,说明撞到了其他蛇身部分
                if temp_map(head_index) = '1' then
                    is_dead <= '1';
                end if;
            end if;
        end if;
    end process;

    -- 输出
    snake_length <= std_logic_vector(snake_len_r);
    is_win <= is_win_r;
    snake_map <= snake_map_r;
    flag_eat <= flag_eat_r;

end Behavioral;
