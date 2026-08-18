import sys
import os
from google import genai
from dotenv import load_dotenv

load_dotenv(os.path.expanduser('~/.env'))

def analyze_ux(image_path):
    client = genai.Client()
    print(f"Uploading {image_path}...")
    image = client.files.upload(file=image_path)
    
    prompt = """You are an L6 Sr UX Designer. Analyze this screenshot of an indie farming game's HUD.
Critique it ruthlessly on:
1. 9-slice rendering artifacts (stretching, improper corner clipping, distortion).
2. Data display errors (misalignment, text cutoff, padding inconsistencies, poor contrast).
3. Overall aesthetic cohesion, layout, typography, and accessibility (Fat Finger design).
4. Do not hold back. Point out every single pixel-level flaw.
5. Provide a strict set of 'First-Principles' fixes to resolve these issues, including exact padding values, spacing, color hex codes, and alignment rules.

Format your output as a structured Markdown teardown report."""

    print("Requesting critique from gemini-3.6-flash...")
    response = client.models.generate_content(
        model='gemini-3.6-flash',
        contents=[image, prompt]
    )
    
    out_path = '/home/daniel/.gemini/antigravity-ide/brain/497891ba-22f7-4135-b471-a6ec6a6566da/ux_critique_after.md'
    with open(out_path, 'w') as f:
        f.write(response.text)
    print(f"Critique written to {out_path}")

if __name__ == '__main__':
    analyze_ux(sys.argv[1])
