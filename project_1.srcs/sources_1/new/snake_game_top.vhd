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
        btn_start : in  std_logic;  -- 开始按钮
        btn_select: in  std_logic;  -- 选择按钮
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
    signal general_state : std_logic_vector(2 downto 0);  -- 游戏状态
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
    
    -- 显示相关信号
    signal pixel_x       : unsigned(10 downto 0);           -- 像素x坐标
    signal pixel_y       : unsigned(9 downto 0);            -- 像素y坐标
    signal pixel_color   : std_logic_vector(11 downto 0);   -- 像素颜色
    signal write_en      : std_logic;                       -- 写使能
    signal frame_complete: std_logic;                       -- 帧完成信号
    signal color_array   : std_logic_vector(11 downto 0);   -- 颜色数据
    signal active_flag   : std_logic;                       -- 有效显示区标志
    signal R_h_cnt       : unsigned(11 downto 0);           -- VGA行计数
    signal R_v_cnt       : unsigned(11 downto 0);           -- VGA列计数
    
    -- 图像ROM相关信号
    signal image_select  : std_logic_vector(2 downto 0);    -- 图片选择信号
    signal rom_addr      : unsigned(19 downto 0);           -- 图片ROM地址
    signal rom_data      : std_logic_vector(11 downto 0);   -- 图片ROM数据

begin
    -- 游戏状态机
    game_fsm_inst : entity work.game_fsm
    port map (
        clk           => clk,
        rst_n         => rst_n,
        start_btn     => btn_start,
        is_dead       => is_dead,
        is_win        => is_win,
        select_btn    => btn_select,
        back_btn      => btn_back,
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
        general_state => general_state(1 downto 0),
        flag_eat      => flag_eat,
        flag_update   => update_signal,
        score         => score,
        high_score    => high_score
    );

    -- 图像ROM
    image_rom_inst : entity work.image_rom
    port map (
        clk           => clk,
        addr          => rom_addr,
        image_select  => image_select,
        data          => rom_data
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
        pixel_x        => pixel_x,
        pixel_y        => pixel_y,
        pixel_color    => pixel_color,
        write_en       => write_en,
        frame_complete => frame_complete,
        image_select   => image_select,
        rom_addr       => rom_addr,
        rom_data       => rom_data
    );

    -- 帧缓冲区
    framebuffer_inst : entity work.framebuffer_rgb444
    port map (
        clk            => clk,
        rst_n          => rst_n,
        write_en       => write_en,
        frame_complete => frame_complete,
        pixel_x        => pixel_x,
        pixel_y        => pixel_y,
        pixel_color    => pixel_color,
        R_h_cnt        => R_h_cnt,
        R_v_cnt        => R_v_cnt,
        W_active_flag  => active_flag,
        color_array    => color_array
    );

    -- VGA控制器
    vga_inst : entity work.vga_simple
    port map (
        clk         => clk,
        rst_n       => rst_n,
        color_array => color_array,
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