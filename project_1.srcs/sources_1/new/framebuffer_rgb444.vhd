library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity framebuffer_rgb444 is
    port (
        clk_write    : in  std_logic;
        write_en     : in  std_logic;
        pixel_x      : in  unsigned(9 downto 0);  -- 写入像素 x 坐标（0~639）
        pixel_y      : in  unsigned(8 downto 0);  -- 写入像素 y 坐标（0~479）
        pixel_color  : in  std_logic_vector(11 downto 0); -- RGB444 (4+4+4)

        clk_read     : in  std_logic;
        R_h_cnt      : in  unsigned(11 downto 0); -- VGA 控制器提供的行像素计数
        R_v_cnt      : in  unsigned(11 downto 0); -- VGA 控制器提供的列像素计数
        W_active_flag: in  std_logic;

        red_out      : out std_logic_vector(3 downto 0);
        green_out    : out std_logic_vector(3 downto 0);
        blue_out     : out std_logic_vector(3 downto 0)
    );
end framebuffer_rgb444;

architecture Behavioral of framebuffer_rgb444 is

    constant SCREEN_WIDTH  : integer := 640;
    constant SCREEN_HEIGHT : integer := 480;
    constant PIXEL_COUNT   : integer := SCREEN_WIDTH * SCREEN_HEIGHT;  -- 307200
    constant ADDR_WIDTH    : integer := 19;  -- ceil(log2(307200))

    type ram_type is array (0 to PIXEL_COUNT - 1) of std_logic_vector(11 downto 0);
    signal framebuffer : ram_type := (others => (others => '0'));

    signal write_addr : unsigned(ADDR_WIDTH-1 downto 0);
    signal read_addr  : unsigned(ADDR_WIDTH-1 downto 0);
    signal pixel_read : std_logic_vector(11 downto 0);

begin

    -- ✅ 写地址（行优先编码）
    write_addr <= pixel_y * SCREEN_WIDTH + pixel_x;

    -- ✅ 写入过程
    process(clk_write)
    begin
        if rising_edge(clk_write) then
            if write_en = '1' then
                framebuffer(to_integer(write_addr)) <= pixel_color;
            end if;
        end if;
    end process;

    -- ✅ 读地址（与 VGA 控制器扫描同步）
    read_addr <= R_v_cnt * SCREEN_WIDTH + R_h_cnt;

    -- ✅ 读取过程
    process(clk_read)
    begin
        if rising_edge(clk_read) then
            pixel_read <= framebuffer(to_integer(read_addr));
        end if;
    end process;

    -- ✅ RGB 输出
    red_out   <= pixel_read(11 downto 8) when W_active_flag = '1' else (others => '0');
    green_out <= pixel_read(7 downto 4)  when W_active_flag = '1' else (others => '0');
    blue_out  <= pixel_read(3 downto 0)  when W_active_flag = '1' else (others => '0');

end Behavioral;
