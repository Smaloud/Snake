library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity score_keeper is
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        general_state : in  std_logic_vector(1 downto 0);  -- 游戏状态
        flag_eat      : in  std_logic;                     -- 吃到食物信号
        
        score         : out std_logic_vector(15 downto 0); -- 当前分数（最高65535）
        high_score    : out std_logic_vector(15 downto 0)  -- 最高分
    );
end score_keeper;

architecture Behavioral of score_keeper is
    -- 内部信号
    signal score_r      : unsigned(15 downto 0) := (others => '0');
    signal high_score_r : unsigned(15 downto 0) := (others => '0');
    
    -- 游戏状态常量
    constant GAME_START : std_logic_vector(1 downto 0) := "10";
    constant GAMING     : std_logic_vector(1 downto 0) := "11";
    
begin
    -- 分数计算过程
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            score_r <= (others => '0');
            -- 复位时不清除最高分
            
        elsif rising_edge(clk) then
            if general_state = GAME_START then
                -- 游戏重新开始时，重置当前分数
                score_r <= (others => '0');
                
            elsif general_state = GAMING then
                -- 游戏进行中，吃到食物加10分
                if flag_eat = '1' then
                    score_r <= score_r + 10;
                end if;
            end if;
            
            -- 更新最高分
            if score_r > high_score_r then
                high_score_r <= score_r;
            end if;
        end if;
    end process;
    
    -- 输出分数
    score <= std_logic_vector(score_r);
    high_score <= std_logic_vector(high_score_r);
    
end Behavioral;