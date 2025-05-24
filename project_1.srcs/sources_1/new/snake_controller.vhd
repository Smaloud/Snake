library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_controller is
    generic (
        SCREEN_WIDTH  : integer := 800;  -- 屏幕宽度
        SCREEN_HEIGHT : integer := 600;  -- 屏幕高度
        SQUARE_SIZE   : integer := 40;   -- 蛇身方块大小
        MAX_SNAKE_LEN : integer := 300  -- 最大蛇身长度
    );
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        general_state : in  std_logic_vector(1 downto 0);  -- 状态码：00-菜单, 01-初始化, 10-运行中, 11-游戏结束
        move_state    : in  std_logic_vector(4 downto 0);
        flag_update   : in  std_logic;  -- 控制每帧移动
        food_x        : in  unsigned(4 downto 0);  -- 食物x坐标
        food_y        : in  unsigned(3 downto 0);   -- 食物y坐标

        snake_length  : out std_logic_vector(8 downto 0);  -- 蛇的长度
        snake_map     : out std_logic_vector(299 downto 0);  -- 输出蛇身位置图
        is_win        : out std_logic;   -- 游戏胜利信号
        is_dead       : out std_logic;   -- 游戏失败信号
        flag_eat      : out std_logic   -- 食物被吃掉的信号
    );
end snake_controller;

architecture Behavioral of snake_controller is

    -- 坐标位宽（按屏幕划分的格子数量计算）
    constant GRID_WIDTH  : integer := SCREEN_WIDTH / SQUARE_SIZE;
    constant GRID_HEIGHT : integer := SCREEN_HEIGHT / SQUARE_SIZE;
    constant GRID_SIZE   : integer := GRID_WIDTH * GRID_HEIGHT;

    -- 位置编码：行优先，一维数组（snake_map[i]=1 表示该格有蛇）
    type coord_array is array (0 to MAX_SNAKE_LEN - 1) of unsigned(11 downto 0);  -- 最大支持 4096 格子
    signal snake_body : coord_array;
    signal head_ptr   : integer range 0 to MAX_SNAKE_LEN - 1 := 2;
    signal tail_ptr   : integer range 0 to MAX_SNAKE_LEN - 1 := 0;

    signal current_length : integer range 0 to MAX_SNAKE_LEN := 3;
    signal growth_pending : std_logic := '0';

    signal head_x, head_y : integer range 0 to GRID_WIDTH;
    signal next_x, next_y : integer range 0 to GRID_WIDTH;

    signal internal_map   : std_logic_vector(GRID_SIZE-1 downto 0) := (others => '0');

    function encode(x, y: integer) return integer is
    begin
        return y * GRID_WIDTH + x;
    end function;

begin

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            -- Reset 状态
            head_ptr       <= 2;
            tail_ptr       <= 0;
            current_length <= 3;
            growth_pending <= '0';
            internal_map   <= (others => '0');
            is_dead        <= '0';
            is_win         <= '0';
            flag_eat       <= '0';

        elsif rising_edge(clk) then
            if general_state = "01" then  -- 初始化状态
                -- 初始化蛇居中
                head_x <= GRID_WIDTH / 2;
                head_y <= GRID_HEIGHT / 2;

                for i in 0 to 2 loop
                    snake_body(i) <= to_unsigned(encode(GRID_WIDTH / 2 - 2 + i, GRID_HEIGHT / 2), 12);
                    internal_map(encode(GRID_WIDTH / 2 - 2 + i, GRID_HEIGHT / 2)) <= '1';
                end loop;

                head_ptr       <= 2;
                tail_ptr       <= 0;
                current_length <= 3;
                growth_pending <= '0';
                is_dead        <= '0';
                is_win         <= '0';
                flag_eat       <= '0';

            elsif general_state = "10" and flag_update = '1' and is_dead = '0' and is_win = '0' then
                -- 移动方向计算
                case move_state is
                    when "00001" =>  -- 上
                        next_x <= head_x;
                        next_y <= head_y - 1;
                    when "00010" =>  -- 下
                        next_x <= head_x;
                        next_y <= head_y + 1;
                    when "00100" =>  -- 左
                        next_x <= head_x - 1;
                        next_y <= head_y;
                    when "01000" =>  -- 右
                        next_x <= head_x + 1;
                        next_y <= head_y;
                    when others =>
                        next_x <= head_x;
                        next_y <= head_y;
                end case;

                -- 死亡检测（撞墙）
                if next_x < 0 or next_x >= GRID_WIDTH or next_y < 0 or next_y >= GRID_HEIGHT then
                    is_dead <= '1';
                elsif internal_map(encode(next_x, next_y)) = '1' then
                    -- 撞自己
                    is_dead <= '1';
                else
                    -- 正常移动
                    head_x <= next_x;
                    head_y <= next_y;

                    -- 插入新蛇头
                    head_ptr <= (head_ptr + 1) mod MAX_SNAKE_LEN;
                    snake_body(head_ptr) <= to_unsigned(encode(next_x, next_y), 12);
                    internal_map(encode(next_x, next_y)) <= '1';

                    -- 判断是否吃到食物
                    if next_x = to_integer(food_x) and next_y = to_integer(food_y) then
                        growth_pending <= '1';
                        flag_eat <= '1';
                    else
                        flag_eat <= '0';
                    end if;

                    -- 是否增长或更新尾部
                    if growth_pending = '1' then
                        growth_pending <= '0';  -- 本拍不移动尾巴
                        current_length <= current_length + 1;
                    else
                        -- 移除尾部格子
                        internal_map(to_integer(snake_body(tail_ptr))) <= '0';
                        tail_ptr <= (tail_ptr + 1) mod MAX_SNAKE_LEN;
                    end if;

                    -- 胜利判断
                    if current_length = MAX_SNAKE_LEN then
                        is_win <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- 输出映射
    snake_map <= internal_map;
    snake_length <= std_logic_vector(to_unsigned(current_length, 9));

end Behavioral;
