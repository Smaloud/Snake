library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


entity vga is
    port(
        clk              : in  std_logic;                          -- 100 MHz
        rst_n            : in  std_logic;                          -- low active reset
        general_state    : in  std_logic_vector(1 downto 0); --总状态切�?
        difficulty_state : in  std_logic_vector(1 downto 0); --难度切换
        move_state       : in  std_logic_vector(4 downto 0);--蛇朝向切�?
        random_x         : in  std_logic_vector(4 downto 0);--食物随机x
        random_y         : in  std_logic_vector(4 downto 0);--食物随机y

        O_red            : out std_logic_vector(3 downto 0);--vga红色
        O_green          : out std_logic_vector(3 downto 0);--vga绿色
        O_blue           : out std_logic_vector(3 downto 0);--vga蓝色

        snake_x          : out std_logic_vector(199 downto 0);
        snake_y          : out std_logic_vector(199 downto 0);
        snake_length     : out std_logic_vector(9 downto 0);

        O_hs             : out std_logic;--vga行同�?
        flag_isdead      : out std_logic;--蛇死亡判�?
        O_vs             : out std_logic --vga场同�?
    );
end vga;

architecture Behavioral of vga is
    --===============  常量映射 ===============
    constant start      : std_logic_vector(1 downto 0) := "00";--�?始菜�?
    constant diff_menu  : std_logic_vector(1 downto 0) := "01";--选择难度菜单
    constant game_start : std_logic_vector(1 downto 0) := "10";--初始
    constant gaming     : std_logic_vector(1 downto 0) := "11";--游戏进行菜单

    constant hard : std_logic_vector(1 downto 0) := "00";--�?
    constant mid  : std_logic_vector(1 downto 0) := "01";--�?
    constant easy : std_logic_vector(1 downto 0) := "10";--�?

    constant length_init : unsigned(9 downto 0) := to_unsigned(3,10);--蛇初始长�?
    constant headx_init  : unsigned(9 downto 0) := to_unsigned(340,10);--蛇头初始x坐标
    constant heady_init  : unsigned(8 downto 0) := to_unsigned(240,9);--蛇头初始y坐标

    constant stop       : std_logic_vector(4 downto 0) := "00001";--初始停止状�??
    constant face_up    : std_logic_vector(4 downto 0) := "00010";--向上状�??
    constant face_down  : std_logic_vector(4 downto 0) := "00100";--向下状�??
    constant face_left  : std_logic_vector(4 downto 0) := "01000";--向左状�??
    constant face_right : std_logic_vector(4 downto 0) := "10000";--向右状�??

    constant square_length : integer := 20;--界面�?
    constant square_width  : integer := 24;--界面�?

  --===============  VGA 时序常量 �?640 * 480�?===============
    constant C_H_SYNC_PULSE   : integer := 96;
    constant C_H_BACK_PORCH   : integer := 48;
    constant C_H_ACTIVE_TIME  : integer := 640;
    constant C_H_FRONT_PORCH  : integer := 16;
    constant C_H_LINE_PERIOD  : integer := 800;

    constant C_V_SYNC_PULSE   : integer := 2;
    constant C_V_BACK_PORCH   : integer := 33;
    constant C_V_ACTIVE_TIME  : integer := 480;
    constant C_V_FRONT_PORCH  : integer := 10;
    constant C_V_FRAME_PERIOD : integer := 525;

    constant h_before : integer := C_H_SYNC_PULSE + C_H_BACK_PORCH;
    constant h_after  : integer := C_H_LINE_PERIOD - C_H_FRONT_PORCH;
    constant v_before : integer := C_V_SYNC_PULSE + C_V_BACK_PORCH;
    constant v_after  : integer := C_V_FRAME_PERIOD - C_V_FRONT_PORCH;

    --===============  内部信号 ===============
    signal R_h_cnt       : unsigned(11 downto 0);-- 行时序计数器
    signal R_v_cnt       : unsigned(11 downto 0);-- 列时序计数器
    signal W_active_flag : std_logic;--刷新标志，为1时rgb数据显示

    signal stay_cnt  : unsigned(29 downto 0);--蛇在每一格停留时长计数器
    signal interval  : unsigned(29 downto 0);--蛇在每一格停留时�?

    signal flag_printnew : std_logic;--指定难度时间间隔，用于刷新屏�?




    --=== 颜色寄存�? ===
    signal red_r   : std_logic_vector(3 downto 0);
    signal green_r : std_logic_vector(3 downto 0);
    signal blue_r  : std_logic_vector(3 downto 0);

    --=============== 工具函数（用于切片，把存储的蛇的位置数据转换为单元格数据�? ===============
    function slice10(vec : std_logic_vector; idx : natural) return unsigned is
        variable lo : integer := idx*10;
    begin
        return unsigned(vec(lo+9 downto lo));
    end function;

    function slice10_y(vec : std_logic_vector; idx : natural) return unsigned is
        variable lo : integer := idx*10;
    begin
        return unsigned(vec(lo+9 downto lo));
    end function;

begin
    ------------------------------------------------------------------
    -- 行计数器
    ------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '1' then
            R_h_cnt <= (others => '0');
        elsif rising_edge(clk) then
            if R_h_cnt = C_H_LINE_PERIOD-1 then
                R_h_cnt <= (others => '0');
            else
                R_h_cnt <= R_h_cnt + 1;
            end if;
        end if;
    end process;

    O_hs <= '0' when (R_h_cnt < C_H_SYNC_PULSE) else '1';

    ------------------------------------------------------------------
    -- 列计数器
    ------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '1' then
            R_v_cnt <= (others => '0');
        elsif rising_edge(clk) then
            if R_v_cnt = C_V_FRAME_PERIOD-1 then
                R_v_cnt <= (others => '0');
            elsif R_h_cnt = C_H_LINE_PERIOD-1 then
                R_v_cnt <= R_v_cnt + 1;
            end if;
        end if;
    end process;

    O_vs <= '0' when (R_v_cnt < C_V_SYNC_PULSE) else '1';

    ------------------------------------------------------------------
    -- 有效区标�?
    ------------------------------------------------------------------
    W_active_flag <= '1' when 
    (to_integer(R_h_cnt) >= h_before)  and
    (to_integer(R_h_cnt) <  h_after)   and
    (to_integer(R_v_cnt) >= v_before)  and
    (to_integer(R_v_cnt) <  v_after)   else '0';

    ------------------------------------------------------------------
    -- pause 计数�? (stay_cnt) 以及 flag_printnew
    ------------------------------------------------------------------
    W_active_flag <= '1' when 
         (to_integer(R_h_cnt) >= h_before)  and
         (to_integer(R_h_cnt) <  h_after)   and
         (to_integer(R_v_cnt) >= v_before)  and
         (to_integer(R_v_cnt) <  v_after)   else '0';

    ------------------------------------------------------------------
    -- pause 计数�? (stay_cnt) 以及 flag_printnew
    ------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '1' then
            stay_cnt <= (others => '0');
        elsif rising_edge(clk) then
            if general_state = game_start then
                stay_cnt <= (others => '0');
            elsif (general_state = gaming) and (move_state /= stop) then
                if stay_cnt = interval - 1 then
                    stay_cnt <= (others => '0');
                else
                    stay_cnt <= stay_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    flag_printnew <= '1' when stay_cnt = interval - 1 else '0';

    ------------------------------------------------------------------
    -- 难度对应 interval
    ------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '1' then
            interval <= to_unsigned(20_000_000, 30); -- 0.8 s
        elsif rising_edge(clk) then
            if (general_state = diff_menu) then
                case difficulty_state is
                    when easy => interval <= to_unsigned(20_000_000,30); --0.8
                    when mid  => interval <= to_unsigned(10_000_000,30); --0.4
                    when hard => interval <= to_unsigned(5_000_000 ,30); --0.2
                    when others => null;
                end case;
            end if;
        end if;
    end process;




end Behavioral;
