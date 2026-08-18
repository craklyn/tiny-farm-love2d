from PIL import Image, ImageDraw
import os

def create_wood_panel():
    size = 48
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Colors
    border_dark = (60, 35, 20, 255)
    border_light = (110, 70, 40, 255)
    wood_base = (160, 105, 65, 255)
    wood_dark = (140, 90, 50, 255)
    wood_light = (180, 120, 80, 255)
    
    # 1. Main background fill
    draw.rectangle([2, 2, size-3, size-3], fill=wood_base)
    
    # 2. Wood grain pattern (horizontal lines)
    for y in range(4, size-4, 4):
        draw.line([4, y, size-5, y], fill=wood_dark, width=1)
        draw.line([4, y+1, size-5, y+1], fill=wood_light, width=1)
        
    for y in range(6, size-4, 6):
        draw.line([6, y, size-7, y], fill=wood_dark, width=1)

    # 3. Outer border
    draw.rectangle([0, 0, size-1, size-1], outline=border_dark, width=2)
    
    # 4. Inner highlight/shadow for depth
    draw.rectangle([2, 2, size-3, size-3], outline=border_light, width=2)
    
    # 5. Corner nails/screws
    nail_color = (200, 200, 200, 255)
    draw.rectangle([4, 4, 5, 5], fill=nail_color)
    draw.rectangle([size-6, 4, size-5, 5], fill=nail_color)
    draw.rectangle([4, size-6, 5, size-5], fill=nail_color)
    draw.rectangle([size-6, size-6, size-5, size-5], fill=nail_color)

    # Make corners transparent for rounded look
    draw.point([0, 0], fill=(0,0,0,0))
    draw.point([0, size-1], fill=(0,0,0,0))
    draw.point([size-1, 0], fill=(0,0,0,0))
    draw.point([size-1, size-1], fill=(0,0,0,0))

    # Ensure assets/sprites directory exists
    os.makedirs('../assets/sprites', exist_ok=True)
    img.save('../assets/sprites/ui_wood_panel.png')
    print("Generated ui_wood_panel.png")

if __name__ == '__main__':
    create_wood_panel()
