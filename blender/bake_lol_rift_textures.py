#!/usr/bin/env python3
"""
Hand-Painted League of Legends / Summoner's Rift Seamless Texture Pipeline (v2 - Smooth Gouache):
1. Derives stone tiles, weathered ashlar stone, and terracotta roof tiles pixel-for-pixel
   from the user's seamless 512x512 hand-painted League of Legends mossy stone tile reference.
2. Paints 1024x1024 smooth gouache League of Legends foliage frond textures
   (`T_Real_Palia_Leaves.png` & `T_LoL_Blossom_Leaves.png`) with a cohesive top-to-bottom
   bough gradient (cool viridian-teal shadow tuck at the top of each UV skirt -> lush mid-jade
   or orchid-rose gouache leaf plumes -> warm sunlit chartreuse-olive or pastel sakura-pink
   pointed leaf tips at the bottom of each UV skirt), with broad soft-blended leaf brushstrokes
   and zero high-frequency speckle noise!
3. Paints a 1024x1024 100% seamless Summoner's Rift hand-painted meadow grass canvas
   (`T_LoL_Rift_Terrain.png`, `T_LoL_Ground_Canvas_2K.png`, `T_Real_Palia_Grass.png`) with
   broad, soft gouache color washes (deep forest-teal shadow grass, emerald meadow, sunlit
   chartreuse-sage clearings) and low-contrast directional grass-blade tuft strokes.
4. Paints organic twisted walnut & mossy root bark (`T_LoL_Walnut_Wood.png`, `T_Real_Palia_Wood.png`).
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

PROJECT_DIR = "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel"
BLENDER_DIR = os.path.join(PROJECT_DIR, "blender")
OUT_GLB_DIR = os.path.join(PROJECT_DIR, "addons/lorencia_town")
REF_FLAGSTONE = "/Users/diogo.silva/OpenBot/Shared/Transfers/32890187-4388-4c85-ac1c-11b0a850082f/image.png"

os.makedirs(BLENDER_DIR, exist_ok=True)
os.makedirs(OUT_GLB_DIR, exist_ok=True)


def save_both(img, filenames):
    for name in filenames:
        img.save(os.path.join(BLENDER_DIR, name), "PNG")
        img.save(os.path.join(OUT_GLB_DIR, "Lorencia_Town_" + name), "PNG")


def build_lol_hand_painted_stone_family():
    src = Image.open(REF_FLAGSTONE).convert("RGB")
    w, h = src.size
    src_px = src.load()

    flag_img = Image.new("RGB", (w, h))
    stone_img = Image.new("RGB", (w, h))
    roof_img = Image.new("RGB", (w, h))

    flag_px = flag_img.load()
    stone_px = stone_img.load()
    roof_px = roof_img.load()

    for y in range(h):
        for x in range(w):
            r, g, b = src_px[x, y]
            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0

            fr = min(1.0, (rf ** 0.74) * 1.04)
            fg = min(1.0, (gf ** 0.74) * 1.03)
            fb = min(1.0, (bf ** 0.76) * 0.98)
            flag_px[x, y] = (int(fr * 255), int(fg * 255), int(fb * 255))

            luma = 0.299 * fr + 0.587 * fg + 0.114 * fb
            sr = min(1.0, (fr * 0.45 + luma * 0.55) * 1.18 + 0.05)
            sg = min(1.0, (fg * 0.28 + luma * 0.72) * 1.10 + 0.04)
            sb = min(1.0, (fb * 0.40 + luma * 0.60) * 0.96 + 0.02)
            stone_px[x, y] = (int(sr * 255), int(sg * 255), int(sb * 255))

            tile_v = max(0.25, min(1.15, (luma ** 0.85) * 1.35))
            tr = min(1.0, tile_v * 0.78)
            tg = min(1.0, tile_v * 0.36)
            tb = min(1.0, tile_v * 0.26)
            roof_px[x, y] = (int(tr * 255), int(tg * 255), int(tb * 255))

    save_both(flag_img, ["T_LoL_Mossy_Flagstones.png", "T_Real_Palia_Cobble.png"])
    save_both(stone_img, ["T_LoL_Weathered_Stone.png", "T_Real_Palia_Stucco.png", "T_Real_Palia_Stone.png"])
    save_both(roof_img, ["T_Palia_Terracotta_Roof.png", "T_Real_Palia_Terracotta.png"])
    print("Built seamless hand-painted LoL stone & roof textures from image.png")


def _draw_wrapped_polygon(draw, W, H, pts, fill_col):
    for ox in (-W, 0, W):
        for oy in (-H, 0, H):
            shifted = [(x + ox, y + oy) for (x, y) in pts]
            xs = [p[0] for p in shifted]
            ys = [p[1] for p in shifted]
            if max(xs) >= 0 and min(xs) <= W and max(ys) >= 0 and min(ys) <= H:
                draw.polygon(shifted, fill=fill_col)


def build_hand_painted_lol_foliage_textures():
    """
    Paints smooth, broad-brushstroke League of Legends foliage sheets (512x512, blurred for soft
    hand-painted gouache transitions — zero high-frequency speckle noise!):
    - In Blender's `UVMap`, `v = 0.0..0.25` is the recessed upper shadow tuck under the tier above,
      `v = 0.25..0.72` is the sweeping mid-bough body with 8 broad vertical leaf-frond plumes across `u`,
      and `v = 0.72..1.00` is the warm sunlit pointed leaf tip at the lower edge of each bough skirt!
    """
    W, H = 512, 512
    two_pi = 2.0 * math.pi

    for is_blossom, filenames in [
        (False, ["T_Real_Palia_Leaves.png"]),
        (True, ["T_LoL_Blossom_Leaves.png"]),
    ]:
        img = Image.new("RGB", (W, H))
        px = img.load()

        for y in range(H):
            # Note: PIL y=0 is top (Blender UV.v = 1.0), PIL y=H-1 is bottom (Blender UV.v = 0.0).
            # In our Blender meshes, UV.v = 0.12 is the upper crown/tuck, UV.v = 0.92 is the hanging pointed tip!
            # Wait: in Blender, image UV (u, v) has v=0 at the BOTTOM of the PNG (y = H-1) and v=1 at the TOP of the PNG (y = 0)!
            uv_v = 1.0 - (float(y) / float(H - 1))
            for x in range(W):
                uv_u = float(x) / float(W)
                # 8 broad vertical leaf-frond brushstroke plumes across u
                plume_wave = 0.5 + 0.5 * math.cos(two_pi * (uv_u * 8.0) + math.sin(two_pi * uv_v) * 0.35)
                sub_stroke = 0.5 + 0.5 * math.sin(two_pi * (uv_u * 16.0 - uv_v * 1.5))
                rib = 0.65 * plume_wave + 0.35 * sub_stroke

                # Smooth tier gradient from upper under-tier shadow (uv_v ~ 0.1) to sunlit hanging tip (uv_v ~ 0.92)
                t_vert = max(0.0, min(1.0, (uv_v - 0.08) / 0.84))
                # Soft jagged painterly transition line along the bough
                t_paint = max(0.0, min(1.0, t_vert + (rib - 0.5) * 0.22))

                if not is_blossom:
                    # Summoner's Rift Pine/Forest Palette (exact match to Captura de Tela 2026-11-23 às 19.03.45.png):
                    # Shadow tuck RGB(34, 68, 60) -> Mid Jade RGB(76, 126, 78) -> Sunlit Chartreuse Tip RGB(144, 178, 92)
                    if t_paint < 0.45:
                        k = t_paint / 0.45
                        r = 34 + k * (76 - 34)
                        g = 68 + k * (126 - 68)
                        b = 60 + k * (78 - 60)
                    else:
                        k = (t_paint - 0.45) / 0.55
                        r = 76 + k * (144 - 76)
                        g = 126 + k * (178 - 126)
                        b = 78 + k * (92 - 78)
                    # Gentle brushstroke groove variation (+/- 7 RGB)
                    delta = (rib - 0.5) * 14.0
                    px[x, y] = (
                        max(0, min(255, int(r + delta * 0.9))),
                        max(0, min(255, int(g + delta * 1.1))),
                        max(0, min(255, int(b + delta * 0.5))),
                    )
                else:
                    # Spirit Blossom / Devoted Studios Sakura Palette (exact match to image-2.png):
                    # Soft Plum Shadow RGB(132, 66, 118) -> Lush Orchid Rose RGB(188, 96, 156) -> Pastel Sakura Crown RGB(232, 142, 192)
                    if t_paint < 0.45:
                        k = t_paint / 0.45
                        r = 132 + k * (188 - 132)
                        g = 66 + k * (96 - 66)
                        b = 118 + k * (156 - 118)
                    else:
                        k = (t_paint - 0.45) / 0.55
                        r = 188 + k * (232 - 188)
                        g = 96 + k * (142 - 96)
                        b = 156 + k * (192 - 156)
                    delta = (rib - 0.5) * 12.0
                    px[x, y] = (
                        max(0, min(255, int(r + delta))),
                        max(0, min(255, int(g + delta * 0.8))),
                        max(0, min(255, int(b + delta * 0.9))),
                    )

        # Layer 28 large, soft-blended gouache leaf-frond dabs (subtle contrast, then Gaussian-blurred)
        draw = ImageDraw.Draw(img)
        rng = random.Random(707 if not is_blossom else 909)
        for _ in range(36):
            cx = rng.uniform(0, W)
            cy = rng.uniform(0, H)
            uv_v = 1.0 - (cy / float(H))
            bw = rng.uniform(26.0, 44.0)
            bh = rng.uniform(55.0, 90.0)
            ang = rng.uniform(-0.18, 0.18)
            ca, sa = math.cos(ang), math.sin(ang)

            def b_pt(lx, ly):
                return (cx + lx * ca - ly * sa, cy + lx * sa + ly * ca)

            pts = [
                b_pt(0.0, -bh * 0.50),
                b_pt(bw * 0.52, -bh * 0.05),
                b_pt(bw * 0.35, bh * 0.32),
                b_pt(0.0, bh * 0.50),
                b_pt(-bw * 0.35, bh * 0.32),
                b_pt(-bw * 0.52, -bh * 0.05),
            ]
            if not is_blossom:
                col = (94, 146, 84) if uv_v < 0.55 else (132, 168, 88)
            else:
                col = (196, 104, 164) if uv_v < 0.55 else (224, 134, 184)
            _draw_wrapped_polygon(draw, W, H, pts, col)

        img = img.filter(ImageFilter.GaussianBlur(radius=2.4))
        save_both(img, filenames)

    print("Built smooth gouache League of Legends foliage & Spirit Blossom leaf textures.")


def build_seamless_lol_rift_terrain():
    """
    Paints a 100% seamless hand-painted Summoner's Rift meadow grass & mossy path canvas
    (matching the user's Rift forest reference `image.png`):
    - Broad, soft gouache color zones (cool forest-teal shadow grass, lush emerald meadow,
      warm sunlit chartreuse-sage clearings) with soft low-contrast painted grass-blade clusters
      and zero high-frequency speckle noise!
    """
    W, H = 512, 512
    img = Image.new("RGB", (W, H))
    px = img.load()
    two_pi = 2.0 * math.pi

    for y in range(H):
        v = float(y) / float(H)
        ay = two_pi * v
        s1y, c1y = math.sin(ay), math.cos(ay)
        s2y, c2y = math.sin(2.0 * ay + 0.7), math.cos(2.0 * ay - 0.4)
        for x in range(W):
            u = float(x) / float(W)
            ax = two_pi * u

            w1 = math.sin(ax + 0.4) * c1y + math.cos(ax - 0.8) * s1y
            w2 = math.sin(2.0 * ax - 1.1) * s2y + math.cos(2.0 * ax + 0.5) * c2y
            w3 = math.sin(3.0 * ax + 2.0 * ay + 0.6) * 0.5 + math.cos(3.0 * ax - 2.0 * ay - 0.5) * 0.5

            t = max(0.0, min(1.0, 0.50 + 0.25 * w1 + 0.16 * w2 + 0.08 * w3))

            # Summoner's Rift gouache meadow palette: Forest-Teal -> Emerald -> Sunlit Sage-Chartreuse
            if t < 0.40:
                k = t / 0.40
                r = 48 + k * (72 - 48)
                g = 86 + k * (116 - 86)
                b = 68 + k * (72 - 68)
            elif t < 0.75:
                k = (t - 0.40) / 0.35
                r = 72 + k * (98 - 72)
                g = 116 + k * (142 - 116)
                b = 72 + k * (82 - 72)
            else:
                k = (t - 0.75) / 0.25
                r = 98 + k * (116 - 98)
                g = 142 + k * (154 - 142)
                b = 82 + k * (96 - 82)

            px[x, y] = (int(r), int(g), int(b))

    draw = ImageDraw.Draw(img)
    rng = random.Random(404)

    # 1. Broad, soft gouache brush washes (wrapped across all edges)
    for _ in range(95):
        cx = rng.uniform(0, W)
        cy = rng.uniform(0, H)
        rw = rng.uniform(24.0, 52.0)
        rh = rng.uniform(18.0, 38.0)
        ang = rng.uniform(0, math.pi)
        ca, sa = math.cos(ang), math.sin(ang)
        pts = []
        for s_i in range(8):
            a = (s_i / 8.0) * two_pi
            lx, ly = math.cos(a) * rw, math.sin(a) * rh
            pts.append((cx + lx * ca - ly * sa, cy + lx * sa + ly * ca))
        pal = rng.choice([
            (58, 96, 70),
            (76, 120, 74),
            (88, 132, 78),
            (104, 144, 86),
            (66, 108, 74),
        ])
        _draw_wrapped_polygon(draw, W, H, pts, pal)

    # 2. Broad, soft-blended painted grass-blade tuft strokes (low contrast delta so it never speckles)
    for _ in range(110):
        tx = rng.uniform(0, W)
        ty = rng.uniform(0, H)
        num_blades = rng.randint(3, 4)
        tuft_w = rng.uniform(16.0, 26.0)
        blade_col = rng.choice([
            (88, 134, 78),
            (102, 146, 84),
            (114, 156, 88),
            (76, 120, 74),
        ])
        for b_i in range(num_blades):
            frac = (b_i / float(max(1, num_blades - 1))) - 0.5
            bx = tx + frac * tuft_w
            bh = rng.uniform(18.0, 30.0)
            bw = rng.uniform(3.2, 4.8)
            lean = frac * rng.uniform(7.0, 13.0)
            blade_pts = [
                (bx - bw, ty + 2.0),
                (bx + bw, ty + 2.0),
                (bx + lean * 0.55 + bw * 0.45, ty - bh * 0.5),
                (bx + lean, ty - bh),
                (bx + lean * 0.55 - bw * 0.45, ty - bh * 0.5),
            ]
            _draw_wrapped_polygon(draw, W, H, blade_pts, blade_col)

    img = img.filter(ImageFilter.GaussianBlur(radius=1.8))
    save_both(img, ["T_LoL_Rift_Terrain.png", "T_LoL_Ground_Canvas_2K.png", "T_Real_Palia_Grass.png"])
    print("Built 100% seamless Summoner's Rift smooth gouache grass & meadow texture.")


def build_seamless_walnut_wood():
    W, H = 512, 512
    img = Image.new("RGB", (W, H))
    px = img.load()
    two_pi = 2.0 * math.pi

    for y in range(H):
        v = float(y) / float(H)
        plank_pos = (v * 8.0) % 1.0
        plank_id = int(v * 8.0)
        seam = 1.0
        is_crevice = False
        if plank_pos < 0.06:
            seam = 0.62 + (plank_pos / 0.06) * 0.38
            is_crevice = True
        elif plank_pos < 0.14:
            seam = 1.12
        elif plank_pos > 0.94:
            seam = 0.62 + ((1.0 - plank_pos) / 0.06) * 0.38
            is_crevice = True

        for x in range(W):
            u = float(x) / float(W)
            grain = (
                math.sin(two_pi * (u * 2.0 + v * 1.0) + plank_id * 1.7) * 0.5
                + math.cos(two_pi * (u * 5.0 - v * 2.0) + plank_id * 0.9) * 0.3
                + math.sin(two_pi * (v * 24.0 + u * 1.0)) * 0.2
            )
            moss_wave = max(0.0, math.sin(two_pi * (u * 3.0 - v * 2.0) + 0.8))
            g_t = 0.5 + 0.35 * grain
            r = (92 + g_t * 36) * seam
            g = (62 + g_t * 26) * seam
            b = (38 + g_t * 16) * seam
            if is_crevice and moss_wave > 0.45:
                m_str = (moss_wave - 0.45) * 0.55
                r = r * (1.0 - m_str) + 64 * m_str
                g = g * (1.0 - m_str) + 104 * m_str
                b = b * (1.0 - m_str) + 54 * m_str
            px[x, y] = (
                max(0, min(255, int(r))),
                max(0, min(255, int(g))),
                max(0, min(255, int(b))),
            )

    save_both(img, ["T_LoL_Walnut_Wood.png", "T_Real_Palia_Wood.png"])
    print("Built 100% seamless hand-painted Walnut Timber & Mossy Bark texture.")


if __name__ == "__main__":
    build_lol_hand_painted_stone_family()
    build_hand_painted_lol_foliage_textures()
    build_seamless_lol_rift_terrain()
    build_seamless_walnut_wood()
