import sys
import os
from google import genai
from dotenv import load_dotenv

load_dotenv(os.path.expanduser('~/.env'))

def analyze_map(image_path):
    client = genai.Client()
    print(f"Uploading {image_path}...")
    image = client.files.upload(file=image_path)
    
    prompt = """You are a Lead Technical Artist and Level Designer. Analyze this screenshot of the top-left corner of a 2D farming game.
Look specifically at the objects placed near the top boundary (the bed/cot, shipping bin, well, seed box).
Critique them on:
1. Y-sorting and depth rendering issues (does anything overlap incorrectly?).
2. Clipping and bounds (do the tall sprites extend off the map boundary or overlap the top border trees/rocks inappropriately?).
3. Visual continuity and placement (do they look like they are placed correctly on the grass, or are there clipping artifacts?).
Provide specific observations of exactly what is visually broken.
"""

    print("Requesting critique from gemini-3.6-flash...")
    response = client.models.generate_content(
        model='gemini-3.6-flash',
        contents=[image, prompt]
    )
    
    out_path = '/home/daniel/.gemini/antigravity-ide/brain/497891ba-22f7-4135-b471-a6ec6a6566da/scratch/map_critique.md'
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'w') as f:
        f.write(response.text)
    print(f"Critique written to {out_path}")

if __name__ == '__main__':
    analyze_map(sys.argv[1])
