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
        general_state : in  std_logic_vector(1 downto 0);  -- 状态编码：00-菜单, 01-初始化, 10-运行中, 11-游戏结束
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
    signal need_food  : std_logic := '0';  -- 需要生成食物的标志
    
    -- 计算空闲格子数量的函数
    function count_empty_spaces(snake_map : std_logic_vector) return integer is
        variable count : integer := 0;
    begin
        for i in 0 to snake_map'length-1 loop
            if snake_map(i) = '0' then
                count := count + 1;
            end if;
        end loop;
        return count;
    end function;
    
begin
    ------------------------------------------------------------------
    -- 食物位置生成逻辑
    ------------------------------------------------------------------
    process(clk, rst_n)
        variable feedback : std_logic;
        variable random_pos : integer range 0 to 299;
        variable valid_pos_found : boolean;
        variable retry_count : integer range 0 to 299;
        variable empty_spaces : integer;
    begin
        if rst_n = '0' then
            food_x_r <= (others => '0');
            food_y_r <= (others => '0');
            lfsr <= x"ACE1";
            valid_pos_found := false;
            retry_count := 0;
            need_food <= '1';  -- 复位时需要生成食物
            
        elsif rising_edge(clk) then
            -- 检测是否需要生成食物
            if general_state = "01" or flag_eat = '1' then
                need_food <= '1';
            end if;
            
            -- 生成食物
            if need_food = '1' then
                valid_pos_found := false;
                retry_count := 0;
                empty_spaces := count_empty_spaces(snake_map);
                
                -- 尝试找到有效位置
                while not valid_pos_found and retry_count < empty_spaces loop
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
                        need_food <= '0';  -- 找到有效位置，清除标志
                    end if;
                    
                    retry_count := retry_count + 1;
                end loop;
                
                -- 如果尝试次数达到空闲格子数量仍未找到位置，说明没有可用空间
                if not valid_pos_found then
                    -- 可以在这里添加错误处理，比如设置一个默认位置
                    food_x_r <= to_unsigned(10, 5);  -- 默认位置
                    food_y_r <= to_unsigned(8, 4);
                    need_food <= '0';  -- 清除标志，避免无限循环
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
