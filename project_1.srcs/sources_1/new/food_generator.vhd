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
        general_state : in  std_logic_vector(2 downto 0);  -- 状态码扩展到3位
        flag_eat      : inout  std_logic;  -- 食物被吃掉的信号
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
    signal random_x    : unsigned(4 downto 0) := (others => '0');
    signal random_y    : unsigned(3 downto 0) := (others => '0');
    signal lfsr       : std_logic_vector(15 downto 0) := x"ACE1";  -- 16位LFSR初始值

begin
    ------------------------------------------------------------------
    -- 随机数生成（使用LFSR）
    ------------------------------------------------------------------
    process(clk, rst_n)
        variable feedback : std_logic;
    begin
        if rst_n = '0' then
            lfsr <= x"ACE1";
        elsif rising_edge(clk) then
            if general_state = "010" or flag_eat = '1' then  -- 初始化或食物被吃掉
                -- LFSR更新
                feedback := lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10);
                lfsr <= lfsr(14 downto 0) & feedback;
                
                -- 生成随机坐标
                random_x <= unsigned(lfsr(4 downto 0)) mod to_unsigned(GRID_WIDTH, 5);
                random_y <= unsigned(lfsr(8 downto 5)) mod to_unsigned(GRID_HEIGHT, 4);
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 食物位置生成逻辑
    ------------------------------------------------------------------
    process(clk, rst_n)
        variable map_index : integer;
    begin
        if rst_n = '0' then
            food_x_r <= (others => '0');
            food_y_r <= (others => '0');
        elsif rising_edge(clk) then
            if general_state = "010" or flag_eat = '1' then  -- 初始化或食物被吃掉
                -- 计算在snake_map中的索引
                map_index := to_integer(random_x) + to_integer(random_y) * GRID_WIDTH;
                
                -- 如果位置未被占用，则更新食物位置
                if snake_map(map_index) = '0' then
                    food_x_r <= random_x;
                    food_y_r <= random_y;
                    flag_eat <= '0';
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 输出
    ------------------------------------------------------------------
    food_x <= food_x_r;
    food_y <= food_y_r;

end Behavioral;
