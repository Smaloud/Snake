library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity frame_generator is

    generic(
    -- 显示参数常量定义
    constant SCREEN_WIDTH  : integer := 1024;  -- 屏幕宽度
    constant SCREEN_HEIGHT : integer := 600;  -- 屏幕高度
    constant ADDR_WIDTH    : integer := 20;   -- 地址位宽：SCREEN_WIDTH*SCREEN_HEIGHT需要20位
    constant COLOR_DEPTH   : integer := 3;    -- 颜色深度：RGB各1位
    constant SNAKE_SIZE    : integer := 40   -- 蛇身单元大小（正方形）
    );   
    
    port (
        clk            : in  std_logic;
        rst_n          : in  std_logic;
        general_state  : in  std_logic_vector(2 downto 0);  -- 游戏状态：000-菜单, 001-难度选择, 010-初始化, 011-运行中, 100-游戏结束
        
        -- 游戏配置信息
        game_speed     : in  std_logic_vector(1 downto 0);  -- 游戏速度：00-慢, 01-中, 10-快, 11-超快
        
        -- 蛇的信息
        snake_map_r    : in std_logic_vector(299 downto 0); -- 20*15=300位，表示蛇身位置

        
        -- 食物的信息
        food_x         : in  unsigned(9 downto 0);
        food_y         : in  unsigned(8 downto 0);
        
        -- 障碍物信息（用于障碍模式）
        obstacle_map   : in  std_logic_vector(63 downto 0); -- 8x8网格的障碍物地图
        
        -- 分数信息
        score          : in  std_logic_vector(7 downto 0);  -- 假设分数为8位
        high_score     : in  std_logic_vector(15 downto 0); -- 最高分记录
        
        -- Framebuffer写入接口
        pixel_x       : out unsigned(10 downto 0);         -- 写入像素 x 坐标（0~1023）
        pixel_y       : out unsigned(9 downto 0);         -- 写入像素 y 坐标（0~599）
        pixel_color   : out std_logic_vector(11 downto 0); -- RGB444 (4+4+4)
        write_en      : out std_logic;                     -- 写使能
        frame_complete: out std_logic                      -- 帧完成信号
    );
end frame_generator;

architecture Behavioral of frame_generator is
    -- 常量定义
    constant GRID_SIZE  : integer := 40;  -- 网格大小等于蛇身大小
    -- 派生常量
    constant GRID_COLS     : integer := 20;   -- 水平方向网格数
    constant GRID_ROWS     : integer := 15;  -- 垂直方向网格数
    constant GRID_TOTAL    : integer := 300;       -- 总网格数
    constant MAX_SNAKE_LEN : integer := 300;                  -- 蛇的最大长度

    -- 定义渲染阶段类型
    type render_stage_type is (INIT_BACKGROUND, DRAW_CONTENT);
    
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
    end function is_food;
    
    -- 辅助函数：判断当前像素是否为分数显示区域
    function is_score_display(
        x : integer;
        y : integer;
        score_val : std_logic_vector(7 downto 0)
    ) return boolean is
        constant SCORE_START_X  : integer := SCREEN_WIDTH - 100;
        constant SCORE_END_X    : integer := SCREEN_WIDTH - 20;
        constant SCORE_START_Y  : integer := 20;
        constant SCORE_END_Y    : integer := 40;
    begin
        -- 使用常量定义分数显示位置
        if x >= SCORE_START_X and x < SCORE_END_X and y >= SCORE_START_Y and y < SCORE_END_Y then
            return true;
        else
            return false;
        end if;
    end function is_score_display;
    
    -- 辅助函数：判断当前像素是否为最高分显示区域
    function is_high_score_display(
        x : integer;
        y : integer;
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
    end function is_high_score_display;
    
    -- 辅助函数：显示游戏模式、速度和难度信息
    function is_game_info_display(
        x : integer;
        y : integer;
        speed : std_logic_vector(1 downto 0)
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
    end function is_game_info_display;
    
    -- 辅助函数：判断当前像素是否在指定格子内
    function is_in_grid(
        x : integer;                    -- 当前像素x坐标
        y : integer;                    -- 当前像素y坐标
        grid_x : integer;               -- 格子x索引 (0-19)
        grid_y : integer                -- 格子y索引 (0-14)
    ) return boolean is
        variable grid_pixel_x : integer;
        variable grid_pixel_y : integer;
    begin
        -- 计算格子左上角的像素坐标
        grid_pixel_x := grid_x * GRID_SIZE;
        grid_pixel_y := grid_y * GRID_SIZE;
        
        -- 判断当前像素是否在这个格子内
        if x >= grid_pixel_x and x < grid_pixel_x + GRID_SIZE and
           y >= grid_pixel_y and y < grid_pixel_y + GRID_SIZE then
            return true;
        else
            return false;
        end if;
    end function is_in_grid;
    
    -- 格子填色函数：根据指定格子和颜色判断当前像素是否应该被填充
    function fill_grid(
        x : integer;                    -- 当前像素x坐标
        y : integer;                    -- 当前像素y坐标
        grid_x : integer;               -- 格子x索引 (0-19)
        grid_y : integer;               -- 格子y索引 (0-14)
        color : std_logic_vector(11 downto 0)  -- 指定的填充颜色
    ) return boolean is
    begin
        -- 检查是否在指定格子内
        if is_in_grid(x, y, grid_x, grid_y) then
            return true;  -- 当前像素在指定格子内，应当填充指定颜色
        else
            return false; -- 当前像素不在指定格子内
        end if;
    end function fill_grid;

    -- 实际使用的格子填色函数：填充指定颜色到指定格子
    procedure fill_grid_with_color(
        signal pixel_x_out : out unsigned(10 downto 0);
        signal pixel_y_out : out unsigned(9 downto 0);
        signal pixel_color_out : out std_logic_vector(11 downto 0);
        signal write_en_out : out std_logic;
        constant grid_x : in integer;
        constant grid_y : in integer;
        constant color : in std_logic_vector(11 downto 0);
        variable x_pos : inout integer;
        variable y_pos : inout integer
    ) is
    begin
        -- 检查当前像素是否在指定格子内
        if is_in_grid(x_pos, y_pos, grid_x, grid_y) then
            -- 写入坐标和颜色
            pixel_x_out <= to_unsigned(x_pos, 11);
            pixel_y_out <= to_unsigned(y_pos, 10);
            pixel_color_out <= color;
            write_en_out <= '1';
        end if;
    end procedure fill_grid_with_color;

begin
    -- 帧生成过程
    process(clk, rst_n)
        variable x_pos : integer range 0 to 1023 := 0;
        variable y_pos : integer range 0 to 599 := 0;
        variable render_stage : render_stage_type := INIT_BACKGROUND;
        variable grid_x : integer;
        variable grid_y : integer;
        variable position : integer;
        
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
        
        -- 游戏区和信息区边界
        constant GAME_AREA_END_X : integer := 800;
    begin
        if rst_n = '0' then
            write_en <= '0';
            frame_complete <= '0';
            render_stage := INIT_BACKGROUND;
            x_pos := 0;
            y_pos := 0;
        elsif rising_edge(clk) then
            -- 初始化帧完成信号为0
            frame_complete <= '0';
            
            -- 逐像素生成帧并写入RAM
            pixel_x <= to_unsigned(x_pos, 11);
            pixel_y <= to_unsigned(y_pos, 10);
            
            -- 根据当前渲染阶段执行不同的操作
            case render_stage is
                -- 阶段1: 初始化背景
                when INIT_BACKGROUND =>
                    -- 写入背景颜色
                    if x_pos >= 0 and x_pos <= GAME_AREA_END_X and y_pos >= 0 and y_pos <= 599 then
                        -- 游戏区(0-800, 0-599)写入黑色背景
                        pixel_color <= "000000000000"; -- 黑色背景 (R=0, G=0, B=0)
                    else
                        -- 信息区(801-1023, 0-599)写入白色背景
                        pixel_color <= "111111111111"; -- 白色背景 (R=F, G=F, B=F)
                    end if;
                    
                    write_en <= '1';
                    
                    -- 更新位置
                    if x_pos = SCREEN_WIDTH-1 then
                        x_pos := 0;
                        if y_pos = SCREEN_HEIGHT-1 then
                            y_pos := 0;
                            -- 背景初始化完成，切换到内容绘制阶段
                            render_stage := DRAW_CONTENT;
                        else
                            y_pos := y_pos + 1;
                        end if;
                    else
                        x_pos := x_pos + 1;
                    end if;
                
                -- 阶段2: 绘制游戏内容
                when DRAW_CONTENT =>
                    -- 默认不写入
                    write_en <= '0';
                    
                    -- 根据游戏状态绘制不同内容
                    case general_state is
                        -- 主菜单
                        when "000" =>
                            -- 开始菜单内容
                            if (x_pos >= TITLE_START_X and x_pos < TITLE_END_X and y_pos >= TITLE_START_Y and y_pos < TITLE_END_Y) then
                                pixel_color <= "000000001111"; -- 蓝色标题 (R=0, G=0, B=F)
                                write_en <= '1';
                            elsif is_game_info_display(x_pos, y_pos, game_speed) then
                                pixel_color <= "111111110000"; -- 黄色信息区 (R=F, G=F, B=0)
                                write_en <= '1';
                            end if;
                        
                        -- 难度选择
                        when "001" =>
                            -- 初始化界面内容
                            if (x_pos >= PROGRESS_START_X and x_pos < PROGRESS_END_X and y_pos >= PROGRESS_START_Y and y_pos < PROGRESS_END_Y) then
                                pixel_color <= "111100001111"; -- 紫色进度条背景 (R=F, G=0, B=F)
                                write_en <= '1';
                            end if;
                        
                        -- 游戏初始化
                        when "010" =>
                            -- 初始化界面内容
                            if (x_pos >= PROGRESS_START_X and x_pos < PROGRESS_END_X and y_pos >= PROGRESS_START_Y and y_pos < PROGRESS_END_Y) then
                                pixel_color <= "111100001111"; -- 紫色进度条背景 (R=F, G=0, B=F)
                                write_en <= '1';
                            end if;
                        
                        -- 游戏运行中
                        when "011" =>
                            -- 游戏中的内容
                            
                            -- 0. 显示游戏信息（模式、速度、难度）
                            if is_game_info_display(x_pos, y_pos, game_speed) then
                                pixel_color <= "111111110000"; -- 黄色信息区 (R=F, G=F, B=0)
                                write_en <= '1';
                            
                            -- 1. 绘制食物
                            elsif is_food(x_pos, y_pos, food_x, food_y) then
                                pixel_color <= "111100000000"; -- 红色食物 (R=F, G=0, B=0)
                                write_en <= '1';
                            
                            -- 2. 绘制分数
                            elsif is_score_display(x_pos, y_pos, score) then
                                pixel_color <= "000000001111"; -- 蓝色分数 (R=0, G=0, B=F)
                                write_en <= '1';
                            
                            -- 3. 绘制最高分
                            elsif is_high_score_display(x_pos, y_pos, high_score) then
                                pixel_color <= "111100001111"; -- 紫色最高分 (R=F, G=0, B=F)
                                write_en <= '1';
                            end if;
                            
                            -- 4. 绘制蛇身（使用snake_map_r）
                            -- 计算当前像素所在的网格位置
                            if x_pos < GAME_AREA_END_X then  -- 只在游戏区域内检查蛇身
                                -- 计算当前像素对应的网格索引
                                grid_x := x_pos / GRID_SIZE;
                                grid_y := y_pos / GRID_SIZE;
                                
                                -- 确保网格索引在有效范围内
                                if grid_x >= 0 and grid_x < GRID_COLS and grid_y >= 0 and grid_y < GRID_ROWS then
                                    -- 计算在snake_map_r中的位置
                                    position := grid_x + grid_y * GRID_COLS;
                                    
                                    -- 检查该位置是否有蛇身
                                    if position < 300 and snake_map_r(position) = '1' then
                                        -- 绘制蛇身
                                        fill_grid_with_color(pixel_x, pixel_y, pixel_color, write_en, 
                                                           grid_x, grid_y, "000011110000", x_pos, y_pos);
                                    end if;
                                end if;
                            end if;
                        
                        -- 游戏结束
                        when "100" =>
                            -- 游戏结束内容
                            if (x_pos >= GAMEOVER_START_X and x_pos < GAMEOVER_END_X and y_pos >= GAMEOVER_START_Y and y_pos < GAMEOVER_END_Y) then
                                pixel_color <= "111100000000"; -- 红色游戏结束文字 (R=F, G=0, B=0)
                                write_en <= '1';
                            elsif is_score_display(x_pos, y_pos, score) then
                                pixel_color <= "000000001111"; -- 蓝色最终分数 (R=0, G=0, B=F)
                                write_en <= '1';
                            elsif is_high_score_display(x_pos, y_pos, high_score) then
                                pixel_color <= "111100001111"; -- 紫色最高分 (R=F, G=0, B=F)
                                write_en <= '1';
                            end if;
                        
                        -- 默认情况
                        when others =>
                            -- 不执行任何操作
                            null;
                    end case;
                    
                    -- 更新位置
                    if x_pos = SCREEN_WIDTH-1 then
                        x_pos := 0;
                        if y_pos = SCREEN_HEIGHT-1 then
                            y_pos := 0;
                            -- 内容绘制完成，回到背景初始化阶段（为下一帧准备）
                            render_stage := INIT_BACKGROUND;
                            -- 发出帧完成信号
                            frame_complete <= '1';
                        else
                            y_pos := y_pos + 1;
                        end if;
                    else
                        x_pos := x_pos + 1;
                    end if;
            end case;
        end if;
    end process;
end Behavioral;
