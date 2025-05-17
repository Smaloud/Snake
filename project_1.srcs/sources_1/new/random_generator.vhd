library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity random_generator is
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        enable    : in  std_logic;  -- 使能信号，控制何时更新随机数
        random_x  : out std_logic_vector(5 downto 0);  -- 0-63范围的X坐标(640/10=64格)
        random_y  : out std_logic_vector(5 downto 0)   -- 0-47范围的Y坐标(480/10=48格)
    );
end random_generator;

architecture Behavioral of random_generator is
    -- 8位LFSR，足够生成0-63的随机数
    signal lfsr_reg : std_logic_vector(7 downto 0) := "00000001";  -- 非零初始值
    
    -- 为Y使用不同的LFSR，增加随机性
    signal lfsr_reg2 : std_logic_vector(7 downto 0) := "10101010";  -- 非零初始值
begin
    -- LFSR过程 - 使用多项式x^8 + x^6 + x^5 + x^4 + 1
    -- 参考：https://zipcpu.com/dsp/2017/10/27/lfsr.html
    process(clk, rst_n)
        variable feedback : std_logic;
        variable feedback2 : std_logic;
    begin
        if rst_n = '0' then
            lfsr_reg <= "00000001";  -- 重置为非零初始值
            lfsr_reg2 <= "10101010"; -- 重置为非零初始值
        elsif rising_edge(clk) then
            if enable = '1' then
                -- 第一个LFSR的反馈计算
                feedback := lfsr_reg(7) xor lfsr_reg(5) xor lfsr_reg(4) xor lfsr_reg(3);
                lfsr_reg <= lfsr_reg(6 downto 0) & feedback;
                
                -- 第二个LFSR的反馈计算（使用不同的多项式）
                feedback2 := lfsr_reg2(7) xor lfsr_reg2(6) xor lfsr_reg2(3) xor lfsr_reg2(1);
                lfsr_reg2 <= lfsr_reg2(6 downto 0) & feedback2;
            end if;
        end if;
    end process;
    
    -- 输出映射：取LFSR的低位作为随机坐标
    -- X坐标限制在0-63范围内
    random_x <= std_logic_vector(resize(unsigned(lfsr_reg(5 downto 0)) mod 64, 6));
    
    -- Y坐标限制在0-47范围内
    random_y <= std_logic_vector(resize(unsigned(lfsr_reg2(5 downto 0)) mod 48, 6));
end Behavioral;