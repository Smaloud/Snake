from PIL import Image

def convert_jpg_to_coe_rgb111(input_image_path, output_coe_path, width=1024, height=600):
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

                # 将RGB每通道降为1位（取高位）
                r1 = 1 if r > 127 else 0
                g1 = 1 if g > 127 else 0
                b1 = 1 if b > 127 else 0

                rgb111 = (r1 << 2) | (g1 << 1) | b1
                bin_str = format(rgb111, '03b')  # 3位二进制字符串
                f.write(bin_str)

                count += 1
                if count != width * height:
                    f.write(",\n")
                else:
                    f.write(";\n")

    print(f"✅ 已生成 RGB111 .coe 文件：{output_coe_path}")

# 示例调用
convert_jpg_to_coe_rgb111("GameOver.jpg", "GameOver_rom_rgb111.coe")
