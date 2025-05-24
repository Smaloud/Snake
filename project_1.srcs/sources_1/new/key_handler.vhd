library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity key_handler is
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;

        -- 物理按键输入（低电平有效�?
        btn_up        : in  std_logic;
        btn_down      : in  std_logic;
        btn_left      : in  std_logic;
        btn_right     : in  std_logic;

        -- 当前方向状�?�（用于防止180度转向）
        current_dir   : in  std_logic_vector(4 downto 0);

        -- 输出到snake_controller的移动状�?
        move_state    : out std_logic_vector(4 downto 0)
    );
end key_handler;

architecture Behavioral of key_handler is

    -- 方向编码
    constant STOP       : std_logic_vector(4 downto 0) := "00001";
    constant FACE_UP    : std_logic_vector(4 downto 0) := "00010";
    constant FACE_DOWN  : std_logic_vector(4 downto 0) := "00100";
    constant FACE_LEFT  : std_logic_vector(4 downto 0) := "01000";
    constant FACE_RIGHT : std_logic_vector(4 downto 0) := "10000";

    -- 清抖后的按键输出
    signal btn_up_clean    : std_logic;
    signal btn_down_clean  : std_logic;
    signal btn_left_clean  : std_logic;
    signal btn_right_clean : std_logic;

    signal move_state_r : std_logic_vector(4 downto 0) := STOP;

begin

    -- 实例化按键消抖模块（每个按键�?个）
    up_debounce_inst : entity work.ButtonDebounce
        generic map (
            DEBOUNCE_DELAY => 500000  -- 5ms@100MHz
        )
        port map (
            clk     => clk,
            btn_in  =>  btn_up,  -- 按键低电平有�? �? 反转
            btn_out => btn_up_clean
        );

    down_debounce_inst : entity work.ButtonDebounce
        generic map (DEBOUNCE_DELAY => 500000)
        port map (
            clk     => clk,
            btn_in  =>  btn_down,
            btn_out => btn_down_clean
        );

    left_debounce_inst : entity work.ButtonDebounce
        generic map (DEBOUNCE_DELAY => 500000)
        port map (
            clk     => clk,
            btn_in  =>  btn_left,
            btn_out => btn_left_clean
        );

    right_debounce_inst : entity work.ButtonDebounce
        generic map (DEBOUNCE_DELAY => 500000)
        port map (
            clk     => clk,
            btn_in  =>  btn_right,
            btn_out => btn_right_clean
        );

    -- 按键方向控制逻辑
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            move_state_r <= STOP;
        elsif rising_edge(clk) then
            -- 注意加上防止 180 度反向判�?
            if btn_up_clean = '1' and current_dir /= FACE_DOWN then
                move_state_r <= FACE_UP;
            elsif btn_down_clean = '1' and current_dir /= FACE_UP then
                move_state_r <= FACE_DOWN;
            elsif btn_left_clean = '1' and current_dir /= FACE_RIGHT then
                move_state_r <= FACE_LEFT;
            elsif btn_right_clean = '1' and current_dir /= FACE_LEFT then
                move_state_r <= FACE_RIGHT;
            end if;
        end if;
    end process;

    -- 输出方向
    move_state <= move_state_r;

end Behavioral;
