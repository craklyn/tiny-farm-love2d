from PIL import Image, ImageDraw
img = Image.open('assets/sprites/sprout_lands/furniture.png')
draw = ImageDraw.Draw(img)
for x in range(0, img.width, 16):
    draw.line([(x, 0), (x, img.height)], fill='red')
for y in range(0, img.height, 16):
    draw.line([(0, y), (img.width, y)], fill='red')
img.save('/home/daniel/.gemini/antigravity-ide/brain/497891ba-22f7-4135-b471-a6ec6a6566da/scratch/furniture_grid.png')
