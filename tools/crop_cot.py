from PIL import Image
img = Image.open('assets/sprites/sprout_lands/furniture.png')
# crop 16x32 at 0, 32
bed = img.crop((0, 32, 16, 64))
bed.save('/home/daniel/.gemini/antigravity-ide/brain/497891ba-22f7-4135-b471-a6ec6a6566da/scratch/bed_crop.png')
