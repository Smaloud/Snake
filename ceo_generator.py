from PIL import Image

def convert_jpg_to_coe(input_image_path, output_coe_path, width=1024, height=600):
    # 1. 打开图像并缩放到指定大小
    img = Image.open(input_image_path)
    img = img.resize((width, height))
    img = img.convert('RGB')

    # 2. 写入 .coe 文件头
    with open(output_coe_path, 'w') as f:
        f.write("memory_initialization_radix=2;\n")
        f.write("memory_initialization_vector=\n")

        count = 0
        for y in range(height):
            for x in range(width):
                r, g, b = img.getpixel((x, y))

                # 提取高4位（RGB444）
                r4 = r >> 4
                g4 = g >> 4
                b4 = b >> 4

                rgb444 = (r4 << 8) | (g4 << 4) | b4
                bin_str = format(rgb444, '012b')  # 12位二进制字符串
                f.write(bin_str)

                count += 1
                if count != width * height:
                    f.write(",\n")
                else:
                    f.write(";\n")

    print(f"✅ 已生成 .coe 文件：{output_coe_path}")

# 示例调用
convert_jpg_to_coe("GameOver.jpg", "GameOver_rom.coe")
