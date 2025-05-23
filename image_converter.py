import numpy as np
from PIL import Image
import os

def convert_images_to_vhdl(image_paths, output_file):
    """
    将多张图片转换为VHDL ROM文件
    image_paths: 字典，键为图片编号(0-7)，值为图片路径
    output_file: 输出VHDL文件路径
    """
    # 创建VHDL文件
    with open(output_file, 'w') as f:
        # 写入库声明
        f.write('library IEEE;\n')
        f.write('use IEEE.STD_LOGIC_1164.ALL;\n')
        f.write('use IEEE.NUMERIC_STD.ALL;\n\n')
        
        # 写入实体声明
        f.write('entity image_rom is\n')
        f.write('    Port (\n')
        f.write('        clk : in STD_LOGIC;\n')
        f.write('        addr : in unsigned(19 downto 0);\n')
        f.write('        image_select : in std_logic_vector(2 downto 0);\n')
        f.write('        data : out std_logic_vector(11 downto 0)\n')
        f.write('    );\n')
        f.write('end image_rom;\n\n')
        
        # 写入架构声明
        f.write('architecture Behavioral of image_rom is\n')
        f.write('    type rom_type is array (0 to 614399) of std_logic_vector(11 downto 0);\n')
        f.write('    type rom_array_type is array (0 to 7) of rom_type;\n')
        f.write('    constant rom_array : rom_array_type := (\n')
        
        # 处理每张图片
        for img_idx in range(8):  # 处理所有8个可能的图片位置
            if img_idx in image_paths:
                # 打开图片
                img = Image.open(image_paths[img_idx])
                
                # 调整图片大小为1024x600（与VGA分辨率匹配）
                img = img.resize((1024, 600))
                
                # 转换为RGB模式
                img = img.convert('RGB')
                
                # 获取像素数据
                pixels = np.array(img)
                
                # 写入图片数据
                f.write('        -- 图片 {} ({})\n'.format(img_idx, os.path.basename(image_paths[img_idx])))
                f.write('        (\n')
                
                # 写入像素数据
                for y in range(600):
                    for x in range(1024):
                        r, g, b = pixels[y, x]
                        # 转换为RGB444格式
                        r = r >> 4
                        g = g >> 4
                        b = b >> 4
                        color = (r << 8) | (g << 4) | b
                        f.write(f'            x"{color:03x}",\n')
                
                f.write('            others => x"000"\n')
                f.write('        )')
            else:
                # 如果没有对应的图片，使用空白图片
                f.write('        -- 空白图片 {}\n'.format(img_idx))
                f.write('        (others => x"000")')
            
            # 添加逗号（除了最后一张图片）
            if img_idx < 7:
                f.write(',\n')
            else:
                f.write('\n')
        
        f.write('    );\n')
        f.write('begin\n')
        f.write('    process(clk)\n')
        f.write('    begin\n')
        f.write('        if rising_edge(clk) then\n')
        f.write('            data <= rom_array(to_integer(unsigned(image_select)))(to_integer(addr));\n')
        f.write('        end if;\n')
        f.write('    end process;\n')
        f.write('end Behavioral;\n')

if __name__ == '__main__':
    # 使用示例
    # 图片编号对应frame_generator中的选择逻辑：
    # 000: 菜单背景
    # 001: 游戏背景
    # 010: 游戏结束背景
    # 其他编号可以用于其他界面
    image_paths = {
        # 0: 'menu.jpg',      # 菜单背景
        # 1: 'game.jpg',      # 游戏背景
        2: 'gameover.jpg',  # 游戏结束背景
        # 可以添加更多图片，编号3-7
    }
    
    # 输出文件路径
    output_file = 'project_1.srcs/sources_1/new/image_rom.vhd'
    
    # 确保输出目录存在
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    # 转换图片
    convert_images_to_vhdl(image_paths, output_file)