#!/usr/bin/env python3
"""
Generates high-resolution (2048x2048) painterly Arcane / Piltover / League of Legends
architectural & banner texture atlases:
1. T_Lorencia_Architecture.png:
   - Band 0 (V 0.76..0.99, y 0..512): Deep slate-indigo & copper-ribbed Mansard Roof tiles with painterly gradients
   - Band 1 (V 0.51..0.74, y 512..1024): Warm cream-ivory & golden sandstone Piltover facade plaster with subtle cornice bands
   - Band 2 (V 0.26..0.49, y 1024..1536): Rich warm mahogany/walnut timber, café decking & golden-oak bevel planks
   - Band 3 (V 0.01..0.24, y 1536..2048): Large sunlit peach-cream & rose-sandstone boulevard flagstones (painterly brush washes, soft warm grout)
2. T_Lorencia_Metal_Trim.png:
   - Band 0 (V 0.52..0.98, y 0..1024): Burnished Piltover Gold / Brass filigree & sunlit cornice trim
   - Band 1 (V 0.02..0.48, y 1024..2048): Verdigris Dark Wrought-Iron & Patina Bronze (for Art-Nouveau streetlamps, gates & anvils)
3. T_Arcane_Banner.png (1024x2048):
   - Directly inspired by the Arcane boulevard reference:
     Top ivory rune header -> Crimson & burnt-orange geometric facets -> Radiant golden sun-crowned warrior/heraldic crest -> Pointed cobalt-blue bottom pennant with gold runes.
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

BLENDER_DIR = "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel/blender"
OUT_GLB_DIR = "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel/addons/lorencia_town"
os.makedirs(BLENDER_DIR, exist_ok=True)
os.makedirs(OUT_GLB_DIR, exist_ok=True)


def paint_brush_strokes(draw, x0, y0, x1, y1, palette, count=240, min_w=28, max_w=110, min_h=14, max_h=48, seed=42):
    rng = random.Random(seed)
    w_span = max(1, x1 - x0)
    for _ in range(count):
        col = rng.choice(palette)
        bw = rng.randint(min_w, max_w)
        bh = rng.randint(min_h, max_h)
        cx = rng.randint(x0, x1)
        cy = rng.randint(y0 + bh // 2, max(y0 + bh // 2 + 1, y1 - bh // 2))
        # Wrap horizontally for seamless U tiling
        for dx in (-w_span, 0, w_span):
            bx0 = cx + dx - bw // 2
            by0 = cy - bh // 2
            bx1 = bx0 + bw
            by1 = by0 + bh
            if bx1 >= x0 and bx0 <= x1:
                draw.rounded_rectangle([bx0, by0, bx1, by1], radius=bh // 3, fill=col)


def build_architecture_atlas():
    W, H = 2048, 2048
    img = Image.new("RGB", (W, H), (228, 206, 182))
    draw = ImageDraw.Draw(img)

    # -------------------------------------------------------------------------
    # BAND 0 (y = 0..512, UV V = 0.75..1.00):
    # Arcane Slate-Indigo Mansard Roof with Subtle Copper-Gold Vertical Ribs
    # -------------------------------------------------------------------------
    for y in range(0, 512):
        t = y / 511.0
        # Top of roof is sunlit warm slate-violet; lower edge has deep indigo-teal richness
        r = int(74 + 26 * (1.0 - t))
        g = int(84 + 24 * (1.0 - t))
        b = int(116 + 26 * (1.0 - t))
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    roof_Strokes = [
        (86, 96, 130),
        (78, 88, 122),
        (96, 104, 138),
        (70, 79, 112),
        (106, 112, 144),
    ]
    paint_brush_strokes(draw, 0, 8, W, 504, roof_Strokes, count=420, min_w=45, max_w=140, min_h=18, max_h=52, seed=101)

    # Subtle horizontal slate shingle courses (soft, painterly, never harsh black)
    for course_y in range(36, 496, 46):
        draw.line([(0, course_y), (W, course_y)], fill=(62, 70, 102), width=3)
        draw.line([(0, course_y + 3), (W, course_y + 3)], fill=(108, 116, 148), width=2)

    # Ornate Mansard vertical ribs & gold cresting band at the top/bottom
    for rib_x in range(0, W, 256):
        draw.rectangle([rib_x, 0, rib_x + 14, 511], fill=(96, 106, 138))
        draw.rectangle([rib_x + 3, 0, rib_x + 8, 511], fill=(166, 148, 112))
    draw.rectangle([0, 0, W, 16], fill=(184, 154, 102))
    draw.rectangle([0, 494, W, 511], fill=(64, 72, 100))

    # -------------------------------------------------------------------------
    # BAND 1 (y = 512..1024, UV V = 0.50..0.75):
    # Sunlit Piltover Cream-Limestone & Warm Sandstone Facade Wall
    # (Tuned to rich painterly midtones so sunlight & characters pop without blowing out!)
    # -------------------------------------------------------------------------
    for y in range(512, 1024):
        t = (y - 512) / 511.0
        r = int(206 - 22 * t)
        g = int(182 - 24 * t)
        b = int(152 - 24 * t)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    wall_strokes = [
        (212, 188, 158),
        (198, 174, 144),
        (190, 164, 134),
        (218, 194, 164),
        (182, 156, 128),
        (204, 178, 148),
    ]
    paint_brush_strokes(draw, 0, 520, W, 1016, wall_strokes, count=520, min_w=60, max_w=180, min_h=24, max_h=72, seed=202)

    # Large, subtle carved ashlar limestone blocks
    course_h = 84
    for row_idx, cy in enumerate(range(532, 980, course_h)):
        draw.line([(0, cy), (W, cy)], fill=(166, 142, 114), width=3)
        draw.line([(0, cy + 3), (W, cy + 3)], fill=(220, 198, 168), width=2)
        offset = 128 if (row_idx % 2 == 1) else 0
        for cx in range(offset, W, 256):
            draw.line([(cx, cy), (cx, min(1010, cy + course_h))], fill=(170, 146, 118), width=3)

    # Top classical cornice frieze & bottom warm stone plinth trim
    draw.rectangle([0, 512, W, 534], fill=(178, 150, 116))
    draw.rectangle([0, 534, W, 542], fill=(222, 200, 170))
    draw.rectangle([0, 996, W, 1023], fill=(162, 136, 108))

    # -------------------------------------------------------------------------
    # BAND 2 (y = 1024..1536, UV V = 0.25..0.50):
    # Warm Sunlit Cedar / Walnut Boulevard Timber & Café Decking
    # -------------------------------------------------------------------------
    for y in range(1024, 1536):
        t = (y - 1024) / 511.0
        r = int(164 - 16 * t)
        g = int(116 - 14 * t)
        b = int(78 - 10 * t)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    wood_strokes = [
        (172, 122, 82),
        (156, 108, 72),
        (182, 132, 90),
        (146, 100, 66),
        (166, 116, 78),
    ]
    paint_brush_strokes(draw, 0, 1030, W, 1530, wood_strokes, count=480, min_w=80, max_w=240, min_h=14, max_h=34, seed=303)

    for py in range(1024, 1536, 64):
        draw.line([(0, py), (W, py)], fill=(122, 82, 54), width=4)
        draw.line([(0, py + 4), (W, py + 4)], fill=(192, 142, 98), width=2)

    # -------------------------------------------------------------------------
    # BAND 3 (y = 1536..2048, UV V = 0.00..0.25):
    # Sunlit Arcane Boulevard Travertine & Peach-Rose Sandstone Flagstones
    # (Rich warm midtones directly matching the Arcane reference street!)
    # -------------------------------------------------------------------------
    for y in range(1536, 2048):
        t = (y - 1536) / 511.0
        r = int(192 - 12 * math.sin(t * math.pi))
        g = int(158 - 10 * math.sin(t * math.pi))
        b = int(134 - 8 * math.sin(t * math.pi))
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    pave_tiles = [
        (198, 166, 140),  # Sunlit warm travertine
        (188, 154, 128),  # Warm peach-sandstone
        (180, 144, 122),  # Soft terracotta-rose wash
        (194, 162, 134),  # Golden sandstone
        (172, 140, 122),  # Warm taupe-rose slab
        (204, 172, 144),  # Warm limestone slab
    ]
    rng = random.Random(404)
    row_heights = [128, 128, 128, 128]
    cy = 1536
    for r_i, rh in enumerate(row_heights):
        num_cols = 8
        cw = W // num_cols
        x_off = (cw // 2) if (r_i % 2 == 1) else 0
        for c_i in range(-1, num_cols + 1):
            sx0 = c_i * cw + x_off
            sx1 = sx0 + cw
            sy0 = cy
            sy1 = cy + rh
            col = rng.choice(pave_tiles)
            draw.rectangle([sx0 + 5, sy0 + 5, sx1 - 5, sy1 - 5], fill=col)
            # Soft sunlit top-left bevel & warm taupe-rose slab seam
            draw.line([(sx0 + 5, sy0 + 6), (sx1 - 5, sy0 + 6)], fill=(214, 184, 156), width=3)
            draw.line([(sx0 + 6, sy0 + 5), (sx0 + 6, sy1 - 5)], fill=(210, 180, 152), width=3)
            draw.line([(sx0, sy0), (sx1, sy0)], fill=(144, 116, 98), width=5)
            draw.line([(sx0, sy0), (sx0, sy1)], fill=(144, 116, 98), width=5)
        cy += rh

    paint_brush_strokes(draw, 0, 1542, W, 2042, pave_tiles, count=220, min_w=50, max_w=140, min_h=18, max_h=42, seed=505)

    img = img.filter(ImageFilter.SMOOTH_MORE)
    for out_p in [
        os.path.join(BLENDER_DIR, "T_Lorencia_Architecture.png"),
        os.path.join(OUT_GLB_DIR, "Lorencia_Town_T_Lorencia_Architecture.png"),
    ]:
        img.save(out_p, "PNG")
    print("Saved Painterly Arcane Architecture Atlas.")


def build_metal_and_banner_atlas():
    # We pack Metal & Trim + Arcane Heraldic Banner + Arched Window into T_Lorencia_Metal_Trim.png (2048x2048)
    # so existing and new meshes can sample:
    # - V 0.52..0.98 (y 0..1024), U 0.00..0.48 (x 0..1024): Burnished Piltover Gold & Brass Trim
    # - V 0.02..0.48 (y 1024..2048), U 0.00..0.48 (x 0..1024): Verdigris Dark Wrought-Iron & Patina Bronze
    # - V 0.02..0.98 (y 0..2048), U 0.52..0.75 (x 1044..1536): Iconic Arcane Crimson-Gold-Cobalt Street Banner!
    # - V 0.02..0.98 (y 0..2048), U 0.76..0.99 (x 1556..2048): Ornate Arched Mullioned Piltover Window & Teal Portal Gate!
    W, H = 2048, 2048
    img = Image.new("RGB", (W, H), (54, 62, 58))
    draw = ImageDraw.Draw(img)

    # 1. Burnished Gold / Brass (x = 0..1024, y = 0..1024)
    for y in range(0, 1024):
        t = y / 1023.0
        r = int(236 - 38 * t)
        g = int(192 - 42 * t)
        b = int(106 - 28 * t)
        draw.line([(0, y), (1024, y)], fill=(r, g, b))
    gold_strokes = [(246, 206, 122), (222, 174, 88), (204, 154, 74), (252, 220, 142)]
    paint_brush_strokes(draw, 0, 10, 1024, 1014, gold_strokes, count=220, min_w=40, max_w=130, min_h=16, max_h=44, seed=601)
    for ry in range(64, 1000, 128):
        draw.line([(0, ry), (1024, ry)], fill=(254, 232, 164), width=5)
        draw.line([(0, ry + 6), (1024, ry + 6)], fill=(168, 124, 56), width=4)

    # 2. Verdigris Dark Wrought-Iron & Patina Bronze (x = 0..1024, y = 1024..2048)
    for y in range(1024, 2048):
        t = (y - 1024) / 1023.0
        r = int(58 - 14 * t)
        g = int(72 - 16 * t)
        b = int(66 - 14 * t)
        draw.line([(0, y), (1024, y)], fill=(r, g, b))
    iron_strokes = [(66, 82, 74), (50, 64, 58), (76, 94, 84), (44, 54, 50)]
    paint_brush_strokes(draw, 0, 1034, 1024, 2038, iron_strokes, count=220, min_w=40, max_w=130, min_h=16, max_h=44, seed=602)

    # 3. ICONIC ARCANE STREET BANNER (x = 1040..1540, y = 0..2048)
    # Matches the uploaded Arcane reference:
    # - Top ivory-cream header band with stylized arcane runes (y = 0..230)
    # - Rich crimson, scarlet & burnt-orange faceted background with diagonal gold Art-Deco rays (y = 230..1680)
    # - Radiant golden sun-crowned figure / crest centerpiece (y = 620..1460)
    # - Cobalt-blue bottom pennant band with golden rune script (y = 1680..2048)
    bx0, bx1 = 1040, 1540
    bw = bx1 - bx0
    bcx = (bx0 + bx1) // 2

    # Crimson-orange gradient body
    for y in range(0, 2048):
        t = y / 2047.0
        r = int(218 - 64 * t)
        g = int(78 - 34 * t)
        b = int(52 + 18 * t)
        draw.line([(bx0, y), (bx1, y)], fill=(r, g, b))

    # Geometric Art-Deco background facets (violet-crimson, burnt-orange, deep maroon)
    draw.polygon([(bx0, 240), (bcx + 40, 240), (bx0, 960)], fill=(128, 48, 72))
    draw.polygon([(bx1, 320), (bcx - 50, 740), (bx1, 1240)], fill=(196, 62, 48))
    draw.polygon([(bx0, 960), (bcx + 80, 1180), (bx0, 1680)], fill=(154, 42, 54))
    draw.polygon([(bcx - 60, 240), (bx1, 240), (bx1, 780), (bcx + 20, 620)], fill=(232, 112, 52))

    # Diagonal golden Art-Deco rays
    for ray in [
        [(bx0, 420), (bx1, 880)],
        [(bx0, 780), (bx1, 360)],
        [(bx0 + 40, 240), (bx1 - 30, 1520)],
        [(bcx, 240), (bcx, 1680)],
    ]:
        draw.line(ray, fill=(244, 192, 82), width=8)

    # Radiant Golden Sun-Crown & Stylized Portrait / Crest Motif in center of banner
    # Outer golden sun-rays crown
    crown_pts = [
        (bcx - 190, 980),
        (bcx - 220, 760),
        (bcx - 120, 830),
        (bcx - 140, 610),
        (bcx - 45, 740),
        (bcx + 15, 540),
        (bcx + 65, 730),
        (bcx + 165, 590),
        (bcx + 135, 810),
        (bcx + 225, 735),
        (bcx + 185, 980),
    ]
    draw.polygon(crown_pts, fill=(246, 194, 68), outline=(255, 232, 136))
    # Warm golden-amber stylized face/shield planes inside the sun crown
    draw.polygon([(bcx - 125, 850), (bcx + 95, 820), (bcx + 115, 1260), (bcx - 85, 1340)], fill=(226, 146, 64))
    draw.polygon([(bcx - 125, 850), (bcx - 10, 840), (bcx - 25, 1310), (bcx - 95, 1240)], fill=(244, 178, 78))
    # Golden cheek-guard & helm wings (just like the Arcane banner artwork!)
    draw.polygon([(bcx + 25, 920), (bcx + 185, 830), (bcx + 155, 1220), (bcx + 35, 1270)], fill=(248, 204, 74))
    draw.polygon([(bcx - 185, 940), (bcx - 75, 910), (bcx - 65, 1240), (bcx - 165, 1180)], fill=(238, 184, 62))
    # Stylized brow & eye slit accents
    draw.line([(bcx - 95, 980), (bcx - 25, 965)], fill=(124, 44, 36), width=10)
    draw.line([(bcx + 10, 965), (bcx + 75, 980)], fill=(124, 44, 36), width=10)

    # Top Ivory Header Band with Arcane Vertical Rune Glyphs (y = 30..235)
    draw.rectangle([bx0 + 14, 30, bx1 - 14, 235], fill=(234, 224, 210), outline=(186, 154, 104), width=6)
    for rx in range(bx0 + 48, bx1 - 44, 42):
        draw.line([(rx, 62), (rx, 202)], fill=(96, 82, 76), width=6)
        draw.line([(rx, 62), (rx + 18, 92)], fill=(96, 82, 76), width=5)
        draw.line([(rx - 10, 132), (rx + 14, 132)], fill=(96, 82, 76), width=5)

    # Bottom Cobalt-Blue Pennant Band with Golden Runes (y = 1660..2048)
    draw.rectangle([bx0, 1660, bx1, 2048], fill=(64, 124, 204))
    draw.line([(bx0, 1660), (bx1, 1660)], fill=(246, 202, 86), width=10)
    for rx in range(bx0 + 64, bx1 - 54, 54):
        draw.ellipse([rx - 12, 1730, rx + 12, 1765], outline=(246, 210, 112), width=5)
        draw.line([(rx, 1765), (rx, 1845)], fill=(246, 210, 112), width=5)

    # Outer gold border frame along the banner edges
    draw.rectangle([bx0 + 6, 6, bx1 - 6, 2042], outline=(242, 192, 84), width=8)

    # 4. ORNATE PILTOVER ARCHED WINDOW & BRONZE FILIGREE PANEL (x = 1556..2048, y = 0..2048)
    wx0, wx1 = 1556, 2048
    wcx = (wx0 + wx1) // 2
    # Warm sunlit window glass background (soft golden-teal interior reflection)
    for y in range(0, 2048):
        t = y / 2047.0
        r = int(122 + 88 * (1.0 - t))
        g = int(152 + 64 * (1.0 - t))
        b = int(156 + 42 * (1.0 - t))
        draw.line([(wx0, y), (wx1, y)], fill=(r, g, b))

    # Verdigris bronze window frame & decorative circular rose mullion (like the right-side arch in the Arcane image!)
    draw.rectangle([wx0 + 12, 12, wx1 - 12, 2036], outline=(58, 78, 68), width=24)
    draw.rectangle([wx0 + 32, 32, wx1 - 32, 2016], outline=(214, 176, 96), width=6)
    # Vertical & horizontal mullions
    draw.line([(wcx, 32), (wcx, 2016)], fill=(58, 78, 68), width=18)
    for wy in [520, 1024, 1520]:
        draw.line([(wx0 + 24, wy), (wx1 - 24, wy)], fill=(58, 78, 68), width=16)
        draw.line([(wx0 + 24, wy + 10), (wx1 - 24, wy + 10)], fill=(214, 176, 96), width=4)
    # Circular Art-Nouveau medallion in the upper window transom
    draw.ellipse([wcx - 130, 390, wcx + 130, 650], outline=(58, 78, 68), width=18)
    draw.ellipse([wcx - 116, 404, wcx + 116, 636], outline=(224, 184, 102), width=6)

    img = img.filter(ImageFilter.SMOOTH)
    for out_p in [
        os.path.join(BLENDER_DIR, "T_Lorencia_Metal_Trim.png"),
        os.path.join(OUT_GLB_DIR, "Lorencia_Town_T_Lorencia_Metal_Trim.png"),
    ]:
        img.save(out_p, "PNG")
    print("Saved Painterly Arcane Metal, Banner & Window Atlas.")


if __name__ == "__main__":
    build_architecture_atlas()
    build_metal_and_banner_atlas()
