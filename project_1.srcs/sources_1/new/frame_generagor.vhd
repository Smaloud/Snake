library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity frame_generator is
    -- 显示参数常量定义
    constant SCREEN_WIDTH  : integer := 640;  -- 屏幕宽度
    constant SCREEN_HEIGHT : integer := 480;  -- 屏幕高度
    constant ADDR_WIDTH    : integer := 19;   -- 地址位宽：SCREEN_WIDTH*SCREEN_HEIGHT需要19位
    constant COLOR_DEPTH   : integer := 3;    -- 颜色深度：RGB各1位
    constant SNAKE_SIZE    : integer := 40;   -- 蛇身单元大小（正方形）
    
    -- 派生常量（需要在port定义前计算）
    constant GRID_COLS     : integer := SCREEN_WIDTH / SNAKE_SIZE;   -- 水平方向网格数（16）
    constant GRID_ROWS     : integer := SCREEN_HEIGHT / SNAKE_SIZE;  -- 垂直方向网格数（12）
    constant GRID_TOTAL    : integer := GRID_COLS * GRID_ROWS;       -- 总网格数（192）
    constant MAX_SNAKE_LEN : integer := GRID_TOTAL;                  -- 蛇的最大长度
    constant SNAKE_POS_BITS: integer := 10;                          -- 每个蛇身节点坐标使用的位数
    constant SNAKE_VEC_BITS: integer := MAX_SNAKE_LEN * SNAKE_POS_BITS; -- 蛇身向量总位数
    constant SNAKE_LEN_BITS: integer := 8;                           -- 蛇长度需要的位数
    
    port (
        clk            : in  std_logic;
        rst_n          : in  std_logic;
        general_state  : in  std_logic_vector(1 downto 0);  -- 游戏状态
        
        -- 游戏配置信息
        game_speed     : in  std_logic_vector(1 downto 0);  -- 游戏速度：00-慢, 01-中, 10-快, 11-超快
        
        -- 蛇的信息
        snake_x        : in  std_logic_vector(SNAKE_VEC_BITS-1 downto 0); -- 最多MAX_SNAKE_LEN节，每节SNAKE_POS_BITS位
        snake_y        : in  std_logic_vector(SNAKE_VEC_BITS-1 downto 0); -- 最多MAX_SNAKE_LEN节，每节SNAKE_POS_BITS位
        snake_length   : in  std_logic_vector(7 downto 0);  -- 蛇的长度，最大值为192（需要8位）
        
        -- 食物的信息
        food_x         : in  unsigned(9 downto 0);
        food_y         : in  unsigned(8 downto 0);
        
        -- 障碍物信息（用于障碍模式）
        obstacle_map   : in  std_logic_vector(63 downto 0); -- 8x8网格的障碍物地图
        
        -- 分数信息
        score          : in  std_logic_vector(7 downto 0);  -- 假设分数为8位
        high_score     : in  std_logic_vector(15 downto 0); -- 最高分记录
        
        -- RAM写入接口
        ram_addr       : out std_logic_vector(ADDR_WIDTH-1 downto 0); -- 地址
        ram_data       : out std_logic_vector(COLOR_DEPTH-1 downto 0); -- 数据：RGB各1位
        ram_we         : out std_logic                      -- 写使能
    );
end frame_generator;

architecture Behavioral of frame_generator is
    -- 常量定义
    constant GRID_SIZE  : integer := SNAKE_SIZE;  -- 网格大小等于蛇身大小

    -- 辅助函数：判断当前像素是否为蛇身
    function is_snake_body(
        x : integer; 
        y : integer; 
        snake_x_vec : std_logic_vector(SNAKE_VEC_BITS-1 downto 0);
        snake_y_vec : std_logic_vector(SNAKE_VEC_BITS-1 downto 0);
        length : std_logic_vector(SNAKE_LEN_BITS-1 downto 0)
    ) return boolean is
        variable length_int : integer;
        variable snake_x_int, snake_y_int : integer;
    begin
        length_int := to_integer(unsigned(length));
        
        for i in 0 to MAX_SNAKE_LEN-1 loop  -- 最多MAX_SNAKE_LEN节蛇身
            if i < length_int then
                -- 从蛇身数组中提取每个节点的x和y坐标
                -- 每SNAKE_POS_BITS位表示一个坐标
                snake_x_int := to_integer(unsigned(snake_x_vec((i+1)*SNAKE_POS_BITS-1 downto i*SNAKE_POS_BITS)));
                snake_y_int := to_integer(unsigned(snake_y_vec((i+1)*SNAKE_POS_BITS-1 downto i*SNAKE_POS_BITS)));
                
                -- 判断当前像素是否在蛇身坐标附近
                if x >= snake_x_int and x < snake_x_int + SNAKE_SIZE and
                   y >= snake_y_int and y < snake_y_int + SNAKE_SIZE then
                    return true;
                end if;
            end if;
        end loop;
        
        return false;
    end function;
    
    -- 辅助函数：判断当前像素是否为食物
    function is_food(
        x : integer;
        y : integer;
        food_x_pos : unsigned(9 downto 0);
        food_y_pos : unsigned(8 downto 0)
    ) return boolean is
    begin
        -- 食物大小与蛇身相同
        if x >= to_integer(food_x_pos) and x < to_integer(food_x_pos) + SNAKE_SIZE and
           y >= to_integer(food_y_pos) and y < to_integer(food_y_pos) + SNAKE_SIZE then
            return true;
        else
            return false;
        end if;
    end function;
    
    -- 辅助函数：判断当前像素是否为分数显示区域
    function is_score_display(
        x : integer;
        y : integer;
        score_val : std_logic_vector(7 downto 0)
    ) return boolean is
        variable score_int : integer;
        constant SCORE_START_X  : integer := SCREEN_WIDTH - 100;
        constant SCORE_END_X    : integer := SCREEN_WIDTH - 20;
        constant SCORE_START_Y  : integer := 20;
        constant SCORE_END_Y    : integer := 40;
    begin
        score_int := to_integer(unsigned(score_val));
        
        -- 使用常量定义分数显示位置
        if x >= SCORE_START_X and x < SCORE_END_X and y >= SCORE_START_Y and y < SCORE_END_Y then
            -- 这里应该有更复杂的逻辑来将分数转换为像素，简化处理
            return true;
        else
            return false;
        end if;
    end function;
    
    -- 辅助函数：判断当前像素是否为最高分显示区域
    function is_high_score_display(
        x : integer;
        y : integer,
        high_score_val : std_logic_vector(15 downto 0)
    ) return boolean is
        constant SCORE_START_X  : integer := SCREEN_WIDTH - 100;
        constant SCORE_END_X    : integer := SCREEN_WIDTH - 20;
        constant HSCORE_START_Y : integer := 50;
        constant HSCORE_END_Y   : integer := 70;
    begin
        -- 使用常量定义最高分显示位置
        if x >= SCORE_START_X and x < SCORE_END_X and y >= HSCORE_START_Y and y < HSCORE_END_Y then
            return true;
        else
            return false;
        end if;
    end function;
    
    -- 辅助函数：判断当前像素是否为障碍物
    function is_obstacle(
        x : integer;
        y : integer,
        obstacle_map_val : std_logic_vector(63 downto 0)
    ) return boolean is
        variable grid_x, grid_y : integer;
        variable map_index : integer;
        constant OBSTACLE_GRID_SIZE : integer := SCREEN_WIDTH / 8; -- 障碍物网格大小
    begin
        -- 转换像素坐标到8x8网格坐标
        grid_x := x / OBSTACLE_GRID_SIZE;
        grid_y := y / OBSTACLE_GRID_SIZE;
        
        if grid_x >= 0 and grid_x < 8 and grid_y >= 0 and grid_y < 8 then
            map_index := grid_y * 8 + grid_x;
            -- 检查该位置是否有障碍物
            if obstacle_map_val(map_index) = '1' then
                -- 在障碍物中心画一个较小的方块
                if (x mod OBSTACLE_GRID_SIZE >= OBSTACLE_GRID_SIZE/4 and x mod OBSTACLE_GRID_SIZE < OBSTACLE_GRID_SIZE*3/4) and
                   (y mod OBSTACLE_GRID_SIZE >= OBSTACLE_GRID_SIZE/4 and y mod OBSTACLE_GRID_SIZE < OBSTACLE_GRID_SIZE*3/4) then
                    return true;
                end if;
            end if;
        end if;
        
        return false;
    end function;
    
    -- 辅助函数：显示游戏模式、速度和难度信息
    function is_game_info_display(
        x : integer;
        y : integer,
        speed : std_logic_vector(1 downto 0),
    ) return boolean is
        constant INFO_START_X   : integer := 20;
        constant INFO_END_X     : integer := 120;
        constant MODE_START_Y   : integer := 20;
        constant MODE_END_Y     : integer := 40;
        constant SPEED_START_Y  : integer := 50;
        constant SPEED_END_Y    : integer := 70;
        constant DIFF_START_Y   : integer := 80;
        constant DIFF_END_Y     : integer := 100;
    begin
        -- 使用常量定义游戏信息显示区域
        -- 游戏模式显示区域
        if x >= INFO_START_X and x < INFO_END_X and y >= MODE_START_Y and y < MODE_END_Y then
            return true;
        -- 游戏速度显示区域
        elsif x >= INFO_START_X and x < INFO_END_X and y >= SPEED_START_Y and y < SPEED_END_Y then
            return true;
        -- 游戏难度显示区域
        elsif x >= INFO_START_X and x < INFO_END_X and y >= DIFF_START_Y and y < DIFF_END_Y then
            return true;
        else
            return false;
        end if;
    end function;

begin
    -- 帧生成过程
    process(clk, rst_n)
        variable x_pos : integer range 0 to SCREEN_WIDTH-1 := 0;
        variable y_pos : integer range 0 to SCREEN_HEIGHT-1 := 0;
        
        -- 进程内部常量定义
        constant TITLE_START_X  : integer := SCREEN_WIDTH/2 - 80;
        constant TITLE_END_X    : integer := SCREEN_WIDTH/2 + 80;
        constant TITLE_START_Y  : integer := 100;
        constant TITLE_END_Y    : integer := 140;
        
        constant PROGRESS_START_X : integer := SCREEN_WIDTH/2 - 100;
        constant PROGRESS_END_X   : integer := SCREEN_WIDTH/2 + 100;
        constant PROGRESS_START_Y : integer := 230;
        constant PROGRESS_END_Y   : integer := 250;
        
        constant GAMEOVER_START_X : integer := SCREEN_WIDTH/2 - 80;
        constant GAMEOVER_END_X   : integer := SCREEN_WIDTH/2 + 80;
        constant GAMEOVER_START_Y : integer := 200;
        constant GAMEOVER_END_Y   : integer := 240;
    begin
        if rst_n = '0' then
            ram_we <= '0';
        elsif rising_edge(clk) then
            -- 逐像素生成帧并写入RAM
            ram_addr <= std_logic_vector(to_unsigned(y_pos * SCREEN_WIDTH + x_pos, ADDR_WIDTH));
            
            -- 判断当前像素应该显示什么内容
            if general_state = "00" then
                -- 开始菜单背景
                ram_data <= "111"; -- 白色背景
                
                -- 显示游戏标题和选项
                if (x_pos >= TITLE_START_X and x_pos < TITLE_END_X and y_pos >= TITLE_START_Y and y_pos < TITLE_END_Y) then
                    ram_data <= "001"; -- 蓝色标题
                -- 显示游戏模式选择
                elsif is_game_info_display(x_pos, y_pos, game_speed) then
                    ram_data <= "110"; -- 黄色信息区
                end if;
                
            elsif general_state = "10" then
                -- 初始化界面
                ram_data <= "111"; -- 白色背景
                
                -- 显示加载进度条
                if (x_pos >= PROGRESS_START_X and x_pos < PROGRESS_END_X and y_pos >= PROGRESS_START_Y and y_pos < PROGRESS_END_Y) then
                    ram_data <= "101"; -- 紫色进度条背景
                end if;
                
            elsif general_state = "11" then
                -- 游戏中
                
                -- 0. 显示游戏信息（模式、速度、难度）
                if is_game_info_display(x_pos, y_pos, game_speed) then
                    ram_data <= "110"; -- 黄色信息区
                
                -- 1. 判断是否为蛇身
                elsif is_snake_body(x_pos, y_pos, snake_x, snake_y, snake_length) then
                    ram_data <= "010"; -- 绿色蛇身
                
                -- 2. 判断是否为食物
                elsif is_food(x_pos, y_pos, food_x, food_y) then
                    ram_data <= "100"; -- 红色食物
                
                -- 4. 绘制分数
                elsif is_score_display(x_pos, y_pos, score) then
                    ram_data <= "001"; -- 蓝色分数
                
                -- 5. 绘制最高分
                elsif is_high_score_display(x_pos, y_pos, high_score) then
                    ram_data <= "101"; -- 紫色最高分
                
                -- 6. 背景
                else
                    ram_data <= "111"; -- 白色背景
                    
                end if;
                
            else
                -- 默认状态（如游戏结束）
                ram_data <= "111"; -- 白色背景
                
                -- 显示游戏结束和最终分数
                if (x_pos >= GAMEOVER_START_X and x_pos < GAMEOVER_END_X and y_pos >= GAMEOVER_START_Y and y_pos < GAMEOVER_END_Y) then
                    ram_data <= "100"; -- 红色游戏结束文字
                elsif is_score_display(x_pos, y_pos, score) then
                    ram_data <= "001"; -- 蓝色最终分数
                elsif is_high_score_display(x_pos, y_pos, high_score) then
                    ram_data <= "101"; -- 紫色最高分
                end if;
            end if;
            
            ram_we <= '1';
            
            -- 更新位置
            if x_pos = SCREEN_WIDTH-1 then
                x_pos := 0;
                if y_pos = SCREEN_HEIGHT-1 then
                    y_pos := 0;
                else
                    y_pos := y_pos + 1;
                end if;
            else
                x_pos := x_pos + 1;
            end if;
        end if;
    end process;
end Behavioral;
