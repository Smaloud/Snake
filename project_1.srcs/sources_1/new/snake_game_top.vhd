library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_game_top is
    port (
        -- 系统信号
        clk     : in  std_logic;  -- 100MHz系统时钟
        rst_n   : in  std_logic;  -- 低电平有效复位
        
        -- 按键输入（低电平有效）
        btn_up    : in  std_logic;
        btn_down  : in  std_logic;
        btn_left  : in  std_logic;
        btn_right : in  std_logic;
        btn_diff1 : in  std_logic;  -- 难度选择按钮1
        btn_diff2 : in  std_logic;  -- 难度选择按钮2
        btn_diff3 : in  std_logic;  -- 难度选择按钮3
        btn_back  : in  std_logic;  -- 返回按钮
        
        -- VGA输出
        O_hs    : out std_logic;  -- 行同步
        O_vs    : out std_logic;  -- 场同步
        O_red   : out std_logic_vector(3 downto 0);
        O_green : out std_logic_vector(3 downto 0);
        O_blue  : out std_logic_vector(3 downto 0)
    );
end snake_game_top;

architecture Behavioral of snake_game_top is
    -- 内部信号声明
    signal general_state : std_logic_vector(1 downto 0);  -- 游戏状态
    signal difficulty    : std_logic_vector(1 downto 0);  -- 难度选择
    signal update_signal : std_logic;                     -- 更新信号
    signal move_state    : std_logic_vector(4 downto 0);  -- 移动状态
    signal flag_eat      : std_logic;                     -- 吃到食物信号
    signal is_dead       : std_logic;                     -- 死亡信号
    signal is_win        : std_logic;                     -- 胜利信号
    
    -- 蛇和食物相关信号
    signal snake_map     : std_logic_vector(299 downto 0);  -- 蛇身位置图
    signal food_x        : unsigned(4 downto 0);            -- 食物x坐标
    signal food_y        : unsigned(3 downto 0);            -- 食物y坐标
    
    -- 分数相关信号
    signal score         : std_logic_vector(11 downto 0);   -- 当前分数
    signal high_score    : std_logic_vector(11 downto 0);   -- 最高分
    signal score_bcd     : std_logic_vector(15 downto 0);   -- 转换为BCD的分数
    signal high_score_bcd: std_logic_vector(15 downto 0);   -- 转换为BCD的最高分
    
    -- 显示相关信号
    signal pixel_x       : unsigned(10 downto 0);           -- 像素x坐标
    signal pixel_y       : unsigned(9 downto 0);            -- 像素y坐标
    signal pixel_color   : std_logic_vector(2 downto 0);   -- 像素颜色
    signal write_en      : std_logic;                       -- 写使能
    signal frame_complete: std_logic;                       -- 帧完成信号
    signal active_flag   : std_logic;                       -- 有效显示区标志
    signal R_h_cnt       : unsigned(11 downto 0);           -- VGA行计数
    signal R_v_cnt       : unsigned(11 downto 0);           -- VGA列计数
    
    -- ROM相关信号
    signal menu_rom_addr : std_logic_vector(19 downto 0);   -- 菜单ROM地址
    signal menu_rom_data : std_logic_vector(0 downto 0);    -- 菜单ROM数据
    signal gameover_rom_addr : std_logic_vector(19 downto 0); -- GameOver ROM地址
    signal gameover_rom_data : std_logic_vector(0 downto 0);  -- GameOver ROM数据
    
    -- 字体ROM相关信号
    signal font_char_code : std_logic_vector(3 downto 0);   -- 字符代码
    signal font_row       : std_logic_vector(3 downto 0);   -- 字符行
    signal font_row_data  : std_logic_vector(7 downto 0);   -- 字符行数据
    
    -- 文本显示相关信号
    signal text_type     : std_logic_vector(1 downto 0);   -- 文本类型
    signal text_x_pos    : std_logic_vector(5 downto 0);   -- 文本内X坐标
    signal text_y_pos    : std_logic_vector(2 downto 0);   -- 文本内Y坐标
    signal text_pixel_on : std_logic;                      -- 文本像素是否点亮
    
    -- ROM IP核组件声明
    component blk_mem_gen_menu
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(19 downto 0);
            douta : out std_logic_vector(0 downto 0)
        );
    end component;
    
    component blk_mem_gen_gameover
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(19 downto 0);
            douta : out std_logic_vector(0 downto 0)
        );
    end component;
    
    -- 字体ROM组件声明
    component font_rom
        port(
            clk       : in  std_logic;
            char_code : in  std_logic_vector(3 downto 0);
            row       : in  std_logic_vector(3 downto 0);
            row_data  : out std_logic_vector(7 downto 0)
        );
    end component;
    
    -- 二进制转BCD组件声明
    component bin_to_bcd
        port(
            bin_in  : in  std_logic_vector(11 downto 0);
            bcd_out : out std_logic_vector(15 downto 0)
        );
    end component;
    
    -- 文本显示模块声明
    component text_display
        port(
            clk       : in  std_logic;
            text_type : in  std_logic_vector(1 downto 0);
            x_pos     : in  std_logic_vector(5 downto 0);
            y_pos     : in  std_logic_vector(2 downto 0);
            pixel_on  : out std_logic
        );
    end component;
    
begin
    -- 游戏状态机
    game_fsm_inst : entity work.game_fsm
    port map (
        clk           => clk,
        rst_n         => rst_n,
        is_dead       => is_dead,
        is_win        => is_win,
        diff_btn1     => btn_diff1,
        diff_btn2     => btn_diff2,
        diff_btn3     => btn_diff3,
        back_btn      => btn_back,
        up_btn        => btn_up,
        down_btn      => btn_down,
        left_btn      => btn_left,
        right_btn     => btn_right,
        current_state => general_state,
        difficulty    => difficulty
    );

    -- 难度控制器
    difficulty_controller_inst : entity work.difficulty_controller
    port map (
        clk           => clk,
        rst_n         => rst_n,
        difficulty    => difficulty,
        update_signal => update_signal
    );

    -- 按键处理
    key_handler_inst : entity work.key_handler
    port map (
        clk         => clk,
        rst_n       => rst_n,
        btn_up      => btn_up,
        btn_down    => btn_down,
        btn_left    => btn_left,
        btn_right   => btn_right,
        current_dir => move_state,  -- 当前方向
        move_state  => move_state   -- 输出移动状态
    );

    -- 蛇控制器
    snake_controller_inst : entity work.snake_controller
    port map (
        clk           => clk,
        rst_n         => rst_n,
        general_state => general_state,
        move_state    => move_state,
        flag_update   => update_signal,
        food_x        => food_x,
        food_y        => food_y,
        snake_map     => snake_map,
        is_win        => is_win,
        is_dead       => is_dead,
        flag_eat      => flag_eat
    );

    -- 食物生成器
    food_generator_inst : entity work.food_generator
    port map (
        clk           => clk,
        rst_n         => rst_n,
        general_state => general_state,
        flag_eat      => flag_eat,
        snake_map     => snake_map,
        food_x        => food_x,
        food_y        => food_y
    );

    -- 分数记录器
    score_keeper_inst : entity work.score_keeper
    port map (
        clk           => clk,
        rst_n         => rst_n,
        general_state => general_state,
        flag_eat      => flag_eat,
        flag_update   => update_signal,
        score         => score,
        high_score    => high_score
    );
    
    -- 菜单ROM实例化
    menu_rom_inst : blk_mem_gen_menu
    port map (
        clka  => clk,
        addra => menu_rom_addr,
        douta => menu_rom_data
    );
    
    -- GameOver ROM实例化
    gameover_rom_inst : blk_mem_gen_gameover
    port map (
        clka  => clk,
        addra => gameover_rom_addr,
        douta => gameover_rom_data
    );
    
    -- 字体ROM实例化
    font_rom_inst : font_rom
    port map (
        clk       => clk,
        char_code => font_char_code,
        row       => font_row,
        row_data  => font_row_data
    );
    
    -- 文本显示模块实例化
    text_display_inst : text_display
    port map (
        clk       => clk,
        text_type => text_type,
        x_pos     => text_x_pos,
        y_pos     => text_y_pos,
        pixel_on  => text_pixel_on
    );
    
    -- 分数二进制转BCD实例化
    score_bcd_inst : bin_to_bcd
    port map (
        bin_in  => score,
        bcd_out => score_bcd
    );
    
    -- 最高分二进制转BCD实例化
    high_score_bcd_inst : bin_to_bcd
    port map (
        bin_in  => high_score,
        bcd_out => high_score_bcd
    );

    -- 帧生成器
    frame_generator_inst : entity work.frame_generator
    port map (
        clk            => clk,
        rst_n          => rst_n,
        general_state  => general_state,
        difficulty     => difficulty,
        snake_map      => snake_map,
        food_x         => food_x,
        food_y         => food_y,
        score          => score,
        high_score     => high_score,
        is_win         => is_win,
        is_dead        => is_dead,
        R_h_cnt        => R_h_cnt,
        R_v_cnt        => R_v_cnt,
        W_active_flag  => active_flag,
        menu_rom_data  => menu_rom_data,
        gameover_rom_data => gameover_rom_data,
        font_row_data  => font_row_data,
        text_pixel_on  => text_pixel_on,
        text_type      => text_type,
        text_x_pos     => text_x_pos,
        text_y_pos     => text_y_pos,
        pixel_color    => pixel_color,
        write_en       => write_en,
        frame_complete => frame_complete,
        menu_rom_addr  => menu_rom_addr,
        gameover_rom_addr => gameover_rom_addr,
        font_char_code => font_char_code,
        font_row       => font_row
    );

    -- VGA控制器
    vga_inst : entity work.vga_simple
    port map (
        clk         => clk,
        rst_n       => rst_n,
        color_array => pixel_color,
        square_h_idx     => R_h_cnt,
        square_v_idx     => R_v_cnt,
        O_hs        => O_hs,
        O_vs        => O_vs,
        O_red       => O_red,
        O_green     => O_green,
        O_blue      => O_blue,
        active_flag => active_flag
    );

end Behavioral;