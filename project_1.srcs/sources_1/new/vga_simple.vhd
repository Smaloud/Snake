library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_simple is
    port(
        clk              : in  std_logic;                     -- 100 MHz 主时钟
        rst_n            : in  std_logic;                     -- 低电平有效复位

        color_array      : in  std_logic_vector(11 downto 0); -- RAM 送来的 4-4-4 RGB

        O_hs             : out std_logic;                     -- 行同步（负极性）
        O_vs             : out std_logic;                     -- 场同步（负极性）

        square_h_idx     : out unsigned(11 downto 0);         -- 输出当前像素列计数
        square_v_idx     : out unsigned(11 downto 0);         -- 输出当前像素行计数

        O_red            : out std_logic_vector(3 downto 0);
        O_green          : out std_logic_vector(3 downto 0);
        O_blue           : out std_logic_vector(3 downto 0)
    );
end vga_simple;

architecture Behavioral of vga_simple is

    ------------------------------------------------------------------
    -- 1. 100 MHz → 50 MHz 像素时钟（占空比 50 %）
    ------------------------------------------------------------------
    signal pix_clk : std_logic := '0';
    signal div_ff  : std_logic := '0';

    ------------------------------------------------------------------
    -- 2. 1024×600  @≈58 Hz（50 MHz 像素时钟） CVT-RB 时序
    ------------------------------------------------------------------
    constant C_H_FRONT : integer := 24;
    constant C_H_SYNC  : integer := 136;
    constant C_H_BACK  : integer := 160;
    constant C_H_ACT   : integer := 1024;
    constant C_H_TOTAL : integer := C_H_FRONT + C_H_SYNC + C_H_BACK + C_H_ACT; -- 1344

    constant C_V_FRONT : integer := 8;
    constant C_V_SYNC  : integer := 4;
    constant C_V_BACK  : integer := 23;
    constant C_V_ACT   : integer := 600;
    constant C_V_TOTAL : integer := C_V_FRONT + C_V_SYNC + C_V_BACK + C_V_ACT; -- 635

    -- 起止位置（方便判断有效区）
    constant H_BEFORE : integer := C_H_FRONT + C_H_SYNC + C_H_BACK; -- = 320
    constant H_AFTER  : integer := C_H_TOTAL - C_H_FRONT;           -- = 1320
    constant V_BEFORE : integer := C_V_FRONT + C_V_SYNC + C_V_BACK; -- = 35
    constant V_AFTER  : integer := C_V_TOTAL - C_V_FRONT;           -- = 627

    ------------------------------------------------------------------
    -- 3. 行列计数器
    ------------------------------------------------------------------
    signal h_cnt : unsigned(11 downto 0) := (others=>'0');  -- 0‥1343
    signal v_cnt : unsigned(11 downto 0) := (others=>'0');  -- 0‥634

    -- 有效显示区标志
    signal active_flag : std_logic;

    -- 颜色寄存器
    signal color_reg : std_logic_vector(11 downto 0);
    signal red_r, green_r, blue_r : std_logic_vector(3 downto 0);

    ------------------------------------------------------------------
    -- 工具函数：从 12-bit RGB 中拆分 R/G/B
    ------------------------------------------------------------------
    function slice_r(vec : std_logic_vector) return std_logic_vector is
    begin
        return vec(3 downto 0);
    end function;

    function slice_g(vec : std_logic_vector) return std_logic_vector is
    begin
        return vec(7 downto 4);
    end function;

    function slice_b(vec : std_logic_vector) return std_logic_vector is
    begin
        return vec(11 downto 8);
    end function;

begin
    ------------------------------------------------------------------
    -- A. 2 分频：100 MHz → 50 MHz
    ------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then                 -- 低电平复位
                div_ff  <= '0';
                pix_clk <= '0';
            else
                div_ff  <= not div_ff;
                pix_clk <= div_ff;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- B. 行计数器
    ------------------------------------------------------------------
    process(pix_clk)
    begin
        if rising_edge(pix_clk) then
            if rst_n = '0' then
                h_cnt <= (others=>'0');
            elsif h_cnt = C_H_TOTAL-1 then
                h_cnt <= (others=>'0');
            else
                h_cnt <= h_cnt + 1;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- C. 列计数器
    ------------------------------------------------------------------
    process(pix_clk)
    begin
        if rising_edge(pix_clk) then
            if rst_n = '0' then
                v_cnt <= (others=>'0');
            elsif h_cnt = C_H_TOTAL-1 then
                if v_cnt = C_V_TOTAL-1 then
                    v_cnt <= (others=>'0');
                else
                    v_cnt <= v_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- D. 同步信号（负极性）
    ------------------------------------------------------------------
    O_hs <= '0' when (to_integer(h_cnt) >= C_H_FRONT) and
                     (to_integer(h_cnt) <  C_H_FRONT + C_H_SYNC)
            else '1';

    O_vs <= '0' when (to_integer(v_cnt) >= C_V_FRONT) and
                     (to_integer(v_cnt) <  C_V_FRONT + C_V_SYNC)
            else '1';

    ------------------------------------------------------------------
    -- E. 有效区标志
    ------------------------------------------------------------------
    active_flag <= '1' when
                   (to_integer(h_cnt) >= H_BEFORE) and
                   (to_integer(h_cnt) <  H_AFTER)  and
                   (to_integer(v_cnt) >= V_BEFORE) and
                   (to_integer(v_cnt) <  V_AFTER)
                   else '0';

    ------------------------------------------------------------------
    -- F. 将外部颜色数据打一拍
    ------------------------------------------------------------------
    process(pix_clk)
    begin
        if rising_edge(pix_clk) then
            if rst_n = '0' then
                color_reg <= (others=>'0');
            else
                color_reg <= color_array;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- G. 根据 active_flag 输出 RGB
    ------------------------------------------------------------------
    process(pix_clk)
    begin
        if rising_edge(pix_clk) then
            if rst_n = '0' then
                red_r   <= (others=>'0');
                green_r <= (others=>'0');
                blue_r  <= (others=>'0');
            elsif active_flag = '1' then
                red_r   <= slice_r(color_reg);
                green_r <= slice_g(color_reg);
                blue_r  <= slice_b(color_reg);
            else
                red_r   <= (others=>'0');
                green_r <= (others=>'0');
                blue_r  <= (others=>'0');
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- H. 端口输出
    ------------------------------------------------------------------
    O_red         <= red_r;
    O_green       <= green_r;
    O_blue        <= blue_r;
    square_h_idx  <= h_cnt;
    square_v_idx  <= v_cnt;

end Behavioral;
