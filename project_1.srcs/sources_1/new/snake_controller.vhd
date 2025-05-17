library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_controller is
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        general_state : in  std_logic_vector(1 downto 0);
        move_state    : in  std_logic_vector(4 downto 0);
        flag_update   : in  std_logic;  -- 控制蛇每帧移动
        flag_eat      : in  std_logic;  -- 吃到食物时置位

        snake_length  : out std_logic_vector(9 downto 0);
        snake_x       : out std_logic_vector(199 downto 0);
        snake_y       : out std_logic_vector(199 downto 0)
    );
end snake_controller;


architecture Behavioral of snake_controller is
    constant LENGTH_INIT  : integer := 3;
    constant SQUARE_LEN   : integer := 20;
    constant MAX_LENGTH   : integer := 20;

    -- 方向定义
    constant STOP        : std_logic_vector(4 downto 0) := "00001";
    constant FACE_UP     : std_logic_vector(4 downto 0) := "00010";
    constant FACE_DOWN   : std_logic_vector(4 downto 0) := "00100";
    constant FACE_LEFT   : std_logic_vector(4 downto 0) := "01000";
    constant FACE_RIGHT  : std_logic_vector(4 downto 0) := "10000";

    type coord_array is array (0 to MAX_LENGTH-1) of unsigned(9 downto 0);
    type coord_y_array is array (0 to MAX_LENGTH-1) of unsigned(8 downto 0);

    signal snake_x_buf   : coord_array;
    signal snake_y_buf   : coord_y_array;
    signal snake_len_r   : unsigned(9 downto 0);

    signal current_dir   : std_logic_vector(4 downto 0);
    
begin

    -- 移动控制
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            snake_len_r <= to_unsigned(LENGTH_INIT, 10);
            current_dir <= STOP;

            -- 初始化蛇的位置（默认横向）
            for i in 0 to MAX_LENGTH-1 loop
                snake_x_buf(i) <= to_unsigned(340 - i*SQUARE_LEN, 10);
                snake_y_buf(i) <= to_unsigned(240, 9);
            end loop;

        elsif rising_edge(clk) then
            if general_state = "10" then  -- 游戏初始化
                snake_len_r <= to_unsigned(LENGTH_INIT, 10);
                current_dir <= STOP;
            elsif general_state = "11" then  -- 游戏中
                -- 更新方向（可加入禁止反向逻辑）
                if move_state /= STOP then
                    current_dir <= move_state;
                end if;

                -- 每帧更新一次位置
                if flag_update = '1' then
                    -- 身体从尾巴向头部移动（shift）
                    for i in MAX_LENGTH - 1 downto 1 loop
                        if i < to_integer(snake_len_r) then
                            snake_x_buf(i) <= snake_x_buf(i-1);
                            snake_y_buf(i) <= snake_y_buf(i-1);
                        end if;
                    end loop;

                    -- 根据方向更新蛇头位置
                    case current_dir is
                        when FACE_UP    => snake_y_buf(0) <= snake_y_buf(0) - to_unsigned(SQUARE_LEN, 9);
                        when FACE_DOWN  => snake_y_buf(0) <= snake_y_buf(0) + to_unsigned(SQUARE_LEN, 9);
                        when FACE_LEFT  => snake_x_buf(0) <= snake_x_buf(0) - to_unsigned(SQUARE_LEN, 10);
                        when FACE_RIGHT => snake_x_buf(0) <= snake_x_buf(0) + to_unsigned(SQUARE_LEN, 10);
                        when others     => null;
                    end case;

                    -- 吃到食物则增长一节
                    if flag_eat = '1' and snake_len_r < to_unsigned(MAX_LENGTH, 10) then
                        snake_len_r <= snake_len_r + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- 输出坐标和长度
    snake_length <= std_logic_vector(snake_len_r);
    snake_x <= (others => '0');
    snake_y <= (others => '0');

    process(snake_x_buf)
    begin
        for i in 0 to MAX_LENGTH-1 loop
            snake_x(i*10+9 downto i*10) <= std_logic_vector(snake_x_buf(i));
        end loop;
    end process;

    process(snake_y_buf)
    begin
        for i in 0 to MAX_LENGTH-1 loop
            snake_y(i*10+9 downto i*10) <= std_logic_vector(resize(snake_y_buf(i), 10));
        end loop;
    end process;

end Behavioral;
