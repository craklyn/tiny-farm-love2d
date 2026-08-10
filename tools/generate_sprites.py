#!/usr/bin/env python3
"""
Generate placeholder pixel art sprites for Tiny Farm.
Creates simple but recognizable 16x16 sprites using Pillow.
All sprites are color-coded for clarity during development.
"""

from PIL import Image, ImageDraw
import os

TILE_SIZE = 16
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites")

# --- Color Palette ---
C = {
    "transparent":  (0, 0, 0, 0),
    "black":        (20, 20, 30, 255),
    "white":        (240, 240, 235, 255),
    # Player
    "skin":         (234, 190, 150, 255),
    "hair":         (100, 60, 30, 255),
    "shirt_blue":   (70, 130, 200, 255),
    "pants_brown":  (120, 80, 50, 255),
    "boots":        (60, 40, 25, 255),
    # Terrain
    "grass_light":  (100, 180, 70, 255),
    "grass_dark":   (75, 150, 55, 255),
    "dirt_light":   (150, 115, 75, 255),
    "dirt_dark":    (140, 100, 60, 255),
    "tilled":       (140, 105, 65, 255),
    "tilled_line":  (110, 75, 45, 255),
    # Obstacles
    "rock_light":   (160, 160, 170, 255),
    "rock_dark":    (110, 110, 120, 255),
    "rock_shadow":  (80, 80, 90, 255),
    "log_light":    (160, 110, 60, 255),
    "log_dark":     (120, 80, 40, 255),
    "log_ring":     (100, 65, 30, 255),
    "weed_green":   (60, 160, 50, 255),
    "weed_dark":    (40, 120, 35, 255),
    "seed_brown":   (220, 180, 100, 255),
    "sprout_green": (80, 180, 60, 255),
    "stem_green":   (60, 140, 45, 255),
    "carrot_orange":(240, 150, 30, 255),
    "carrot_top":   (50, 160, 40, 255),
    "tomato_red":   (220, 50, 40, 255),
    "tomato_green": (60, 150, 50, 255),
    "sunflower_yellow": (255, 220, 50, 255),
    "sunflower_center": (140, 90, 30, 255),
    "sunflower_stem":   (70, 140, 50, 255),
    # Objects
    "wood_light":   (180, 130, 70, 255),
    "wood_dark":    (130, 90, 45, 255),
    "wood_plank":   (160, 115, 60, 255),
    "metal_gray":   (140, 145, 155, 255),
    "metal_dark":   (100, 105, 115, 255),
    "water_blue":   (80, 150, 220, 255),
    "water_light":  (130, 190, 240, 255),
    "stone_well":   (150, 150, 160, 255),
    "cloth_beige":  (210, 195, 165, 255),
    "cloth_shadow": (180, 165, 135, 255),
    "red_sign":     (200, 60, 50, 255),
    # Fence
    "fence_light":  (170, 130, 70, 255),
    "fence_dark":   (130, 95, 50, 255),
    # Tools (HUD icons)
    "axe_blade":    (180, 185, 195, 255),
    "handle_brown": (150, 100, 50, 255),
    # Particle
    "particle_white": (255, 255, 255, 255),
    # UI
    "gold_yellow":  (255, 210, 50, 255),
}


def create_sheet(cols, rows):
    """Create a blank spritesheet with transparency."""
    img = Image.new("RGBA", (cols * TILE_SIZE, rows * TILE_SIZE), C["transparent"])
    return img


def get_draw(img, col, row):
    """Get an ImageDraw with offset for a specific cell."""
    return ImageDraw.Draw(img), col * TILE_SIZE, row * TILE_SIZE


def px(draw, ox, oy, x, y, color):
    """Draw a single pixel at offset position."""
    draw.point((ox + x, oy + y), fill=color)


def rect(draw, ox, oy, x1, y1, x2, y2, color):
    """Draw a filled rectangle at offset position."""
    draw.rectangle((ox + x1, oy + y1, ox + x2, oy + y2), fill=color)


def generate_tiles():
    """Generate tiles.png: 8 columns x 1 row spritesheet.
    Col 0: grass (border/fence)
    Col 1: obstacle_rock
    Col 2: obstacle_log
    Col 3: obstacle_weed
    Col 4: cleared (dirt)
    Col 5: tilled (furrows)
    Col 6: watered tilled (darker)
    Col 7: grass (walkable)
    """
    img = create_sheet(8, 1)

    # Col 0: Fence/border
    d, ox, oy = get_draw(img, 0, 0)
    rect(d, ox, oy, 0, 0, 15, 15, C["grass_dark"])
    rect(d, ox, oy, 2, 6, 4, 8, C["fence_light"])
    rect(d, ox, oy, 11, 6, 13, 8, C["fence_light"])
    rect(d, ox, oy, 0, 7, 15, 7, C["fence_dark"])
    rect(d, ox, oy, 0, 6, 15, 6, C["fence_light"])

    # Col 1: Rock
    d, ox, oy = get_draw(img, 1, 0)
    rect(d, ox, oy, 0, 0, 15, 15, C["grass_light"])
    rect(d, ox, oy, 3, 5, 12, 13, C["rock_dark"])
    rect(d, ox, oy, 4, 4, 11, 12, C["rock_light"])
    rect(d, ox, oy, 5, 4, 8, 5, C["white"])  # highlight
    rect(d, ox, oy, 9, 10, 11, 12, C["rock_shadow"])  # shadow

    # Col 2: Log
    d, ox, oy = get_draw(img, 2, 0)
    rect(d, ox, oy, 0, 0, 15, 15, C["grass_light"])
    rect(d, ox, oy, 2, 6, 13, 12, C["log_dark"])
    rect(d, ox, oy, 3, 5, 12, 11, C["log_light"])
    # Rings
    rect(d, ox, oy, 5, 6, 5, 10, C["log_ring"])
    rect(d, ox, oy, 9, 6, 9, 10, C["log_ring"])

    # Col 3: Weed
    d, ox, oy = get_draw(img, 3, 0)
    rect(d, ox, oy, 0, 0, 15, 15, C["grass_light"])
    for wx, wy in [(4, 5), (7, 3), (10, 6), (6, 9), (9, 11)]:
        rect(d, ox, oy, wx, wy, wx + 2, wy + 4, C["weed_green"])
        px(d, ox, oy, wx + 1, wy - 1, C["weed_dark"])

    # Col 4: Cleared dirt
    d, ox, oy = get_draw(img, 4, 0)
    rect(d, ox, oy, 0, 0, 15, 15, C["dirt_light"])
    # Some texture dots
    for dx, dy in [(3, 3), (9, 5), (5, 11), (12, 9), (7, 7)]:
        px(d, ox, oy, dx, dy, C["dirt_dark"])

    # Col 5: Tilled
    d, ox, oy = get_draw(img, 5, 0)
    rect(d, ox, oy, 0, 0, 15, 15, C["tilled"])
    for row_y in [3, 7, 11]:
        rect(d, ox, oy, 1, row_y, 14, row_y, C["tilled_line"])

    # Col 6: Watered tilled (darker)
    d, ox, oy = get_draw(img, 6, 0)
    rect(d, ox, oy, 0, 0, 15, 15, (80, 55, 30, 255))
    for row_y in [3, 7, 11]:
        rect(d, ox, oy, 1, row_y, 14, row_y, (60, 40, 20, 255))
    # Water sheen
    px(d, ox, oy, 4, 5, C["water_light"])
    px(d, ox, oy, 10, 9, C["water_light"])

    # Col 7: Plain grass (walkable)
    d, ox, oy = get_draw(img, 7, 0)
    rect(d, ox, oy, 0, 0, 15, 15, C["grass_light"])
    for dx, dy in [(3, 4), (10, 7), (6, 12), (13, 3)]:
        px(d, ox, oy, dx, dy, C["grass_dark"])

    img.save(os.path.join(OUTPUT_DIR, "tiles.png"))
    print("  ✓ tiles.png (8×1 = 8 tiles)")


def generate_crops():
    """Generate crops.png: 4 columns (stages) x 3 rows (crop types).
    Row 0: Carrot (seed, sprout, leafy top, harvestable)
    Row 1: Tomato (seed, sprout, bush, harvestable)
    Row 2: Sunflower (seed, sprout, stem, harvestable)
    """
    img = create_sheet(4, 3)

    # --- Carrot ---
    # Stage 0: Seed
    d, ox, oy = get_draw(img, 0, 0)
    rect(d, ox, oy, 6, 8, 9, 10, C["seed_brown"])

    # Stage 1: Sprout
    d, ox, oy = get_draw(img, 1, 0)
    rect(d, ox, oy, 7, 6, 8, 10, C["sprout_green"])
    rect(d, ox, oy, 6, 5, 9, 6, C["sprout_green"])

    # Stage 2: Leafy
    d, ox, oy = get_draw(img, 2, 0)
    rect(d, ox, oy, 7, 7, 8, 11, C["stem_green"])
    rect(d, ox, oy, 4, 3, 11, 6, C["carrot_top"])
    rect(d, ox, oy, 5, 2, 10, 3, C["carrot_top"])

    # Stage 3: Harvestable
    d, ox, oy = get_draw(img, 3, 0)
    rect(d, ox, oy, 4, 2, 11, 5, C["carrot_top"])
    rect(d, ox, oy, 5, 1, 10, 2, C["carrot_top"])
    rect(d, ox, oy, 6, 7, 9, 13, C["carrot_orange"])
    rect(d, ox, oy, 7, 6, 8, 7, C["carrot_orange"])

    # --- Tomato ---
    # Stage 0: Seed
    d, ox, oy = get_draw(img, 0, 1)
    rect(d, ox, oy, 6, 8, 9, 10, C["seed_brown"])

    # Stage 1: Sprout
    d, ox, oy = get_draw(img, 1, 1)
    rect(d, ox, oy, 7, 6, 8, 11, C["sprout_green"])
    rect(d, ox, oy, 5, 5, 10, 6, C["sprout_green"])

    # Stage 2: Bush
    d, ox, oy = get_draw(img, 2, 1)
    rect(d, ox, oy, 7, 5, 8, 12, C["stem_green"])
    rect(d, ox, oy, 3, 3, 12, 8, C["tomato_green"])
    rect(d, ox, oy, 4, 2, 11, 3, C["tomato_green"])

    # Stage 3: Harvestable
    d, ox, oy = get_draw(img, 3, 1)
    rect(d, ox, oy, 7, 4, 8, 12, C["stem_green"])
    rect(d, ox, oy, 3, 2, 12, 7, C["tomato_green"])
    rect(d, ox, oy, 4, 8, 7, 11, C["tomato_red"])
    rect(d, ox, oy, 9, 7, 12, 10, C["tomato_red"])

    # --- Sunflower ---
    # Stage 0: Seed
    d, ox, oy = get_draw(img, 0, 2)
    rect(d, ox, oy, 6, 8, 9, 10, C["seed_brown"])

    # Stage 1: Sprout
    d, ox, oy = get_draw(img, 1, 2)
    rect(d, ox, oy, 7, 5, 8, 12, C["sprout_green"])
    rect(d, ox, oy, 5, 4, 10, 5, C["sprout_green"])

    # Stage 2: Stem with leaves
    d, ox, oy = get_draw(img, 2, 2)
    rect(d, ox, oy, 7, 3, 8, 14, C["sunflower_stem"])
    rect(d, ox, oy, 4, 7, 7, 9, C["stem_green"])  # leaf
    rect(d, ox, oy, 9, 9, 12, 11, C["stem_green"])  # leaf

    # Stage 3: Harvestable (full bloom)
    d, ox, oy = get_draw(img, 3, 2)
    rect(d, ox, oy, 7, 5, 8, 14, C["sunflower_stem"])
    rect(d, ox, oy, 4, 7, 7, 9, C["stem_green"])
    rect(d, ox, oy, 9, 9, 12, 11, C["stem_green"])
    rect(d, ox, oy, 4, 0, 11, 5, C["sunflower_yellow"])
    rect(d, ox, oy, 5, 0, 10, 6, C["sunflower_yellow"])
    rect(d, ox, oy, 6, 2, 9, 4, C["sunflower_center"])

    img.save(os.path.join(OUTPUT_DIR, "crops.png"))
    print("  ✓ crops.png (4×3 = 12 sprites)")


def generate_player():
    """Generate player.png: 4 columns (frames) x 4 rows (directions).
    Row 0: Down (facing camera)
    Row 1: Up (facing away)
    Row 2: Left
    Row 3: Right
    Each row: idle, walk1, walk2, action/swing
    """
    img = create_sheet(4, 4)

    def draw_player(col, row, leg_offset=0, arm_swing=False, flip=False):
        d, ox, oy = get_draw(img, col, row)
        # Body base
        rect(d, ox, oy, 5, 0, 10, 3, C["hair"])       # hair
        rect(d, ox, oy, 5, 3, 10, 5, C["skin"])        # face
        rect(d, ox, oy, 4, 6, 11, 10, C["shirt_blue"]) # torso
        # Legs with walk animation
        left_leg_y = 11 + leg_offset
        right_leg_y = 11 - leg_offset
        rect(d, ox, oy, 5, 11, 7, min(left_leg_y + 2, 14), C["pants_brown"])
        rect(d, ox, oy, 8, 11, 10, min(right_leg_y + 2, 14), C["pants_brown"])
        rect(d, ox, oy, 5, min(left_leg_y + 2, 14), 7, 15, C["boots"])
        rect(d, ox, oy, 8, min(right_leg_y + 2, 14), 10, 15, C["boots"])
        # Arms
        if arm_swing:
            rect(d, ox, oy, 2, 5, 4, 8, C["skin"])  # arm out
            rect(d, ox, oy, 1, 3, 3, 5, C["metal_gray"])  # tool
        else:
            rect(d, ox, oy, 3, 6, 4, 10, C["skin"])  # left arm
            rect(d, ox, oy, 11, 6, 12, 10, C["skin"])  # right arm
        # Eyes for down-facing
        if row == 0:
            px(d, ox, oy, 6, 4, C["black"])
            px(d, ox, oy, 9, 4, C["black"])

    # Down: idle, walk1, walk2, action
    draw_player(0, 0, leg_offset=0)
    draw_player(1, 0, leg_offset=1)
    draw_player(2, 0, leg_offset=-1)
    draw_player(3, 0, arm_swing=True)

    # Up: idle, walk1, walk2, action
    draw_player(0, 1, leg_offset=0)
    draw_player(1, 1, leg_offset=1)
    draw_player(2, 1, leg_offset=-1)
    draw_player(3, 1, arm_swing=True)

    # Left: idle, walk1, walk2, action
    draw_player(0, 2, leg_offset=0)
    draw_player(1, 2, leg_offset=1)
    draw_player(2, 2, leg_offset=-1)
    draw_player(3, 2, arm_swing=True)

    # Right: same as left (we'll flip in-engine or mirror here)
    draw_player(0, 3, leg_offset=0)
    draw_player(1, 3, leg_offset=1)
    draw_player(2, 3, leg_offset=-1)
    draw_player(3, 3, arm_swing=True)

    img.save(os.path.join(OUTPUT_DIR, "player.png"))
    print("  ✓ player.png (4×4 = 16 frames)")


def generate_objects():
    """Generate objects.png: 4 columns x 1 row.
    Col 0: Cot (bed)
    Col 1: Shipping bin
    Col 2: Water well
    Col 3: Seed box
    """
    img = create_sheet(4, 1)

    # Col 0: Cot
    d, ox, oy = get_draw(img, 0, 0)
    rect(d, ox, oy, 0, 0, 15, 15, C["grass_light"])
    rect(d, ox, oy, 1, 5, 14, 13, C["wood_dark"])  # frame
    rect(d, ox, oy, 2, 6, 13, 12, C["cloth_beige"])  # mattress
    rect(d, ox, oy, 2, 6, 5, 9, C["cloth_shadow"])  # pillow

    # Col 1: Shipping bin
    d, ox, oy = get_draw(img, 1, 0)
    rect(d, ox, oy, 0, 0, 15, 15, C["grass_light"])
    rect(d, ox, oy, 2, 4, 13, 13, C["wood_dark"])  # bin body
    rect(d, ox, oy, 3, 5, 12, 12, C["wood_light"])  # front
    rect(d, ox, oy, 2, 3, 13, 4, C["wood_plank"])  # lid
    rect(d, ox, oy, 6, 8, 9, 9, C["metal_gray"])  # handle

    # Col 2: Well
    d, ox, oy = get_draw(img, 2, 0)
    rect(d, ox, oy, 0, 0, 15, 15, C["grass_light"])
    rect(d, ox, oy, 3, 6, 12, 14, C["stone_well"])  # base
    rect(d, ox, oy, 4, 7, 11, 13, C["water_blue"])  # water inside
    rect(d, ox, oy, 4, 7, 11, 8, C["water_light"])  # water shine
    rect(d, ox, oy, 6, 1, 7, 6, C["wood_dark"])  # post left
    rect(d, ox, oy, 9, 1, 10, 6, C["wood_dark"])  # post right
    rect(d, ox, oy, 5, 1, 10, 2, C["wood_plank"])  # roof

    # Col 3: Seed box/sign
    d, ox, oy = get_draw(img, 3, 0)
    rect(d, ox, oy, 0, 0, 15, 15, C["grass_light"])
    rect(d, ox, oy, 4, 7, 11, 13, C["wood_light"])  # box
    rect(d, ox, oy, 5, 8, 10, 12, C["wood_dark"])  # inner
    rect(d, ox, oy, 5, 2, 10, 7, C["wood_plank"])  # sign
    rect(d, ox, oy, 6, 3, 9, 6, C["red_sign"])  # text area
    rect(d, ox, oy, 7, 12, 8, 14, C["wood_dark"])  # post

    img.save(os.path.join(OUTPUT_DIR, "objects.png"))
    print("  ✓ objects.png (4×1 = 4 objects)")


def generate_particle():
    """Generate particle.png: 4x4 white dot with soft edges."""
    img = Image.new("RGBA", (4, 4), C["transparent"])
    d = ImageDraw.Draw(img)
    d.rectangle((1, 0, 2, 3), fill=(255, 255, 255, 200))
    d.rectangle((0, 1, 3, 2), fill=(255, 255, 255, 200))
    d.rectangle((1, 1, 2, 2), fill=(255, 255, 255, 255))
    img.save(os.path.join(OUTPUT_DIR, "particle.png"))
    print("  ✓ particle.png (4×4 dot)")


def generate_tool_icons():
    """Generate tool_icons.png: 6 columns x 1 row (16x16 each).
    Col 0: Hands
    Col 1: Axe
    Col 2: Pickaxe
    Col 3: Hoe
    Col 4: Watering Can
    Col 5: Seeds
    """
    img = create_sheet(6, 1)

    # Col 0: Hands (open palm)
    d, ox, oy = get_draw(img, 0, 0)
    rect(d, ox, oy, 5, 4, 11, 12, C["skin"])
    rect(d, ox, oy, 3, 4, 5, 7, C["skin"])  # thumb
    for fx in range(5, 11, 2):
        rect(d, ox, oy, fx, 2, fx + 1, 4, C["skin"])  # fingers

    # Col 1: Axe
    d, ox, oy = get_draw(img, 1, 0)
    rect(d, ox, oy, 7, 3, 8, 14, C["handle_brown"])  # handle
    rect(d, ox, oy, 3, 1, 7, 5, C["axe_blade"])  # blade
    rect(d, ox, oy, 3, 2, 5, 4, C["metal_dark"])  # edge

    # Col 2: Pickaxe
    d, ox, oy = get_draw(img, 2, 0)
    rect(d, ox, oy, 7, 5, 8, 14, C["handle_brown"])  # handle
    rect(d, ox, oy, 3, 2, 12, 4, C["metal_gray"])  # head
    rect(d, ox, oy, 2, 2, 4, 3, C["metal_dark"])  # point left
    rect(d, ox, oy, 11, 2, 13, 3, C["metal_dark"])  # point right

    # Col 3: Hoe
    d, ox, oy = get_draw(img, 3, 0)
    rect(d, ox, oy, 7, 3, 8, 14, C["handle_brown"])  # handle
    rect(d, ox, oy, 4, 1, 11, 3, C["metal_gray"])  # blade
    rect(d, ox, oy, 4, 3, 11, 4, C["metal_dark"])  # edge

    # Col 4: Watering can
    d, ox, oy = get_draw(img, 4, 0)
    rect(d, ox, oy, 4, 5, 12, 13, C["metal_gray"])  # body
    rect(d, ox, oy, 5, 6, 11, 12, C["water_blue"])  # water inside
    rect(d, ox, oy, 1, 3, 4, 5, C["metal_dark"])  # spout
    rect(d, ox, oy, 10, 2, 13, 5, C["metal_dark"])  # handle

    # Col 5: Seeds (bag)
    d, ox, oy = get_draw(img, 5, 0)
    rect(d, ox, oy, 4, 4, 11, 13, C["cloth_beige"])  # bag
    rect(d, ox, oy, 5, 5, 10, 12, C["cloth_shadow"])  # shading
    rect(d, ox, oy, 5, 2, 10, 4, C["cloth_beige"])  # top fold
    rect(d, ox, oy, 6, 7, 7, 8, C["seed_brown"])  # seed peek
    rect(d, ox, oy, 8, 6, 9, 7, C["seed_brown"])

    img.save(os.path.join(OUTPUT_DIR, "tool_icons.png"))
    print("  ✓ tool_icons.png (6×1 = 6 icons)")


if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("Generating Tiny Farm sprites...")
    generate_tiles()
    generate_crops()
    generate_player()
    generate_objects()
    generate_particle()
    generate_tool_icons()
    print(f"\nAll sprites saved to: {OUTPUT_DIR}")
