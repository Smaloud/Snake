library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity food_generator is
    generic (
        SCREEN_WIDTH  : integer := 640;  -- 屏幕宽度
        SCREEN_HEIGHT : integer := 480;  -- 屏幕高度
        SQUARE_SIZE   : integer := 20;   -- 蛇身方块大小
        MAX_SNAKE_LEN : integer := 3072  -- 最大蛇身长度
    );
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        general_state : in  std_logic_vector(2 downto 0);  -- 状态码扩展到3位

        snake_x       : in  std_logic_vector(MAX_SNAKE_LEN*10-1 downto 0);
        snake_y       : in  std_logic_vector(MAX_SNAKE_LEN*10-1 downto 0);
        snake_length  : in  std_logic_vector(11 downto 0);

        head_x        : in  unsigned(9 downto 0);
        head_y        : in  unsigned(8 downto 0);

        random_x      : in  std_logic_vector(4 downto 0);
        random_y      : in  std_logic_vector(4 downto 0);

        flag_eat      : out std_logic;
        food_x        : out unsigned(9 downto 0);
        food_y        : out unsigned(8 downto 0)
    );
end food_generator;

architecture Behavioral of food_generator is
    constant GRID_WIDTH   : integer := SCREEN_WIDTH/SQUARE_SIZE;
    constant GRID_HEIGHT  : integer := SCREEN_HEIGHT/SQUARE_SIZE;

    signal food_x_r    : unsigned(9 downto 0) := (others => '0');
    signal food_y_r    : unsigned(8 downto 0) := (others => '0');
    signal flag_eat_r  : std_logic := '0';

    -- 蛇身坐标切片函数
    function slice10(vec : std_logic_vector; idx : natural) return unsigned is
        variable lo : integer := idx * 10;
    begin
        return unsigned(vec(lo + 9 downto lo));
    end function;

begin

    ------------------------------------------------------------------
    -- 判断蛇头是否吃到食物
    ------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            flag_eat_r <= '0';
        elsif rising_edge(clk) then
            if (head_x = food_x_r) and (head_y = food_y_r) and (general_state = "011") then -- gaming
                flag_eat_r <= '1';
            else
                flag_eat_r <= '0';
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 食物生成逻辑（检查所有蛇身节点）
    ------------------------------------------------------------------
    process(clk, rst_n)
        variable candidate_x : unsigned(9 downto 0);
        variable candidate_y : unsigned(8 downto 0);
        variable overlap     : boolean;
        variable snake_len   : integer;
    begin
        if rst_n = '0' then
            food_x_r <= (others => '0');
            food_y_r <= (others => '0');
        elsif rising_edge(clk) then
            if (flag_eat_r = '1') or (general_state = "010") then -- eat 或 初始化
                -- 计算候选值
                candidate_x := unsigned(random_x) * SQUARE_SIZE;
                candidate_y := unsigned(random_y) * SQUARE_SIZE;
                
                -- 确保在屏幕范围内
                if candidate_x >= to_unsigned(SCREEN_WIDTH, 10) then
                    candidate_x := to_unsigned(SCREEN_WIDTH - SQUARE_SIZE, 10);
                end if;
                if candidate_y >= to_unsigned(SCREEN_HEIGHT, 9) then
                    candidate_y := to_unsigned(SCREEN_HEIGHT - SQUARE_SIZE, 9);
                end if;

                -- 检查是否与所有蛇身节点重叠
                overlap := false;
                snake_len := to_integer(unsigned(snake_length));
                
                for i in 0 to snake_len-1 loop
                    if (candidate_x = slice10(snake_x, i)) and
                       (resize(candidate_y, 10) = slice10(snake_y, i)) then
                        overlap := true;
                        exit;  -- 发现重叠立即退出
                    end if;
                end loop;

                -- 不重叠则更新食物位置
                if not overlap then
                    food_x_r <= candidate_x;
                    food_y_r <= candidate_y;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 输出
    ------------------------------------------------------------------
    food_x   <= food_x_r;
    food_y   <= food_y_r;
    flag_eat <= flag_eat_r;

end Behavioral;
