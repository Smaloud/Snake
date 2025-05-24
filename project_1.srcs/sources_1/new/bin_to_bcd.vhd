library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bin_to_bcd is
    port(
        bin_in  : in  std_logic_vector(11 downto 0);  -- 12位二进制输入
        bcd_out : out std_logic_vector(15 downto 0)   -- 16位BCD输出 (4位十进制数，每位4bit)
    );
end bin_to_bcd;

architecture Behavioral of bin_to_bcd is
begin
    -- 二进制转BCD（双倍加三法）
    process(bin_in)
        variable temp : std_logic_vector(27 downto 0); -- 临时变量，存放中间结果
    begin
        -- 初始化temp，高16位为0，低12位为输入的二进制数
        temp := (others => '0');
        temp(11 downto 0) := bin_in;
        
        -- 双倍加三法
        for i in 0 to 11 loop
            -- 检查十进制每个位是否大于4，如果是，加3
            -- 检查千位
            if temp(15 downto 12) > "0100" then
                temp(15 downto 12) := std_logic_vector(unsigned(temp(15 downto 12)) + "0011");
            end if;
            
            -- 检查百位
            if temp(19 downto 16) > "0100" then
                temp(19 downto 16) := std_logic_vector(unsigned(temp(19 downto 16)) + "0011");
            end if;
            
            -- 检查十位
            if temp(23 downto 20) > "0100" then
                temp(23 downto 20) := std_logic_vector(unsigned(temp(23 downto 20)) + "0011");
            end if;
            
            -- 检查个位
            if temp(27 downto 24) > "0100" then
                temp(27 downto 24) := std_logic_vector(unsigned(temp(27 downto 24)) + "0011");
            end if;
            
            -- 左移一位
            temp(27 downto 1) := temp(26 downto 0);
            temp(0) := '0';
        end loop;
        
        -- 输出BCD结果
        bcd_out <= temp(27 downto 12);
    end process;
end Behavioral; 