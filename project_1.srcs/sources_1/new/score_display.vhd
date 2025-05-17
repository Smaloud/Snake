library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity score_display is
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        score         : in  std_logic_vector(15 downto 0);  -- 当前分数
        high_score    : in  std_logic_vector(15 downto 0);  -- 最高分
        
        -- VGA坐标和显示控制
        h_cnt         : in  unsigned(11 downto 0);  -- 当前水平像素位置
        v_cnt         : in  unsigned(11 downto 0);  -- 当前垂直像素位置
        active_flag   : in  std_logic;              -- 有效显示区域标志
        
        -- 输出像素颜色（如果在分数区域）
        is_score_area : out std_logic;              -- 当前像素是否在分数显示区域
        r_out         : out std_logic_vector(3 downto 0);  -- 红色分量
        g_out         : out std_logic_vector(3 downto 0);  -- 绿色分量
        b_out         : out std_logic_vector(3 downto 0)   -- 蓝色分量
    );
end score_display;

architecture Behavioral of score_display is
    -- VGA时序常量
    constant H_BEFORE : integer := 144;  -- 同步+后沿
    constant V_BEFORE : integer := 35;   -- 同步+后沿
    
    -- 分数显示区域定义
    constant SCORE_X      : integer := 50;   -- 分数显示区域起始X坐标
    constant SCORE_Y      : integer := 20;   -- 分数显示区域起始Y坐标
    constant DIGIT_WIDTH  : integer := 8;    -- 数字宽度
    constant DIGIT_HEIGHT : integer := 16;   -- 数字高度
    constant CHAR_SPACING : integer := 2;    -- 字符间距
    
    -- 分数数字ROM (0-9数字的16x8点阵)
    type digit_rom_t is array(0 to 9, 0 to 15) of std_logic_vector(7 downto 0);
    constant DIGIT_ROM : digit_rom_t := (
        -- 数字0
        ( "00111100",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "00111100",
          "00000000" ),
        -- 数字1
        ( "00011000",
          "00111000",
          "01111000",
          "00011000",
          "00011000",
          "00011000",
          "00011000",
          "00011000",
          "00011000",
          "00011000",
          "00011000",
          "00011000",
          "00011000",
          "00011000",
          "01111110",
          "00000000" ),
        -- 数字2
        ( "00111100",
          "01100110",
          "01100110",
          "00000110",
          "00000110",
          "00001100",
          "00011000",
          "00110000",
          "01100000",
          "01000000",
          "01000000",
          "01000000",
          "01000000",
          "01100110",
          "01111110",
          "00000000" ),
        -- 数字3
        ( "00111100",
          "01100110",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "00111100",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "01100110",
          "00111100",
          "00000000" ),
        -- 数字4
        ( "00000110",
          "00001110",
          "00011110",
          "00110110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01111110",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "00000000" ),
        -- 数字5
        ( "01111110",
          "01100000",
          "01100000",
          "01100000",
          "01100000",
          "01100000",
          "01111100",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "01100110",
          "00111100",
          "00000000" ),
        -- 数字6
        ( "00111100",
          "01100110",
          "01100000",
          "01100000",
          "01100000",
          "01100000",
          "01111100",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "00111100",
          "00000000" ),
        -- 数字7
        ( "01111110",
          "01100110",
          "00000110",
          "00000110",
          "00001100",
          "00001100",
          "00011000",
          "00011000",
          "00110000",
          "00110000",
          "00110000",
          "00110000",
          "00110000",
          "00110000",
          "00110000",
          "00000000" ),
        -- 数字8
        ( "00111100",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "00111100",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "00111100",
          "00000000" ),
        -- 数字9
        ( "00111100",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "01100110",
          "00111110",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "00000110",
          "01100110",
          "00111100",
          "00000000" )
    );
    
    -- 文本"SCORE:"和"HIGH:"的ROM
    type text_rom_t is array(0 to 1, 0 to 5, 0 to 15) of std_logic_vector(7 downto 0);
    constant TEXT_ROM : text_rom_t := (
        -- "SCORE:"
        (
            -- 'S'
            ( "00111100",
              "01100110",
              "01100110",
              "01100000",
              "01100000",
              "00111100",
              "00000110",
              "00000110",
              "00000110",
              "00000110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "00111100",
              "00000000" ),
            -- 'C'
            ( "00111100",
              "01100110",
              "01100110",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01100110",
              "01100110",
              "01100110",
              "00111100",
              "00000000" ),
            -- 'O'
            ( "00111100",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "00111100",
              "00000000" ),
            -- 'R'
            ( "01111100",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01111100",
              "01111000",
              "01101100",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "00000000" ),
            -- 'E'
            ( "01111110",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01111100",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01111110",
              "00000000" ),
            -- ':'
            ( "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00111100",
              "00111100",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00111100",
              "00111100",
              "00000000",
              "00000000",
              "00000000",
              "00000000" )
        ),
        -- "HIGH:"
        (
            -- 'H'
            ( "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01111110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "00000000" ),
            -- 'I'
            ( "01111110",
              "00011000",
              "00011000",
              "00011000",
              "00011000",
              "00011000",
              "00011000",
              "00011000",
              "00011000",
              "00011000",
              "00011000",
              "00011000",
              "00011000",
              "00011000",
              "01111110",
              "00000000" ),
            -- 'G'
            ( "00111100",
              "01100110",
              "01100110",
              "01100000",
              "01100000",
              "01100000",
              "01100000",
              "01101110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "00111100",
              "00000000" ),
            -- 'H'
            ( "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01111110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "01100110",
              "00000000" ),
            -- ' '
            ( "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00000000" ),
            -- ':'
            ( "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00111100",
              "00111100",
              "00000000",
              "00000000",
              "00000000",
              "00000000",
              "00111100",
              "00111100",
              "00000000",
              "00000000",
              "00000000",
              "00000000" )
        )
    );
    
    -- 分数解码信号
    signal score_digits      : unsigned(19 downto 0); -- 5个BCD码数字
    signal high_score_digits : unsigned(19 downto 0); -- 5个BCD码数字
    
    -- 当前像素位置
    signal pixel_x : integer;
    signal pixel_y : integer;
    
    -- 辅助函数：将二进制转换为BCD码
    function to_bcd(bin : unsigned(15 downto 0)) return unsigned is
        variable bcd : unsigned(19 downto 0) := (others => '0');
        variable bin_int : unsigned(15 downto 0) := bin;
    begin
        for i in 0 to 15 loop
            -- 如果任何BCD数字大于等于5，加3
            if bcd(3 downto 0) >= 5 then
                bcd(3 downto 0) := bcd(3 downto 0) + 3;
            end if;
            if bcd(7 downto 4) >= 5 then
                bcd(7 downto 4) := bcd(7 downto 4) + 3;
            end if;
            if bcd(11 downto 8) >= 5 then
                bcd(11 downto 8) := bcd(11 downto 8) + 3;
            end if;
            if bcd(15 downto 12) >= 5 then
                bcd(15 downto 12) := bcd(15 downto 12) + 3;
            end if;
            if bcd(19 downto 16) >= 5 then
                bcd(19 downto 16) := bcd(19 downto 16) + 3;
            end if;
            
            -- 左移一位
            bcd := bcd(18 downto 0) & bin_int(15);
            bin_int := bin_int(14 downto 0) & '0';
        end loop;
        
        return bcd;
    end function;
    
begin
    -- 将当前VGA位置转换为像素坐标
    pixel_x <= to_integer(h_cnt - H_BEFORE);
    pixel_y <= to_integer(v_cnt - V_BEFORE);
    
    -- 将分数转换为BCD码
    process(clk)
    begin
        if rising_edge(clk) then
            score_digits <= to_bcd(unsigned(score));
            high_score_digits <= to_bcd(unsigned(high_score));
        end if;
    end process;
    
    -- 分数显示逻辑
    process(clk, rst_n)
        variable in_score_area : boolean;
        variable char_x, char_y : integer;
        variable digit_index : integer;
        variable digit_value : integer;
        variable text_index : integer;
        variable pixel_on : std_logic;
    begin
        if rst_n = '0' then
            is_score_area <= '0';
            r_out <= (others => '0');
            g_out <= (others => '0');
            b_out <= (others => '0');
        elsif rising_edge(clk) then
            -- 默认不在分数区域
            in_score_area := false;
            pixel_on := '0';
            
            -- 检查是否在活动显示区域
            if active_flag = '1' then
                -- 检查"SCORE:"文本区域
                if pixel_y >= SCORE_Y and pixel_y < SCORE_Y + DIGIT_HEIGHT then
                    -- 文本"SCORE:"
                    for i in 0 to 5 loop
                        if pixel_x >= SCORE_X + i*(DIGIT_WIDTH + CHAR_SPACING) and 
                           pixel_x < SCORE_X + i*(DIGIT_WIDTH + CHAR_SPACING) + DIGIT_WIDTH then
                            char_x := pixel_x - (SCORE_X + i*(DIGIT_WIDTH + CHAR_SPACING));
                            char_y := pixel_y - SCORE_Y;
                            in_score_area := true;
                            pixel_on := TEXT_ROM(0, i, char_y)(7-char_x);
                        end if;
                    end loop;
                    
                    -- 分数数字
                    for i in 0 to 4 loop
                        digit_index := 4 - i;
                        digit_value := to_integer(score_digits((digit_index*4)+3 downto digit_index*4));
                        
                        if pixel_x >= SCORE_X + (6+i)*(DIGIT_WIDTH + CHAR_SPACING) and 
                           pixel_x < SCORE_X + (6+i)*(DIGIT_WIDTH + CHAR_SPACING) + DIGIT_WIDTH then
                            char_x := pixel_x - (SCORE_X + (6+i)*(DIGIT_WIDTH + CHAR_SPACING));
                            char_y := pixel_y - SCORE_Y;
                            in_score_area := true;
                            pixel_on := DIGIT_ROM(digit_value, char