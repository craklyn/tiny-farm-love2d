from PIL import Image, ImageDraw
import os
import random

def create_forest_panel():
    size = 48
    # Create image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Colors from UX critique
    bg_primary = (35, 46, 33, 230) 
    bg_dark = (25, 35, 23, 230)
    bg_light = (45, 56, 43, 230)
    border_outer = (18, 26, 17, 255)
    border_inner = (79, 105, 75, 255)

    # 1. Main background fill
    draw.rectangle([2, 2, size-3, size-3], fill=bg_primary)
    
    # Procedural Wood Grain Noise
    pixels = img.load()
    for y in range(2, size-2):
        for x in range(2, size-2):
            # Horizontal streaky grain
            noise = random.randint(-15, 15)
            # Add some horizontal persistence
            if x > 2 and random.random() > 0.3:
                noise = pixels[x-1, y][0] - bg_primary[0]
            
            r = max(0, min(255, bg_primary[0] + noise))
            g = max(0, min(255, bg_primary[1] + noise))
            b = max(0, min(255, bg_primary[2] + noise))
            pixels[x, y] = (r, g, b, 240)
            
    # 2. Outer border (2px)
    draw.rectangle([0, 0, size-1, size-1], outline=border_outer, width=2)
    
    # 3. Inner highlight (1px, inset by 2px)
    draw.rectangle([2, 2, size-3, size-3], outline=border_inner, width=1)

    # 4. Make outside corners transparent for slightly rounded look
    draw.point([0, 0], fill=(0,0,0,0))
    draw.point([0, size-1], fill=(0,0,0,0))
    draw.point([size-1, 0], fill=(0,0,0,0))
    draw.point([size-1, size-1], fill=(0,0,0,0))

    # Fix path assuming it's run from project root
    os.makedirs('assets/sprites', exist_ok=True)
    img.save('assets/sprites/ui_forest.png')
    print("Generated ui_forest.png")

if __name__ == '__main__':
    create_forest_panel()
