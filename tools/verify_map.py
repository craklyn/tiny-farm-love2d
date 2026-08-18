import sys
import os
from google import genai
from dotenv import load_dotenv

load_dotenv(os.path.expanduser('~/.env'))

def verify():
    client = genai.Client()
    img_path = "/home/daniel/.local/share/love/tiny-farm/map_verify.png"
    print(f"Uploading {img_path}...")
    f = client.files.upload(file=img_path)
    
    prompt = """Please look closely at the objects near the top of the map (the bed, the chest, the well, the potted plant).
Are any of them still slicing the wrong sprite coordinates? Do any look like half of an object or cut off? Do they look like floating stickers, or are they properly grounded?
Specifically, look at the chest, the bed, the well (if present), and the seed box.
Describe exactly what they look like and if they are correctly drawn."""

    print("Requesting description from gemini-3.6-flash...")
    response = client.models.generate_content(
        model='gemini-3.6-flash',
        contents=[f, prompt]
    )
    
    out_path = '/home/daniel/.gemini/antigravity-ide/brain/497891ba-22f7-4135-b471-a6ec6a6566da/scratch/map_verification.md'
    with open(out_path, 'w') as f_out:
        f_out.write(response.text)
    print("Done")

if __name__ == '__main__':
    verify()
