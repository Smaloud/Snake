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
    
    -- 消抖计数器和寄存器
    constant DEBOUNCE_LIMIT : integer := 500000;  -- 5ms@100MHz
    signal debounce_counter : integer range 0 to DEBOUNCE_LIMIT := 0;
    
    -- 按键状态寄存器
    signal btn_up_reg    : std_logic_vector(1 downto 0) := "11";
    signal btn_down_reg  : std_logic_vector(1 downto 0) := "11";
    signal btn_left_reg  : std_logic_vector(1 downto 0) := "11";
    signal btn_right_reg : std_logic_vector(1 downto 0) := "11";
    
    -- 输出方向寄存器
    signal move_state_r  : std_logic_vector(4 downto 0) := STOP;
    
begin
    -- 按键消抖和方向控制过程
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            btn_up_reg <= "11";
            btn_down_reg <= "11";
            btn_left_reg <= "11";
            btn_right_reg <= "11";
            debounce_counter <= 0;
            move_state_r <= STOP;
            
        elsif rising_edge(clk) then
            -- 移位寄存器采样按键状态
            btn_up_reg <= btn_up_reg(0) & btn_up;
            btn_down_reg <= btn_down_reg(0) & btn_down;
            btn_left_reg <= btn_left_reg(0) & btn_left;
            btn_right_reg <= btn_right_reg(0) & btn_right;
            
            -- 消抖计数
            if debounce_counter = DEBOUNCE_LIMIT then
                debounce_counter <= 0;
                
                -- 检测按键并更新方向（防止180度转向）
                if btn_up_reg = "00" and current_dir /= FACE_DOWN then
                    move_state_r <= FACE_UP;
                elsif btn_down_reg = "00" and current_dir /= FACE_UP then
                    move_state_r <= FACE_DOWN;
                elsif btn_left_reg = "00" and current_dir /= FACE_RIGHT then
                    move_state_r <= FACE_LEFT;
                elsif btn_right_reg = "00" and current_dir /= FACE_LEFT then
                    move_state_r <= FACE_RIGHT;
                end if;
            else
                debounce_counter <= debounce_counter + 1;
            end if;
        end if;
    end process;
    
    -- 输出当前移动状态
    move_state <= move_state_r;
    
end Behavioral;