library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bin_to_bcd is
    port ( 
        bin_in  : in  std_logic_vector(11 downto 0);  -- 二进制输入，最大4095
        bcd_out : out std_logic_vector(15 downto 0)   -- BCD输出 (4位，每位4bit)
    );
end bin_to_bcd;

architecture Behavioral of bin_to_bcd is
begin
    -- Double Dabble 算法实现二进制转BCD
    process(bin_in)
        variable temp : unsigned(27 downto 0);  -- 二进制输入 + 16位BCD输出
        variable bcd  : unsigned(15 downto 0) := (others => '0');
    begin
        -- 初始化
        bcd := (others => '0');
        temp(27 downto 16) := (others => '0');
        temp(11 downto 0) := unsigned(bin_in);
        
        -- 执行12次移位和加3操作
        for i in 0 to 11 loop
            -- 检查数字是否大于等于5，如果是则加3
            if temp(15 downto 12) > 4 then
                temp(15 downto 12) := temp(15 downto 12) + 3;
            end if;
            
            if temp(19 downto 16) > 4 then
                temp(19 downto 16) := temp(19 downto 16) + 3;
            end if;
            
            if temp(23 downto 20) > 4 then
                temp(23 downto 20) := temp(23 downto 20) + 3;
            end if;
            
            if temp(27 downto 24) > 4 then
                temp(27 downto 24) := temp(27 downto 24) + 3;
            end if;
            
            -- 左移一位
            temp := temp(26 downto 0) & '0';
        end loop;
        
        -- 输出BCD结果
        bcd_out <= std_logic_vector(temp(27 downto 12));
    end process;
end Behavioral; 