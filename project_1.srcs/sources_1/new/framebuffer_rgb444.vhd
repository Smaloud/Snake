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
        pixel_color   : in  std_logic_vector(2 downto 0);  -- 写入像素颜色RGB444

        -- VGA控制接口
        R_h_cnt       : in  unsigned(11 downto 0);          -- VGA 控制器提供的行像素计数
        R_v_cnt       : in  unsigned(11 downto 0);          -- VGA 控制器提供的列像素计数
        W_active_flag : in  std_logic;                      -- VGA有效显示区标志

        -- 输出给VGA控制器的颜色
        color_array   : out std_logic_vector(2 downto 0)   -- 12位RGB444色彩信号
    );
end framebuffer_rgb444;

architecture Behavioral of framebuffer_rgb444 is
    constant SCREEN_WIDTH  : integer := 1024;
    constant SCREEN_HEIGHT : integer := 600;
    constant PIXEL_COUNT   : integer := SCREEN_WIDTH * SCREEN_HEIGHT;  -- 614400
    constant ADDR_WIDTH    : integer := 20;  -- ceil(log2(614400))

    -- 帧缓冲区管理信号
    signal frame_ready : std_logic := '0';
    signal frame_buffer_index : std_logic := '0';
    signal display_buffer_index : std_logic := '0';
    
    -- 像素时钟相关
    signal pix_clk : std_logic := '0';
    signal div_ff  : std_logic := '0';

    -- 双缓冲区RAM
    type ram_type is array (0 to PIXEL_COUNT - 1) of std_logic_vector(2 downto 0);
    signal framebuffer0 : ram_type := (others => (others => '0'));
    signal framebuffer1 : ram_type := (others => (others => '0'));

    signal write_addr : unsigned(ADDR_WIDTH-1 downto 0);
    signal read_addr  : unsigned(ADDR_WIDTH-1 downto 0);
    signal pixel_read : std_logic_vector(2 downto 0);

begin
    -- 生成像素时钟
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

    -- 写入过程
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                frame_buffer_index <= '0';
                frame_ready <= '0';
            elsif write_en = '1' then
                if frame_buffer_index = '0' then
                    framebuffer0(to_integer(write_addr)) <= pixel_color;
                else
                    framebuffer1(to_integer(write_addr)) <= pixel_color;
                end if;
            elsif frame_complete = '1' then
                frame_buffer_index <= not frame_buffer_index;
                frame_ready <= '1';
            end if;
        end if;
    end process;

    -- 读地址计算
    read_addr <= resize(R_v_cnt * SCREEN_WIDTH + R_h_cnt, ADDR_WIDTH);

    -- 读取过程
    process(pix_clk)
    begin
        if rising_edge(pix_clk) then
            if rst_n = '0' then
                pixel_read <= (others => '0');
                display_buffer_index <= '0';
            else
                -- 从帧缓冲区读取数据
                if display_buffer_index = '0' then
                    pixel_read <= framebuffer0(to_integer(read_addr));
                else
                    pixel_read <= framebuffer1(to_integer(read_addr));
                end if;
                
                if R_v_cnt = 0 and R_h_cnt = 0 and frame_ready = '1' then
                    display_buffer_index <= frame_buffer_index;
                    frame_ready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- RGB输出 - 移除显示控制，直接输出像素值，让frame_generator控制
    color_array <= pixel_read;

end Behavioral;