library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity framebuffer_rgb444 is
    port (
        clk           : in  std_logic;                      -- 系统时钟(100MHz)
        rst_n         : in  std_logic;                      -- 复位信号
        write_en      : in  std_logic;                      -- 写使能
        frame_complete: in  std_logic;                      -- 一帧写入完成标志
        pixel_x       : in  unsigned(10 downto 0);          -- 写入像素 x 坐标(0~1023)
        pixel_y       : in  unsigned(9 downto 0);           -- 写入像素 y 坐标(0~599)
        pixel_color   : in  std_logic_vector(11 downto 0);  -- 写入像素颜色RGB444

        -- VGA控制接口
        R_h_cnt       : in  unsigned(11 downto 0);          -- VGA 行计数
        R_v_cnt       : in  unsigned(11 downto 0);          -- VGA 列计数
        W_active_flag : in  std_logic;                      -- VGA有效显示标志

        -- VGA输出
        color_array   : out std_logic_vector(11 downto 0);   -- RGB444输出
        buffer_ready  : out std_logic                        -- 缓冲区就绪信号
    );
end framebuffer_rgb444;

architecture Behavioral of framebuffer_rgb444 is
    constant SCREEN_WIDTH  : integer := 1024;
    constant SCREEN_HEIGHT : integer := 600;
    constant PIXEL_COUNT   : integer := SCREEN_WIDTH * SCREEN_HEIGHT;  -- 614400
    constant ADDR_WIDTH    : integer := 20;

    type ram_type is array (0 to PIXEL_COUNT - 1) of std_logic_vector(11 downto 0);
    signal framebuffer0, framebuffer1 : ram_type := (others => (others => '0'));

    signal write_addr  : unsigned(ADDR_WIDTH-1 downto 0);
    signal read_addr   : unsigned(ADDR_WIDTH-1 downto 0);
    signal pixel_read  : std_logic_vector(11 downto 0);

    signal frame_buffer_index      : std_logic := '0';  -- 当前写缓冲
    signal display_buffer_index    : std_logic := '0';  -- 当前读缓冲
    signal next_frame_buffer_index : std_logic := '0';  -- 即将显示的缓冲

    signal pix_clk : std_logic := '0';
    signal div_ff  : std_logic := '0';

    -- 状态机定义
    type state_type is (IDLE, WRITING, WAIT_DISPLAY, DISPLAYING);
    signal state : state_type := IDLE;

begin
    -- 生成像素时钟（50MHz）
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                div_ff  <= '0';
                pix_clk <= '0';
            else
                div_ff  <= not div_ff;
                pix_clk <= div_ff;
            end if;
        end if;
    end process;

    -- 写地址计算
    write_addr <= resize(pixel_y * SCREEN_WIDTH + pixel_x, ADDR_WIDTH);

    -- 写入缓冲区
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                frame_buffer_index <= '0';
                framebuffer0 <= (others => (others => '0'));
                framebuffer1 <= (others => (others => '0'));
            elsif write_en = '1' then
                if frame_buffer_index = '0' then
                    framebuffer0(to_integer(write_addr)) <= pixel_color;
                else
                    framebuffer1(to_integer(write_addr)) <= pixel_color;
                end if;
            end if;
        end if;
    end process;

    -- 状态机控制缓冲切换
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE;
                frame_buffer_index <= '0';
                display_buffer_index <= '0';
                next_frame_buffer_index <= '0';
                buffer_ready <= '1';
            else
                case state is
                    when IDLE =>
                        buffer_ready <= '1';
                        if write_en = '1' then
                            state <= WRITING;
                            buffer_ready <= '1';
                        end if;

                    when WRITING =>
                        if frame_complete = '1' then
                            next_frame_buffer_index <= not frame_buffer_index;
                            state <= WAIT_DISPLAY;
                            buffer_ready <= '0';
                        end if;

                    when WAIT_DISPLAY =>
                        if R_h_cnt = 0 and R_v_cnt = 0 then
                            display_buffer_index <= not next_frame_buffer_index;
                            frame_buffer_index   <= next_frame_buffer_index;
                            state <= DISPLAYING;
                            buffer_ready <= '1';
                        end if;

                    when DISPLAYING =>
                        if write_en = '1' then
                            state <= WRITING;
                            buffer_ready <= '1';
                        end if;

                    when others =>
                        state <= IDLE;
                        buffer_ready <= '1';
                end case;
            end if;
        end if;
    end process;

    -- VGA读取地址计算
    read_addr <= resize(R_v_cnt * SCREEN_WIDTH + R_h_cnt, ADDR_WIDTH);

    -- 从显示缓冲中读取像素数据
    process(pix_clk)
    begin
        if rising_edge(pix_clk) then
            if rst_n = '0' then
                pixel_read <= (others => '0');
            else
                if display_buffer_index = '0' then
                    pixel_read <= framebuffer0(to_integer(read_addr));
                else
                    pixel_read <= framebuffer1(to_integer(read_addr));
                end if;
            end if;
        end if;
    end process;

    -- 输出到 VGA 控制器
    color_array <= pixel_read;

end Behavioral;
