library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity food_generator is
    generic (
        SCREEN_WIDTH  : integer := 800;  -- 屏幕宽度
        SCREEN_HEIGHT : integer := 600;  -- 屏幕高度
        SQUARE_SIZE   : integer := 40;   -- 蛇身方块大小
        MAX_SNAKE_LEN : integer := 300   -- 最大蛇身长度
    );
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        general_state : in  std_logic_vector(1 downto 0);  -- 状态码：00-菜单, 01-初始化, 10-运行中, 11-游戏结束
        flag_eat      : in  std_logic;  -- 食物被吃掉的信号
        snake_map     : in  std_logic_vector(299 downto 0);  -- 蛇身位置图

        food_x        : out unsigned(4 downto 0);  -- 食物x坐标
        food_y        : out unsigned(3 downto 0)   -- 食物y坐标
    );
end food_generator;

architecture Behavioral of food_generator is
    constant GRID_WIDTH   : integer := SCREEN_WIDTH/SQUARE_SIZE;   -- 20
    constant GRID_HEIGHT  : integer := SCREEN_HEIGHT/SQUARE_SIZE;  -- 15

    signal food_x_r    : unsigned(4 downto 0) := (others => '0');
    signal food_y_r    : unsigned(3 downto 0) := (others => '0');
    signal lfsr       : std_logic_vector(15 downto 0) := x"ACE1";  -- 16位LFSR初始值

begin
    ------------------------------------------------------------------
    -- 食物位置生成逻辑
    ------------------------------------------------------------------
    process(clk, rst_n)
        variable feedback : std_logic;
        variable random_pos : integer range 0 to 299;
        variable valid_pos_found : boolean;
        variable retry_count : integer range 0 to 299;
    begin
        if rst_n = '0' then
            food_x_r <= (others => '0');
            food_y_r <= (others => '0');
            lfsr <= x"ACE1";
            valid_pos_found := false;
            retry_count := 0;
        elsif rising_edge(clk) then
            if general_state = "01" or flag_eat = '1' then  -- 初始化或食物被吃掉
                valid_pos_found := false;
                retry_count := 0;
                
                -- 尝试找到有效位置
                while not valid_pos_found and retry_count < 300 loop
                    -- 更新LFSR
                    feedback := lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10);
                    lfsr <= lfsr(14 downto 0) & feedback;
                    
                    -- 生成0-299之间的随机位置
                    random_pos := to_integer(unsigned(lfsr(8 downto 0))) mod 300;
                    
                    -- 检查位置是否有效（没有蛇身）
                    if snake_map(random_pos) = '0' then
                        valid_pos_found := true;
                        -- 将位置转换为x,y坐标（从1开始）
                        food_x_r <= to_unsigned((random_pos mod GRID_WIDTH) + 1, 5);
                        food_y_r <= to_unsigned((random_pos / GRID_WIDTH) + 1, 4);
                    end if;
                    
                    retry_count := retry_count + 1;
                end loop;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 输出
    ------------------------------------------------------------------
    food_x <= food_x_r;
    food_y <= food_y_r;

end Behavioral;
