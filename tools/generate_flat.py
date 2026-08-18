from PIL import Image, ImageDraw
import os

def create_flat_panel():
    size = 48
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 1. Main background fill
    draw.rectangle([2, 2, size-3, size-3], fill=(70, 130, 180, 255)) # Steel blue
    
    # 3. Outer border
    draw.rectangle([0, 0, size-1, size-1], outline=(30, 60, 90, 255), width=2)
    
    # 4. Inner highlight
    draw.rectangle([2, 2, size-3, size-3], outline=(100, 150, 200, 255), width=2)

    # Make corners transparent
    draw.point([0, 0], fill=(0,0,0,0))
    draw.point([0, size-1], fill=(0,0,0,0))
    draw.point([size-1, 0], fill=(0,0,0,0))
    draw.point([size-1, size-1], fill=(0,0,0,0))

    img.save('../assets/sprites/ui_flat.png')
    print("Generated ui_flat.png")

if __name__ == '__main__':
    create_flat_panel()
