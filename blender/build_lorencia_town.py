import os
import sys
import math
import random
import bpy
import bmesh
import mathutils

# ═══════════════════════════════════════════════════════════════════════════
# LEAGUE OF LEGENDS / SUMMONER'S RIFT & SPIRIT BLOSSOM CITY (v10 - Alpha Card & Varied Silhouettes)
# 1. Authentic Riot Games / Devoted Studios RGBA Alpha-Cutout Leaf Cluster Cards
#    (`T_LoL_Blossom_Leaves.png` & `T_Real_Palia_Leaves.png` 2x2 Atlases) + CC0 Alpha Grass
#    Tuft Cards (`T_LoL_Grass_Tuft_Alpha.png`) with Spherical Normal Transfer!
# 2. Every single tree in the world has a UNIQUE body shape (7 distinct tree architecture
#    archetypes + per-instance procedural trunk curves, branch angles, and canopy cloud proportions —
#    ZERO repeated diorama clones!).
# 3. Stripe-free, octagon-free Summoner's Rift hand-painted meadow grass terrain with
#    dual-scale rotated UV shader blending.
# ═══════════════════════════════════════════════════════════════════════════

PROJECT_DIR = "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel"
BLENDER_DIR = os.path.join(PROJECT_DIR, "blender")
OUT_GLB_DIR = os.path.join(PROJECT_DIR, "addons/lorencia_town")

os.makedirs(BLENDER_DIR, exist_ok=True)
os.makedirs(OUT_GLB_DIR, exist_ok=True)

UV_BANNER = (0.51, 0.75, 0.02, 0.98)

# 2x2 RGBA Atlas UV bounds in Blender (u0, u1, v_bot, v_top)
ATLAS_CELLS = [
    (0.02, 0.48, 0.52, 0.98),  # Cell 0: Top-Left (Main cascading canopy bouquet)
    (0.52, 0.98, 0.52, 0.98),  # Cell 1: Top-Right (Bonsai twin-lobe bouquet)
    (0.02, 0.48, 0.02, 0.48),  # Cell 2: Bottom-Left (Cascading double-lobe bouquet)
    (0.52, 0.98, 0.02, 0.48),  # Cell 3: Bottom-Right (Full crown & shoulder bouquet)
]


def gpos(gx, gy, gz):
    return mathutils.Vector((float(gx), float(-gz), float(gy)))


def assign_world_uvs(bm, faces, tile_scale=0.24):
    uv_layer = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
    for f in faces:
        n = f.normal
        is_horiz = abs(n.z) > 0.65
        for loop in f.loops:
            co = loop.vert.co
            if is_horiz:
                loop[uv_layer].uv = (co.x * tile_scale, co.y * tile_scale)
            else:
                loop[uv_layer].uv = ((co.x + co.y) * tile_scale, co.z * tile_scale)


def add_box(bm, gx, gy, gz, sx, sy, sz, rot_y_deg=0.0, taper_top=1.0, tile_scale=0.24):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    new_verts = ret["verts"]
    new_faces = list({f for v in new_verts for f in v.link_faces})
    rot = mathutils.Matrix.Rotation(math.radians(rot_y_deg), 3, "Z")
    center = gpos(gx, gy + sy * 0.5, gz)
    for v in new_verts:
        is_top = v.co.z > 0.0
        tx = taper_top if is_top else 1.0
        local = mathutils.Vector((v.co.x * sx * tx, v.co.y * sz * tx, v.co.z * sy))
        v.co = center + (rot @ local)
    bmesh.ops.recalc_face_normals(bm, faces=new_faces)
    assign_world_uvs(bm, new_faces, tile_scale=tile_scale)


def add_chiseled_block(bm_body, bm_edge_hi, gx, gy, gz, sx, sy, sz, rot_y_deg=0.0, bevel_inset=0.92, tile_scale=0.24):
    body_h = sy * 0.84
    cap_h = sy * 0.16
    add_box(bm_body, gx, gy, gz, sx, body_h, sz, rot_y_deg=rot_y_deg, taper_top=0.98, tile_scale=tile_scale)
    add_box(bm_edge_hi, gx, gy + body_h, gz, sx * 0.98, cap_h, sz * 0.98, rot_y_deg=rot_y_deg, taper_top=bevel_inset, tile_scale=tile_scale)


def add_staggered_rift_border_stones(bm_body, bm_edge_hi, x0, z0, x1, z1, step=1.55, seed=42, bm_grass=None):
    rng = random.Random(seed)
    dist = math.hypot(x1 - x0, z1 - z0)
    count = max(2, int(round(dist / step)))
    base_ang = math.degrees(math.atan2(x1 - x0, z1 - z0))
    for i in range(count + 1):
        t = float(i) / float(count)
        cx = x0 + (x1 - x0) * t + rng.uniform(-0.18, 0.18)
        cz = z0 + (z1 - z0) * t + rng.uniform(-0.18, 0.18)
        w = rng.uniform(0.95, 1.45)
        d = rng.uniform(1.05, 1.55)
        h = rng.uniform(0.14, 0.26)
        rot = base_ang + rng.uniform(-16.0, 16.0)
        add_chiseled_block(bm_body, bm_edge_hi, cx, -0.02, cz, w, h, d, rot_y_deg=rot)
        if bm_grass is not None and (i % 2 == 0):
            gx_t = cx + rng.uniform(-0.45, 0.45)
            gz_t = cz + rng.uniform(-0.45, 0.45)
            add_lol_alpha_grass_tuft(bm_grass, gx_t, -0.02, gz_t, scale=0.85, seed=seed + i * 7)


def add_lol_alpha_grass_tuft(bm_grass, gx, gy, gz, scale=1.0, seed=303):
    """
    3D Alpha-Cutout Grass Tuft Card Cluster (`T_LoL_Grass_Tuft_Alpha.png` from CC0 grassbush):
    Places 3 intersecting slightly curved quad cards at 60° star angles, tilted outward so
    they read cleanly from both isometric top-down and side views!
    """
    rng = random.Random(seed)
    uv_layer = bm_grass.loops.layers.uv.active or bm_grass.loops.layers.uv.new("UVMap")
    col_layer = bm_grass.loops.layers.color.active or bm_grass.loops.layers.color.new("Col")

    w = rng.uniform(0.95, 1.25) * scale
    h = rng.uniform(0.70, 0.95) * scale
    base_yaw = rng.uniform(0.0, math.pi)
    new_faces = []

    for c_i in range(3):
        ang = base_yaw + c_i * (math.pi / 3.0) + rng.uniform(-0.12, 0.12)
        ca, sa = math.cos(ang), math.sin(ang)
        nx, nz = -sa, ca
        tilt = 0.28 * h * (1.0 if (c_i % 2 == 0) else -1.0)
        hw = w * 0.5

        v_bl = bm_grass.verts.new(gpos(gx - ca * hw, gy - 0.03, gz - sa * hw))
        v_br = bm_grass.verts.new(gpos(gx + ca * hw, gy - 0.03, gz + sa * hw))
        v_tr = bm_grass.verts.new(gpos(gx + ca * hw + nx * tilt, gy + h, gz + sa * hw + nz * tilt))
        v_tl = bm_grass.verts.new(gpos(gx - ca * hw + nx * tilt, gy + h, gz - sa * hw + nz * tilt))

        f = bm_grass.faces.new((v_bl, v_br, v_tr, v_tl))
        new_faces.append(f)
        uv_map = {
            v_bl: (0.04, 0.04),
            v_br: (0.96, 0.04),
            v_tr: (0.96, 0.96),
            v_tl: (0.04, 0.96),
        }
        col_map = {
            v_bl: (0.72, 0.84, 0.78, 1.0),
            v_br: (0.72, 0.84, 0.78, 1.0),
            v_tr: (1.04, 1.06, 0.94, 1.0),
            v_tl: (1.04, 1.06, 0.94, 1.0),
        }
        for loop in f.loops:
            loop[uv_layer].uv = uv_map[loop.vert]
            loop[col_layer] = col_map[loop.vert]

    bmesh.ops.recalc_face_normals(bm_grass, faces=new_faces)
    for f in new_faces:
        for v in f.verts:
            v.normal = mathutils.Vector((0.0, 0.0, 1.0))


def add_curved_alpha_leaf_card(
    bm, uv_layer, col_layer,
    card_cx, card_cy, card_cz,
    cloud_cx, cloud_cy, cloud_cz,
    width, height, yaw_rad, pitch_rad,
    cell_idx=0, shade_tint=(1.0, 1.0, 1.0), flip_u=False
):
    """
    Creates a gently domed 2x2-subdivided quad card mapped to one of the 4 authentic
    Devoted Studios hand-painted leaf-cluster bouquets in our 1024x1024 RGBA Atlas!
    """
    u0, u1, v0, v1 = ATLAS_CELLS[cell_idx % 4]
    if flip_u:
        u0, u1 = u1, u0

    cy_a, sy_a = math.cos(yaw_rad), math.sin(yaw_rad)
    cp_a, sp_a = math.cos(pitch_rad), math.sin(pitch_rad)

    rx_v, ry_v, rz_v = -sy_a, 0.0, cy_a
    nx_v, ny_v, nz_v = cy_a * cp_a, sp_a, sy_a * cp_a
    ux_v, uy_v, uz_v = -cy_a * sp_a, cp_a, -sy_a * sp_a

    grid_verts = [[None] * 3 for _ in range(3)]
    grid_uvs = [[None] * 3 for _ in range(3)]
    grid_cols = [[None] * 3 for _ in range(3)]

    cloud_center_b = gpos(cloud_cx, cloud_cy, cloud_cz)

    for iy in range(3):
        fy = (iy / 2.0) - 0.5
        v_tex = v0 + (iy / 2.0) * (v1 - v0)
        for ix in range(3):
            fx = (ix / 2.0) - 0.5
            u_tex = u0 + (ix / 2.0) * (u1 - u0)

            camber = (1.0 - (fx * fx * 2.2 + fy * fy * 2.2)) * 0.22 * min(width, height)
            wx = card_cx + rx_v * (fx * width) + ux_v * (fy * height) + nx_v * camber
            wy = card_cy + ry_v * (fx * width) + uy_v * (fy * height) + ny_v * camber
            wz = card_cz + rz_v * (fx * width) + uz_v * (fy * height) + nz_v * camber

            bv = bm.verts.new(gpos(wx, wy, wz))
            sph_n = (bv.co - cloud_center_b)
            sph_n.z = max(0.25, sph_n.z + 0.55)
            bv.normal = sph_n.normalized()

            v_lift = 0.86 + 0.18 * (iy / 2.0)
            cr = min(1.0, shade_tint[0] * v_lift)
            cg = min(1.0, shade_tint[1] * v_lift)
            cb = min(1.0, shade_tint[2] * v_lift)

            grid_verts[iy][ix] = bv
            grid_uvs[iy][ix] = (u_tex, v_tex)
            grid_cols[iy][ix] = (cr, cg, cb, 1.0)

    faces = []
    for iy in range(2):
        for ix in range(2):
            v00 = grid_verts[iy][ix]
            v10 = grid_verts[iy][ix + 1]
            v11 = grid_verts[iy + 1][ix + 1]
            v01 = grid_verts[iy + 1][ix]
            f = bm.faces.new((v00, v10, v11, v01))
            faces.append(f)
            uv_lookup = {
                v00: grid_uvs[iy][ix],
                v10: grid_uvs[iy][ix + 1],
                v11: grid_uvs[iy + 1][ix + 1],
                v01: grid_uvs[iy + 1][ix],
            }
            col_lookup = {
                v00: grid_cols[iy][ix],
                v10: grid_cols[iy][ix + 1],
                v11: grid_cols[iy + 1][ix + 1],
                v01: grid_cols[iy + 1][ix],
            }
            for loop in f.loops:
                loop[uv_layer].uv = uv_lookup[loop.vert]
                loop[col_layer] = col_lookup[loop.vert]
    return faces


def add_alpha_card_canopy_bouquet(bm_lit, bm_shade, cx, cy, cz, rx, ry, rz, seed=42):
    """
    Constructs a lush, volumetric 3D hand-painted foliage cloud solely from overlapping
    domed RGBA Alpha-Cutout Leaf Cluster Cards (`T_LoL_Blossom_Leaves.png` or `T_Real_Palia_Leaves.png`)
    with Spherical Normal Transfer:
    - Layer 1 (Inner & Lower Under-Bough Cushion in `bm_shade`): 6 large intersecting/ringed curved
      alpha cards blocking any central gaps and providing deep cool under-shadow.
    - Layer 2 (Mid-Canopy Shingled Shoulder Ring in `bm_lit`): 7 curved alpha cards shingled around
      the perimeter and isometric camera-facing hemisphere.
    - Layer 3 (Upper Sunlit Crown Cap in `bm_lit`): 4 curved dome cards crowning the top of the cloud.
    """
    rng = random.Random(seed)
    uv_lit = bm_lit.loops.layers.uv.active or bm_lit.loops.layers.uv.new("UVMap")
    col_lit = bm_lit.loops.layers.color.active or bm_lit.loops.layers.color.new("Col")
    uv_shd = bm_shade.loops.layers.uv.active or bm_shade.loops.layers.uv.new("UVMap")
    col_shd = bm_shade.loops.layers.color.active or bm_shade.loops.layers.color.new("Col")

    avg_r = 0.5 * (rx + rz)
    rot_off = rng.uniform(0.0, 2.0 * math.pi)

    # 1. Inner & Lower Shadow Core Cards (6 cards in `bm_shade`)
    for i in range(6):
        ang = rot_off + (i / 6.0) * 2.0 * math.pi + rng.uniform(-0.15, 0.15)
        ca, sa = math.cos(ang), math.sin(ang)
        dist_f = 0.25 if (i < 2) else 0.52
        px = cx + ca * rx * dist_f
        pz = cz + sa * rz * dist_f
        py = cy - ry * (0.12 if i < 2 else 0.22)
        pitch = rng.uniform(0.45, 0.72) if i < 2 else rng.uniform(0.22, 0.42)
        add_curved_alpha_leaf_card(
            bm_shade, uv_shd, col_shd,
            px, py, pz, cx, cy - 0.35 * ry, cz,
            width=avg_r * rng.uniform(1.65, 1.90),
            height=ry * rng.uniform(1.55, 1.80),
            yaw_rad=ang, pitch_rad=pitch,
            cell_idx=(seed + i) % 4,
            shade_tint=(0.82, 0.76, 0.88),
            flip_u=(i % 2 == 1)
        )

    # 2. Mid-Crown Shingled Perimeter & Camera-Facing Cards (7 cards in `bm_lit`)
    for i in range(7):
        ang = rot_off + 0.35 + (i / 7.0) * 2.0 * math.pi + rng.uniform(-0.14, 0.14)
        ca, sa = math.cos(ang), math.sin(ang)
        px = cx + ca * rx * 0.58
        pz = cz + sa * rz * 0.58
        py = cy + ry * rng.uniform(0.05, 0.24)
        pitch = rng.uniform(0.48, 0.74)
        add_curved_alpha_leaf_card(
            bm_lit, uv_lit, col_lit,
            px, py, pz, cx, cy - 0.30 * ry, cz,
            width=avg_r * rng.uniform(1.62, 1.88),
            height=ry * rng.uniform(1.52, 1.76),
            yaw_rad=ang, pitch_rad=pitch,
            cell_idx=(seed + i + 1) % 4,
            shade_tint=(0.96, 0.95, 0.98),
            flip_u=(i % 2 == 0)
        )

    # 3. Upper Sunlit Crown Cap Cards (4 cards in `bm_lit`, tilted strongly skyward for isometric camera)
    for i in range(4):
        ang = rot_off + 0.75 + (i / 4.0) * 2.0 * math.pi + rng.uniform(-0.18, 0.18)
        ca, sa = math.cos(ang), math.sin(ang)
        px = cx + ca * rx * 0.28
        pz = cz + sa * rz * 0.28
        py = cy + ry * rng.uniform(0.42, 0.58)
        pitch = rng.uniform(0.84, 1.12)
        add_curved_alpha_leaf_card(
            bm_lit, uv_lit, col_lit,
            px, py, pz, cx, cy - 0.25 * ry, cz,
            width=avg_r * rng.uniform(1.55, 1.80),
            height=ry * rng.uniform(1.45, 1.68),
            yaw_rad=ang, pitch_rad=pitch,
            cell_idx=0 if (i % 2 == 0) else 3,
            shade_tint=(1.04, 1.02, 1.04),
            flip_u=(i % 2 == 1)
        )


def add_chiseled_rift_rock_ledge(
    bm_rock_dark, bm_rock_top, gx, gy, gz, rad_x, rad_z, height,
    rot_y_deg=0.0, seed=99, bm_grass=None, bm_rune=None
):
    rng = random.Random(seed)
    segs = 8
    rot = mathutils.Matrix.Rotation(math.radians(rot_y_deg), 3, "Z")
    c_bot = gpos(gx, gy, gz)
    c_mid = gpos(gx, gy + height * 0.84, gz)
    c_top = gpos(gx, gy + height, gz)

    bot_verts = []
    mid_verts = []
    top_verts = []
    rim_world_pts = []
    for i in range(segs):
        ang = (float(i) / float(segs)) * 2.0 * math.pi + rng.uniform(-0.10, 0.10)
        jit = rng.uniform(0.85, 1.15)
        lx = math.cos(ang) * rad_x * jit
        ly = math.sin(ang) * rad_z * jit
        bot_verts.append(bm_rock_dark.verts.new(c_bot + (rot @ mathutils.Vector((lx * 1.18, ly * 1.18, 0.0)))))
        mid_verts.append(bm_rock_dark.verts.new(c_mid + (rot @ mathutils.Vector((lx * 0.92, ly * 0.92, 0.0)))))
        top_b = bm_rock_top.verts.new(c_mid + (rot @ mathutils.Vector((lx * 0.92, ly * 0.92, 0.0))))
        top_t = bm_rock_top.verts.new(c_top + (rot @ mathutils.Vector((lx * 0.78, ly * 0.78, 0.0))))
        top_verts.append((top_b, top_t))
        wp = c_top + (rot @ mathutils.Vector((lx * 0.72, ly * 0.72, 0.0)))
        rim_world_pts.append((wp.x, wp.z, -wp.y))

    dark_faces = []
    top_faces = []
    for i in range(segs):
        ni = (i + 1) % segs
        dark_faces.append(bm_rock_dark.faces.new((bot_verts[i], bot_verts[ni], mid_verts[ni], mid_verts[i])))
        tb0, tt0 = top_verts[i]
        tb1, tt1 = top_verts[ni]
        top_faces.append(bm_rock_top.faces.new((tb0, tb1, tt1, tt0)))
    top_faces.append(bm_rock_top.faces.new([tv[1] for tv in top_verts]))
    bmesh.ops.recalc_face_normals(bm_rock_dark, faces=dark_faces)
    bmesh.ops.recalc_face_normals(bm_rock_top, faces=top_faces)
    assign_world_uvs(bm_rock_dark, dark_faces, tile_scale=0.24)
    assign_world_uvs(bm_rock_top, top_faces, tile_scale=0.24)

    if bm_grass is not None:
        for rx_p, ry_p, rz_p in rim_world_pts[::2]:
            add_lol_alpha_grass_tuft(bm_grass, rx_p, ry_p - 0.02, rz_p, scale=0.88, seed=seed + int(abs(rx_p * 13)))

    if bm_rune is not None:
        r_ang = math.radians(rot_y_deg)
        fx_n = math.sin(r_ang)
        fz_n = math.cos(r_ang)
        tx_n = math.cos(r_ang)
        tz_n = -math.sin(r_ang)
        face_dist = min(rad_x, rad_z) * 0.96
        rcx = gx + fx_n * face_dist
        rcy = gy + height * 0.48
        rcz = gz + fz_n * face_dist
        spiral_pts = []
        for s_i in range(18):
            t = s_i / 17.0
            a = t * 2.6 * math.pi
            sr = (0.10 + 0.34 * t) * min(1.1, height * 0.85)
            px = rcx + tx_n * (math.cos(a) * sr) + fx_n * 0.04
            py = rcy + math.sin(a) * sr * 0.85
            pz = rcz + tz_n * (math.cos(a) * sr) + fz_n * 0.04
            spiral_pts.append((px, py, pz))
        add_swept_tube(bm_rune, spiral_pts, 0.038, 0.038, sides=5)


def add_cylinder(bm, gx, gy, gz, rad_bot, rad_top, height, segs, rot_y_deg=0.0, tile_scale=0.24):
    ret = bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segs,
        radius1=rad_bot,
        radius2=rad_top,
        depth=height,
    )
    new_verts = ret["verts"]
    new_faces = list({f for v in new_verts for f in v.link_faces})
    rot = mathutils.Matrix.Rotation(math.radians(rot_y_deg), 3, "Z")
    center = gpos(gx, gy + height * 0.5, gz)
    for v in new_verts:
        v.co = center + (rot @ v.co)
    bmesh.ops.recalc_face_normals(bm, faces=new_faces)
    assign_world_uvs(bm, new_faces, tile_scale=tile_scale)


def add_swept_tube(bm, pts_3d, rad_x, rad_y, sides=8, close_loop=False, radii_scale=None, tile_scale=0.24):
    if len(pts_3d) < 2:
        return
    rings = []
    b_pts = [gpos(p[0], p[1], p[2]) for p in pts_3d]
    n_pts = len(b_pts)
    for i, bp in enumerate(b_pts):
        if close_loop:
            tan = (b_pts[(i + 1) % n_pts] - b_pts[(i - 1) % n_pts]).normalized()
        elif i == 0:
            tan = (b_pts[1] - b_pts[0]).normalized()
        elif i == n_pts - 1:
            tan = (b_pts[-1] - b_pts[-2]).normalized()
        else:
            tan = (b_pts[i + 1] - b_pts[i - 1]).normalized()
        up_ref = mathutils.Vector((0.0, 1.0, 0.0))
        if abs(tan.dot(up_ref)) > 0.92:
            up_ref = mathutils.Vector((1.0, 0.0, 0.0))
        n1 = tan.cross(up_ref).normalized()
        n2 = n1.cross(tan).normalized()
        sc = radii_scale[i] if (radii_scale and i < len(radii_scale)) else 1.0
        ring = []
        for s in range(sides):
            ang = (float(s) / float(sides)) * 2.0 * math.pi
            off = n1 * (math.cos(ang) * rad_x * sc) + n2 * (math.sin(ang) * rad_y * sc)
            ring.append(bm.verts.new(bp + off))
        rings.append(ring)

    new_faces = []
    limit = n_pts if close_loop else (n_pts - 1)
    for i in range(limit):
        r0 = rings[i]
        r1 = rings[(i + 1) % n_pts]
        for s in range(sides):
            sn = (s + 1) % sides
            new_faces.append(bm.faces.new((r0[s], r1[s], r1[sn], r0[sn])))
    if not close_loop:
        new_faces.append(bm.faces.new(reversed(rings[0])))
        new_faces.append(bm.faces.new(rings[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=new_faces)
    assign_world_uvs(bm, new_faces, tile_scale=tile_scale)


def add_annulus_sector(bm, cx, cz, r_in, r_out, deg_start, deg_end, segs=12, y_bot=0.0, y_top=0.08, tile_scale=0.22):
    top_in, top_out, bot_in, bot_out = [], [], [], []
    for i in range(segs + 1):
        t = float(i) / float(segs)
        ang = math.radians(deg_start + t * (deg_end - deg_start))
        s_a, c_a = math.sin(ang), math.cos(ang)
        xi, zi = cx + s_a * r_in, cz + c_a * r_in
        xo, zo = cx + s_a * r_out, cz + c_a * r_out
        top_in.append(bm.verts.new(gpos(xi, y_top, zi)))
        top_out.append(bm.verts.new(gpos(xo, y_top, zo)))
        bot_in.append(bm.verts.new(gpos(xi, y_bot, zi)))
        bot_out.append(bm.verts.new(gpos(xo, y_bot, zo)))

    faces = []
    for i in range(segs):
        faces.append(bm.faces.new((top_in[i], top_out[i], top_out[i + 1], top_in[i + 1])))
        faces.append(bm.faces.new((bot_out[i], bot_in[i], bot_in[i + 1], bot_out[i + 1])))
        faces.append(bm.faces.new((bot_in[i], top_in[i], top_in[i + 1], bot_in[i + 1])))
        faces.append(bm.faces.new((top_out[i], bot_out[i], bot_out[i + 1], top_out[i + 1])))
    if abs((deg_end - deg_start) - 360.0) > 0.1:
        faces.append(bm.faces.new((bot_in[0], bot_out[0], top_out[0], top_in[0])))
        faces.append(bm.faces.new((top_in[-1], top_out[-1], bot_out[-1], bot_in[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    assign_world_uvs(bm, faces, tile_scale=tile_scale)


def add_sculpted_foliage_cloud(bm, gx, gy, gz, rx, ry, rz, subdiv=1, seed=42, tile_scale=0.30):
    ret = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    verts = ret["verts"]
    faces = list({f for v in verts for f in v.link_faces})
    center = gpos(gx, gy, gz)
    ph1 = (seed * 1.37) % 6.28
    ph2 = (seed * 2.91) % 6.28
    for v in verts:
        nx, ny, nz = v.co.x, v.co.y, v.co.z
        puff = 1.0 + 0.12 * math.sin(nx * 3.2 + ph1) * math.cos(ny * 3.2 + ph2)
        v.co = center + mathutils.Vector((nx * rx * puff, ny * rz * puff, nz * ry * puff))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    assign_world_uvs(bm, faces, tile_scale=tile_scale)


# ═══════════════════════════════════════════════════════════════════════════
# 7 DISTINCT TREE BODY-SHAPE ARCHETYPES (NO TWO TREES SHARE THE SAME SILHOUETTE!)
# ═══════════════════════════════════════════════════════════════════════════

def add_shimenawa_sacred_stone(bm_stone_body, bm_stone_hi, bm_gold, bm_white, gx, gy, gz, scale=1.0, rot_deg=0.0):
    add_chiseled_block(bm_stone_body, bm_stone_hi, gx, gy, gz, 0.62 * scale, 0.78 * scale, 0.54 * scale, rot_y_deg=rot_deg, bevel_inset=0.72)
    add_cylinder(bm_gold, gx, gy + 0.42 * scale, gz, 0.36 * scale, 0.36 * scale, 0.11 * scale, 10, rot_y_deg=rot_deg)
    for t_i in [-1, 0, 1]:
        ang = math.radians(rot_deg + t_i * 28.0)
        tx = gx + math.sin(ang) * 0.35 * scale
        tz = gz + math.cos(ang) * 0.35 * scale
        add_box(bm_gold if t_i != 0 else bm_white, tx, gy + 0.24 * scale, tz, 0.07 * scale, 0.20 * scale, 0.05 * scale, rot_y_deg=rot_deg, taper_top=0.65)


def add_tree_shape_elder_hollow_shrine(
    bm_stone_body, bm_stone_hi, bm_wood, bm_blossom_lit, bm_blossom_shade,
    bm_grass, bm_iron, bm_gold, bm_flw_white, bm_flw_pink,
    gx, gy, gz, scale=1.0, seed=104
):
    """
    BODY SHAPE 1 (Used ONCE at East Windmill / Apothecary Shrine `(23.2, 0.0, -0.8)`):
    The Ancient Hollow-Root Spirit Blossom Shrine Tree (`1795472939345-download.png` center tree):
    - Stepped mossy chiseled rock ledge base + shimenawa rope-bound stone.
    - 3 arched wishbone root legs straddling a dark hollow root cave (`bm_iron`).
    - Hanging sacred cord with 3 white paper shide talisman streamers under the left bough.
    - Asymmetric 4-bouquet cascading sakura alpha-card canopy.
    """
    rng = random.Random(seed)
    add_chiseled_rift_rock_ledge(bm_stone_body, bm_stone_hi, gx, gy, gz, 2.35 * scale, 1.85 * scale, 0.58 * scale, rot_y_deg=14.0, seed=seed, bm_grass=bm_grass)
    add_chiseled_rift_rock_ledge(bm_stone_body, bm_stone_hi, gx - 1.95 * scale, gy, gz + 0.55 * scale, 1.45 * scale, 1.20 * scale, 0.34 * scale, rot_y_deg=-18.0, seed=seed + 1, bm_grass=bm_grass)
    add_shimenawa_sacred_stone(bm_stone_body, bm_stone_hi, bm_gold, bm_flw_white, gx + 1.65 * scale, gy + 0.42 * scale, gz + 0.75 * scale, scale=0.85 * scale, rot_deg=18.0)

    by = gy + 0.54 * scale
    add_cylinder(bm_iron, gx, by + 0.02, gz + 0.05 * scale, 0.58 * scale, 0.36 * scale, 1.02 * scale, 10)

    waist_x, waist_y, waist_z = gx - 0.18 * scale, by + 1.45 * scale, gz
    for leg_pts in [
        [(gx - 1.12 * scale, by - 0.05, gz + 0.42 * scale), (gx - 0.82 * scale, by + 0.55 * scale, gz + 0.28 * scale), (waist_x, waist_y, waist_z)],
        [(gx + 1.08 * scale, by - 0.05, gz + 0.38 * scale), (gx + 0.78 * scale, by + 0.52 * scale, gz + 0.24 * scale), (waist_x, waist_y, waist_z)],
        [(gx + 0.04 * scale, by - 0.05, gz - 0.92 * scale), (gx + 0.06 * scale, by + 0.60 * scale, gz - 0.54 * scale), (waist_x, waist_y, waist_z)],
    ]:
        add_swept_tube(bm_wood, leg_pts, 0.28 * scale, 0.28 * scale, sides=8, radii_scale=[0.75, 0.95, 1.12])

    for r_i in range(6):
        ang = math.radians(-150.0 + r_i * 58.0 + rng.uniform(-10.0, 10.0))
        dx, dz = math.cos(ang), math.sin(ang)
        t_pts = [
            (gx + dx * 0.65 * scale, by + 0.52 * scale, gz + dz * 0.65 * scale),
            (gx + dx * 1.25 * scale, by + 0.08 * scale, gz + dz * 1.25 * scale),
            (gx + dx * 1.90 * scale, by - 0.18 * scale, gz + dz * 1.90 * scale),
        ]
        add_swept_tube(bm_wood, t_pts, 0.14 * scale, 0.14 * scale, sides=6, radii_scale=[1.0, 0.55, 0.14])

    trunk_pts = [
        (waist_x, waist_y - 0.12 * scale, waist_z),
        (gx - 0.52 * scale, by + 2.25 * scale, gz + 0.10 * scale),
        (gx - 0.70 * scale, by + 3.05 * scale, gz + 0.04 * scale),
        (gx - 0.35 * scale, by + 3.85 * scale, gz - 0.06 * scale),
    ]
    add_swept_tube(bm_wood, trunk_pts, 0.42 * scale, 0.42 * scale, sides=10, radii_scale=[1.15, 0.94, 0.76, 0.54])

    # Left bough + hanging white paper shide talisman streamers
    bough_l = [(gx - 0.62 * scale, by + 2.85 * scale, gz + 0.08 * scale), (gx - 1.75 * scale, by + 2.95 * scale, gz + 0.36 * scale)]
    add_swept_tube(bm_wood, bough_l, 0.19 * scale, 0.19 * scale, sides=7, radii_scale=[1.0, 0.45])
    for t_frac in [0.28, 0.55, 0.82]:
        tx_s = gx - (0.75 + t_frac * 0.85) * scale
        tz_s = gz + (0.12 + t_frac * 0.22) * scale
        ty_s = by + (2.82 - math.sin(t_frac * math.pi) * 0.28) * scale
        add_box(bm_flw_pink, tx_s, ty_s - 0.08 * scale, tz_s, 0.08 * scale, 0.08 * scale, 0.06 * scale)
        add_box(bm_flw_white, tx_s, ty_s - 0.38 * scale, tz_s, 0.11 * scale, 0.32 * scale, 0.04 * scale, taper_top=0.58)

    tx_top, ty_top, tz_top = trunk_pts[-1]
    for dx_b, dy_b, dz_b, rx_b, ry_b, rz_b, s_off in [
        (0.10,  0.85, -0.10, 1.85, 1.35, 1.75, 11),
        (-1.25, 0.15,  0.30, 1.65, 1.20, 1.55, 29),
        (1.15,  0.25,  0.22, 1.55, 1.15, 1.48, 47),
        (-1.85, -0.45, 0.42, 1.25, 0.98, 1.20, 67),
    ]:
        add_alpha_card_canopy_bouquet(
            bm_blossom_lit, bm_blossom_shade,
            tx_top + dx_b * scale, ty_top + dy_b * scale, tz_top + dz_b * scale,
            rx=rx_b * scale, ry=ry_b * scale, rz=rz_b * scale, seed=seed + s_off
        )


def add_tree_shape_windswept_canal_bonsai(
    bm_stone_body, bm_stone_hi, bm_wood, bm_blossom_lit, bm_blossom_shade, bm_grass,
    gx, gy, gz, scale=1.0, seed=102
):
    """
    BODY SHAPE 2 (West Tavern Canal Terrace `(-25.8, 0.0, 10.2)`):
    Low Windswept Horizontal S-Bend Bonsai Tree (completely distinct from Body Shape 1!):
    - Single thick base trunk gripping a low flat rock slab, sweeping sharply horizontally
      toward the canal (`+X = +2.1m`) before rising into 3 separated horizontal floating cloud shelves!
    """
    add_chiseled_rift_rock_ledge(bm_stone_body, bm_stone_hi, gx, gy, gz, 1.85 * scale, 1.65 * scale, 0.36 * scale, rot_y_deg=-22.0, seed=seed, bm_grass=bm_grass)
    by = gy + 0.32 * scale

    # Dramatic horizontal S-sweep trunk leaning out toward the canal (+X)
    trunk_pts = [
        (gx - 0.35 * scale, by - 0.08, gz),
        (gx + 0.45 * scale, by + 0.85 * scale, gz + 0.25 * scale),
        (gx + 1.45 * scale, by + 1.55 * scale, gz + 0.42 * scale),
        (gx + 1.95 * scale, by + 2.45 * scale, gz + 0.20 * scale),
        (gx + 1.25 * scale, by + 3.45 * scale, gz - 0.15 * scale),
    ]
    add_swept_tube(bm_wood, trunk_pts, 0.40 * scale, 0.40 * scale, sides=9, radii_scale=[1.45, 1.05, 0.82, 0.64, 0.44])

    # Secondary lower horizontal bough reaching back-left
    bough_back = [
        (gx + 0.65 * scale, by + 1.05 * scale, gz + 0.28 * scale),
        (gx - 0.65 * scale, by + 1.75 * scale, gz - 0.45 * scale),
        (gx - 1.35 * scale, by + 2.15 * scale, gz - 0.72 * scale),
    ]
    add_swept_tube(bm_wood, bough_back, 0.24 * scale, 0.24 * scale, sides=7, radii_scale=[1.0, 0.68, 0.38])

    # 3 distinct wide, flat-tiered floating horizontal bonsai cloud shelves at staggered heights!
    add_alpha_card_canopy_bouquet(
        bm_blossom_lit, bm_blossom_shade,
        gx - 1.40 * scale, by + 2.45 * scale, gz - 0.75 * scale,
        rx=1.55 * scale, ry=0.88 * scale, rz=1.42 * scale, seed=seed + 13
    )
    add_alpha_card_canopy_bouquet(
        bm_blossom_lit, bm_blossom_shade,
        gx + 2.15 * scale, by + 2.75 * scale, gz + 0.28 * scale,
        rx=1.75 * scale, ry=0.95 * scale, rz=1.58 * scale, seed=seed + 31
    )
    add_alpha_card_canopy_bouquet(
        bm_blossom_lit, bm_blossom_shade,
        gx + 1.15 * scale, by + 3.95 * scale, gz - 0.18 * scale,
        rx=1.92 * scale, ry=1.08 * scale, rz=1.76 * scale, seed=seed + 53
    )


def add_tree_shape_twin_forked_sakura(
    bm_wood, bm_blossom_lit, bm_blossom_shade, bm_grass,
    gx, gy, gz, scale=1.0, seed=112
):
    """
    BODY SHAPE 3 (NW Rift Outskirts `(-15.8, -0.14, -18.8)`):
    Twin V-Forked Diverging Trunks rising from a shared root burl at opposite angles (-38° and +30°),
    holding separated high and low canopy clouds with open sky between the two trunks!
    """
    # Left tall slender trunk
    t_left = [
        (gx, gy - 0.08, gz),
        (gx - 0.55 * scale, gy + 1.25 * scale, gz + 0.18 * scale),
        (gx - 1.35 * scale, gy + 2.75 * scale, gz + 0.38 * scale),
        (gx - 1.75 * scale, gy + 4.15 * scale, gz + 0.45 * scale),
    ]
    add_swept_tube(bm_wood, t_left, 0.34 * scale, 0.34 * scale, sides=8, radii_scale=[1.35, 0.92, 0.68, 0.45])

    # Right shorter wide-leaning trunk
    t_right = [
        (gx + 0.15 * scale, gy - 0.08, gz - 0.10 * scale),
        (gx + 0.78 * scale, gy + 1.05 * scale, gz - 0.28 * scale),
        (gx + 1.65 * scale, gy + 2.15 * scale, gz - 0.48 * scale),
        (gx + 2.15 * scale, gy + 2.85 * scale, gz - 0.55 * scale),
    ]
    add_swept_tube(bm_wood, t_right, 0.28 * scale, 0.28 * scale, sides=8, radii_scale=[1.25, 0.86, 0.62, 0.42])

    for g_i in range(3):
        ang = g_i * 2.1
        add_lol_alpha_grass_tuft(bm_grass, gx + math.cos(ang) * 0.95 * scale, gy, gz + math.sin(ang) * 0.95 * scale, scale=0.92 * scale, seed=seed + g_i)

    # High crown on left trunk + lower twin clouds on right trunk
    add_alpha_card_canopy_bouquet(
        bm_blossom_lit, bm_blossom_shade,
        gx - 1.80 * scale, gy + 4.55 * scale, gz + 0.45 * scale,
        rx=1.95 * scale, ry=1.28 * scale, rz=1.82 * scale, seed=seed + 19
    )
    add_alpha_card_canopy_bouquet(
        bm_blossom_lit, bm_blossom_shade,
        gx + 2.25 * scale, gy + 3.15 * scale, gz - 0.55 * scale,
        rx=1.68 * scale, ry=1.12 * scale, rz=1.55 * scale, seed=seed + 41
    )


def add_tree_shape_twisted_upright_willow_blossom(
    bm_wood, bm_blossom_lit, bm_blossom_shade, bm_grass,
    gx, gy, gz, scale=1.0, seed=117
):
    """
    BODY SHAPE 4 (NE Rift Outskirts `(21.5, -0.14, -23.8)`):
    Tall Corkscrew Upright Trunk branching at the top into a wide 4-pronged Y-crown dome.
    """
    trunk_pts = [
        (gx, gy - 0.08, gz),
        (gx + 0.28 * scale, gy + 1.35 * scale, gz - 0.22 * scale),
        (gx - 0.24 * scale, gy + 2.75 * scale, gz + 0.20 * scale),
        (gx + 0.08 * scale, gy + 4.05 * scale, gz - 0.05 * scale),
    ]
    add_swept_tube(bm_wood, trunk_pts, 0.38 * scale, 0.38 * scale, sides=9, radii_scale=[1.42, 0.95, 0.74, 0.52])
    add_lol_alpha_grass_tuft(bm_grass, gx + 0.75 * scale, gy, gz + 0.45 * scale, scale=0.95 * scale, seed=seed + 3)

    top_x, top_y, top_z = trunk_pts[-1]
    for b_i, (dx_b, dz_b) in enumerate([(-1.35, 0.65), (1.35, 0.65), (0.0, -1.35)]):
        b_pts = [(top_x, top_y - 0.25 * scale, top_z), (top_x + dx_b * scale, top_y + 0.75 * scale, top_z + dz_b * scale)]
        add_swept_tube(bm_wood, b_pts, 0.20 * scale, 0.20 * scale, sides=7, radii_scale=[1.0, 0.45])
        add_alpha_card_canopy_bouquet(
            bm_blossom_lit, bm_blossom_shade,
            top_x + dx_b * 1.05 * scale, top_y + 0.95 * scale, top_z + dz_b * 1.05 * scale,
            rx=1.55 * scale, ry=1.12 * scale, rz=1.48 * scale, seed=seed + 20 + b_i * 17
        )
    add_alpha_card_canopy_bouquet(
        bm_blossom_lit, bm_blossom_shade,
        top_x, top_y + 1.65 * scale, top_z,
        rx=1.85 * scale, ry=1.22 * scale, rz=1.78 * scale, seed=seed + 91
    )


def add_tree_shape_multi_limb_emerald_oak(
    bm_wood, bm_fol_lit, bm_fol_shade, bm_grass,
    gx, gy, gz, scale=1.0, num_limbs=4, lean_angle_deg=35.0, seed=103
):
    """
    BODY SHAPE 5 (Green Summoner's Rift Broadleaf Trees — each instance has a unique limb count,
    lean direction, branch lengths, and alpha-card emerald bouquet proportions!).
    """
    rng = random.Random(seed)
    la = math.radians(lean_angle_deg)
    lx = math.cos(la) * rng.uniform(0.45, 0.85) * scale
    lz = math.sin(la) * rng.uniform(0.45, 0.85) * scale
    trunk_h = rng.uniform(3.0, 3.8) * scale

    trunk_pts = [
        (gx, gy - 0.08, gz),
        (gx + lx * 0.25, gy + trunk_h * 0.35, gz + lz * 0.25),
        (gx + lx * 0.70, gy + trunk_h * 0.72, gz + lz * 0.70),
        (gx + lx, gy + trunk_h, gz + lz),
    ]
    add_swept_tube(bm_wood, trunk_pts, 0.42 * scale, 0.42 * scale, sides=9, radii_scale=[1.42, 0.94, 0.72, 0.52])

    for r_i in range(4):
        ra = la + r_i * 1.57 + rng.uniform(-0.25, 0.25)
        r_pts = [
            (gx + math.cos(ra) * 0.16 * scale, gy + 0.95 * scale, gz + math.sin(ra) * 0.16 * scale),
            (gx + math.cos(ra) * 0.78 * scale, gy + 0.18 * scale, gz + math.sin(ra) * 0.78 * scale),
            (gx + math.cos(ra) * 1.38 * scale, gy - 0.05 * scale, gz + math.sin(ra) * 1.38 * scale),
        ]
        add_swept_tube(bm_wood, r_pts, 0.19 * scale, 0.19 * scale, sides=6, radii_scale=[1.0, 0.58, 0.16])
    add_lol_alpha_grass_tuft(bm_grass, gx + math.cos(la) * 0.85 * scale, gy, gz + math.sin(la) * 0.85 * scale, scale=0.85 * scale, seed=seed + 9)

    top_x, top_y, top_z = trunk_pts[-1]
    base_yaw = rng.uniform(0.0, 2.0 * math.pi)
    for b_i in range(num_limbs):
        ba = base_yaw + (b_i / float(num_limbs)) * 2.0 * math.pi + rng.uniform(-0.28, 0.28)
        b_reach = rng.uniform(1.15, 1.85) * scale
        b_rise = rng.uniform(0.55, 1.35) * scale
        ex = top_x + math.cos(ba) * b_reach
        ey = top_y + b_rise
        ez = top_z + math.sin(ba) * b_reach
        add_swept_tube(bm_wood, [(top_x, top_y - 0.25 * scale, top_z), (ex, ey, ez)], 0.21 * scale, 0.21 * scale, sides=7, radii_scale=[1.0, 0.42])
        add_alpha_card_canopy_bouquet(
            bm_fol_lit, bm_fol_shade,
            ex, ey + 0.25 * scale, ez,
            rx=rng.uniform(1.38, 1.78) * scale,
            ry=rng.uniform(0.95, 1.25) * scale,
            rz=rng.uniform(1.35, 1.72) * scale,
            seed=seed + 30 + b_i * 19
        )


def add_tree_shape_varied_conifer_pine(
    bm_wood, bm_fol_lit, bm_fol_shade, bm_grass,
    gx, gy, gz, scale=1.0, variant_idx=0, seed=108
):
    """
    BODY SHAPES 6 & 7 (Summoner's Rift Conifer / Pine Trees with 4 distinct body silhouettes
    built from tiered drooping Alpha-Cutout Emerald Leaf Cluster Cards + serrated under-boughs!):
    - `variant_idx == 0`: Tall Crooked Mountain Spire (slender, S-curved tall trunk, 6 tiers)
    - `variant_idx == 1`: Wide Squat Old-Growth Forest Cedar (broad spreading lower skirts, 4 wide tiers)
    - `variant_idx == 2`: Twin-Stemmed Forked Fir (two angled conifer spires of unequal height)
    - `variant_idx == 3`: Windswept Leaning Ridge Pine (dramatic side lean with asymmetric bough cards)
    """
    rng = random.Random(seed)
    uv_lit = bm_fol_lit.loops.layers.uv.active or bm_fol_lit.loops.layers.uv.new("UVMap")
    col_lit = bm_fol_lit.loops.layers.color.active or bm_fol_lit.loops.layers.color.new("Col")
    uv_shd = bm_fol_shade.loops.layers.uv.active or bm_fol_shade.loops.layers.uv.new("UVMap")
    col_shd = bm_fol_shade.loops.layers.color.active or bm_fol_shade.loops.layers.color.new("Col")

    def build_single_conifer_spire(sx, sy, sz, sp_scale, width_mult, height_mult, lean_x, lean_z, n_tiers, sp_seed):
        sp_rng = random.Random(sp_seed)
        tot_h = 4.6 * sp_scale * height_mult
        t_pts = [
            (sx, sy - 0.10, sz),
            (sx + lean_x * 0.25, sy + tot_h * 0.35, sz + lean_z * 0.25),
            (sx + lean_x * 0.70, sy + tot_h * 0.72, sz + lean_z * 0.70),
            (sx + lean_x, sy + tot_h * 0.96, sz + lean_z),
        ]
        add_swept_tube(bm_wood, t_pts, 0.32 * sp_scale * width_mult, 0.32 * sp_scale * width_mult, sides=8, radii_scale=[1.38, 0.88, 0.54, 0.22])

        for t_i in range(n_tiers):
            t_frac = float(t_i) / float(max(1, n_tiers - 1))
            ty = sy + (0.65 + t_frac * (3.75 * height_mult)) * sp_scale
            cx_t = sx + lean_x * (t_frac ** 1.25)
            cz_t = sz + lean_z * (t_frac ** 1.25)
            r_tier = (2.15 - t_frac * 1.38) * sp_scale * width_mult
            h_tier = (1.45 - t_frac * 0.45) * sp_scale

            # Number of overlapping curved alpha-cutout bough cards around this conifer tier
            n_cards = max(4, 7 - (t_i // 2))
            rot_tier = t_i * 0.55 + sp_rng.uniform(-0.18, 0.18)
            for c_i in range(n_cards):
                ang = rot_tier + (c_i / float(n_cards)) * 2.0 * math.pi
                ca, sa = math.cos(ang), math.sin(ang)
                px = cx_t + ca * (r_tier * 0.52)
                pz = cz_t + sa * (r_tier * 0.52)
                # Drooping bough pitch (0.52..0.72 rad) so the alpha-cutout leaf tips hang down like pine boughs!
                pitch = 0.54 + t_frac * 0.24
                use_lit = (t_i >= 1 and (c_i % 3 != 0)) or (t_i == n_tiers - 1)
                t_bm = bm_fol_lit if use_lit else bm_fol_shade
                t_uv = uv_lit if use_lit else uv_shd
                t_col = col_lit if use_lit else col_shd
                tint = (0.98, 1.02, 0.92) if use_lit else (0.72, 0.84, 0.78)
                add_curved_alpha_leaf_card(
                    t_bm, t_uv, t_col,
                    px, ty, pz, cx_t, ty - 0.45 * h_tier, cz_t,
                    width=r_tier * 1.35, height=h_tier * 1.28,
                    yaw_rad=ang, pitch_rad=pitch,
                    cell_idx=(sp_seed + t_i + c_i) % 4,
                    shade_tint=tint,
                    flip_u=(c_i % 2 == 1)
                )

    v_kind = variant_idx % 4
    la = rng.uniform(0.0, 2.0 * math.pi)
    if v_kind == 0:
        # Tall Crooked Mountain Spire + 1 small base sprout
        build_single_conifer_spire(gx, gy, gz, scale, width_mult=0.88, height_mult=1.22, lean_x=math.cos(la) * 0.65 * scale, lean_z=math.sin(la) * 0.65 * scale, n_tiers=6, sp_seed=seed)
        build_single_conifer_spire(gx - math.cos(la) * 1.35 * scale, gy, gz - math.sin(la) * 1.35 * scale, scale * 0.52, width_mult=0.95, height_mult=0.95, lean_x=-math.cos(la) * 0.35 * scale, lean_z=-math.sin(la) * 0.35 * scale, n_tiers=4, sp_seed=seed + 31)
    elif v_kind == 1:
        # Wide Squat Old-Growth Forest Cedar
        build_single_conifer_spire(gx, gy, gz, scale, width_mult=1.24, height_mult=0.84, lean_x=math.cos(la) * 0.28 * scale, lean_z=math.sin(la) * 0.28 * scale, n_tiers=5, sp_seed=seed)
    elif v_kind == 2:
        # Twin-Stemmed Forked Fir (two diverging trunks of unequal height)
        build_single_conifer_spire(gx - 0.35 * scale, gy, gz, scale * 0.96, width_mult=0.92, height_mult=1.12, lean_x=-0.75 * scale, lean_z=0.25 * scale, n_tiers=6, sp_seed=seed)
        build_single_conifer_spire(gx + 0.55 * scale, gy, gz + 0.25 * scale, scale * 0.74, width_mult=0.98, height_mult=0.92, lean_x=0.82 * scale, lean_z=-0.30 * scale, n_tiers=5, sp_seed=seed + 47)
    else:
        # Windswept Leaning Ridge Pine + 2 low sub-spires
        build_single_conifer_spire(gx, gy, gz, scale, width_mult=1.02, height_mult=1.05, lean_x=math.cos(la) * 0.92 * scale, lean_z=math.sin(la) * 0.92 * scale, n_tiers=6, sp_seed=seed)
        for s_i in [-1, 1]:
            sa = la + s_i * 2.1
            build_single_conifer_spire(gx + math.cos(sa) * 1.45 * scale, gy, gz + math.sin(sa) * 1.45 * scale, scale * (0.48 if s_i < 0 else 0.58), width_mult=1.0, height_mult=0.90, lean_x=math.cos(sa) * 0.35 * scale, lean_z=math.sin(sa) * 0.35 * scale, n_tiers=4, sp_seed=seed + 60 + s_i)

    for g_i in range(3):
        ga = la + g_i * 2.09
        add_lol_alpha_grass_tuft(bm_grass, gx + math.cos(ga) * 1.45 * scale, gy, gz + math.sin(ga) * 1.45 * scale, scale=0.88 * scale, seed=seed + 90 + g_i)


def add_palia_cypress_tree(bm_wood, bm_fol_lit, bm_fol_shade, bm_grass, gx, gy, gz, scale=1.0, variant_idx=0, seed=202):
    add_tree_shape_varied_conifer_pine(bm_wood, bm_fol_lit, bm_fol_shade, bm_grass, gx, gy, gz, scale=0.66 * scale, variant_idx=variant_idx, seed=seed)


def add_flower_bush_cluster(bm_fol_lit, bm_fol_shade, bm_grass, bm_flw_purple, bm_flw_pink, bm_flw_white, gx, gy, gz, scale=1.0, seed=303):
    rng = random.Random(seed)
    add_alpha_card_canopy_bouquet(
        bm_fol_lit, bm_fol_shade,
        gx, gy + 0.32 * scale, gz,
        rx=0.62 * scale, ry=0.38 * scale, rz=0.60 * scale, seed=seed
    )
    add_lol_alpha_grass_tuft(bm_grass, gx, gy, gz, scale=0.85 * scale, seed=seed + 7)
    for _ in range(3):
        lx = gx + rng.uniform(-0.35, 0.35) * scale
        lz = gz + rng.uniform(-0.35, 0.35) * scale
        add_cylinder(bm_flw_purple, lx, gy + 0.32 * scale, lz, 0.10 * scale, 0.03 * scale, 0.50 * scale, 6)
    for bm_f in (bm_flw_pink, bm_flw_white):
        fx = gx + rng.uniform(-0.38, 0.38) * scale
        fz = gz + rng.uniform(-0.38, 0.38) * scale
        add_sculpted_foliage_cloud(bm_f, fx, gy + 0.42 * scale, fz, 0.20 * scale, 0.16 * scale, 0.20 * scale, subdiv=1, seed=seed + 19)


def add_semicircular_arch(bm_stone, bm_gold, gx, gy_spring, gz, span_z, thickness_x, arch_width=0.42, facing_east=True):
    rad = span_z * 0.5
    segs = 14
    pts = []
    for i in range(segs + 1):
        ang = (float(i) / float(segs)) * math.pi
        cz = gz - math.cos(ang) * rad
        cy = gy_spring + math.sin(ang) * rad
        pts.append((gx, cy, cz))
    add_swept_tube(bm_stone, pts, thickness_x * 0.5, arch_width * 0.5, sides=6)
    add_box(bm_gold, gx + (0.08 if facing_east else -0.08), gy_spring + rad - 0.22, gz, thickness_x + 0.18, 0.56, 0.40)


def add_3d_mullioned_window(bm_glass, bm_iron, bm_gold, gx, gy, gz, height, width_z, with_circle_transom=True):
    add_box(bm_glass, gx, gy, gz, 0.10, height, width_z)
    add_box(bm_iron, gx, gy, gz - width_z * 0.48, 0.16, height, 0.09)
    add_box(bm_iron, gx, gy, gz + width_z * 0.48, 0.16, height, 0.09)
    add_box(bm_iron, gx, gy + height - 0.08, gz, 0.16, 0.09, width_z)
    add_box(bm_iron, gx, gy, gz, 0.16, 0.09, width_z)
    add_box(bm_iron, gx, gy, gz, 0.15, height, 0.07)
    for frac in [0.32, 0.66]:
        add_box(bm_iron, gx, gy + height * frac, gz, 0.15, 0.07, width_z)
        add_box(bm_gold, gx, gy + height * frac + 0.05, gz, 0.16, 0.03, width_z * 0.92)
    if with_circle_transom:
        ring_r = min(width_z * 0.28, height * 0.16)
        ring_cy = gy + height * 0.76
        ring_pts = []
        for i in range(12):
            ang = (float(i) / 12.0) * 2.0 * math.pi
            ring_pts.append((gx, ring_cy + math.sin(ang) * ring_r, gz + math.cos(ang) * ring_r))
        add_swept_tube(bm_iron, ring_pts, 0.04, 0.04, sides=5, close_loop=True)


def add_mansard_roof(bm_roof, bm_gold, gx, gy, gz, sx, sz, h_lower=2.4, h_upper=1.4, overhang=0.55, rot_y_deg=0.0):
    add_box(bm_roof, gx, gy, gz, sx + overhang * 2.0, h_lower, sz + overhang * 2.0, rot_y_deg=rot_y_deg, taper_top=0.80)
    add_box(bm_gold, gx, gy + h_lower - 0.08, gz, (sx + overhang * 2.0) * 0.81, 0.16, (sz + overhang * 2.0) * 0.81, rot_y_deg=rot_y_deg)
    add_box(bm_roof, gx, gy + h_lower + 0.08, gz, (sx + overhang * 2.0) * 0.78, h_upper, (sz + overhang * 2.0) * 0.78, rot_y_deg=rot_y_deg, taper_top=0.55)
    add_box(bm_gold, gx, gy + h_lower + h_upper + 0.05, gz, (sx + overhang * 2.0) * 0.42, 0.28, (sz + overhang * 2.0) * 0.42, rot_y_deg=rot_y_deg)


def add_lol_runeterra_building(
    bm_wall, bm_trim, bm_edge_hi, bm_terra, bm_roof, bm_gold, bm_iron, bm_glass,
    gx, gz, width_x, length_z, stories=3, facing_east=True
):
    sign_x = 1.0 if facing_east else -1.0
    front_x = gx + sign_x * (width_x * 0.5)

    ground_h = 4.8
    story_h = 3.5
    total_wall_h = ground_h + (stories - 1) * story_h

    add_box(bm_wall, gx, 0.0, gz, width_x, total_wall_h, length_z)
    add_box(bm_terra, gx + sign_x * 0.05, ground_h - 0.82, gz, width_x, 0.82, length_z - 0.2)
    add_chiseled_block(bm_trim, bm_edge_hi, gx, 0.0, gz, width_x + 0.42, 1.15, length_z + 0.42)

    num_bays = max(2, int(round(length_z / 4.2)))
    bay_span = length_z / float(num_bays)
    z_start = gz - length_z * 0.5

    for b_i in range(num_bays + 1):
        pz = z_start + b_i * bay_span
        add_box(bm_trim, front_x + sign_x * 0.18, 0.0, pz, 0.54, total_wall_h + 0.2, 0.64)
        for qy in range(0, int(total_wall_h), 2):
            add_chiseled_block(bm_trim, bm_edge_hi, front_x + sign_x * 0.22, float(qy), pz, 0.60, 0.90, 0.72)
        add_box(bm_gold, front_x + sign_x * 0.24, ground_h - 0.30, pz, 0.62, 0.24, 0.76)

    for b_i in range(num_bays):
        bz = z_start + (b_i + 0.5) * bay_span
        arch_span = bay_span - 0.80
        add_3d_mullioned_window(bm_glass, bm_iron, bm_gold, front_x + sign_x * 0.06, 0.25, bz, ground_h - 0.75, arch_span - 0.20, with_circle_transom=True)
        add_semicircular_arch(bm_edge_hi, bm_gold, front_x + sign_x * 0.22, ground_h - 1.45, bz, arch_span, 0.44, arch_width=0.42, facing_east=facing_east)
        add_chiseled_block(bm_trim, bm_edge_hi, front_x + sign_x * 0.48, 0.0, bz, 0.90, 0.26, arch_span * 0.84)

        for st in range(1, stories):
            wy = ground_h + (st - 1) * story_h + 0.60
            wh = story_h - 1.20
            for w_off in [-0.24, 0.24]:
                wz = bz + w_off * bay_span
                ww = bay_span * 0.34
                add_3d_mullioned_window(bm_glass, bm_iron, bm_gold, front_x + sign_x * 0.06, wy, wz, wh, ww, with_circle_transom=False)
                add_chiseled_block(bm_trim, bm_edge_hi, front_x + sign_x * 0.22, wy - 0.18, wz, 0.38, 0.20, ww + 0.26)

    for st in range(1, stories + 1):
        cy = ground_h + (st - 1) * story_h
        add_chiseled_block(bm_trim, bm_edge_hi, gx, cy - 0.14, gz, width_x + 0.68, 0.36, length_z + 0.68)
        add_box(bm_gold, gx, cy + 0.18, gz, width_x + 0.72, 0.12, length_z + 0.72)

    add_mansard_roof(bm_roof, bm_gold, gx, total_wall_h + 0.28, gz, width_x, length_z, h_lower=2.4, h_upper=1.4, overhang=0.60)


def add_domed_rotunda_cathedral(bm_wall, bm_trim, bm_edge_hi, bm_roof, bm_gold, gx, gz, radius=5.6, height=11.5):
    add_cylinder(bm_trim, gx, 0.0, gz, radius + 0.5, radius + 0.35, 1.3, 12, rot_y_deg=15.0)
    add_cylinder(bm_wall, gx, 1.3, gz, radius, radius * 0.96, height - 1.3, 12, rot_y_deg=15.0)
    add_cylinder(bm_edge_hi, gx, 5.4, gz, radius + 0.35, radius + 0.35, 0.42, 12, rot_y_deg=15.0)
    add_cylinder(bm_gold, gx, 5.82, gz, radius + 0.42, radius + 0.42, 0.16, 12, rot_y_deg=15.0)
    add_cylinder(bm_edge_hi, gx, height - 0.3, gz, radius + 0.45, radius + 0.45, 0.45, 12, rot_y_deg=15.0)
    add_cylinder(bm_roof, gx, height + 0.15, gz, radius + 0.35, radius * 0.62, 2.8, 12, rot_y_deg=15.0)
    add_cylinder(bm_gold, gx, height + 2.95, gz, radius * 0.64, radius * 0.60, 0.22, 12, rot_y_deg=15.0)
    add_cylinder(bm_roof, gx, height + 3.17, gz, radius * 0.58, 0.45, 2.2, 12, rot_y_deg=15.0)
    add_cylinder(bm_gold, gx, height + 5.35, gz, 0.48, 0.08, 1.45, 8)
    for i in range(8):
        ang = (float(i) / 8.0) * 2.0 * math.pi + math.radians(22.5)
        px = gx + math.cos(ang) * (radius + 0.15)
        pz = gz + math.sin(ang) * (radius + 0.15)
        add_chiseled_block(bm_trim, bm_edge_hi, px, 0.0, pz, 0.72, height + 0.2, 0.72, rot_y_deg=math.degrees(-ang))


def add_windmill_tower(bm_wall, bm_trim, bm_edge_hi, bm_terracotta, bm_wood, bm_gold, wx=25.5, wz=10.2):
    add_cylinder(bm_trim, wx, 0.0, wz, 2.65, 2.45, 2.2, 12)
    add_cylinder(bm_wall, wx, 2.2, wz, 2.35, 1.95, 6.4, 14)
    for b_i in range(6):
        ang = (float(b_i) / 6.0) * 2.0 * math.pi
        add_box(bm_wood, wx + math.cos(ang) * 2.15, 2.2, wz + math.sin(ang) * 2.15, 0.28, 6.4, 0.28)
    add_cylinder(bm_edge_hi, wx, 8.5, wz, 2.25, 2.25, 0.45, 14)
    add_cylinder(bm_terracotta, wx, 8.95, wz, 2.65, 0.15, 2.2, 14)
    add_cylinder(bm_gold, wx, 11.1, wz, 0.22, 0.05, 0.65, 8)

    hub_x, hub_y, hub_z = wx - 2.15, 7.8, wz
    add_cylinder(bm_wood, hub_x, hub_y - 0.35, hub_z, 0.45, 0.45, 0.70, 10)
    for sail_i in range(6):
        s_ang = math.radians(sail_i * 60.0 + 15.0)
        dy, dz = math.sin(s_ang), math.cos(s_ang)
        spar_pts = [
            (hub_x - 0.2, hub_y + dy * 0.4, hub_z + dz * 0.4),
            (hub_x - 0.5, hub_y + dy * 4.8, hub_z + dz * 4.8),
        ]
        add_swept_tube(bm_wood, spar_pts, 0.11, 0.11, sides=6)
        blade_pts = [
            (hub_x - 0.35, hub_y + dy * 1.4, hub_z + dz * 1.4),
            (hub_x - 0.52, hub_y + dy * 4.6, hub_z + dz * 4.6),
        ]
        add_swept_tube(bm_wall, blade_pts, 0.06, 0.50, sides=4)


def add_canal_footbridge(bm_stone_body, bm_stone_hi, bm_wood, bm_gold, bm_ember, gx, gz, span_x=4.8, width_z=4.2):
    for side in [-1.0, 1.0]:
        add_chiseled_block(bm_stone_body, bm_stone_hi, gx + side * (span_x * 0.46), -0.35, gz, 1.1, 0.55, width_z + 0.6)
    for p_i in range(6):
        px = gx - span_x * 0.42 + p_i * (span_x * 0.84 / 5.0)
        py = 0.04 + 0.06 * math.sin((float(p_i) / 5.0) * math.pi)
        add_box(bm_wood, px, py, gz, (span_x / 6.0) + 0.05, 0.12, width_z)
    for z_side in [-1.0, 1.0]:
        rz = gz + z_side * (width_z * 0.5 + 0.22)
        add_chiseled_block(bm_stone_body, bm_stone_hi, gx, 0.0, rz, span_x + 0.4, 0.82, 0.42)
        add_box(bm_gold, gx, 0.82, rz, span_x + 0.5, 0.08, 0.48)
        for x_post in [-span_x * 0.48, span_x * 0.48]:
            add_chiseled_block(bm_stone_body, bm_stone_hi, gx + x_post, 0.0, rz, 0.58, 1.25, 0.58)
            add_cylinder(bm_ember, gx + x_post, 1.25, rz, 0.16, 0.20, 0.28, 8)


def add_arcane_streetlamp_with_banner(bm_trim, bm_edge_hi, bm_iron, bm_gold, bm_banner, bm_ember, gx, gy, gz, banner_dir_x=1.0):
    add_chiseled_block(bm_trim, bm_edge_hi, gx, gy, gz, 0.68, 0.56, 0.68)
    for pz_off in [-0.14, 0.14]:
        add_cylinder(bm_iron, gx, gy + 0.55, gz + pz_off, 0.065, 0.055, 5.45, 6)
    for cross_y in [1.8, 3.2, 4.6, 5.75]:
        add_box(bm_iron, gx, gy + cross_y, gz, 0.11, 0.08, 0.36)

    spiral_cx = gx + banner_dir_x * 0.58
    spiral_cy = gy + 5.82
    spiral_pts = []
    segs = 24
    for i in range(segs + 1):
        t = float(i) / float(segs)
        ang = t * 2.4 * math.pi
        r = 0.56 * (1.0 - 0.74 * t)
        sx = spiral_cx - banner_dir_x * math.cos(ang) * r
        sy = spiral_cy + math.sin(ang) * r
        spiral_pts.append((sx, sy, gz))
    add_swept_tube(bm_iron, spiral_pts, 0.042, 0.042, sides=6)

    lamp_x = gx + banner_dir_x * 1.15
    add_box(bm_iron, gx + banner_dir_x * 0.58, gy + 5.65, gz, 1.22, 0.08, 0.09)
    add_cylinder(bm_iron, lamp_x, gy + 5.25, gz, 0.38, 0.08, 0.28, 8)
    add_cylinder(bm_ember, lamp_x, gy + 4.92, gz, 0.15, 0.20, 0.32, 8)

    bx = gx + banner_dir_x * 0.72
    add_box(bm_gold, bx, gy + 4.95, gz, 1.26, 0.08, 0.08)

    b_top = gy + 4.92
    b_rect_bot = gy + 2.05
    b_tip_bot = gy + 1.42
    hw = 0.52

    uv_layer = bm_banner.loops.layers.uv.active or bm_banner.loops.layers.uv.new("UVMap")
    u0, u1, v0, v1 = UV_BANNER
    u_mid = 0.5 * (u0 + u1)
    v_shoulder = v0 + 0.18 * (v1 - v0)

    for z_side, flip in [(gz + 0.025, False), (gz - 0.025, True)]:
        v_tl = bm_banner.verts.new(gpos(bx - hw, b_top, z_side))
        v_tr = bm_banner.verts.new(gpos(bx + hw, b_top, z_side))
        v_br = bm_banner.verts.new(gpos(bx + hw, b_rect_bot, z_side))
        v_bl = bm_banner.verts.new(gpos(bx - hw, b_rect_bot, z_side))
        v_tip = bm_banner.verts.new(gpos(bx, b_tip_bot, z_side))

        if not flip:
            f_main = bm_banner.faces.new((v_bl, v_br, v_tr, v_tl))
            f_tip = bm_banner.faces.new((v_tip, v_br, v_bl))
        else:
            f_main = bm_banner.faces.new((v_tl, v_tr, v_br, v_bl))
            f_tip = bm_banner.faces.new((v_bl, v_br, v_tip))

        uv_map = {
            v_tl: (u0, v1),
            v_tr: (u1, v1),
            v_br: (u1, v_shoulder),
            v_bl: (u0, v_shoulder),
            v_tip: (u_mid, v0),
        }
        for f in (f_main, f_tip):
            for loop in f.loops:
                loop[uv_layer].uv = uv_map[loop.vert]


def add_palia_rope_lantern_post(bm_wood, bm_gold, bm_iron, bm_ember, gx, gy, gz, facing_x=1.0, facing_z=0.0):
    add_box(bm_wood, gx, gy, gz, 0.44, 0.44, 0.44)
    add_box(bm_wood, gx, gy + 0.44, gz, 0.32, 4.15, 0.32)
    add_box(bm_wood, gx, gy + 4.59, gz, 0.42, 0.16, 0.42, taper_top=0.75)
    for r_y in [3.75, 3.87, 3.99, 4.11]:
        add_cylinder(bm_gold, gx, gy + r_y, gz, 0.24, 0.24, 0.09, 10)
    bx = gx + facing_x * 0.62
    bz = gz + facing_z * 0.62
    add_box(bm_iron, gx + facing_x * 0.30, gy + 3.95, gz + facing_z * 0.30, 0.68 if abs(facing_x) > 0.5 else 0.10, 0.09, 0.68 if abs(facing_z) > 0.5 else 0.10)
    add_cylinder(bm_iron, bx, gy + 3.77, bz, 0.22, 0.06, 0.18, 10)
    add_sculpted_foliage_cloud(bm_ember, bx, gy + 3.45, bz, 0.24, 0.32, 0.24, subdiv=1, seed=91)


def add_festoon_lantern_string(bm_iron, bm_ember, p0, p1, sag=0.70, num_lanterns=3):
    segs = 12
    cable_pts = []
    for i in range(segs + 1):
        t = float(i) / float(segs)
        x = p0[0] + (p1[0] - p0[0]) * t
        z = p0[2] + (p1[2] - p0[2]) * t
        y = p0[1] + (p1[1] - p0[1]) * t - math.sin(t * math.pi) * sag
        cable_pts.append((x, y, z))
    add_swept_tube(bm_iron, cable_pts, 0.025, 0.025, sides=5)

    for l_i in range(1, num_lanterns + 1):
        t = float(l_i) / float(num_lanterns + 1)
        lx = p0[0] + (p1[0] - p0[0]) * t
        lz = p0[2] + (p1[2] - p0[2]) * t
        ly = p0[1] + (p1[1] - p0[1]) * t - math.sin(t * math.pi) * sag
        add_cylinder(bm_iron, lx, ly - 0.14, lz, 0.18, 0.05, 0.14, 8)
        add_sculpted_foliage_cloud(bm_ember, lx, ly - 0.42, lz, 0.23, 0.31, 0.23, subdiv=1, seed=120 + l_i)


def bake_lol_edge_highlights_and_crevices(bm, top_highlight=1.16, crevice_dark=0.70):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    col_layer = bm.loops.layers.color.active or bm.loops.layers.color.new("Col")
    if not bm.verts:
        return
    min_z = min(v.co.z for v in bm.verts)
    max_z = max(v.co.z for v in bm.verts)
    span_z = max(0.25, max_z - min_z)

    for v in bm.verts:
        l_faces = v.link_faces
        if not l_faces:
            continue
        has_up = any(f.normal.z > 0.45 for f in l_faces)
        has_side = any(abs(f.normal.z) < 0.45 for f in l_faces)
        has_down = any(f.normal.z < -0.35 for f in l_faces)
        h_ratio = max(0.0, min(1.0, (v.co.z - min_z) / span_z))

        shade = 0.86 + 0.16 * h_ratio
        if has_up and has_side:
            shade = max(shade, top_highlight)
        elif has_up and h_ratio > 0.72:
            shade = max(shade, 1.06)

        if has_down and has_side:
            shade = min(shade, crevice_dark + 0.08)
        if v.co.z < 0.14 and has_side and not has_up:
            shade = min(shade, crevice_dark)

        if shade >= 1.0:
            r = min(1.0, shade * 1.00)
            g = min(1.0, shade * 0.98)
            b = min(1.0, shade * 0.94)
        else:
            r = shade * 0.96
            g = shade * 0.95
            b = min(1.0, shade * 1.04)

        for loop in v.link_loops:
            loop[col_layer] = (r, g, b, 1.0)


def make_mesh_object(name, bm, mat, smooth_shading=False, top_hi=1.16, crev_dark=0.70, is_foliage=False):
    if not is_foliage:
        bake_lol_edge_highlights_and_crevices(bm, top_highlight=top_hi, crevice_dark=crev_dark)
    mesh = bpy.data.meshes.new(name + "_Mesh")
    # Preserve custom spherical normals on foliage cards!
    custom_vert_normals = [tuple(v.normal) for v in bm.verts] if is_foliage else None
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.material_index = 0
        p.use_smooth = smooth_shading
    if is_foliage and custom_vert_normals and hasattr(mesh, "normals_split_custom_set_from_vertices"):
        mesh.normals_split_custom_set_from_vertices(custom_vert_normals)
    return obj


def make_mat(name, color=(1, 1, 1, 1), tex_path=None, rough=0.88, metal=0.0, emission=None, emit_str=0.0, is_alpha_clip=False):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    if is_alpha_clip and hasattr(mat, "blend_method"):
        mat.blend_method = "CLIP"
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Base Color"].default_value = color
    if tex_path and os.path.exists(tex_path):
        tn = nodes.new("ShaderNodeTexImage")
        tn.image = bpy.data.images.load(tex_path)
        links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
        if is_alpha_clip and "Alpha" in tn.outputs and "Alpha" in bsdf.inputs:
            links.new(tn.outputs["Alpha"], bsdf.inputs["Alpha"])
    if emission is not None and emit_str > 0.0:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission
            bsdf.inputs["Emission Strength"].default_value = emit_str
    return mat


def build_lorencia_lol_city_v10():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    flagstone_tex = os.path.join(BLENDER_DIR, "T_LoL_Mossy_Flagstones.png")
    weathered_stone_tex = os.path.join(BLENDER_DIR, "T_LoL_Weathered_Stone.png")
    walnut_wood_tex = os.path.join(BLENDER_DIR, "T_LoL_Walnut_Wood.png")
    rift_terrain_tex = os.path.join(BLENDER_DIR, "T_LoL_Rift_Terrain.png")
    roof_tex = os.path.join(BLENDER_DIR, "T_Palia_Terracotta_Roof.png")
    leaves_tex = os.path.join(BLENDER_DIR, "T_Real_Palia_Leaves.png")
    blossom_tex = os.path.join(BLENDER_DIR, "T_LoL_Blossom_Leaves.png")
    grass_tuft_tex = os.path.join(BLENDER_DIR, "T_LoL_Grass_Tuft_Alpha.png")
    metal_tex = os.path.join(BLENDER_DIR, "T_Lorencia_Metal_Trim.png")

    mat_flagstones = make_mat("MI_LoL_Mossy_Flagstones", color=(1.0, 0.99, 0.97, 1.0), tex_path=flagstone_tex, rough=0.90)
    mat_terrain = make_mat("MI_LoL_Rift_Terrain", color=(1.0, 0.99, 0.97, 1.0), tex_path=rift_terrain_tex, rough=0.92)
    mat_stone_body = make_mat("MI_LoL_Stone_Body", color=(0.86, 0.82, 0.76, 1.0), tex_path=weathered_stone_tex)
    mat_stone_wall = make_mat("MI_LoL_Stone_Wall", color=(0.98, 0.94, 0.88, 1.0), tex_path=weathered_stone_tex)
    mat_stone_hi = make_mat("MI_LoL_Stone_Edge_Hi", color=(1.10, 1.06, 0.98, 1.0), tex_path=weathered_stone_tex)
    mat_terracotta = make_mat("MI_LoL_Terracotta", color=(0.96, 0.90, 0.86, 1.0), tex_path=roof_tex)
    mat_roof_slate = make_mat("MI_LoL_Roof_Slate", color=(0.42, 0.50, 0.68, 1.0), tex_path=weathered_stone_tex)
    mat_wood_walnut = make_mat("MI_LoL_Walnut_Wood", color=(1.0, 0.96, 0.92, 1.0), tex_path=walnut_wood_tex)
    mat_iron_verdigris = make_mat("MI_LoL_Wrought_Iron", color=(0.20, 0.28, 0.26, 1.0), rough=0.42, metal=0.35)
    mat_gold_brass = make_mat("MI_LoL_Antique_Gold", color=(0.64, 0.48, 0.22, 1.0), rough=0.44, metal=0.38)
    mat_window_glass = make_mat("MI_LoL_Window_Glass", color=(0.28, 0.44, 0.52, 1.0), rough=0.25)
    mat_banner = make_mat("MI_LoL_Banner", color=(1.0, 0.98, 0.96, 1.0), tex_path=metal_tex, rough=0.80)
    mat_water = make_mat("MI_Lorencia_Water", color=(0.22, 0.78, 0.88, 1.0), rough=0.18, emission=(0.16, 0.68, 0.82, 1.0), emit_str=0.55)
    mat_ember = make_mat("MI_Lorencia_Ember", color=(1.0, 0.74, 0.28, 1.0), rough=0.35, emission=(1.0, 0.62, 0.18, 1.0), emit_str=1.35)
    mat_fol_lit = make_mat("MI_LoL_Foliage_Lit", color=(1.02, 1.05, 0.94, 1.0), tex_path=leaves_tex, is_alpha_clip=True)
    mat_fol_shade = make_mat("MI_LoL_Foliage_Shade", color=(0.74, 0.86, 0.78, 1.0), tex_path=leaves_tex, is_alpha_clip=True)
    mat_blossom_lit = make_mat("MI_LoL_Blossom_Lit", color=(1.00, 0.96, 1.00, 1.0), tex_path=blossom_tex, is_alpha_clip=True)
    mat_blossom_shade = make_mat("MI_LoL_Blossom_Shade", color=(0.78, 0.70, 0.86, 1.0), tex_path=blossom_tex, is_alpha_clip=True)
    mat_grass_cards = make_mat("MI_LoL_Grass_Cards", color=(1.00, 1.02, 0.94, 1.0), tex_path=grass_tuft_tex, is_alpha_clip=True)
    mat_flw_purple = make_mat("MI_Palia_Flowers_Purple", color=(0.58, 0.34, 0.88, 1.0))
    mat_flw_pink = make_mat("MI_Palia_Flowers_Pink", color=(0.94, 0.48, 0.72, 1.0))
    mat_flw_white = make_mat("MI_Palia_Flowers_White", color=(0.98, 0.96, 0.90, 1.0))

    bm_flagstones = bmesh.new()
    bm_terrain = bmesh.new()
    bm_stone_body = bmesh.new()
    bm_stone_wall = bmesh.new()
    bm_stone_hi = bmesh.new()
    bm_terra = bmesh.new()
    bm_roof = bmesh.new()
    bm_wood = bmesh.new()
    bm_iron = bmesh.new()
    bm_gold = bmesh.new()
    bm_glass = bmesh.new()
    bm_banner = bmesh.new()
    bm_water = bmesh.new()
    bm_ember = bmesh.new()
    bm_fol_lit = bmesh.new()
    bm_fol_shade = bmesh.new()
    bm_blossom_lit = bmesh.new()
    bm_blossom_shade = bmesh.new()
    bm_grass = bmesh.new()
    bm_flw_purple = bmesh.new()
    bm_flw_pink = bmesh.new()
    bm_flw_white = bmesh.new()

    # ═══════════════════════════════════════════════════════════════════
    # 1. SEAMLESS SUMMONER'S RIFT TERRAIN & ZERO-OVERLAP LOL STONE TILE FLOORS
    # ═══════════════════════════════════════════════════════════════════
    fx, fz = 0.0, 11.5
    add_box(bm_terrain, 0.0, -0.34, -12.0, 160.0, 0.20, 160.0, tile_scale=0.065)

    add_box(bm_flagstones, 9.8, -0.08, 14.0, 42.4, 0.08, 34.0, tile_scale=0.24)
    add_box(bm_flagstones, -23.7, -0.08, 12.5, 17.4, 0.08, 31.0, tile_scale=0.24)
    add_box(bm_flagstones, 0.0, -0.08, -21.1, 7.6, 0.08, 13.2, tile_scale=0.24)
    add_cylinder(bm_flagstones, 0.0, -0.08, -42.0, 14.2, 14.0, 0.08, 16, rot_y_deg=11.25, tile_scale=0.24)

    ring_pts_outer, ring_pts_inner = [], []
    for i in range(16):
        ang = (float(i) / 16.0) * 2.0 * math.pi
        ring_pts_outer.append((math.cos(ang) * 8.0, 0.03, 11.5 + math.sin(ang) * 8.0))
        ring_pts_inner.append((math.cos(ang) * 4.4, 0.03, 11.5 + math.sin(ang) * 4.4))
    add_swept_tube(bm_stone_hi, ring_pts_outer, 0.36, 0.03, sides=6, close_loop=True)
    add_swept_tube(bm_stone_hi, ring_pts_inner, 0.28, 0.03, sides=6, close_loop=True)
    for spoke_i in range(8):
        ang_deg = float(spoke_i) * 45.0
        ang_rad = math.radians(ang_deg)
        sx_sp = math.sin(ang_rad) * 6.2
        sz_sp = 11.5 + math.cos(ang_rad) * 6.2
        add_box(bm_stone_hi, sx_sp, 0.0, sz_sp, 0.54, 0.03, 3.1, rot_y_deg=ang_deg)

    for g_idx, g_deg in enumerate([45.0, 135.0, 225.0, 315.0]):
        add_annulus_sector(bm_terrain, fx, fz, 8.4, 11.8, g_deg - 20.0, g_deg + 20.0, segs=6, y_bot=0.0, y_top=0.08, tile_scale=0.08)
        add_annulus_sector(bm_stone_body, fx, fz, 8.2, 8.5, g_deg - 21.0, g_deg + 21.0, segs=6, y_bot=0.0, y_top=0.28, tile_scale=0.24)
        add_annulus_sector(bm_stone_body, fx, fz, 11.7, 12.0, g_deg - 21.0, g_deg + 21.0, segs=6, y_bot=0.0, y_top=0.28, tile_scale=0.24)
        ang_r = math.radians(g_deg)
        gx_mid = fx + math.sin(ang_r) * 10.1
        gz_mid = fz + math.cos(ang_r) * 10.1
        add_palia_cypress_tree(bm_wood, bm_fol_lit, bm_fol_shade, bm_grass, gx_mid, 0.08, gz_mid, scale=0.95, variant_idx=g_idx, seed=500 + g_idx)
        for f_off in [-13.0, 13.0]:
            af = math.radians(g_deg + f_off)
            add_flower_bush_cluster(
                bm_fol_lit, bm_fol_shade, bm_grass, bm_flw_purple, bm_flw_pink, bm_flw_white,
                fx + math.sin(af) * 10.0, 0.08, fz + math.cos(af) * 10.0,
                scale=0.92, seed=520 + g_idx * 3 + (1 if f_off > 0 else 0)
            )
        for g_off in [-7.0, 7.0]:
            ag = math.radians(g_deg + g_off)
            add_lol_alpha_grass_tuft(
                bm_grass,
                fx + math.sin(ag) * 9.8, 0.08, fz + math.cos(ag) * 9.8,
                scale=0.92, seed=560 + g_idx * 5 + (1 if g_off > 0 else 0)
            )

    # ═══════════════════════════════════════════════════════════════════
    # 2. WEST AQUEDUCT CANAL & TWIN ARCHED FOOTBRIDGES (x = -13.2)
    # ═══════════════════════════════════════════════════════════════════
    cx_canal = -13.2
    add_box(bm_water, cx_canal, -0.11, 12.5, 3.4, 0.12, 30.5)
    for bank_s in [-1.0, 1.0]:
        bx_c = cx_canal + bank_s * 1.85
        for seg_z, seg_len in [(-0.8, 5.2), (10.5, 6.2), (22.5, 6.2)]:
            add_chiseled_block(bm_stone_body, bm_stone_hi, bx_c, 0.0, seg_z, 0.55, 0.34, seg_len)
    add_canal_footbridge(bm_stone_body, bm_stone_hi, bm_wood, bm_gold, bm_ember, cx_canal, 4.5, span_x=4.8, width_z=4.4)
    add_canal_footbridge(bm_stone_body, bm_stone_hi, bm_wood, bm_gold, bm_ember, cx_canal, 16.5, span_x=4.8, width_z=4.6)

    # ═══════════════════════════════════════════════════════════════════
    # 3. CENTRAL RUNETERRA CHALICE & CRYSTAL FOUNTAIN (0, 0, 11.5)
    # ═══════════════════════════════════════════════════════════════════
    add_cylinder(bm_stone_body, fx, 0.0, fz, 3.90, 3.75, 0.26, 16, rot_y_deg=11.25)
    add_cylinder(bm_stone_wall, fx, 0.26, fz, 3.45, 3.35, 0.36, 16, rot_y_deg=11.25)
    add_cylinder(bm_stone_hi, fx, 0.60, fz, 3.58, 3.52, 0.11, 16, rot_y_deg=11.25)
    add_cylinder(bm_water, fx, 0.48, fz, 3.15, 3.15, 0.12, 16, rot_y_deg=11.25)
    for i in range(8):
        ang = (float(i) / 8.0) * 2.0 * math.pi
        px = fx + math.cos(ang) * 3.42
        pz = fz + math.sin(ang) * 3.42
        add_chiseled_block(bm_stone_body, bm_stone_hi, px, 0.0, pz, 0.52, 0.86, 0.52, rot_y_deg=math.degrees(-ang))

    for b_deg in [45.0, 135.0, 225.0, 315.0]:
        add_annulus_sector(bm_stone_body, fx, fz, 3.88, 4.35, b_deg - 24.0, b_deg + 24.0, segs=6, y_bot=0.0, y_top=0.42, tile_scale=0.24)
        add_annulus_sector(bm_wood, fx, fz, 3.85, 4.42, b_deg - 25.0, b_deg + 25.0, segs=6, y_bot=0.42, y_top=0.50, tile_scale=0.24)

    for leg_i in range(4):
        ang = math.radians(45.0 + leg_i * 90.0)
        dx, dz = math.cos(ang), math.sin(ang)
        leg_pts = [
            (fx + dx * 2.95, 0.18, fz + dz * 2.95),
            (fx + dx * 2.25, 1.30, fz + dz * 2.25),
            (fx + dx * 1.45, 2.35, fz + dz * 1.45),
            (fx + dx * 1.05, 2.75, fz + dz * 1.05),
        ]
        add_swept_tube(bm_stone_hi, leg_pts, 0.36, 0.40, sides=8, radii_scale=[1.12, 0.95, 0.85, 0.75])

    add_cylinder(bm_stone_wall, fx, 0.50, fz, 0.96, 0.72, 1.65, 12)
    add_cylinder(bm_stone_body, fx, 2.15, fz, 1.05, 1.75, 0.55, 12)
    add_cylinder(bm_wood, fx, 2.70, fz, 1.75, 1.95, 0.65, 12)
    add_cylinder(bm_stone_hi, fx, 3.32, fz, 2.02, 1.98, 0.10, 12)
    add_cylinder(bm_water, fx, 3.38, fz, 1.76, 1.76, 0.08, 12)
    for m_i in range(6):
        ang = (float(m_i) / 6.0) * 2.0 * math.pi + 0.35
        add_lol_alpha_grass_tuft(
            bm_grass,
            fx + math.cos(ang) * 1.90, 2.85, fz + math.sin(ang) * 1.90,
            scale=0.68, seed=800 + m_i
        )

    # ═══════════════════════════════════════════════════════════════════
    # 4. DISTRICT 2 (WEST): ARTISAN FORGE FOUNDRY & CANAL-SIDE TAVERN
    # ═══════════════════════════════════════════════════════════════════
    add_lol_runeterra_building(bm_stone_wall, bm_stone_body, bm_stone_hi, bm_terra, bm_roof, bm_gold, bm_iron, bm_glass, -32.8, 3.5, 7.2, 12.2, stories=3, facing_east=True)
    add_domed_rotunda_cathedral(bm_stone_wall, bm_stone_body, bm_stone_hi, bm_roof, bm_gold, -31.8, 17.8, radius=5.8, height=11.8)

    tx, tz = -21.5, 3.8
    for p_i in range(9):
        add_box(bm_wood, tx, 0.08, tz - 3.6 + p_i * 0.92, 8.8, 0.08, 0.84)
    add_box(bm_wood, tx - 0.2, 0.16, tz - 1.1, 5.2, 0.86, 0.86)
    add_box(bm_wood, tx - 0.2, 1.00, tz - 1.1, 5.45, 0.11, 1.02)
    add_box(bm_gold, tx - 0.2, 0.94, tz - 1.1, 5.48, 0.06, 1.04)
    add_box(bm_wood, tx - 2.4, 0.16, tz + 0.7, 0.86, 0.86, 3.2)
    add_box(bm_wood, tx - 2.4, 1.00, tz + 0.7, 1.02, 0.11, 3.35)
    for mx_o in [-1.4, 0.0, 1.3]:
        add_cylinder(bm_ember, tx + mx_o, 1.11, tz - 1.1, 0.12, 0.10, 0.26, 6)
    for kz in [-2.0, -0.3, 1.4]:
        add_cylinder(bm_wood, tx - 3.8, 0.52, tz + kz, 0.46, 0.46, 0.98, 8)
        add_cylinder(bm_gold, tx - 3.8, 0.68, tz + kz, 0.48, 0.48, 0.08, 8)
        add_cylinder(bm_gold, tx - 3.8, 1.14, tz + kz, 0.48, 0.48, 0.08, 8)
    for t_z in [1.0, 3.0]:
        tbx, tbz = tx + 1.6, tz + t_z
        add_box(bm_wood, tbx, 0.16, tbz, 2.2, 0.64, 1.10)
        add_box(bm_wood, tbx, 0.78, tbz, 2.4, 0.09, 1.25)
        add_box(bm_wood, tbx, 0.16, tbz - 0.85, 2.1, 0.42, 0.38)
        add_box(bm_wood, tbx, 0.16, tbz + 0.85, 2.1, 0.42, 0.38)

    sx, sz = -22.5, 16.8
    add_chiseled_block(bm_stone_body, bm_stone_hi, sx - 2.2, 0.08, sz, 2.8, 4.4, 4.2)
    add_cylinder(bm_iron, sx - 2.4, 4.48, sz, 0.82, 0.62, 4.8, 8)
    add_box(bm_ember, sx - 0.85, 0.82, sz, 0.40, 1.30, 2.00)
    add_semicircular_arch(bm_stone_hi, bm_gold, sx - 0.80, 1.65, sz, 2.3, 0.48, arch_width=0.40, facing_east=True)

    ax, az = -17.8, 16.5
    add_cylinder(bm_stone_body, ax, 0.0, az, 0.82, 0.74, 0.16, 8)
    add_cylinder(bm_wood, ax, 0.16, az, 0.54, 0.50, 0.46, 8)
    add_cylinder(bm_gold, ax, 0.40, az, 0.56, 0.56, 0.08, 8)
    add_box(bm_iron, ax, 0.62, az, 0.68, 0.18, 0.94)
    add_box(bm_iron, ax, 0.80, az, 0.52, 0.24, 1.38)
    add_box(bm_iron, ax, 0.88, az + 0.82, 0.32, 0.14, 0.48, taper_top=0.6)
    add_box(bm_ember, ax, 1.04, az - 0.1, 0.24, 0.07, 0.50)

    add_chiseled_block(bm_stone_body, bm_stone_hi, sx + 1.2, 0.08, sz + 2.8, 1.20, 0.70, 2.25)
    add_box(bm_water, sx + 1.2, 0.74, sz + 2.8, 0.90, 0.10, 1.90)
    for wz_r in [-3.0, 3.0]:
        add_box(bm_wood, sx + 0.4, 0.08, sz + wz_r, 2.4, 1.88, 0.34)
        add_box(bm_iron, sx + 0.4, 0.74, sz + wz_r, 2.0, 0.96, 0.14)

    # ═══════════════════════════════════════════════════════════════════
    # 5. DISTRICT 3 (EAST): HIGH-ARCANE APOTHECARY, 6-SAIL WINDMILL & VAULT ROTUNDA
    # ═══════════════════════════════════════════════════════════════════
    for seg_z, seg_len in [(-0.8, 4.4), (10.5, 5.4), (22.2, 4.8)]:
        add_chiseled_block(bm_stone_body, bm_stone_hi, 12.8, 0.0, seg_z, 0.75, 0.45, seg_len)

    add_lol_runeterra_building(bm_stone_wall, bm_stone_body, bm_stone_hi, bm_terra, bm_roof, bm_gold, bm_iron, bm_glass, 31.8, 3.5, 7.2, 12.4, stories=3, facing_east=False)
    add_windmill_tower(bm_stone_wall, bm_stone_body, bm_stone_hi, bm_terra, bm_wood, bm_gold, wx=25.5, wz=10.2)
    add_domed_rotunda_cathedral(bm_stone_wall, bm_stone_body, bm_stone_hi, bm_roof, bm_gold, 30.8, 17.5, radius=6.2, height=12.4)

    mx, mz = 18.2, 4.2
    add_box(bm_wood, mx, 0.08, mz, 1.10, 0.92, 5.8)
    add_box(bm_wood, mx, 0.98, mz, 1.26, 0.11, 6.0)
    add_box(bm_gold, mx, 0.92, mz, 1.30, 0.06, 6.04)
    for pz_c in [-1.9, 0.0, 1.9]:
        add_cylinder(bm_water if pz_c == 0.0 else bm_ember, mx, 1.10, mz + pz_c, 0.24, 0.13, 0.48, 8)

    for cz_o in [-2.8, 0.0, 2.8]:
        add_box(bm_wood, 20.5, 0.08, 16.5 + cz_o, 1.15, 0.85, 1.55)
        add_box(bm_gold, 20.5, 0.50, 16.5 + cz_o, 1.22, 0.18, 1.62)

    # ═══════════════════════════════════════════════════════════════════
    # 6. 18 SPIRAL STREETLAMPS + HERALDIC BANNERS, AND 100% UNIQUE TREE BODY SHAPES
    #    USING REAL DEVOTED STUDIOS RGBA ALPHA-CUTOUT LEAF CLUSTER CARDS!
    # ═══════════════════════════════════════════════════════════════════
    for sx_l, b_dir in [(-16.2, -1.0), (15.5, 1.0), (-9.2, 1.0), (9.2, -1.0)]:
        for lz in [-0.5, 10.5, 21.5]:
            add_arcane_streetlamp_with_banner(bm_stone_body, bm_stone_hi, bm_iron, bm_gold, bm_banner, bm_ember, sx_l, 0.0, lz, banner_dir_x=b_dir)

    add_palia_rope_lantern_post(bm_wood, bm_gold, bm_iron, bm_ember, -17.2, 0.0, 8.2, facing_x=1.0)
    add_palia_rope_lantern_post(bm_wood, bm_gold, bm_iron, bm_ember, -17.2, 0.0, 1.2, facing_x=1.0)
    add_festoon_lantern_string(bm_iron, bm_ember, (-17.2, 4.45, 8.2), (-17.2, 4.45, 1.2), sag=0.60, num_lanterns=3)

    # 1. East Apothecary & Windmill Shrine (23.2, -0.8): BODY SHAPE 1 (Ancient Hollow-Root Shrine Mother Tree)
    add_tree_shape_elder_hollow_shrine(
        bm_stone_body, bm_stone_hi, bm_wood, bm_blossom_lit, bm_blossom_shade,
        bm_grass, bm_iron, bm_gold, bm_flw_white, bm_flw_pink,
        23.2, 0.0, -0.8, scale=0.95, seed=104
    )

    # 2. West Tavern Canal Terrace (-25.8, 10.2): BODY SHAPE 2 (Low Windswept Horizontal S-Bend Bonsai Tree)
    add_tree_shape_windswept_canal_bonsai(
        bm_stone_body, bm_stone_hi, bm_wood, bm_blossom_lit, bm_blossom_shade, bm_grass,
        -25.8, 0.0, 10.2, scale=0.96, seed=102
    )

    # 3. NW Rift Outskirts (-15.8, -18.8): BODY SHAPE 3 (Twin V-Forked Diverging Trunks Sakura)
    add_tree_shape_twin_forked_sakura(
        bm_wood, bm_blossom_lit, bm_blossom_shade, bm_grass,
        -15.8, -0.14, -18.8, scale=1.04, seed=112
    )

    # 4. NE Rift Outskirts (21.5, -23.8): BODY SHAPE 4 (Tall Twisted Upright Willow-Blossom Umbrella)
    add_tree_shape_twisted_upright_willow_blossom(
        bm_wood, bm_blossom_lit, bm_blossom_shade, bm_grass,
        21.5, -0.14, -23.8, scale=1.02, seed=117
    )

    # 5. Green Broadleaf Trees: BODY SHAPE 5 (Each with distinct limb count, lean direction, and rock ledge base!)
    for ox, oy, oz, osc, limbs, lean_deg, oseed in [
        (-25.5, 0.0,  23.5, 1.00, 3,  25.0, 103),
        (16.5,  0.0,  27.5, 1.05, 5, -135.0, 107),
        (-13.5, -0.14, -9.8, 1.08, 4,  60.0, 118),
        (13.5,  -0.14, -9.8, 0.98, 3, -75.0, 119),
    ]:
        if oy >= 0.0:
            add_chiseled_rift_rock_ledge(bm_stone_body, bm_stone_hi, ox, 0.0, oz, 1.75 * osc, 1.55 * osc, 0.36 * osc, rot_y_deg=lean_deg, seed=oseed, bm_grass=bm_grass)
            add_tree_shape_multi_limb_emerald_oak(bm_wood, bm_fol_lit, bm_fol_shade, bm_grass, ox, 0.32 * osc, oz, scale=osc * 0.92, num_limbs=limbs, lean_angle_deg=lean_deg, seed=oseed)
        else:
            add_tree_shape_multi_limb_emerald_oak(bm_wood, bm_fol_lit, bm_fol_shade, bm_grass, ox, oy, oz, scale=osc, num_limbs=limbs, lean_angle_deg=lean_deg, seed=oseed)

    # 6. Summoner's Rift Conifer / Pine Trees: BODY SHAPES 6 & 7 (4 distinct variants: spire, wide cedar, twin-stem fir, leaning ridge pine)
    for px_t, py_t, pz_t, psc, pvar, pseed in [
        (-25.8, 0.0,  -1.5,  1.02, 0, 101),
        (24.8,  0.0,  23.5,  1.05, 1, 105),
        (-16.5, 0.0,  27.5,  1.06, 2, 106),
        (-19.5, -0.14, -7.5, 1.24, 3, 108),
        (19.5,  -0.14, -7.5, 1.22, 0, 109),
        (-28.5, -0.14, -11.5, 1.38, 1, 110),
        (28.5,  -0.14, -11.5, 1.35, 2, 111),
        (16.5,  -0.14, -19.5, 1.28, 3, 113),
        (-22.5, -0.14, -24.5, 1.32, 0, 116),
        (-20.0, -0.14, -31.0, 1.40, 2, 114),
        (20.0,  -0.14, -31.0, 1.38, 1, 115),
    ]:
        if py_t >= 0.0:
            add_chiseled_rift_rock_ledge(bm_stone_body, bm_stone_hi, px_t, 0.0, pz_t, 1.65 * psc, 1.45 * psc, 0.34 * psc, rot_y_deg=pseed * 19.0, seed=pseed, bm_grass=bm_grass)
            add_tree_shape_varied_conifer_pine(bm_wood, bm_fol_lit, bm_fol_shade, bm_grass, px_t, 0.30 * psc, pz_t, scale=psc * 0.92, variant_idx=pvar, seed=pseed)
        else:
            add_tree_shape_varied_conifer_pine(bm_wood, bm_fol_lit, bm_fol_shade, bm_grass, px_t, py_t, pz_t, scale=psc, variant_idx=pvar, seed=pseed)

    # C. Staggered Chiseled Border Stones, Moss-Draped Runic Rock Ledges & Alpha Grass Tufts
    add_staggered_rift_border_stones(bm_stone_body, bm_stone_hi, -28.0, -2.5, -15.5, -2.5, step=1.5, seed=31, bm_grass=bm_grass)
    add_staggered_rift_border_stones(bm_stone_body, bm_stone_hi, 15.5, -2.5, 28.0, -2.5, step=1.5, seed=41, bm_grass=bm_grass)
    add_staggered_rift_border_stones(bm_stone_body, bm_stone_hi, -4.2, -14.8, -4.2, -34.0, step=1.5, seed=51, bm_grass=bm_grass)
    add_staggered_rift_border_stones(bm_stone_body, bm_stone_hi, 4.2, -14.8, 4.2, -34.0, step=1.5, seed=61, bm_grass=bm_grass)

    for rx, rz, rw, rd, rh, rrot, rseed in [
        (-16.5, -6.5, 3.6, 2.5, 1.35, 18.0, 101),
        (16.5, -6.5, 3.6, 2.5, 1.35, -22.0, 102),
        (-10.5, -17.5, 3.3, 2.3, 1.25, 32.0, 103),
        (10.8, -19.2, 3.4, 2.3, 1.28, -28.0, 104),
        (-12.5, -27.5, 3.8, 2.6, 1.45, 14.0, 105),
        (12.8, -28.5, 3.8, 2.6, 1.45, -19.0, 106),
        (-24.5, 28.5, 3.2, 2.2, 0.95, 25.0, 107),
        (24.5, 28.5, 3.2, 2.2, 0.95, -25.0, 108),
    ]:
        add_chiseled_rift_rock_ledge(
            bm_stone_body, bm_stone_hi, rx, -0.14, rz, rw, rd, rh,
            rot_y_deg=rrot, seed=rseed,
            bm_grass=bm_grass, bm_rune=bm_water
        )

    rng_grass = random.Random(888)
    for g_idx, (gx_c, gz_c) in enumerate([
        (-8.5, -5.8), (8.5, -5.8), (-11.8, -12.5), (11.8, -12.5),
        (-7.5, -16.2), (7.5, -16.2), (-8.8, -22.5), (8.8, -22.5),
        (-14.5, -15.0), (14.5, -15.0), (-15.0, -24.0), (15.0, -24.0),
        (-6.8, -31.0), (6.8, -31.0),
    ]):
        add_lol_alpha_grass_tuft(
            bm_grass,
            gx_c + rng_grass.uniform(-0.4, 0.4), -0.14, gz_c + rng_grass.uniform(-0.4, 0.4),
            scale=rng_grass.uniform(1.05, 1.38), seed=900 + g_idx
        )

    # ═══════════════════════════════════════════════════════════════════
    # 7. SOUTH BELVEDERE BALUSTRADE & NORTH TWIN-PYLON VIADUCT BRIDGE
    # ═══════════════════════════════════════════════════════════════════
    for side in [-1.0, 1.0]:
        add_chiseled_block(bm_stone_body, bm_stone_hi, side * 16.0, 0.0, 31.2, 22.0, 1.15, 1.30)
        add_chiseled_block(bm_stone_body, bm_stone_hi, side * 5.0, 0.0, 31.2, 1.75, 1.95, 1.75)

    for side in [-1.0, 1.0]:
        px = side * 6.8
        add_chiseled_block(bm_stone_body, bm_stone_hi, px, 0.0, -3.2, 4.4, 2.0, 4.4)
        add_box(bm_stone_wall, px, 2.0, -3.2, 3.8, 8.4, 3.8)
        add_3d_mullioned_window(bm_glass, bm_iron, bm_gold, px, 3.4, -1.25, 4.4, 1.65, with_circle_transom=True)
        add_chiseled_block(bm_stone_body, bm_stone_hi, px, 10.4, -3.2, 4.2, 0.50, 4.2)
        add_mansard_roof(bm_roof, bm_gold, px, 10.9, -3.2, 3.7, 3.7, h_lower=2.2, h_upper=1.25, overhang=0.50)

        add_chiseled_block(bm_stone_body, bm_stone_hi, side * 20.5, 0.0, -3.2, 23.0, 2.8, 1.65)
        for cx in range(11, 31, 3):
            add_chiseled_block(bm_stone_body, bm_stone_hi, side * float(cx), 2.8, -3.2, 1.45, 0.70, 1.75)

    for pz_plank in range(-4, -15, -1):
        add_box(bm_wood, 0.0, -0.01, float(pz_plank) - 0.3, 7.2, 0.16, 0.88)
    for side in [-1.0, 1.0]:
        add_chiseled_block(bm_stone_body, bm_stone_hi, side * 3.65, 0.0, -9.0, 0.60, 0.52, 11.2)
        add_box(bm_wood, side * 3.65, 0.96, -9.0, 0.36, 0.18, 11.2)
        add_box(bm_gold, side * 3.65, 1.14, -9.0, 0.40, 0.08, 11.2)
        for post_z in [-4.0, -7.3, -10.6, -14.0]:
            add_chiseled_block(bm_stone_body, bm_stone_hi, side * 3.65, 0.0, post_z, 0.70, 1.42, 0.70)
            if post_z in [-4.0, -14.0]:
                add_cylinder(bm_ember, side * 3.65, 1.44, post_z, 0.20, 0.26, 0.36, 8)

    for rz in [-18.0, -25.0, -32.0]:
        for side in [-1.0, 1.0]:
            add_arcane_streetlamp_with_banner(bm_stone_body, bm_stone_hi, bm_iron, bm_gold, bm_banner, bm_ember, side * 5.2, -0.14, rz, banner_dir_x=-side)

    for i in range(12):
        ang = (float(i) / 12.0) * (2.0 * math.pi)
        if math.sin(ang) > 0.65:
            continue
        px = math.cos(ang) * 14.0
        pz = -42.0 + math.sin(ang) * 14.0
        h_pil = 6.6 if (i % 2 == 0) else 4.6
        add_cylinder(bm_stone_body, px, -0.14, pz, 0.95, 0.78, h_pil, 10)
        add_cylinder(bm_stone_hi, px, h_pil - 0.14, pz, 1.12, 1.05, 0.45, 10)
        if i % 2 == 0:
            bx = math.cos(ang) * 12.0
            bz = -42.0 + math.sin(ang) * 12.0
            add_cylinder(bm_stone_body, bx, -0.14, bz, 0.50, 0.38, 1.45, 8)
            add_cylinder(bm_gold, bx, 1.31, bz, 0.38, 0.64, 0.44, 8)
            add_cylinder(bm_ember, bx, 1.66, bz, 0.46, 0.26, 0.28, 8)

    add_chiseled_block(bm_stone_body, bm_stone_hi, 0.0, -0.14, -54.5, 12.5, 0.80, 4.4)
    add_cylinder(bm_stone_body, -4.6, 0.66, -54.8, 1.15, 0.95, 8.2, 10)
    add_cylinder(bm_stone_body, 4.6, 0.66, -54.8, 1.15, 0.95, 8.2, 10)
    add_chiseled_block(bm_stone_body, bm_stone_hi, 0.0, 8.86, -54.8, 11.6, 1.75, 1.95)

    make_mesh_object("Lorencia_Mossy_Flagstones", bm_flagstones, mat_flagstones, smooth_shading=False, top_hi=1.06, crev_dark=0.90)
    make_mesh_object("Lorencia_Rift_Terrain", bm_terrain, mat_terrain, smooth_shading=False, top_hi=1.04, crev_dark=0.92)
    make_mesh_object("Lorencia_Stone_Body", bm_stone_body, mat_stone_body, smooth_shading=False)
    make_mesh_object("Lorencia_Stone_Wall", bm_stone_wall, mat_stone_wall, smooth_shading=False)
    make_mesh_object("Lorencia_Stone_Edge_Hi", bm_stone_hi, mat_stone_hi, smooth_shading=False)
    make_mesh_object("Lorencia_Terracotta", bm_terra, mat_terracotta, smooth_shading=False)
    make_mesh_object("Lorencia_Mansard_Roofs", bm_roof, mat_roof_slate, smooth_shading=False)
    make_mesh_object("Lorencia_Walnut_Wood", bm_wood, mat_wood_walnut, smooth_shading=True)
    make_mesh_object("Lorencia_Wrought_Iron", bm_iron, mat_iron_verdigris, smooth_shading=True)
    make_mesh_object("Lorencia_Gold_Brass", bm_gold, mat_gold_brass, smooth_shading=False)
    make_mesh_object("Lorencia_Window_Glass", bm_glass, mat_window_glass, smooth_shading=False)
    make_mesh_object("Lorencia_Banners", bm_banner, mat_banner, smooth_shading=False, top_hi=1.06, crev_dark=0.94)
    make_mesh_object("Lorencia_Water", bm_water, mat_water, smooth_shading=True, top_hi=1.0, crev_dark=1.0)
    make_mesh_object("Lorencia_Embers", bm_ember, mat_ember, smooth_shading=True, top_hi=1.0, crev_dark=1.0)
    make_mesh_object("Lorencia_Foliage_Lit", bm_fol_lit, mat_fol_lit, smooth_shading=True, is_foliage=True)
    make_mesh_object("Lorencia_Foliage_Shade", bm_fol_shade, mat_fol_shade, smooth_shading=True, is_foliage=True)
    make_mesh_object("Lorencia_Foliage_Blossom_Lit", bm_blossom_lit, mat_blossom_lit, smooth_shading=True, is_foliage=True)
    make_mesh_object("Lorencia_Foliage_Blossom_Shade", bm_blossom_shade, mat_blossom_shade, smooth_shading=True, is_foliage=True)
    make_mesh_object("Lorencia_Foliage_Grass_Cards", bm_grass, mat_grass_cards, smooth_shading=True, is_foliage=True)
    make_mesh_object("Lorencia_Flowers_Purple", bm_flw_purple, mat_flw_purple, smooth_shading=True)
    make_mesh_object("Lorencia_Flowers_Pink", bm_flw_pink, mat_flw_pink, smooth_shading=True)
    make_mesh_object("Lorencia_Flowers_White", bm_flw_white, mat_flw_white, smooth_shading=True)

    for img in list(bpy.data.images):
        if img.source == "FILE":
            ap = bpy.path.abspath(img.filepath)
            if os.path.exists(ap):
                img.pack()
    blend_path = os.path.join(BLENDER_DIR, "Lorencia_Town.blend")
    glb_path = os.path.join(OUT_GLB_DIR, "Lorencia_Town.glb")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        export_apply=True,
        export_materials="EXPORT",
    )
    print("Exported LoL / Spirit Blossom Alpha-Card Lorencia City v10:", blend_path, "->", glb_path)


build_lorencia_lol_city_v10()
