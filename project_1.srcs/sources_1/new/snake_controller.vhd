library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_controller is
    generic (
        SCREEN_WIDTH  : integer := 800;  -- 屏幕宽度(像素)
        SCREEN_HEIGHT : integer := 600;  -- 屏幕高度(像素)
        SQUARE_SIZE   : integer := 40;   -- 蛇身方块大小(像素)
        MAX_SNAKE_LEN : integer := 300   -- 最大蛇身长度
    );
    port (
        clk           : in  std_logic;   -- 系统时钟
        rst_n         : in  std_logic;   -- 低电平有效复位信号
        general_state : in  std_logic_vector(1 downto 0);  -- 游戏状态: 00-菜单, 01-初始化, 10-运行中, 11-游戏结束
        move_state    : in  std_logic_vector(4 downto 0);  -- 移动方向控制
        flag_update   : in  std_logic;   -- 更新标志,控制每帧移动
        food_x        : in  unsigned(4 downto 0);  -- 食物x坐标(1-20)
        food_y        : in  unsigned(3 downto 0);  -- 食物y坐标(1-15)

        snake_length  : out std_logic_vector(8 downto 0);  -- 当前蛇身长度
        snake_map     : out std_logic_vector(299 downto 0);  -- 蛇身位置图(20x15=300位)
        is_win        : out std_logic;   -- 游戏胜利信号
        is_dead       : out std_logic;   -- 游戏失败信号
        flag_eat      : out std_logic    -- 食物被吃掉的信号
    );
end snake_controller;

architecture Behavioral of snake_controller is
    -- 常量定义
    constant INIT_LENGTH    : integer := 3;    -- 初始蛇身长度
    constant GRID_WIDTH     : integer := SCREEN_WIDTH/SQUARE_SIZE;   -- 网格宽度(20)
    constant GRID_HEIGHT    : integer := SCREEN_HEIGHT/SQUARE_SIZE;  -- 网格高度(15)
    
    -- 方向控制常量
    constant DIR_STOP       : std_logic_vector(4 downto 0) := "00001";
    constant DIR_UP         : std_logic_vector(4 downto 0) := "00010";
    constant DIR_DOWN       : std_logic_vector(4 downto 0) := "00100";
    constant DIR_LEFT       : std_logic_vector(4 downto 0) := "01000";
    constant DIR_RIGHT      : std_logic_vector(4 downto 0) := "10000";

    -- 游戏状态常量
    constant STATE_MENU     : std_logic_vector(1 downto 0) := "00";
    constant STATE_INIT     : std_logic_vector(1 downto 0) := "01";
    constant STATE_RUNNING  : std_logic_vector(1 downto 0) := "10";
    constant STATE_OVER     : std_logic_vector(1 downto 0) := "11";

    -- 蛇身位置记录类型
    type pos_type is record
        x : unsigned(4 downto 0);  -- x坐标(1-20)
        y : unsigned(3 downto 0);  -- y坐标(1-15)
    end record;

    -- 蛇身位置数组
    type pos_array is array (0 to MAX_SNAKE_LEN-1) of pos_type;
    signal snake_pos : pos_array;
    
    -- 队列控制信号
    signal head_ptr : integer range 0 to MAX_SNAKE_LEN-1 := 0;  -- 头部指针
    signal tail_ptr : integer range 0 to MAX_SNAKE_LEN-1 := 0;  -- 尾部指针
    
    -- 控制信号
    signal snake_len_r   : unsigned(8 downto 0);  -- 蛇身长度寄存器
    signal current_dir   : std_logic_vector(4 downto 0);  -- 当前移动方向
    signal is_win_r      : std_logic;  -- 胜利标志寄存器
    signal is_dead_r     : std_logic;  -- 失败标志寄存器 (新增)
    signal snake_map_r   : std_logic_vector(299 downto 0);  -- 蛇身位置图寄存器
    signal flag_eat_r    : std_logic;  -- 食物标志寄存器
    
    -- 坐标转换函数
    function pos_to_index(x : unsigned; y : unsigned) return integer is
    begin
        -- 确保 x 和 y 在有效范围内才进行转换，防止索引超出 snake_map_r 的范围
        -- 虽然碰撞检测函数也会检查边界，但这里多一层保护更好
        if x >= 1 and x <= to_unsigned(GRID_WIDTH, x'length) and
           y >= 1 and y <= to_unsigned(GRID_HEIGHT, y'length) then
            return to_integer(x-1) + to_integer(y-1) * GRID_WIDTH;
        else
            -- 返回一个无效索引或者触发错误，这里简单返回0，
            -- 但理想情况下应该有更好的错误处理或保证调用者提供有效值
            return 0; -- 或者一个特殊的标记值，如果你的 map 大小允许
        end if;
    end function;
    
    -- 碰撞检测函数
    -- map 参数现在代表的是上一帧的蛇身位置
    function check_collision(new_head_pos : pos_type; current_snake_map : std_logic_vector) return boolean is
        variable index : integer;
    begin
        -- 检查是否撞墙
        if new_head_pos.x < 1 or new_head_pos.x > to_unsigned(GRID_WIDTH, new_head_pos.x'length) or
           new_head_pos.y < 1 or new_head_pos.y > to_unsigned(GRID_HEIGHT, new_head_pos.y'length) then
            return true;
        end if;
        
        -- 检查是否撞到自身 (在 current_snake_map 中检查)
        index := pos_to_index(new_head_pos.x, new_head_pos.y);
        -- 如果索引有效 (pos_to_index 可能返回特殊值如果输入无效，但这里假设 new_head_pos 经墙体检查后是合法的网格内坐标)
        if index >= 0 and index < current_snake_map'length then
            return current_snake_map(index) = '1';
        else
            return true; -- 如果索引计算错误，视为碰撞
        end if;
    end function;
    
begin
    -- 主控制进程 (使用 clk 和 flag_update)
    process(clk, rst_n)
        variable new_head         : pos_type;
        variable map_idx_new_head : integer;
        variable map_idx_old_tail : integer;
        variable old_tail_pos_val : pos_type; -- 用于暂存旧尾巴的坐标
        variable will_collide     : boolean;
        -- 新增变量声明
        variable temp_x          : unsigned(4 downto 0);
        variable temp_y          : unsigned(3 downto 0);
        variable temp_map_idx    : integer;
        variable next_head_ptr_val : integer range 0 to MAX_SNAKE_LEN-1;
    begin
        if rst_n = '0' then
            -- 复位初始化
            for i in 0 to INIT_LENGTH-1 loop
                snake_pos(i).x <= to_unsigned(10 - i, 5);
                snake_pos(i).y <= to_unsigned(8, 4);
            end loop;
            -- 初始化数组中未使用部分 (可选，但推荐)
            for i in INIT_LENGTH to MAX_SNAKE_LEN-1 loop
                snake_pos(i).x <= (others => '0'); -- 或某个无效坐标
                snake_pos(i).y <= (others => '0');
            end loop;

            head_ptr <= INIT_LENGTH-1;
            tail_ptr <= 0;
            snake_len_r <= to_unsigned(INIT_LENGTH, 9);
            current_dir <= DIR_STOP;
            is_win_r <= '0';
            is_dead_r <= '0'; -- 复位 is_dead_r
            flag_eat_r <= '0';
            snake_map_r <= (others => '0');
            
        elsif rising_edge(flag_update) then
            -- if flag_update = '1' then -- 只有在更新帧时才执行逻辑
                
            -- 每帧开始时，先假设没有吃到食物，如果后面检测到吃了会覆盖
            flag_eat_r <= '0'; 

            if general_state = STATE_INIT then
                -- 游戏初始化
                for i in 0 to INIT_LENGTH-1 loop
                    snake_pos(i).x <= to_unsigned(10 - i, 5);
                    snake_pos(i).y <= to_unsigned(8, 4);
                end loop;
                -- 初始化数组中未使用部分 (可选，但推荐)
                for i in INIT_LENGTH to MAX_SNAKE_LEN-1 loop
                    snake_pos(i).x <= (others => '0');
                    snake_pos(i).y <= (others => '0');
                end loop;

                head_ptr <= INIT_LENGTH-1;
                tail_ptr <= 0;
                snake_len_r <= to_unsigned(INIT_LENGTH, 9);
                current_dir <= DIR_STOP;
                is_win_r <= '0';
                is_dead_r <= '0'; -- 初始化时蛇没有死
                flag_eat_r <= '0';
                snake_map_r <= (others => '0'); -- 清空地图
                
                -- 设置初始蛇身位置到地图
                for i in 0 to INIT_LENGTH-1 loop
                    -- 使用局部变量确保综合正确性
                    temp_x := to_unsigned(10-i, 5);
                    temp_y := to_unsigned(8, 4);
                    temp_map_idx := pos_to_index(temp_x, temp_y);
                    if temp_map_idx >= 0 and temp_map_idx < snake_map_r'length then
                        snake_map_r(temp_map_idx) <= '1';
                    end if;
                end loop;
                
            elsif general_state = STATE_RUNNING then
                -- 0. 如果蛇还活着，才进行移动和后续判断
                if is_dead_r = '0' and is_win_r = '0' then -- 游戏未结束才继续
                    -- 0a. 更新移动方向 (如果外部有新的有效输入)
                    if move_state /= DIR_STOP and move_state /= current_dir and -- 防止无效的180度转向
                        not ((current_dir = DIR_UP    and move_state = DIR_DOWN) or
                             (current_dir = DIR_DOWN  and move_state = DIR_UP) or
                             (current_dir = DIR_LEFT  and move_state = DIR_RIGHT) or
                             (current_dir = DIR_RIGHT and move_state = DIR_LEFT)) then
                        current_dir <= move_state;
                    end if;

                    -- 0b. 如果当前方向是停止，则不进行移动逻辑
                    if current_dir /= DIR_STOP then
                        -- 1. 计算新的头部位置 (基于当前 snake_pos(head_ptr) 和 current_dir)
                        new_head := snake_pos(head_ptr); -- 获取当前头部坐标
                        case current_dir is
                            when DIR_UP    => new_head.y := new_head.y - 1;
                            when DIR_DOWN  => new_head.y := new_head.y + 1;
                            when DIR_LEFT  => new_head.x := new_head.x - 1;
                            when DIR_RIGHT => new_head.x := new_head.x + 1;
                            when others    => null; -- DIR_STOP 或其他理论上不应发生的情况
                        end case;

                        -- 2. 碰撞检测 (使用 new_head 和 上一帧的 snake_map_r)
                        --    这一步在任何状态更新 (snake_pos, head_ptr, tail_ptr, snake_map_r) 之前
                        will_collide := check_collision(new_head, snake_map_r);

                        if will_collide then
                            is_dead_r <= '1'; -- 发生碰撞，蛇死亡
                        else
                            -- is_dead_r 保持 '0' (因为上面没撞)

                            -- 3. 检查是否吃到食物 (使用 new_head)
                            if new_head.x -1 = food_x and new_head.y -1 = food_y then
                                flag_eat_r <= '1';
                                -- 增加长度
                                if snake_len_r < to_unsigned(MAX_SNAKE_LEN, 9) then
                                    snake_len_r <= snake_len_r + 1;
                                    -- 检查是否胜利
                                    if snake_len_r + 1 = to_unsigned(MAX_SNAKE_LEN, 9) then -- 注意比较的是增长后的长度
                                        is_win_r <= '1';
                                    end if;
                                end if;
                                -- 吃食物时不移动尾部指针 tail_ptr
                            else
                                -- flag_eat_r 已经是 '0' (在时钟沿开始时设置的)
                                -- 3a. 暂存旧尾巴的坐标 (因为没吃食物，尾巴要移动并从地图上抹去)
                                old_tail_pos_val := snake_pos(tail_ptr);
                                
                                -- 3b. 移动尾部指针 (因为没吃食物，蛇要前进)
                                if tail_ptr = MAX_SNAKE_LEN-1 then
                                    tail_ptr <= 0;
                                else
                                    tail_ptr <= tail_ptr + 1;
                                end if;
                            end if; -- end food check

                            -- 4. 更新头部指针和蛇身数组中新头的位置
                            --    注意: head_ptr 必须在 snake_pos 更新前更新，
                            --    或者使用一个 next_head_ptr 变量
                            if head_ptr = MAX_SNAKE_LEN-1 then
                                next_head_ptr_val := 0;
                            else
                                next_head_ptr_val := head_ptr + 1;
                            end if;
                            head_ptr <= next_head_ptr_val;
                            snake_pos(next_head_ptr_val) <= new_head; -- 更新蛇头位置

                            -- 5. 更新蛇身位置图 (snake_map_r)
                            -- 5a. 清除旧尾巴在地图上的标记
                            --     如果没吃到食物，使用移动后的tail_ptr位置
                            --     如果吃到食物，使用原来的tail_ptr位置
                            if flag_eat_r = '0' then 
                                map_idx_old_tail := pos_to_index(old_tail_pos_val.x, old_tail_pos_val.y);
                            else
                                map_idx_old_tail := pos_to_index(snake_pos(tail_ptr).x, snake_pos(tail_ptr).y);
                            end if;
                            if map_idx_old_tail >=0 and map_idx_old_tail < snake_map_r'length then
                                snake_map_r(map_idx_old_tail) <= '0';
                            end if;

                            -- 5b. 设置新头在地图上的标记
                            map_idx_new_head := pos_to_index(new_head.x, new_head.y);
                            if map_idx_new_head >=0 and map_idx_new_head < snake_map_r'length then
                                snake_map_r(map_idx_new_head) <= '1';
                            end if;
                        end if; -- end "if not will_collide"
                    end if; -- end "if current_dir /= DIR_STOP"
                end if; -- end "if is_dead_r = '0' and is_win_r = '0'"

            end if; -- end general_state cases
            -- end if; -- end flag_update
        end if; -- end rising_edge(clk)
    end process;

    -- 移除旧的组合逻辑碰撞检测进程 (因为它已整合到主时钟进程中)
    -- process(snake_pos, head_ptr, general_state, snake_map_r)
    -- begin
    --     is_dead <= '0';
    --     if general_state = STATE_RUNNING then
    --         if check_collision(snake_pos(head_ptr), snake_map_r) then
    --             is_dead <= '1';
    --         end if;
    --     end if;
    -- end process;

    -- 输出信号赋值
    snake_length <= std_logic_vector(snake_len_r);
    is_win       <= is_win_r;
    is_dead      <= is_dead_r; -- 连接到新的寄存器 is_dead_r
    snake_map    <= snake_map_r;
    flag_eat     <= flag_eat_r;

end Behavioral;