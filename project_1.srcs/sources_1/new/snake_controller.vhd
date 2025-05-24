library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_controller is
    generic (
        SCREEN_WIDTH  : integer := 800;  -- 屏幕宽度
        SCREEN_HEIGHT : integer := 600;  -- 屏幕高度
        SQUARE_SIZE   : integer := 40;   -- 蛇身方块大小
        MAX_SNAKE_LEN : integer := 300  -- �?大蛇身长�?
    );
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        general_state : in  std_logic_vector(1 downto 0);  -- 状�?�码�?00-菜单, 01-初始�?, 10-运行�?, 11-游戏结束
        move_state    : in  std_logic_vector(4 downto 0);
        flag_update   : in  std_logic;  -- 控制每帧移动
        food_x        : in  unsigned(4 downto 0);  -- 食物x坐标
        food_y        : in  unsigned(3 downto 0);   -- 食物y坐标

        snake_length  : out std_logic_vector(8 downto 0);  -- 蛇的长度
        snake_map     : out std_logic_vector(299 downto 0);  -- 输出蛇身位置�?
        is_win        : out std_logic;   -- 游戏胜利信号
        is_dead       : out std_logic;   -- 游戏失败信号
        flag_eat      : out std_logic;  -- 食物被吃掉的信号
        --作为按键测试
        LED : out std_logic_vector(4 downto 0)
    );
end snake_controller;

architecture Behavioral of snake_controller is

    -- 坐标位宽（按屏幕划分的格子数量计算）
    constant GRID_WIDTH  : integer := SCREEN_WIDTH / SQUARE_SIZE;
    constant GRID_HEIGHT : integer := SCREEN_HEIGHT / SQUARE_SIZE;
    constant GRID_SIZE   : integer := GRID_WIDTH * GRID_HEIGHT;

    -- 位置编码：行优先，一维数组（snake_map[i]=1 表示该格有蛇）
    type coord_array is array (0 to MAX_SNAKE_LEN - 1) of unsigned(11 downto 0);  -- 最大支持 4096 格子
    signal snake_body : coord_array;
    signal head_ptr   : integer range 0 to MAX_SNAKE_LEN - 1 := 2;
    signal tail_ptr   : integer range 0 to MAX_SNAKE_LEN - 1 := 0;

    signal current_length : integer range 0 to MAX_SNAKE_LEN := 3;
    signal growth_pending : std_logic := '0';

    signal head_x, head_y : integer range 0 to GRID_WIDTH;
    signal next_x, next_y : integer range 0 to GRID_WIDTH;

    signal internal_map   : std_logic_vector(GRID_SIZE-1 downto 0) := (others => '0');

    function encode(x, y: integer) return integer is
    begin
        return y * GRID_WIDTH + x;
    end function;

begin
    -- 移动控制
    process(flag_update, rst_n)
        variable new_head : pos_type;
        variable old_tail : pos_type;
        variable map_index : integer;
        variable head_index : integer;
        variable tail_index : integer;
        variable new_head_ptr : integer;
    begin
        if rst_n = '0' then
            -- 初始化蛇身，确保在有效范围内
            for i in 0 to LENGTH_INIT-1 loop
                snake_pos(i).x <= to_unsigned(10 - i, 5);  -- 从x=10�?始，向左延伸
                snake_pos(i).y <= to_unsigned(8, 4);       -- y固定在中间位�?
            end loop;
            head_ptr <= LENGTH_INIT-1;  -- 头部指针指向�?后一个位�?
            tail_ptr <= 0;              -- 尾部指针指向第一个位�?
            snake_len_r <= to_unsigned(LENGTH_INIT, 9);
            current_dir <= STOP;
            is_win_r <= '0';
            flag_eat_r <= '0';
            snake_map_r <= (others => '0');  -- 清除蛇身位置�?
            
        elsif rising_edge(flag_update) then
            if general_state = "01" then  -- 游戏初始�?
                -- 重置蛇身，确保在有效范围�?
                for i in 0 to LENGTH_INIT-1 loop
                    snake_pos(i).x <= to_unsigned(10 - i, 5);  -- 从x=10�?始，向左延伸
                    snake_pos(i).y <= to_unsigned(8, 4);       -- y固定在中间位�?
                end loop;
                head_ptr <= LENGTH_INIT-1;  -- 头部指针指向�?后一个位�?
                tail_ptr <= 0;              -- 尾部指针指向第一个位�?
                snake_len_r <= to_unsigned(LENGTH_INIT, 9);
                current_dir <= STOP;
                is_win_r <= '0';
                flag_eat_r <= '0';
                snake_map_r <= (others => '0');  -- 清除蛇身位置�?
                
                -- 设置初始蛇身位置
                for i in 0 to LENGTH_INIT-1 loop
                    head_index := pos_to_index(
                        to_unsigned(10 - i, 5),
                        to_unsigned(8, 4)
                    );
                    snake_map_r(head_index) <= '1';
                end loop;
                
            elsif general_state = "10" then  -- 游戏�?
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

                -- �?查是否吃到食�?
                if new_head.x = food_x and new_head.y = food_y then
                    flag_eat_r <= '1';
                    -- 增加长度
                    if snake_len_r < to_unsigned(MAX_SNAKE_LEN, 9) then
                        snake_len_r <= snake_len_r + 1;
                        -- �?查是否胜�?
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

                -- 更新头部指针和位�?
                if head_ptr = MAX_SNAKE_LEN-1 then
                    new_head_ptr := 0;
                else
                    new_head_ptr := head_ptr + 1;
                end if;
                snake_pos(new_head_ptr) <= new_head;
                head_ptr <= new_head_ptr;

                -- 更新蛇身位置�?
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

    -- �?查是否撞到墙壁或自身
    -- process(snake_pos, head_ptr, snake_len_r, general_state, snake_map_r)
    --     variable head_index : integer;
    --     variable temp_map : std_logic_vector(299 downto 0);
    -- begin
    --     is_dead <= '0';
    --     if general_state = "10" then  -- 只在游戏运行时检查碰�?
    --         head_index := pos_to_index(snake_pos(head_ptr).x, snake_pos(head_ptr).y);
            
    --         -- �?查是否撞�?
    --         if snake_pos(head_ptr).x < 1 or snake_pos(head_ptr).x > to_unsigned(GRID_WIDTH, 5) or
    --            snake_pos(head_ptr).y < 1 or snake_pos(head_ptr).y > to_unsigned(GRID_HEIGHT, 4) then
    --             is_dead <= '1';
    --         -- �?查是否撞到自�?(排除蛇头位置)
    --         -- else
    --         --     -- 创建临时地图,排除蛇头位置
    --         --     temp_map := snake_map_r;
    --         --     temp_map(head_index) := '0';
    --         --     -- 如果蛇头位置在临时地图中�?1,说明撞到了其他蛇身部�?
    --         --     if temp_map(head_index) = '1' then
    --         --         is_dead <= '1';
    --         --     end if;
    --         end if;
    --     end if;
    -- end process;

    -- 输出
    snake_length <= std_logic_vector(snake_len_r);
    is_win <= is_win_r;
    snake_map <= snake_map_r;
    flag_eat <= flag_eat_r;
        LED <= move_state;

end Behavioral;
