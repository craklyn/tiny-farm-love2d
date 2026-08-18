from PIL import Image
import glob
import os

def crop_genai():
    # Find the generated image
    files = glob.glob("/home/daniel/.gemini/antigravity-ide/brain/*/ui_genai_raw_*.jpg")
    if not files:
        print("No genai image found!")
        return
    # Use latest
    img_path = sorted(files)[-1]
    print(f"Processing {img_path}")
    
    img = Image.open(img_path).convert("RGBA")
    
    # Target 48x48 9-slice target image
    target = Image.new("RGBA", (48, 48))
    
    # New image corners: wood border starts around x=40, y=40. width/height is ~944 (1024 - 80)
    # 16x16 corners
    tl = img.crop((40, 40, 56, 56))
    tr = img.crop((968, 40, 984, 56))
    bl = img.crop((40, 968, 56, 984))
    br = img.crop((968, 968, 984, 984))
    
    # Edges
    top = img.crop((512, 40, 528, 56))
    bottom = img.crop((512, 968, 528, 984))
    left = img.crop((40, 512, 56, 528))
    right = img.crop((968, 512, 984, 528))
    
    # Center (parchment)
    center = img.crop((512, 512, 528, 528))
    
    # Paste into target
    target.paste(tl, (0, 0))
    target.paste(top, (16, 0))
    target.paste(tr, (32, 0))
    
    target.paste(left, (0, 16))
    target.paste(center, (16, 16))
    target.paste(right, (32, 16))
    
    target.paste(bl, (0, 32))
    target.paste(bottom, (16, 32))
    target.paste(br, (32, 32))
    
    # Transparent corners replacement
    data = target.getdata()
    new_data = []
    for item in data:
        # The background of this image is dark gray stone (~30-50 rgb)
        # If dark gray, make transparent
        if item[0] < 60 and item[1] < 60 and item[2] < 60:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
    target.putdata(new_data)
    
    os.makedirs('../assets/sprites', exist_ok=True)
    target.save('../assets/sprites/ui_genai.png')
    print("Generated ui_genai.png")

if __name__ == '__main__':
    crop_genai()
