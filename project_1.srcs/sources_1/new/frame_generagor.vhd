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
        general_state  : in  std_logic_vector(1 downto 0);  -- 游戏状态：00-菜单, 01-初始化, 10-运行中, 11-游戏结束
        
        -- 游戏配置信息
        difficulty     : in  std_logic_vector(1 downto 0);  -- 游戏速度：00-慢, 01-中, 10-快, 11-超快
        
        -- 蛇的信息
        snake_map    : in std_logic_vector(299 downto 0); -- 20*15=300位，表示蛇身位置

        
        -- 食物的信息
        food_x         : in  unsigned(4 downto 0);
        food_y         : in  unsigned(3 downto 0);
        
        -- 障碍物信息（用于障碍模式）
        -- obstacle_map   : in  std_logic_vector(63 downto 0); -- 8x8网格的障碍物地图
        
        -- 分数信息
        score          : in  std_logic_vector(11 downto 0);  -- 假设分数为8位
        high_score     : in  std_logic_vector(11 downto 0); -- 最高分记录
        is_win         : in  std_logic;                     -- 是否胜利
        is_dead        : in  std_logic;                     -- 是否死亡
        
        -- VGA 显示控制信号
        R_h_cnt        : in  unsigned(11 downto 0);         -- VGA 控制器提供的行像素计数
        R_v_cnt        : in  unsigned(11 downto 0);         -- VGA 控制器提供的列像素计数
        W_active_flag  : in  std_logic;                     -- VGA有效显示区标志
        
        -- ROM接口
        menu_rom_data  : in  std_logic_vector(0 downto 0);  -- ROM读出的菜单图像数据
        gameover_rom_data : in std_logic_vector(0 downto 0);  -- ROM读出的游戏结束图像数据
        
        -- 字体ROM接口
        font_row_data  : in  std_logic_vector(7 downto 0);  -- 字体ROM行数据
        
        -- 输出接口
        pixel_color   : out std_logic_vector(2 downto 0); -- RGB颜色 (R+G+B)
        write_en      : out std_logic;                     -- 像素有效信号
        frame_complete: out std_logic;                      -- 帧完成信号
        
        -- ROM地址输出
        menu_rom_addr : out std_logic_vector(19 downto 0);  -- 菜单ROM地址 (1024*600需要20位)
        gameover_rom_addr : out std_logic_vector(19 downto 0); -- 游戏结束ROM地址
        
        -- 字体ROM控制
        font_char_code : out std_logic_vector(3 downto 0);  -- 字符代码 (0-9)
        font_row       : out std_logic_vector(3 downto 0)   -- 字符行 (0-15)
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
    
    -- 分数显示位置常量
    constant SCORE_START_X  : integer := SCREEN_WIDTH - 120;
    constant SCORE_START_Y  : integer := 20;
    constant SCORE_DIGIT_WIDTH : integer := 12; -- 每个数字宽度（像素）
    constant DIGIT_HEIGHT   : integer := 16;    -- 数字高度（像素）
    
    -- 最高分显示位置常量
    constant HSCORE_START_X : integer := SCREEN_WIDTH - 120;
    constant HSCORE_START_Y : integer := 50;

    -- BCD接口信号
    signal score_bcd      : std_logic_vector(15 downto 0);
    signal high_score_bcd : std_logic_vector(15 downto 0);
    
    -- BCD转换组件
    component bin_to_bcd
        port(
            bin_in  : in  std_logic_vector(11 downto 0);
            bcd_out : out std_logic_vector(15 downto 0)
        );
    end component;

    -- 辅助函数：判断当前像素是否为分数显示区域
    function is_score_display(
        x : integer;
        y : integer;
        score_val : std_logic_vector(11 downto 0)
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
        high_score_val : std_logic_vector(11 downto 0)
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

begin
    -- 实例化BCD转换器 - 当前分数
    score_bcd_converter: bin_to_bcd
    port map (
        bin_in  => score,
        bcd_out => score_bcd
    );
    
    -- 实例化BCD转换器 - 最高分
    high_score_bcd_converter: bin_to_bcd
    port map (
        bin_in  => high_score,
        bcd_out => high_score_bcd
    );
    
    -- 帧生成过程
    process(clk, rst_n)
        variable h_pos : integer;
        variable v_pos : integer;
        variable grid_x : integer;
        variable grid_y : integer;
        variable position : integer;
        variable rom_addr_int : integer;
        
        -- 分数显示变量
        variable digit_index : integer;
        variable digit_value : std_logic_vector(3 downto 0);
        variable x_offset : integer;
        variable y_offset : integer;
        
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
            menu_rom_addr <= (others => '0');
            gameover_rom_addr <= (others => '0');
            font_char_code <= (others => '0');
            font_row <= (others => '0');
        elsif rising_edge(clk) then
            -- 获取当前像素位置
            h_pos := to_integer(R_h_cnt);
            v_pos := to_integer(R_v_cnt);
            
            -- 检测帧结束
            if h_pos = SCREEN_WIDTH-1 and v_pos = SCREEN_HEIGHT-1 then
                frame_complete <= '1';
            else
                frame_complete <= '0';
            end if;

            -- 默认为背景色和无效像素
            pixel_color <= "000";
            write_en <= '0';
            
            -- 只在有效显示区域内处理像素
            if W_active_flag = '1' then
                -- 设置像素有效
                write_en <= '1';
                
                -- 计算ROM地址 = y * SCREEN_WIDTH + x
                rom_addr_int := v_pos * SCREEN_WIDTH + h_pos;
                menu_rom_addr <= std_logic_vector(to_unsigned(rom_addr_int, 20));
                gameover_rom_addr <= std_logic_vector(to_unsigned(rom_addr_int, 20));
                
                -- 根据游戏状态绘制不同内容
                case general_state is
                    -- 主菜单
                    when "00" =>
                        -- 使用ROM中的图像数据
                        if menu_rom_data(0) = '1' then
                            -- 白色显示ROM中为1的像素
                            pixel_color <= "111";  -- 全白色 (R=1, G=1, B=1)
                        else
                            -- 黑色显示ROM中为0的像素
                            pixel_color <= "000";  -- 黑色背景 (R=0, G=0, B=0)
                        end if;
                    
                    -- 游戏运行中
                    when "01" | "10" =>
                        -- 游戏中的内容
                        
                        -- 绘制蛇身（使用snake_map）
                        -- 计算当前像素所在的网格位置
                        if h_pos < GAME_AREA_END_X then  -- 只在游戏区域内检查蛇身
                            -- 计算当前像素对应的网格索引
                            grid_x := h_pos / GRID_SIZE;
                            grid_y := v_pos / GRID_SIZE;
                            
                            -- 确保网格索引在有效范围内
                            if grid_x >= 0 and grid_x < GRID_COLS and grid_y >= 0 and grid_y < GRID_ROWS then
                                -- 计算在snake_map中的位置
                                position := grid_x + grid_y * GRID_COLS;
                                
                                -- 优先绘制蛇身，如果当前位置没有蛇，再检查是否是食物
                                if position < 300 and snake_map(position) = '1' then
                                    -- 绘制蛇身 (绿色)
                                    pixel_color <= "010";
                                -- 检查是否是食物
                                elsif grid_x = to_integer(food_x) and grid_y = to_integer(food_y) then
                                    -- 绘制食物 (红色)
                                    pixel_color <= "100"; -- 红色食物 (R=1, G=0, B=0)
                                end if;
                            end if;
                        else
                            -- 当前位于信息区域，处理分数显示
                            
                            -- 检查是否在分数显示区域
                            if h_pos >= SCORE_START_X and h_pos < SCORE_START_X + 4*SCORE_DIGIT_WIDTH and 
                               v_pos >= SCORE_START_Y and v_pos < SCORE_START_Y + DIGIT_HEIGHT then
                                
                                -- 计算当前位于哪个数字位置
                                digit_index := (h_pos - SCORE_START_X) / SCORE_DIGIT_WIDTH;
                                
                                -- 根据位置确定显示哪个数字
                                case digit_index is
                                    when 0 => -- 千位
                                        digit_value := score(11 downto 8);
                                    when 1 => -- 百位
                                        digit_value := score(7 downto 4);
                                    when 2 => -- 十位
                                        digit_value := score(3 downto 0);
                                    when 3 => -- 个位
                                        digit_value := "0000";
                                    when others =>
                                        digit_value := "0000";
                                end case;
                                
                                -- 计算在当前数字内的偏移位置
                                x_offset := (h_pos - SCORE_START_X) mod SCORE_DIGIT_WIDTH;
                                y_offset := v_pos - SCORE_START_Y;
                                
                                -- 设置字体ROM地址
                                font_char_code <= digit_value;
                                font_row <= std_logic_vector(to_unsigned(y_offset, 4));
                                
                                -- 检查当前像素是否需要点亮（从字体ROM获取数据）
                                if font_row_data(7 - (x_offset * 8 / SCORE_DIGIT_WIDTH)) = '1' then
                                    pixel_color <= "111"; -- 白色显示数字
                                end if;
                                
                            -- 检查是否在最高分显示区域
                            elsif h_pos >= HSCORE_START_X and h_pos < HSCORE_START_X + 4*SCORE_DIGIT_WIDTH and 
                                  v_pos >= HSCORE_START_Y and v_pos < HSCORE_START_Y + DIGIT_HEIGHT then
                                
                                -- 计算当前位于哪个数字位置
                                digit_index := (h_pos - HSCORE_START_X) / SCORE_DIGIT_WIDTH;
                                
                                -- 根据位置确定显示哪个数字
                                case digit_index is
                                    when 0 => -- 千位
                                        digit_value := high_score(11 downto 8);
                                    when 1 => -- 百位
                                        digit_value := high_score(7 downto 4);
                                    when 2 => -- 十位
                                        digit_value := high_score(3 downto 0);
                                    when 3 => -- 个位
                                        digit_value := "0000";
                                    when others =>
                                        digit_value := "0000";
                                end case;
                                
                                -- 计算在当前数字内的偏移位置
                                x_offset := (h_pos - HSCORE_START_X) mod SCORE_DIGIT_WIDTH;
                                y_offset := v_pos - HSCORE_START_Y;
                                
                                -- 设置字体ROM地址
                                font_char_code <= digit_value;
                                font_row <= std_logic_vector(to_unsigned(y_offset, 4));
                                
                                -- 检查当前像素是否需要点亮（从字体ROM获取数据）
                                if font_row_data(7 - (x_offset * 8 / SCORE_DIGIT_WIDTH)) = '1' then
                                    pixel_color <= "110"; -- 黄色显示最高分
                                end if;
                            end if;
                        end if;
                    
                    -- 游戏结束
                    when "11" =>
                        -- 使用GameOver ROM图像
                        if gameover_rom_data(0) = '1' then
                            -- GameOver图像为1的像素用红色显示
                            pixel_color <= "100";  -- 红色 (R=1, G=0, B=0)
                        else
                            -- GameOver图像为0的像素为黑色背景
                            pixel_color <= "000";  -- 黑色背景 (R=0, G=0, B=0)
                        end if;
                    
                    -- 默认情况
                    when others =>
                        -- 不执行任何操作
                        null;
                end case;
            end if;
        end if;
    end process;
end Behavioral;
