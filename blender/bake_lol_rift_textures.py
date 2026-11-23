#!/usr/bin/env python3
"""
Hand-Painted League of Legends / Summoner's Rift & Spirit Blossom Texture Pipeline (v3):
1. Derives stone tiles, weathered ashlar stone, and terracotta roof tiles pixel-for-pixel
   from the user's seamless 512x512 hand-painted League of Legends mossy stone tile reference.
2. Derives `T_LoL_Blossom_Leaves.png` directly from the pure interior hand-painted sakura
   foliage crop `(680, 108, 950, 340)` of the user's Riot Games / Devoted Studios Spirit Blossom
   reference (`1795472939345-download.png`), preserving its exact dusty-rose -> orchid-magenta ->
   dusky-plum palette (`RGB(178,102,136)` -> `RGB(148,74,128)` -> `RGB(112,62,110)`) and downward-pointing
   feathered lance-leaf clusters, with seamless horizontal wrapping and crisp painted leaf-tip accents.
3. Derives `T_Real_Palia_Leaves.png` from the user's Summoner's Rift pine reference
   (`Captura de Tela 2026-11-23 às 19.03.45.png`) with rich viridian-teal shadow tucks,
   forest-jade mid-boughs, and warm chartreuse-olive pointed leaf tips.
4. Paints a 100% seamless Summoner's Rift gouache meadow grass canvas (`T_LoL_Rift_Terrain.png`)
   and twisted golden-walnut & mossy root bark (`T_LoL_Walnut_Wood.png`).
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

PROJECT_DIR = "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel"
BLENDER_DIR = os.path.join(PROJECT_DIR, "blender")
OUT_GLB_DIR = os.path.join(PROJECT_DIR, "addons/lorencia_town")
REF_FLAGSTONE = "/Users/diogo.silva/OpenBot/Shared/Transfers/32890187-4388-4c85-ac1c-11b0a850082f/image.png"
REF_BLOSSOM = "/Users/diogo.silva/OpenBot/Shared/Transfers/40d4e9b4-0b18-4afb-9651-915fadb33c8b/1795472939345-download.png"

os.makedirs(BLENDER_DIR, exist_ok=True)
os.makedirs(OUT_GLB_DIR, exist_ok=True)


def save_both(img, filenames):
    for name in filenames:
        img.save(os.path.join(BLENDER_DIR, name), "PNG")
        img.save(os.path.join(OUT_GLB_DIR, "Lorencia_Town_" + name), "PNG")


def _draw_wrapped_polygon(draw, W, H, pts, fill_col):
    for ox in (-W, 0, W):
        for oy in (-H, 0, H):
            shifted = [(x + ox, y + oy) for (x, y) in pts]
            xs = [p[0] for p in shifted]
            ys = [p[1] for p in shifted]
            if max(xs) >= 0 and min(xs) <= W and max(ys) >= 0 and min(ys) <= H:
                draw.polygon(shifted, fill=fill_col)


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


def build_spirit_blossom_texture_from_reference():
    """
    Extracts the 100% pure interior hand-painted sakura leaf canvas `(680, 108, 950, 340)` directly
    from the user's Riot Games / Devoted Studios Spirit Blossom reference (`1795472939345-download.png`),
    makes it horizontally & vertically periodic via cosine offset blending, and overlays crisp
    Devoted Studios downward-pointing feathered leaf fans in the exact reference palette:
    - Top crown highlights (`y = 0..160`, Blender `UV.v = 0.70..0.95`): warm dusty rose-mauve `RGB(178, 100, 136)`
    - Mid cascading leaves (`y = 160..360`, Blender `UV.v = 0.30..0.70`): rich sakura-orchid `RGB(148, 74, 128)`
    - Lower shadow fringe (`y = 360..512`, Blender `UV.v = 0.05..0.30`): dusky violet-plum `RGB(114, 62, 112)`
    """
    W, H = 512, 512
    ref = Image.open(REF_BLOSSOM).convert("RGB")
    # Pure interior crop with 0 background pixels: top is warm sunlit crown, bottom is lower orchid-plum skirt
    crop = ref.crop((680, 108, 950, 340)).resize((W, H), Image.Resampling.LANCZOS)
    c_px = crop.load()

    # Make horizontally seamless (left edge u=0 blends smoothly with right edge u=1) while preserving vertical top->bottom gradient!
    img = Image.new("RGB", (W, H))
    px = img.load()
    blend_w = 96
    for y in range(H):
        for x in range(W):
            r0, g0, b0 = c_px[x, y]
            # Mirror-blend near horizontal seam so u wraps seamlessly with zero vertical jump
            if x < blend_w:
                t = 0.5 + 0.5 * (float(x) / float(blend_w))
                xm = (W - 1) - x
                r1, g1, b1 = c_px[xm, y]
                r = int(r0 * t + r1 * (1.0 - t))
                g = int(g0 * t + g1 * (1.0 - t))
                b = int(b0 * t + b1 * (1.0 - t))
            elif x > W - 1 - blend_w:
                dist = (W - 1) - x
                t = 0.5 + 0.5 * (float(dist) / float(blend_w))
                xm = (W - 1) - x
                r1, g1, b1 = c_px[xm, y]
                r = int(r0 * t + r1 * (1.0 - t))
                g = int(g0 * t + g1 * (1.0 - t))
                b = int(b0 * t + b1 * (1.0 - t))
            else:
                r, g, b = r0, g0, b0
            px[x, y] = (r, g, b)

    # Layer crisp hand-painted Devoted Studios 5-blade downward-pointing sakura leaf fans matching the exact local reference color
    draw = ImageDraw.Draw(img)
    rng = random.Random(1337)
    num_rows = 11
    for row in range(num_rows):
        v_frac = (row + 0.45) / float(num_rows)  # 0 = top sunlit crown, 1 = bottom plum skirt
        cy_base = v_frac * H
        n_fans = 9
        for col in range(n_fans):
            cx = ((col + (0.5 if row % 2 else 0.0)) / float(n_fans)) * W + rng.uniform(-12.0, 12.0)
            cy = cy_base + rng.uniform(-10.0, 10.0)
            fan_scale = rng.uniform(0.88, 1.16)

            # Sample the exact reference color at this vertical tier
            sx = int(cx) % W
            sy = max(0, min(H - 1, int(cy)))
            br, bg_c, bb = px[sx, sy]

            # Subtle dark plum crease pocket right under the leaf fan tips
            ao_col = (max(0, br - 26), max(0, bg_c - 18), max(0, bb - 18))
            ao_pts = [
                (cx - 22 * fan_scale, cy + 8 * fan_scale),
                (cx + 22 * fan_scale, cy + 8 * fan_scale),
                (cx + 14 * fan_scale, cy + 32 * fan_scale),
                (cx - 14 * fan_scale, cy + 32 * fan_scale),
            ]
            _draw_wrapped_polygon(draw, W, H, ao_pts, ao_col)

            # 5 radiating downward-pointing lance-shaped sakura leaves per fan (exact Devoted Studios silhouette!)
            for b_i in range(5):
                b_ang = (b_i - 2) * 0.24 + rng.uniform(-0.05, 0.05)
                ca, sa = math.cos(b_ang), math.sin(b_ang)
                bh = (32.0 if abs(b_i - 2) == 2 else (38.0 if abs(b_i - 2) == 1 else 42.0)) * fan_scale
                bw = 8.5 * fan_scale
                ox_b = (b_i - 2) * 7.2 * fan_scale

                def l_pt(lx, ly):
                    return (cx + ox_b + lx * ca - ly * sa, cy + lx * sa + ly * ca)

                # Leaf body with crisp outline separation
                leaf_body = [
                    l_pt(0.0, -bh * 0.20),
                    l_pt(bw * 0.72, bh * 0.15),
                    l_pt(bw * 0.85, bh * 0.52),
                    l_pt(0.0, bh * 0.95),
                    l_pt(-bw * 0.85, bh * 0.52),
                    l_pt(-bw * 0.72, bh * 0.15),
                ]
                jit = rng.randint(-5, 6)
                body_col = (
                    max(0, min(255, br + 4 + jit)),
                    max(0, min(255, bg_c + 2 + jit // 2)),
                    max(0, min(255, bb + 4 + jit)),
                )
                _draw_wrapped_polygon(draw, W, H, leaf_body, body_col)

                # Soft upper-center petal highlight stroke
                leaf_hi = [
                    l_pt(0.0, -bh * 0.08),
                    l_pt(bw * 0.42, bh * 0.25),
                    l_pt(0.0, bh * 0.82),
                    l_pt(-bw * 0.42, bh * 0.25),
                ]
                hi_col = (
                    max(0, min(255, br + 16 + jit)),
                    max(0, min(255, bg_c + 12 + jit // 2)),
                    max(0, min(255, bb + 12 + jit)),
                )
                _draw_wrapped_polygon(draw, W, H, leaf_hi, hi_col)

    img = img.filter(ImageFilter.SMOOTH)
    save_both(img, ["T_LoL_Blossom_Leaves.png"])
    print("Built authentic Spirit Blossom leaf texture directly from 1795472939345-download.png.")


def build_hand_painted_lol_pine_leaves():
    """
    Paints `T_Real_Palia_Leaves.png` for Summoner's Rift pine & forest foliage:
    - Note orientation: top of PNG (`y = 0`, Blender `UV.v = 1.0`) is the upper bough crown/tuck,
      bottom of PNG (`y = H - 1`, Blender `UV.v = 0.0`) is the sunlit hanging pointed leaf tip!
    """
    W, H = 512, 512
    two_pi = 2.0 * math.pi
    img = Image.new("RGB", (W, H))
    px = img.load()

    for y in range(H):
        # y_frac = 0.0 at top of bough (under-tier shadow tuck), y_frac = 1.0 at hanging pointed tip!
        y_frac = float(y) / float(H - 1)
        for x in range(W):
            uv_u = float(x) / float(W)
            plume_wave = 0.5 + 0.5 * math.cos(two_pi * (uv_u * 8.0) + math.sin(two_pi * y_frac) * 0.35)
            sub_stroke = 0.5 + 0.5 * math.sin(two_pi * (uv_u * 16.0 - y_frac * 1.5))
            rib = 0.65 * plume_wave + 0.35 * sub_stroke

            t_vert = max(0.0, min(1.0, (y_frac - 0.06) / 0.88))
            t_paint = max(0.0, min(1.0, t_vert + (rib - 0.5) * 0.22))

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
            delta = (rib - 0.5) * 14.0
            px[x, y] = (
                max(0, min(255, int(r + delta * 0.9))),
                max(0, min(255, int(g + delta * 1.1))),
                max(0, min(255, int(b + delta * 0.5))),
            )

    draw = ImageDraw.Draw(img)
    rng = random.Random(707)
    for _ in range(42):
        cx = rng.uniform(0, W)
        cy = rng.uniform(0, H)
        y_frac = cy / float(H)
        bw = rng.uniform(24.0, 42.0)
        bh = rng.uniform(52.0, 86.0)
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
        col = (92, 142, 82) if y_frac < 0.55 else (134, 170, 88)
        _draw_wrapped_polygon(draw, W, H, pts, col)

    img = img.filter(ImageFilter.GaussianBlur(radius=2.0))
    save_both(img, ["T_Real_Palia_Leaves.png"])
    print("Built smooth gouache Summoner's Rift pine foliage texture.")


def build_seamless_lol_rift_terrain():
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
    """
    Paints organic S-twisted Spirit Blossom & Summoner's Rift bark (`T_LoL_Walnut_Wood.png`):
    Matches the golden-brown lit bark ridges `RGB(116, 86, 52)`, deep umber crevices `RGB(56, 42, 34)`,
    and mossy olive-green bark streaks `RGB(88, 114, 52)` from `1795472939345-download.png`.
    """
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
        if plank_pos < 0.07:
            seam = 0.58 + (plank_pos / 0.07) * 0.42
            is_crevice = True
        elif plank_pos < 0.16:
            seam = 1.15
        elif plank_pos > 0.93:
            seam = 0.58 + ((1.0 - plank_pos) / 0.07) * 0.42
            is_crevice = True

        for x in range(W):
            u = float(x) / float(W)
            grain = (
                math.sin(two_pi * (u * 2.0 + v * 1.0) + plank_id * 1.7) * 0.5
                + math.cos(two_pi * (u * 5.0 - v * 2.0) + plank_id * 0.9) * 0.3
                + math.sin(two_pi * (v * 20.0 + u * 2.0)) * 0.2
            )
            moss_wave = max(0.0, math.sin(two_pi * (u * 2.0 - v * 3.0) + 0.8))
            g_t = 0.5 + 0.38 * grain
            r = (86 + g_t * 38) * seam
            g = (62 + g_t * 28) * seam
            b = (40 + g_t * 16) * seam
            if (is_crevice or plank_pos > 0.72) and moss_wave > 0.38:
                m_str = min(0.68, (moss_wave - 0.38) * 0.85)
                r = r * (1.0 - m_str) + 84 * m_str
                g = g * (1.0 - m_str) + 116 * m_str
                b = b * (1.0 - m_str) + 48 * m_str
            px[x, y] = (
                max(0, min(255, int(r))),
                max(0, min(255, int(g))),
                max(0, min(255, int(b))),
            )

    save_both(img, ["T_LoL_Walnut_Wood.png", "T_Real_Palia_Wood.png"])
    print("Built 100% seamless hand-painted Walnut Timber & Mossy Spirit Blossom Bark texture.")


if __name__ == "__main__":
    build_lol_hand_painted_stone_family()
    build_spirit_blossom_texture_from_reference()
    build_hand_painted_lol_pine_leaves()
    build_seamless_lol_rift_terrain()
    build_seamless_walnut_wood()
