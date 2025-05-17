----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2025/05/17 22:11:04
-- Design Name: 
-- Module Name: vga_simple - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vga_simple is
    port(
        clk              : in  std_logic;                          -- 100 MHz
        rst_n            : in  std_logic;                          -- 低电平有效复位

        color_array      : in std_logic_vector(11 downto 0);       -- 来自ram的vga颜色序列（各4位的红绿蓝）

        O_hs             : out std_logic;                          -- vga行同步
        O_vs             : out std_logic;                          -- vga场同步

        square_h_idx     : out unsigned(10 downto 0);      --目前刷新的行列格子的位置
        square_v_idx     : out unsigned(9 downto 0);

        O_red            : out std_logic_vector(3 downto 0);       --输出显示红色
        O_green          : out std_logic_vector(3 downto 0);       --输出显示绿色
        O_blue           : out std_logic_vector(3 downto 0)      --输出显示蓝色
    );
end vga_simple;

architecture Behavioral of vga_simple is

    --===============  VGA 时序常量 1024 * 600 ===============--
    constant C_H_SYNC_PULSE   : integer := 128;  -- 行同步脉冲
    constant C_H_BACK_PORCH   : integer := 88;   -- 行同步后肩
    constant C_H_ACTIVE_TIME  : integer := 1024; -- 可见区域像素数
    constant C_H_FRONT_PORCH  : integer := 40;   -- 行同步前肩
    constant C_H_LINE_PERIOD  : integer := C_H_SYNC_PULSE + C_H_BACK_PORCH + C_H_ACTIVE_TIME + C_H_FRONT_PORCH; -- 总行时长

    constant C_V_SYNC_PULSE   : integer := 4;    -- 帧同步脉冲
    constant C_V_BACK_PORCH   : integer := 23;   -- 帧同步后肩
    constant C_V_ACTIVE_TIME  : integer := 600;  -- 可见行数
    constant C_V_FRONT_PORCH  : integer := 1;    -- 帧同步前肩
    constant C_V_FRAME_PERIOD : integer := C_V_SYNC_PULSE + C_V_BACK_PORCH + C_V_ACTIVE_TIME + C_V_FRONT_PORCH; -- 总帧周期

    -- 方便使用的中间变量
    constant h_before : integer := C_H_SYNC_PULSE + C_H_BACK_PORCH;
    constant h_after  : integer := C_H_LINE_PERIOD - C_H_FRONT_PORCH;
    constant v_before : integer := C_V_SYNC_PULSE + C_V_BACK_PORCH;
    constant v_after  : integer := C_V_FRAME_PERIOD - C_V_FRONT_PORCH;

    --===============  内部信号 ===============
    signal R_h_cnt_r       : unsigned(11 downto 0);               -- 行时序计数器
    signal R_v_cnt_r       : unsigned(11 downto 0);               -- 列时序计数器
    signal W_active_flag : std_logic;                             -- 刷新标志，为1时rgb数据显示

    signal stay_cnt  : unsigned(29 downto 0);                     -- 蛇在每一格停留时长计数器
    signal interval  : unsigned(29 downto 0);                     -- 蛇在每一格停留时间

    signal flag_printnew : std_logic;                             -- 指定难度时间间隔，用于刷新屏幕

    signal square_h_idx_r : unsigned(10 downto 0) := (others => '0');           
    signal square_v_idx_r : unsigned(9 downto 0) := (others => '0');

    --=== 颜色寄存器 ===
    signal color_array_r : std_logic_vector(11 downto 0);
    signal red_r   : std_logic_vector(3 downto 0);
    signal green_r : std_logic_vector(3 downto 0);
    signal blue_r  : std_logic_vector(3 downto 0);
    
    --=============== 工具函数（用于切片，从输入的12位rgb信号中得到分别的rgb信号） ===============
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
        return vec(11 downto 0);
    end function;

begin

    ------------------------------------------------------------------
    -- 行计数器
    ------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '1' then
            R_h_cnt_r <= (others => '0');
        elsif rising_edge(clk) then
            if R_h_cnt_r = C_H_LINE_PERIOD-1 then
                R_h_cnt_r <= (others => '0');
                if square_h_idx_r < C_H_ACTIVE_TIME - 1 then
                    square_h_idx_r <= square_h_idx_r + 1;
                else square_h_idx_r <= (others => '0');
                end if;
            else
                R_h_cnt_r <= R_h_cnt_r + 1;
            end if;
        end if;
    end process;

    O_hs <= '0' when (R_h_cnt_r < C_H_SYNC_PULSE) else '1';
    square_h_idx <= square_h_idx_r;

    ------------------------------------------------------------------
    -- 列计数器
    ------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '1' then
            R_v_cnt_r <= (others => '0');
        elsif rising_edge(clk) then
            if R_v_cnt_r = C_V_FRAME_PERIOD-1 then
                R_v_cnt_r <= (others => '0');
                if square_v_idx_r < C_V_ACTIVE_TIME - 1 then
                    square_v_idx_r <= square_v_idx_r + 1;
                else square_v_idx_r <= (others => '0');
                end if;
            elsif R_h_cnt_r = C_H_LINE_PERIOD-1 then
                R_v_cnt_r <= R_v_cnt_r + 1;
            end if;
        end if;
    end process;

    O_vs <= '0' when (R_v_cnt_r < C_V_SYNC_PULSE) else '1';
    square_v_idx <= square_v_idx_r;

    ------------------------------------------------------------------
    -- 有效区标志
    ------------------------------------------------------------------
    W_active_flag <= '1' when 
    (to_integer(R_h_cnt_r) >= h_before)  and
    (to_integer(R_h_cnt_r) <  h_after)   and
    (to_integer(R_v_cnt_r) >= v_before)  and
    (to_integer(R_v_cnt_r) <  v_after)   else '0';

    ------------------------------------------------------------------
    -- 获取rgb 
    ------------------------------------------------------------------
    process(clk, rst_n)
        begin
            if rst_n = '1' then
                red_r   <= (others => '0');
                green_r <= (others => '0');
                blue_r  <= (others => '0');
            elsif rising_edge(clk) then
                if W_active_flag = '0' then
                    red_r   <= (others => '0');
                    green_r <= (others => '0');
                    blue_r  <= (others => '0');
                else
                    red_r   <= slice_r(color_array_r);
                    green_r <= slice_g(color_array_r);
                    blue_r  <= slice_b(color_array_r);
                end if;
            end if;
        end process;

    ------------------------------------------------------------------
    -- 颜色端口输出
    ------------------------------------------------------------------
    O_red         <= red_r;
    O_green       <= green_r;
    O_blue        <= blue_r;
            
end Behavioral;
