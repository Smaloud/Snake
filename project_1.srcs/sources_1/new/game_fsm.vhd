library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity game_fsm is
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;

        start_btn     : in  std_logic;  -- 开始按钮（从按键输入获得）
        is_dead       : in  std_logic;  -- 从 collision_checker 获得

        current_state : out std_logic_vector(1 downto 0)
    );
end game_fsm;

architecture Behavioral of game_fsm is
    type state_type is (IDLE, INIT_GAME, RUNNING);
    signal state_r : state_type := IDLE;
begin

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state_r <= IDLE;

        elsif rising_edge(clk) then
            case state_r is

                when IDLE =>
                    if start_btn = '1' then
                        state_r <= INIT_GAME;
                    end if;

                when INIT_GAME =>
                    state_r <= RUNNING;

                when RUNNING =>
                    if is_dead = '1' then
                        state_r <= IDLE; -- 或扩展为 GAME_OVER
                    end if;

                when others =>
                    state_r <= IDLE;

            end case;
        end if;
    end process;

    -- 输出状态（2-bit 编码）
    current_state <= 
        "00" when state_r = IDLE else
        "10" when state_r = INIT_GAME else
        "11";  -- RUNNING

end Behavioral;
