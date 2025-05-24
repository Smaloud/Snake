library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity key_handler is
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        
        -- 物理按键输入（低电平有效）
        btn_up        : in  std_logic;
        btn_down      : in  std_logic;
        btn_left      : in  std_logic;
        btn_right     : in  std_logic;
        
        -- 当前方向状态（用于防止180度转向）
        current_dir   : in  std_logic_vector(4 downto 0);
        
        -- 输出到snake_controller的移动状态
        move_state    : out std_logic_vector(4 downto 0)
    );
end key_handler;

architecture Behavioral of key_handler is
    -- 方向常量定义
    constant STOP      : std_logic_vector(4 downto 0) := "00001";
    constant FACE_UP   : std_logic_vector(4 downto 0) := "00010";
    constant FACE_DOWN : std_logic_vector(4 downto 0) := "00100";
    constant FACE_LEFT : std_logic_vector(4 downto 0) := "01000";
    constant FACE_RIGHT: std_logic_vector(4 downto 0) := "10000";
    
    -- 输出方向寄存器
    signal move_state_r  : std_logic_vector(4 downto 0) := STOP;
    
    -- 按键状态寄存器
    signal btn_up_r     : std_logic := '0';
    signal btn_down_r   : std_logic := '0';
    signal btn_left_r   : std_logic := '0';
    signal btn_right_r  : std_logic := '0';
    
begin
    -- 按键状态更新过程
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            btn_up_r <= '0';
            btn_down_r <= '0';
            btn_left_r <= '0';
            btn_right_r <= '0';
            move_state_r <= STOP;
            
        elsif rising_edge(clk) then
            -- 更新按键状态
            if btn_up = '1' then
                btn_up_r <= '1';
                btn_down_r <= '0';
                btn_left_r <= '0';
                btn_right_r <= '0';
            elsif btn_down = '1' then
                btn_up_r <= '0';
                btn_down_r <= '1';
                btn_left_r <= '0';
                btn_right_r <= '0';
            elsif btn_left = '1' then
                btn_up_r <= '0';
                btn_down_r <= '0';
                btn_left_r <= '1';
                btn_right_r <= '0';
            elsif btn_right = '1' then
                btn_up_r <= '0';
                btn_down_r <= '0';
                btn_left_r <= '0';
                btn_right_r <= '1';
            end if;
            
            -- 根据按键状态更新方向（防止180度转向）
            if btn_up_r = '1' and current_dir /= FACE_DOWN then
                move_state_r <= FACE_UP;
            elsif btn_down_r = '1' and current_dir /= FACE_UP then
                move_state_r <= FACE_DOWN;
            elsif btn_left_r = '1' and current_dir /= FACE_RIGHT then
                move_state_r <= FACE_LEFT;
            elsif btn_right_r = '1' and current_dir /= FACE_LEFT then
                move_state_r <= FACE_RIGHT;
            end if;
        end if;
    end process;
    
    -- 输出当前移动状态
    move_state <= move_state_r;
    
end Behavioral;