library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity collision_checker is
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        general_state : in  std_logic_vector(1 downto 0);

        snake_x       : in  std_logic_vector(199 downto 0);
        snake_y       : in  std_logic_vector(199 downto 0);
        snake_length  : in  std_logic_vector(9 downto 0);

        is_dead       : out std_logic
    );
end collision_checker;

architecture Behavioral of collision_checker is
    constant SCREEN_WIDTH  : integer := 640;
    constant SCREEN_HEIGHT : integer := 480;
    constant SQUARE_LENGTH : integer := 20;
    constant SQUARE_WIDTH  : integer := 24;
    constant MAX_BODY_LEN  : integer := 20;

    signal is_dead_r : std_logic := '0';

    function slice10(vec : std_logic_vector; idx : natural) return unsigned is
        variable lo : integer := idx * 10;
    begin
        return unsigned(vec(lo + 9 downto lo));
    end function;

    function slice10_y(vec : std_logic_vector; idx : natural) return unsigned is
        variable lo : integer := idx * 10;
    begin
        return unsigned(vec(lo + 9 downto lo));
    end function;

begin

    process(clk, rst_n)
        variable head_x : unsigned(9 downto 0);
        variable head_y : unsigned(9 downto 0);
    begin
        if rst_n = '0' then
            is_dead_r <= '0';
        elsif rising_edge(clk) then
            if general_state = "10" then -- 初始化时重置标志
                is_dead_r <= '0';
            elsif general_state = "11" and is_dead_r = '0' then -- 游戏中 & 未死亡
                head_x := slice10(snake_x, 0);
                head_y := slice10_y(snake_y, 0);

                -- 撞墙
                if (head_x < to_unsigned(0, 10)) or
                   (head_x > to_unsigned(SCREEN_WIDTH - SQUARE_LENGTH, 10)) or
                   (head_y < to_unsigned(0, 10)) or
                   (head_y > to_unsigned(SCREEN_HEIGHT - SQUARE_WIDTH, 10)) then
                    is_dead_r <= '1';

                else
                    -- 撞到自己（从第1节点到length-1判断）
                    for i in 1 to MAX_BODY_LEN - 1 loop
                        if (head_x = slice10(snake_x, i)) and
                           (head_y = slice10_y(snake_y, i)) then
                            is_dead_r <= '1';
                        end if;
                    end loop;
                end if;
            end if;
        end if;
    end process;

    is_dead <= is_dead_r;

end Behavioral;
