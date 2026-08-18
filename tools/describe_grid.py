import sys
import os
from google import genai
from dotenv import load_dotenv

load_dotenv(os.path.expanduser('~/.env'))

def describe():
    client = genai.Client()
    img_path = "/home/daniel/.gemini/antigravity-ide/brain/497891ba-22f7-4135-b471-a6ec6a6566da/scratch/furniture_grid.png"
    print(f"Uploading {img_path}...")
    f = client.files.upload(file=img_path)
    
    prompt = """This is a spritesheet with a red grid overlay.
Please carefully identify all the objects in this spritesheet.
Particularly, look for:
1. A bed/cot
2. A water well
3. A seed box or market stall
Give me the EXACT top-left (Column, Row) coordinates for each of those 3 objects.
Assume the top-left cell is (Column 0, Row 0).
Also describe what is currently located at:
- (0, 0)
- (4, 0)
- (5, 2)
"""

    print("Requesting description from gemini-3.6-flash...")
    response = client.models.generate_content(
        model='gemini-3.6-flash',
        contents=[f, prompt]
    )
    
    out_path = '/home/daniel/.gemini/antigravity-ide/brain/497891ba-22f7-4135-b471-a6ec6a6566da/scratch/furniture_description.md'
    with open(out_path, 'w') as f_out:
        f_out.write(response.text)
    print("Done")

if __name__ == '__main__':
    describe()
