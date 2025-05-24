from PIL import Image
import matplotlib.pyplot as plt

def convert_jpg_to_coe_binary(input_image_path, output_coe_path, width=1024, height=600):
    # 1. 打开图像并缩放到指定大小
    img = Image.open(input_image_path)
    img = img.resize((width, height))
    img = img.convert('RGB')
    
    # 创建一个新的黑白图像用于预览
    bw_img = Image.new('1', (width, height))
    
    # 2. 写入 .coe 文件头
    with open(output_coe_path, 'w') as f:
        f.write("memory_initialization_radix=2;\n")
        f.write("memory_initialization_vector=\n")

        count = 0
        for y in range(height):
            for x in range(width):
                r, g, b = img.getpixel((x, y))

                # 计算灰度值并转换为二进制（0或1）
                # 使用标准亮度公式: 0.299*R + 0.587*G + 0.114*B
                gray = int(0.299*r + 0.587*g + 0.114*b)
                binary = 1 if gray > 63 else 0
                
                # 设置黑白图像的像素
                bw_img.putpixel((x, y), binary)
                
                # 写入COE文件
                f.write(str(binary))

                count += 1
                if count != width * height:
                    f.write(",\n")
                else:
                    f.write(";\n")
    
    # 保存黑白预览图像
    output_png_path = output_coe_path.replace('.coe', '_preview.png')
    bw_img.save(output_png_path)
    
    # 显示原图和处理后的图像对比
    plt.figure(figsize=(12, 6))
    
    plt.subplot(1, 2, 1)
    plt.title("原图")
    plt.imshow(img)
    plt.axis('off')
    
    plt.subplot(1, 2, 2)
    plt.title("处理后的二值图像")
    plt.imshow(bw_img, cmap='binary')
    plt.axis('off')
    
    plt.tight_layout()
    plt.show()

    print(f"✅ 已生成二值 .coe 文件：{output_coe_path}")
    print(f"✅ 已保存预览图像：{output_png_path}")

# 示例调用
# convert_jpg_to_coe_binary("GameOver.jpg", "GameOver_rom_binary.coe")
convert_jpg_to_coe_binary("Start.png", "Start_rom_binary.coe")
