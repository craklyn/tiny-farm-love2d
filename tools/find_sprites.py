import sys
import os
from google import genai
from dotenv import load_dotenv

load_dotenv(os.path.expanduser('~/.env'))

def find_sprites():
    client = genai.Client()
    
    img_path1 = "assets/sprites/sprout_lands/furniture.png"
    img_path2 = "assets/sprites/sprout_lands/chest.png"
    print(f"Uploading {img_path1} and {img_path2}...")
    f1 = client.files.upload(file=img_path1)
    f2 = client.files.upload(file=img_path2)
    
    prompt = """You are a Technical Artist. I have two spritesheets.
1. furniture.png: 144x96 pixels (9 tiles wide, 6 tiles tall, each tile is 16x16).
2. chest.png: 240x96 pixels (15 tiles wide, 6 tiles tall).

Please locate the following items by providing their grid coordinates (Column, Row). Columns and rows are 0-indexed!
For example, the top-left tile is (Column 0, Row 0).

In furniture.png, find:
- A bed or cot (usually takes up 1x2 tiles, i.e., 16x32). Give me the Top-Left coordinate of the 1x2 area.
- A water well (usually takes up 1x2 or 2x2 tiles).
- A seed box or market stall or something resembling a box of seeds.

In chest.png, find:
- A wooden shipping bin or chest. Give me the coordinate of the best looking wooden chest.

Output exactly the coordinates (x_col, y_row) and a brief description of what you see there to confirm.
"""

    print("Requesting sprite locations from gemini-3.6-flash...")
    response = client.models.generate_content(
        model='gemini-3.6-flash',
        contents=[f1, f2, prompt]
    )
    
    out_path = '/home/daniel/.gemini/antigravity-ide/brain/497891ba-22f7-4135-b471-a6ec6a6566da/scratch/sprite_locations.md'
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'w') as f:
        f.write(response.text)
    print(f"Critique written to {out_path}")

if __name__ == '__main__':
    find_sprites()
