import os
import sys
import math
import random
import bpy
import bmesh
import mathutils

# ═══════════════════════════════════════════════════════════════════════════
# LEAGUE OF LEGENDS / SUMMONER'S RIFT & SPIRIT BLOSSOM CITY (v9.5)
# Exact Riot Games / Devoted Studios Spirit Blossom Tree Diorama (`1795472939345-download.png`):
# 1. Deep, Asymmetric Multi-Tiered Spirit Blossom Canopy (`add_lol_spirit_blossom_diorama`):
#    - Smooth high-subdivision rounded canopy cloud lobes (`subdiv = 3` icosphere domes,
#      ZERO radial umbrella spokes!) stacked in a cascading 3-tier waterfall silhouette
#      (tall rounded upper crown, wide diagonal mid-cascade shoulders, low drooping left/right
#      bough puffs).
#    - Shingled 3D Feathered Sakura Leaf-Cluster Fans (`add_lol_3d_feathered_leaf_fan`)
#      layered across the crown, mid-cascade, and hanging lower hem so real 3D pointed sakura
#      leaf clusters break the silhouette contour just like `1795472939345-download.png`!
#    - Correct Blender->glTF UV orientation (`UV.v = 0.92` at top sunlit crown -> `UV.v = 0.08`
#      at hanging lower plum leaf tips) sampling the real Devoted Studios leaf crop!
# 2. Arched Hollow-Root Cave Trunk, 7 Sinuous Snaking Root Tendrils, Mossy Bark Streaks,
#    Hanging White Paper Shide Talisman Streamers, Stepped Mossy Rock Outcrop Base,
#    Flanking Companion Blossom Trees, and Sacred Shimenawa Rope-Bound Stones!
# ═══════════════════════════════════════════════════════════════════════════

PROJECT_DIR = "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel"
BLENDER_DIR = os.path.join(PROJECT_DIR, "blender")
OUT_GLB_DIR = os.path.join(PROJECT_DIR, "addons/lorencia_town")

os.makedirs(BLENDER_DIR, exist_ok=True)
os.makedirs(OUT_GLB_DIR, exist_ok=True)

UV_BANNER = (0.51, 0.75, 0.02, 0.98)


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


def add_staggered_rift_border_stones(bm_body, bm_edge_hi, x0, z0, x1, z1, step=1.55, seed=42, bm_fol_lit=None, bm_fol_shade=None):
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
        if bm_fol_lit is not None and bm_fol_shade is not None and (i % 2 == 0):
            gx_t = cx + rng.uniform(-0.45, 0.45)
            gz_t = cz + rng.uniform(-0.45, 0.45)
            add_lol_grass_tuft_cluster(bm_fol_lit, bm_fol_shade, gx_t, -0.02, gz_t, scale=0.85, n_blades=6, seed=seed + i * 7)


def add_lol_grass_tuft_cluster(bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=1.0, n_blades=7, seed=303):
    """
    3D Hand-Painted League of Legends Grass-Blade Tuft Cluster:
     Note Blender UV.v convention: v = 0.88 samples top of texture (dark viridian root tuck),
    v = 0.08 samples bottom of texture (warm sunlit chartreuse blade tip)!
    """
    rng = random.Random(seed)
    uv_lit = bm_fol_lit.loops.layers.uv.active or bm_fol_lit.loops.layers.uv.new("UVMap")
    uv_shd = bm_fol_shade.loops.layers.uv.active or bm_fol_shade.loops.layers.uv.new("UVMap")

    new_lit_faces = []
    new_shd_faces = []

    for b_i in range(n_blades):
        ang = (float(b_i) / float(n_blades)) * 2.0 * math.pi + rng.uniform(-0.26, 0.26)
        ca, sa = math.cos(ang), math.sin(ang)
        px, pz = -sa, ca

        r_off = rng.uniform(0.05, 0.24) * scale
        bx0 = gx + ca * r_off
        bz0 = gz + sa * r_off
        by0 = gy

        b_h = rng.uniform(0.42, 0.78) * scale
        b_w = rng.uniform(0.11, 0.17) * scale
        arch = rng.uniform(0.26, 0.52) * scale

        bm_target = bm_fol_lit if (b_i % 3 != 0) else bm_fol_shade
        uv_layer = uv_lit if (b_i % 3 != 0) else uv_shd
        face_list = new_lit_faces if (b_i % 3 != 0) else new_shd_faces

        v_bl = bm_target.verts.new(gpos(bx0 - px * b_w, by0, bz0 - pz * b_w))
        v_br = bm_target.verts.new(gpos(bx0 + px * b_w, by0, bz0 + pz * b_w))

        mx = bx0 + ca * (arch * 0.45)
        mz = bz0 + sa * (arch * 0.45)
        my = by0 + b_h * 0.54
        mw = b_w * 0.72
        v_ml = bm_target.verts.new(gpos(mx - px * mw, my, mz - pz * mw))
        v_mr = bm_target.verts.new(gpos(mx + px * mw, my, mz + pz * mw))

        tx = bx0 + ca * arch
        tz = bz0 + sa * arch
        ty = by0 + b_h
        v_tip = bm_target.verts.new(gpos(tx, ty, tz))

        f1 = bm_target.faces.new((v_bl, v_br, v_mr, v_ml))
        f2 = bm_target.faces.new((v_ml, v_mr, v_tip))
        face_list.extend([f1, f2])

        uv_map = {
            v_bl: (0.35, 0.88),
            v_br: (0.65, 0.88),
            v_ml: (0.38, 0.48),
            v_mr: (0.62, 0.48),
            v_tip: (0.50, 0.08),
        }
        for f in (f1, f2):
            for loop in f.loops:
                loop[uv_layer].uv = uv_map[loop.vert]

    if new_lit_faces:
        bmesh.ops.recalc_face_normals(bm_fol_lit, faces=new_lit_faces)
    if new_shd_faces:
        bmesh.ops.recalc_face_normals(bm_fol_shade, faces=new_shd_faces)


def add_chiseled_rift_rock_ledge(
    bm_rock_dark, bm_rock_top, gx, gy, gz, rad_x, rad_z, height,
    rot_y_deg=0.0, seed=99, bm_fol_lit=None, bm_fol_shade=None, bm_rune=None
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
        wp = c_top + (rot @ mathutils.Vector((lx * 0.80, ly * 0.80, 0.0)))
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

    if bm_fol_lit is not None and bm_fol_shade is not None:
        add_lol_serrated_cone_skirt(
            bm_fol_lit, bm_fol_shade,
            gx, gy + height - 0.04, gz,
            r_outer_x=rad_x * 0.82, r_outer_z=rad_z * 0.82,
            r_inner_ratio=0.72, h_cone=0.26, tip_drop=0.24,
            n_tips=8, rot_deg=rot_y_deg, seed=seed + 31
        )
        for rx_p, ry_p, rz_p in rim_world_pts[::2]:
            add_lol_grass_tuft_cluster(bm_fol_lit, bm_fol_shade, rx_p, ry_p - 0.04, rz_p, scale=0.88, n_blades=6, seed=seed + int(abs(rx_p * 13)))

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


def add_lol_serrated_cone_skirt(
    bm_outer, bm_under_shade, cx, cy_base, cz,
    r_outer_x, r_outer_z, r_inner_ratio=0.58, h_cone=1.35, tip_drop=0.38,
    n_tips=7, apex_lean_x=0.0, apex_lean_z=0.0, rot_deg=0.0, seed=42
):
    """
    Summoner's Rift Layered Pine Bough Skirt (`Captura de Tela 2026-11-23 às 19.03.45.png`):
    Note Blender UV.v convention: v = 0.90 is TOP of PNG (shadow tuck under upper bough),
    v = 0.08 is BOTTOM of PNG (warm sunlit chartreuse hanging tip)!
    """
    rng = random.Random(seed)
    total_pts = n_tips * 2
    rot_rad = math.radians(rot_deg)

    uv_out = bm_outer.loops.layers.uv.active or bm_outer.loops.layers.uv.new("UVMap")
    uv_shd = bm_under_shade.loops.layers.uv.active or bm_under_shade.loops.layers.uv.new("UVMap")

    v_apex = bm_outer.verts.new(gpos(cx + apex_lean_x, cy_base + h_cone, cz + apex_lean_z))
    v_under_center = bm_under_shade.verts.new(gpos(cx + apex_lean_x * 0.25, cy_base + h_cone * 0.32, cz + apex_lean_z * 0.25))

    mid_verts = []
    rim_out_verts = []
    rim_shd_verts = []
    rim_uvs = []
    mid_uvs = []

    for k in range(total_pts):
        is_tip = (k % 2 == 0)
        frac = float(k) / float(total_pts)
        ang = frac * 2.0 * math.pi + rot_rad + rng.uniform(-0.06, 0.06)
        ca, sa = math.cos(ang), math.sin(ang)

        jit_r = rng.uniform(0.90, 1.12)
        jit_y = rng.uniform(0.86, 1.16)

        if is_tip:
            rx = r_outer_x * jit_r
            rz = r_outer_z * jit_r
            ry = cy_base - tip_drop * jit_y
        else:
            rx = r_outer_x * r_inner_ratio * jit_r
            rz = r_outer_z * r_inner_ratio * jit_r
            ry = cy_base + tip_drop * 0.58 * jit_y

        m_ratio = 0.48 if is_tip else 0.40
        mx = cx + apex_lean_x * 0.50 + ca * (r_outer_x * m_ratio * jit_r)
        mz = cz + apex_lean_z * 0.50 + sa * (r_outer_z * m_ratio * jit_r)
        my = cy_base + h_cone * (0.46 if is_tip else 0.54)

        wx = cx + ca * rx
        wz = cz + sa * rz

        mid_verts.append(bm_outer.verts.new(gpos(mx, my, mz)))
        rim_out_verts.append(bm_outer.verts.new(gpos(wx, ry, wz)))
        rim_shd_verts.append(bm_under_shade.verts.new(gpos(wx * 0.94 + cx * 0.06, ry + 0.03, wz * 0.94 + cz * 0.06)))

        u_coord = float(k) / float(total_pts)
        mid_uvs.append((u_coord, 0.55))
        rim_uvs.append((u_coord, 0.06 if is_tip else 0.36))

    out_faces = []
    shd_faces = []
    for k in range(total_pts):
        nk = (k + 1) % total_pts
        u0 = mid_uvs[k][0]
        u1 = 1.0 if nk == 0 else mid_uvs[nk][0]

        f_top = bm_outer.faces.new((mid_verts[k], mid_verts[nk], v_apex))
        f_skirt = bm_outer.faces.new((rim_out_verts[k], rim_out_verts[nk], mid_verts[nk], mid_verts[k]))
        out_faces.extend([f_top, f_skirt])

        f_top.loops[0][uv_out].uv = (u0, 0.55)
        f_top.loops[1][uv_out].uv = (u1, 0.55)
        f_top.loops[2][uv_out].uv = (0.5 * (u0 + u1), 0.90)

        f_skirt.loops[0][uv_out].uv = (u0, rim_uvs[k][1])
        f_skirt.loops[1][uv_out].uv = (u1, rim_uvs[nk][1])
        f_skirt.loops[2][uv_out].uv = (u1, 0.55)
        f_skirt.loops[3][uv_out].uv = (u0, 0.55)

        f_under = bm_under_shade.faces.new((rim_shd_verts[nk], rim_shd_verts[k], v_under_center))
        shd_faces.append(f_under)
        for loop in f_under.loops:
            loop[uv_shd].uv = (0.5, 0.92)

    bmesh.ops.recalc_face_normals(bm_outer, faces=out_faces)
    bmesh.ops.recalc_face_normals(bm_under_shade, faces=shd_faces)


def add_lol_rift_pine_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=1.0, seed=101):
    rng = random.Random(seed)
    lean_x = rng.uniform(-0.35, 0.35) * scale
    lean_z = rng.uniform(-0.35, 0.35) * scale
    if abs(lean_x) < 0.14 * scale:
        lean_x = 0.24 * scale

    trunk_pts = [
        (gx, gy - 0.10, gz),
        (gx + lean_x * 0.25, gy + 0.85 * scale, gz + lean_z * 0.25),
        (gx + lean_x * 0.60, gy + 2.20 * scale, gz + lean_z * 0.60),
    ]
    add_swept_tube(bm_wood, trunk_pts, 0.34 * scale, 0.34 * scale, sides=8, radii_scale=[1.35, 0.85, 0.45])

    tiers = [
        (0.45, 2.35, 0.56, 1.55, 0.44, 8, False),
        (1.05, 2.08, 0.56, 1.50, 0.42, 8, True),
        (1.68, 1.78, 0.55, 1.45, 0.38, 7, False),
        (2.32, 1.46, 0.55, 1.40, 0.35, 7, True),
        (2.96, 1.12, 0.54, 1.35, 0.30, 6, True),
        (3.58, 0.76, 0.52, 1.55, 0.26, 6, True),
    ]
    for idx, (ty, r_out, r_in_rat, h_c, t_drop, n_t, use_lit) in enumerate(tiers):
        t_frac = idx / float(len(tiers) - 1)
        cx = gx + lean_x * (t_frac ** 1.3)
        cz = gz + lean_z * (t_frac ** 1.3)
        hook_mult = 0.85 if idx == len(tiers) - 1 else 0.42
        ap_x = lean_x * hook_mult * (0.4 + t_frac)
        ap_z = lean_z * hook_mult * (0.4 + t_frac)
        outer_bm = bm_fol_lit if use_lit else bm_fol_shade
        add_lol_serrated_cone_skirt(
            outer_bm, bm_fol_shade,
            cx, gy + ty * scale, cz,
            r_outer_x=r_out * scale, r_outer_z=r_out * scale,
            r_inner_ratio=r_in_rat, h_cone=h_c * scale, tip_drop=t_drop * scale,
            n_tips=n_t, apex_lean_x=ap_x, apex_lean_z=ap_z,
            rot_deg=idx * 25.0 + rng.uniform(-8.0, 8.0),
            seed=seed + idx * 17
        )

    num_sub = 2 if scale < 1.05 else 3
    base_ang = rng.uniform(0.0, 2.0 * math.pi)
    for s_i in range(num_sub):
        s_ang = base_ang + s_i * (2.0 * math.pi / float(num_sub)) + rng.uniform(-0.35, 0.35)
        dist = rng.uniform(1.40, 1.92) * scale
        sx = gx + math.cos(s_ang) * dist
        sz = gz + math.sin(s_ang) * dist
        sub_sc = rng.uniform(0.48, 0.64) * scale
        sub_lean_x = math.cos(s_ang) * 0.32 * sub_sc
        sub_lean_z = math.sin(s_ang) * 0.32 * sub_sc
        for st_idx, (sty, sr_out, sh_c, st_drop, sn_t, s_lit) in enumerate([
            (0.25, 1.72, 1.25, 0.32, 7, False),
            (0.85, 1.36, 1.22, 0.28, 6, True),
            (1.45, 0.96, 1.22, 0.24, 6, True),
            (2.02, 0.58, 1.32, 0.20, 5, True),
        ]):
            add_lol_serrated_cone_skirt(
                bm_fol_lit if s_lit else bm_fol_shade, bm_fol_shade,
                sx + sub_lean_x * (st_idx * 0.3), gy + sty * sub_sc, sz + sub_lean_z * (st_idx * 0.3),
                r_outer_x=sr_out * sub_sc, r_outer_z=sr_out * sub_sc,
                r_inner_ratio=0.56, h_cone=sh_c * sub_sc, tip_drop=st_drop * sub_sc,
                n_tips=sn_t, apex_lean_x=sub_lean_x * 0.55, apex_lean_z=sub_lean_z * 0.55,
                rot_deg=st_idx * 27.0, seed=seed + 200 + s_i * 31 + st_idx
            )

    for g_i in range(4):
        ga = base_ang + g_i * 1.57 + 0.4
        add_lol_grass_tuft_cluster(
            bm_fol_lit, bm_fol_shade,
            gx + math.cos(ga) * 1.75 * scale, gy, gz + math.sin(ga) * 1.75 * scale,
            scale=0.88 * scale, n_blades=7, seed=seed + 400 + g_i
        )


def add_lol_3d_feathered_leaf_fan(bm, uv_layer, cx, cy, cz, dir_x, dir_z, width=0.85, length=0.78, droop=0.52, uv_v_top=0.72, uv_v_bot=0.22):
    """
    3D Curved 3-Point Feathered Sakura Leaf-Cluster Shell (`1795472939345-download.png`):
    Builds a cupped, drooping fan of 3 pointed leaf clusters that juts out from the canopy
    surface and droops downward so the tree silhouette has real 3D jagged sakura leaf tips
    around the crown, mid-tiers, and hanging hem — with ZERO radial umbrella creases!
    """
    tx, tz = -dir_z, dir_x  # horizontal tangent perpendicular to outward direction
    # Top root points anchored inside the canopy lobe
    v_r0 = bm.verts.new(gpos(cx - tx * width * 0.38, cy, cz - tz * width * 0.38))
    v_r1 = bm.verts.new(gpos(cx, cy + 0.06 * length, cz))
    v_r2 = bm.verts.new(gpos(cx + tx * width * 0.38, cy, cz + tz * width * 0.38))

    # Mid-belly swell curving outward and slightly down
    mx = cx + dir_x * (length * 0.55)
    mz = cz + dir_z * (length * 0.55)
    my = cy - droop * 0.35
    v_m0 = bm.verts.new(gpos(mx - tx * width * 0.54, my - 0.04, mz - tz * width * 0.54))
    v_m1 = bm.verts.new(gpos(mx - tx * width * 0.16, my + 0.05, mz - tz * width * 0.16))
    v_m2 = bm.verts.new(gpos(mx + tx * width * 0.16, my + 0.05, mz + tz * width * 0.16))
    v_m3 = bm.verts.new(gpos(mx + tx * width * 0.54, my - 0.04, mz + tz * width * 0.54))

    # 3 distinct pointed sakura leaf tips hanging down at the outer rim + 2 recessed V-notches
    ox = cx + dir_x * length
    oz = cz + dir_z * length
    oy = cy - droop
    v_t0 = bm.verts.new(gpos(ox - tx * width * 0.44, oy - 0.04 * length, oz - tz * width * 0.44))
    v_n0 = bm.verts.new(gpos(cx + dir_x * (length * 0.72) - tx * width * 0.20, cy - droop * 0.58, cz + dir_z * (length * 0.72) - tz * width * 0.20))
    v_t1 = bm.verts.new(gpos(ox + dir_x * (0.12 * length), oy - 0.12 * length, oz + dir_z * (0.12 * length)))
    v_n1 = bm.verts.new(gpos(cx + dir_x * (length * 0.72) + tx * width * 0.20, cy - droop * 0.58, cz + dir_z * (length * 0.72) + tz * width * 0.20))
    v_t2 = bm.verts.new(gpos(ox + tx * width * 0.44, oy - 0.04 * length, oz + tz * width * 0.44))

    uv_v_mid = 0.5 * (uv_v_top + uv_v_bot)
    uv_v_notch = uv_v_bot + 0.35 * (uv_v_top - uv_v_bot)

    faces = [
        bm.faces.new((v_m0, v_m1, v_r1, v_r0)),
        bm.faces.new((v_m1, v_m2, v_r1)),
        bm.faces.new((v_m2, v_m3, v_r2, v_r1)),
        bm.faces.new((v_t0, v_n0, v_m1, v_m0)),
        bm.faces.new((v_n0, v_t1, v_m2, v_m1)),
        bm.faces.new((v_t1, v_n1, v_m2)),
        bm.faces.new((v_n1, v_t2, v_m3, v_m2)),
    ]
    uv_map = {
        v_r0: (0.20, uv_v_top),
        v_r1: (0.50, uv_v_top),
        v_r2: (0.80, uv_v_top),
        v_m0: (0.15, uv_v_mid),
        v_m1: (0.38, uv_v_mid),
        v_m2: (0.62, uv_v_mid),
        v_m3: (0.85, uv_v_mid),
        v_t0: (0.18, uv_v_bot),
        v_n0: (0.35, uv_v_notch),
        v_t1: (0.50, max(0.04, uv_v_bot - 0.05)),
        v_n1: (0.65, uv_v_notch),
        v_t2: (0.82, uv_v_bot),
    }
    for f in faces:
        for loop in f.loops:
            loop[uv_layer].uv = uv_map[loop.vert]
    return faces


def add_lol_sculpted_blossom_lobe(bm_lit, bm_shade, cx, cy, cz, rx, ry, rz, uv_v_min=0.18, uv_v_max=0.92, seed=42):
    """
    Smooth, High-Subdivision Sculpted Blossom Lobe + Shingled 3D Feathered Leaf Fans
    (matching the Devoted Studios Spirit Blossom reference `1795472939345-download.png`):
    1. Builds an isotropic `subdiv = 3` sculpted icosphere cloud dome (ZERO radial umbrella spokes!)
       with a plump rounded top and undercut lower shadow belly.
    2. Shingles 3 concentric rings of 3D curved 3-tip feathered sakura leaf fans (`add_lol_3d_feathered_leaf_fan`)
       around the upper shoulder, equator, and drooping lower hem so real 3D pointed sakura leaf clusters
       jut out around the entire silhouette and across the canopy face!
    """
    rng = random.Random(seed)
    uv_lit = bm_lit.loops.layers.uv.active or bm_lit.loops.layers.uv.new("UVMap")
    uv_shd = bm_shade.loops.layers.uv.active or bm_shade.loops.layers.uv.new("UVMap")

    # 1. Smooth isotropic subdiv=3 icosphere volume (split into upper lit dome & lower shade belly)
    temp_bm = bmesh.new()
    bmesh.ops.create_icosphere(temp_bm, subdivisions=3, radius=1.0)
    ph1 = (seed * 1.31) % 6.28
    ph2 = (seed * 2.73) % 6.28

    vert_map_lit = {}
    vert_map_shd = {}
    lit_faces = []
    shd_faces = []

    def get_sculpted_co_and_uv(v):
        nx, ny, nz = v.co.x, v.co.y, v.co.z
        # Soft organic leaf-pillow undulations (no radial spokes!)
        puff = (
            1.0
            + 0.10 * math.sin(nx * 3.4 + ph1) * math.cos(ny * 3.4 + ph2)
            + 0.06 * math.cos(nz * 4.2 - nx * 2.8)
        )
        # Plump rounded upper dome, gently tucked lower underside
        z_shape = (1.02 if nz >= 0.0 else 0.72)
        # Flared skirt around the lower equator (-0.45 < nz < 0.15)
        eq_flare = 1.0 + 0.12 * max(0.0, 1.0 - abs(nz + 0.12) * 2.4)
        wx = cx + nx * rx * puff * eq_flare
        wz = cz - ny * rz * puff * eq_flare
        wy = cy + nz * ry * puff * z_shape
        # Seamless horizontal UV.u from mirrored angle, vertical UV.v from top (uv_v_max) to bottom (uv_v_min)
        ang = math.atan2(ny, nx)  # -pi..pi
        u_wrap = abs(ang) / math.pi  # 0..1->0 mirror wrap = 100% seamless with zero atan2 seam!
        h_t = max(0.0, min(1.0, (nz + 0.85) / 1.85))
        v_coord = uv_v_min + h_t * (uv_v_max - uv_v_min)
        return gpos(wx, wy, wz), (u_wrap, v_coord)

    for f in temp_bm.faces:
        avg_nz = sum(v.co.z for v in f.verts) / 3.0
        is_lit_face = (avg_nz >= -0.22)
        target_bm = bm_lit if is_lit_face else bm_shade
        target_uv = uv_lit if is_lit_face else uv_shd
        v_map = vert_map_lit if is_lit_face else vert_map_shd
        f_list = lit_faces if is_lit_face else shd_faces

        new_f_verts = []
        new_f_uvs = []
        for v in f.verts:
            co, uv_c = get_sculpted_co_and_uv(v)
            if v.index not in v_map:
                v_map[v.index] = target_bm.verts.new(co)
            new_f_verts.append(v_map[v.index])
            new_f_uvs.append(uv_c)
        nf = target_bm.faces.new(new_f_verts)
        for loop, uv_c in zip(nf.loops, new_f_uvs):
            loop[target_uv].uv = uv_c
        f_list.append(nf)

    temp_bm.free()

    # 2. Shingle 3 concentric rings of 3D Feathered Sakura Leaf Fans over the dome & silhouette rim!
    ring_configs = [
        # (n_fans, lat_z, rad_mult, fan_w, fan_len, fan_droop, v_top, v_bot, use_lit)
        (8,  0.48, 0.72, 0.72, 0.56, 0.36, min(0.95, uv_v_max), 0.52, True),
        (11, 0.12, 0.94, 0.82, 0.66, 0.48, 0.72, 0.30, True),
        (13, -0.24, 0.96, 0.86, 0.72, 0.58, 0.48, max(0.06, uv_v_min - 0.06), False),
    ]
    avg_r = 0.5 * (rx + rz)
    for r_i, (n_fans, lat_z, r_mult, fw, flen, fdrp, vt, vb, use_lit) in enumerate(ring_configs):
        t_bm = bm_lit if use_lit else bm_shade
        t_uv = uv_lit if use_lit else uv_shd
        f_list = lit_faces if use_lit else shd_faces
        for k in range(n_fans):
            ang = ((k + (0.5 if r_i % 2 else 0.0)) / float(n_fans)) * 2.0 * math.pi + rng.uniform(-0.10, 0.10)
            ca, sa = math.cos(ang), math.sin(ang)
            fx = cx + ca * rx * r_mult
            fz = cz + sa * rz * r_mult
            fy = cy + lat_z * ry + rng.uniform(-0.06, 0.06) * ry
            sc_f = (avg_r / 1.65) * rng.uniform(0.90, 1.12)
            f_list.extend(
                add_lol_3d_feathered_leaf_fan(
                    t_bm, t_uv,
                    fx, fy, fz, ca, sa,
                    width=fw * sc_f, length=flen * sc_f, droop=fdrp * sc_f,
                    uv_v_top=vt, uv_v_bot=vb
                )
            )

    if lit_faces:
        bmesh.ops.recalc_face_normals(bm_lit, faces=lit_faces)
    if shd_faces:
        bmesh.ops.recalc_face_normals(bm_shade, faces=shd_faces)


def add_shimenawa_sacred_stone(bm_stone_body, bm_stone_hi, bm_gold, bm_white, gx, gy, gz, scale=1.0, rot_deg=0.0):
    """
    Sacred Shimenawa Rope-Bound Boundary Stone at the base of the Spirit Blossom tree
    (matching the two rope-wrapped stones on the left and right of `1795472939345-download.png`).
    """
    add_chiseled_block(bm_stone_body, bm_stone_hi, gx, gy, gz, 0.62 * scale, 0.78 * scale, 0.54 * scale, rot_y_deg=rot_deg, bevel_inset=0.72)
    # Thick golden-straw shimenawa rope belt around the stone waist
    add_cylinder(bm_gold, gx, gy + 0.42 * scale, gz, 0.36 * scale, 0.36 * scale, 0.11 * scale, 10, rot_y_deg=rot_deg)
    # 3 hanging straw/paper tassels on the front of the rope belt
    for t_i in [-1, 0, 1]:
        ang = math.radians(rot_deg + t_i * 28.0)
        tx = gx + math.sin(ang) * 0.35 * scale
        tz = gz + math.cos(ang) * 0.35 * scale
        add_box(bm_gold if t_i != 0 else bm_white, tx, gy + 0.24 * scale, tz, 0.07 * scale, 0.20 * scale, 0.05 * scale, rot_y_deg=rot_deg, taper_top=0.65)


def add_single_spirit_blossom_tree_body(
    bm_wood, bm_blossom_lit, bm_blossom_shade, bm_fol_lit, bm_fol_shade,
    bm_iron, bm_flw_white, bm_flw_pink,
    gx, gy, gz, scale=1.0, lean_dir_x=-1.0, with_hollow_cave=True, with_shide=True, seed=101
):
    """
    Builds one complete Riot Games / Devoted Studios Spirit Blossom Tree (`1795472939345-download.png`):
    - When `with_hollow_cave=True` (the central mother tree):
      - High arched wishbone root legs straddling a dark recessed hollow cave (`bm_iron`) at ground level.
      - 7 long sinuous surface root tendrils snaking out over the rock ledges (`1.6m..2.3m`),
        with 3D mossy green strips (`bm_fol_shade`) running along the upper root ridges.
      - Muscular S-curved trunk leaning left-then-up into 4 sweeping boughs.
      - Hanging sacred cord with 3 dangling white paper shide talismans (`bm_flw_white` + `bm_flw_pink`)
        under the left bough!
      - Deep, asymmetric 6-lobe cascading feathered sakura canopy (`add_lol_sculpted_blossom_lobe`):
        high rounded top crown (`UV.v = 0.55..0.95`), broad diagonal mid-cascade shoulders (`UV.v = 0.25..0.75`),
        and low drooping left/right feather skirts (`UV.v = 0.08..0.52`).
    """
    rng = random.Random(seed)
    lx = lean_dir_x

    if with_hollow_cave:
        # 1. Dark recessed hollow cave dome underneath the wishbone root arch (`RGB(42,34,39)` in reference!)
        add_cylinder(bm_iron, gx, gy + 0.02, gz + 0.05 * scale, 0.62 * scale, 0.38 * scale, 1.05 * scale, 10)

        # 2. Three massive arched wishbone root buttress legs meeting at the trunk waist (y = 1.48 * scale)
        waist_x = gx + lx * 0.18 * scale
        waist_y = gy + 1.48 * scale
        waist_z = gz
        arch_legs = [
            # Left front root arch leg
            [
                (gx - 1.15 * scale, gy - 0.05, gz + 0.45 * scale),
                (gx - 0.88 * scale, gy + 0.55 * scale, gz + 0.32 * scale),
                (gx - 0.52 * scale, gy + 1.12 * scale, gz + 0.15 * scale),
                (waist_x, waist_y, waist_z),
            ],
            # Right front root arch leg
            [
                (gx + 1.10 * scale, gy - 0.05, gz + 0.42 * scale),
                (gx + 0.82 * scale, gy + 0.52 * scale, gz + 0.28 * scale),
                (gx + 0.44 * scale, gy + 1.08 * scale, gz + 0.14 * scale),
                (waist_x, waist_y, waist_z),
            ],
            # Back support root arch leg
            [
                (gx + 0.05 * scale, gy - 0.05, gz - 0.95 * scale),
                (gx + 0.08 * scale, gy + 0.62 * scale, gz - 0.58 * scale),
                (waist_x, waist_y, waist_z),
            ],
        ]
        for leg_pts in arch_legs:
            add_swept_tube(bm_wood, leg_pts, 0.30 * scale, 0.30 * scale, sides=8, radii_scale=[0.75, 0.95, 1.05, 1.15])
            # Mossy green streak hugging the top ridge of the root arch (`1795472939345-download.png`)
            moss_pts = [(p[0], p[1] + 0.08 * scale, p[2]) for p in leg_pts[:3]]
            add_swept_tube(bm_fol_shade, moss_pts, 0.12 * scale, 0.06 * scale, sides=6, radii_scale=[0.6, 1.0, 0.7])

        # 3. 7 long sinuous snaking surface root tendrils curling down over the rock steps
        for r_i in range(7):
            ang = math.radians(-155.0 + r_i * 52.0 + rng.uniform(-10.0, 10.0))
            dx, dz = math.cos(ang), math.sin(ang)
            px_t, pz_t = -dz, dx
            s_curve = (0.28 if (r_i % 2 == 0) else -0.28) * scale
            tendril_pts = [
                (gx + dx * 0.68 * scale, gy + 0.58 * scale, gz + dz * 0.68 * scale),
                (gx + dx * 1.15 * scale + px_t * s_curve * 0.6, gy + 0.14 * scale, gz + dz * 1.15 * scale + pz_t * s_curve * 0.6),
                (gx + dx * 1.62 * scale - px_t * s_curve * 0.5, gy - 0.04 * scale, gz + dz * 1.62 * scale - pz_t * s_curve * 0.5),
                (gx + dx * 2.05 * scale + px_t * s_curve * 0.3, gy - 0.22 * scale, gz + dz * 2.05 * scale + pz_t * s_curve * 0.3),
            ]
            add_swept_tube(bm_wood, tendril_pts, 0.15 * scale, 0.15 * scale, sides=7, radii_scale=[1.0, 0.68, 0.36, 0.12])

        # 4. S-Curved Muscular Upper Trunk leaning left then curving up to crown fork
        trunk_pts = [
            (waist_x, waist_y - 0.15 * scale, waist_z),
            (gx + lx * 0.48 * scale, gy + 2.25 * scale, gz + 0.12 * scale),
            (gx + lx * 0.72 * scale, gy + 3.05 * scale, gz + 0.05 * scale),
            (gx + lx * 0.42 * scale, gy + 3.85 * scale, gz - 0.08 * scale),
        ]
        add_swept_tube(bm_wood, trunk_pts, 0.44 * scale, 0.44 * scale, sides=10, radii_scale=[1.18, 0.96, 0.78, 0.56])
    else:
        # Smaller flanking companion Spirit Blossom tree trunk (curved S-bend with surface root flare)
        trunk_pts = [
            (gx, gy - 0.08, gz),
            (gx + lx * 0.32 * scale, gy + 0.95 * scale, gz + 0.10 * scale),
            (gx + lx * 0.68 * scale, gy + 1.95 * scale, gz + 0.05 * scale),
            (gx + lx * 0.52 * scale, gy + 2.75 * scale, gz - 0.05 * scale),
        ]
        add_swept_tube(bm_wood, trunk_pts, 0.32 * scale, 0.32 * scale, sides=9, radii_scale=[1.38, 0.92, 0.72, 0.50])
        for r_i in range(4):
            ang = math.radians(r_i * 90.0 + 25.0)
            dx, dz = math.cos(ang), math.sin(ang)
            r_pts = [
                (gx + dx * 0.15 * scale, gy + 0.75 * scale, gz + dz * 0.15 * scale),
                (gx + dx * 0.68 * scale, gy + 0.12 * scale, gz + dz * 0.68 * scale),
                (gx + dx * 1.25 * scale, gy - 0.06 * scale, gz + dz * 1.25 * scale),
            ]
            add_swept_tube(bm_wood, r_pts, 0.16 * scale, 0.16 * scale, sides=6, radii_scale=[1.0, 0.55, 0.16])

    top_x, top_y, top_z = trunk_pts[-1]

    # 5. Hanging Sacred Cord & 3 White Paper Shide Talisman Streamers under the left bough (`1795472939345-download.png`)
    if with_shide:
        bough_left_pts = [
            (gx + lx * 0.62 * scale, gy + 2.85 * scale, gz + 0.08 * scale),
            (gx + lx * 1.35 * scale, gy + 3.05 * scale, gz + 0.28 * scale),
            (gx + lx * 1.95 * scale, gy + 2.90 * scale, gz + 0.42 * scale),
        ]
        add_swept_tube(bm_wood, bough_left_pts, 0.20 * scale, 0.20 * scale, sides=7, radii_scale=[1.0, 0.72, 0.42])

        cord_p0 = (gx + lx * 0.72 * scale, gy + 2.82 * scale, gz + 0.14 * scale)
        cord_p1 = (gx + lx * 1.58 * scale, gy + 2.94 * scale, gz + 0.34 * scale)
        cord_pts = []
        for c_i in range(9):
            t = c_i / 8.0
            cx_c = cord_p0[0] + (cord_p1[0] - cord_p0[0]) * t
            cz_c = cord_p0[2] + (cord_p1[2] - cord_p0[2]) * t
            cy_c = cord_p0[1] + (cord_p1[1] - cord_p0[1]) * t - math.sin(t * math.pi) * 0.34 * scale
            cord_pts.append((cx_c, cy_c, cz_c))
        add_swept_tube(bm_iron, cord_pts, 0.022 * scale, 0.022 * scale, sides=5)

        for t_frac in [0.25, 0.52, 0.78]:
            tx_s = cord_p0[0] + (cord_p1[0] - cord_p0[0]) * t_frac
            tz_s = cord_p0[2] + (cord_p1[2] - cord_p0[2]) * t_frac
            ty_s = cord_p0[1] + (cord_p1[1] - cord_p0[1]) * t_frac - math.sin(t_frac * math.pi) * 0.34 * scale
            # Crimson/pink knot tie + white folded paper shide streamer
            add_box(bm_flw_pink, tx_s, ty_s - 0.08 * scale, tz_s, 0.08 * scale, 0.08 * scale, 0.06 * scale)
            add_box(bm_flw_white, tx_s, ty_s - 0.40 * scale, tz_s, 0.11 * scale, 0.34 * scale, 0.04 * scale, taper_top=0.58)

    # 6. Deep, Asymmetric Multi-Tiered Cascading Sakura Canopy Lobes (exact match to `1795472939345-download.png`!)
    if with_hollow_cave:
        # 6 overlapping sculpted blossom lobes forming the deep waterfall crown + left/right cascading skirts
        canopy_lobes = [
            # (dx, dy_from_top, dz, rx, ry, rz, uv_v_min, uv_v_max, seed_off)
            # Tier 1: High Rounded Top Crown (warm dusty rose-mauve top leaves: UV.v = 0.55..0.95)
            (0.05,  0.95, -0.10, 1.95, 1.38, 1.82, 0.54, 0.95, 11),
            # Tier 2: Upper-Left & Upper-Right Cascading Shoulder Lobes (mid sakura-orchid leaves: UV.v = 0.28..0.78)
            (lx * 1.15, 0.25,  0.30, 1.78, 1.26, 1.65, 0.30, 0.78, 23),
            (-lx * 1.05, 0.32, 0.22, 1.68, 1.22, 1.58, 0.32, 0.80, 37),
            (0.00,  0.35, -0.78, 1.75, 1.24, 1.52, 0.30, 0.76, 49),
            # Tier 3: Low Drooping Left & Right Feather Skirts (rich orchid to dusky plum: UV.v = 0.08..0.52)
            (lx * 1.88, -0.45, 0.42, 1.38, 1.08, 1.32, 0.08, 0.52, 61),
            (-lx * 1.65, -0.28, 0.35, 1.32, 1.04, 1.26, 0.10, 0.54, 73),
        ]
    else:
        # Twin-lobed cascading crown for the flanking companion blossom trees (`1795472939345-download.png` left & right trees)
        canopy_lobes = [
            (0.00, 0.55, 0.00, 1.55, 1.12, 1.48, 0.45, 0.94, 17),
            (lx * 0.95, -0.05, 0.25, 1.32, 0.98, 1.26, 0.12, 0.65, 31),
        ]

    for dx_l, dy_l, dz_l, rx_l, ry_l, rz_l, vmin, vmax, s_off in canopy_lobes:
        add_lol_sculpted_blossom_lobe(
            bm_blossom_lit, bm_blossom_shade,
            top_x + dx_l * scale, top_y + dy_l * scale, top_z + dz_l * scale,
            rx=rx_l * scale, ry=ry_l * scale, rz=rz_l * scale,
            uv_v_min=vmin, uv_v_max=vmax, seed=seed + s_off
        )


def add_lol_spirit_blossom_diorama(
    bm_stone_body, bm_stone_hi, bm_wood, bm_blossom_lit, bm_blossom_shade,
    bm_fol_lit, bm_fol_shade, bm_iron, bm_gold, bm_flw_white, bm_flw_pink,
    gx, gy, gz, scale=1.0, seed=101
):
    """
    Complete Riot Games / Devoted Studios Spirit Blossom Tree Diorama (`1795472939345-download.png`):
    1. Stepped, mossy chiseled gray-slate rock outcrop base (NO square brick planter box!).
    2. Central S-curved mother Spirit Blossom tree with open hollow root cave, 7 snaking root tendrils,
       mossy root knees, hanging white paper shide talismans, and 6-lobe cascading feathered sakura canopy.
    3. Flanking smaller companion Spirit Blossom trees on the stepped left/right rock wings.
    4. Two sacred shimenawa rope-bound boundary stones & 3D mossy grass tufts tucked into the rock seams.
    """
    # 1. Stepped chiseled mossy rock outcrop base (center terrace + left stepped wing + right stepped wing)
    add_chiseled_rift_rock_ledge(
        bm_stone_body, bm_stone_hi, gx, gy, gz,
        rad_x=2.35 * scale, rad_z=1.85 * scale, height=0.62 * scale,
        rot_y_deg=12.0, seed=seed + 1, bm_fol_lit=bm_fol_lit, bm_fol_shade=bm_fol_shade
    )
    add_chiseled_rift_rock_ledge(
        bm_stone_body, bm_stone_hi, gx - 2.15 * scale, gy, gz + 0.55 * scale,
        rad_x=1.65 * scale, rad_z=1.35 * scale, height=0.38 * scale,
        rot_y_deg=-18.0, seed=seed + 2, bm_fol_lit=bm_fol_lit, bm_fol_shade=bm_fol_shade
    )
    add_chiseled_rift_rock_ledge(
        bm_stone_body, bm_stone_hi, gx + 2.05 * scale, gy, gz - 0.35 * scale,
        rad_x=1.75 * scale, rad_z=1.40 * scale, height=0.48 * scale,
        rot_y_deg=24.0, seed=seed + 3, bm_fol_lit=bm_fol_lit, bm_fol_shade=bm_fol_shade
    )

    # 2. Central Mother Spirit Blossom Tree with hollow root cave & hanging shide talismans
    add_single_spirit_blossom_tree_body(
        bm_wood, bm_blossom_lit, bm_blossom_shade, bm_fol_lit, bm_fol_shade,
        bm_iron, bm_flw_white, bm_flw_pink,
        gx, gy + 0.58 * scale, gz, scale=scale * 0.96,
        lean_dir_x=-1.0, with_hollow_cave=True, with_shide=True, seed=seed + 10
    )

    # 3. Left & Right Flanking Companion Spirit Blossom Trees (`1795472939345-download.png`)
    add_single_spirit_blossom_tree_body(
        bm_wood, bm_blossom_lit, bm_blossom_shade, bm_fol_lit, bm_fol_shade,
        bm_iron, bm_flw_white, bm_flw_pink,
        gx - 2.35 * scale, gy + 0.34 * scale, gz + 0.65 * scale,
        scale=scale * 0.54, lean_dir_x=-1.0, with_hollow_cave=False, with_shide=False, seed=seed + 40
    )
    add_single_spirit_blossom_tree_body(
        bm_wood, bm_blossom_lit, bm_blossom_shade, bm_fol_lit, bm_fol_shade,
        bm_iron, bm_flw_white, bm_flw_pink,
        gx + 2.15 * scale, gy + 0.44 * scale, gz - 0.25 * scale,
        scale=scale * 0.62, lean_dir_x=1.0, with_hollow_cave=False, with_shide=False, seed=seed + 70
    )

    # 4. Sacred Shimenawa Rope-Bound Stones on the left & right rock ledges (`1795472939345-download.png`)
    add_shimenawa_sacred_stone(
        bm_stone_body, bm_stone_hi, bm_gold, bm_flw_white,
        gx - 1.65 * scale, gy + 0.35 * scale, gz + 1.05 * scale,
        scale=0.82 * scale, rot_deg=-15.0
    )
    add_shimenawa_sacred_stone(
        bm_stone_body, bm_stone_hi, bm_gold, bm_flw_white,
        gx + 1.75 * scale, gy + 0.45 * scale, gz + 0.72 * scale,
        scale=0.88 * scale, rot_deg=18.0
    )


def add_lol_handpainted_canopy_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=1.0, seed=101, bm_grass_lit=None, bm_grass_shade=None):
    """Green Summoner's Rift Broadleaf Tree using the sculpted feathered lobe pipeline (no radial spokes!)."""
    rng = random.Random(seed)
    g_lit = bm_grass_lit if bm_grass_lit is not None else bm_fol_lit
    g_shd = bm_grass_shade if bm_grass_shade is not None else bm_fol_shade

    lean_x = rng.uniform(-0.42, 0.42) * scale
    lean_z = rng.uniform(-0.42, 0.42) * scale
    trunk_pts = [
        (gx, gy - 0.08, gz),
        (gx - lean_x * 0.25, gy + 1.05 * scale, gz - lean_z * 0.25),
        (gx + lean_x * 0.45, gy + 2.20 * scale, gz + lean_z * 0.45),
        (gx + lean_x, gy + 3.35 * scale, gz + lean_z),
    ]
    add_swept_tube(bm_wood, trunk_pts, 0.44 * scale, 0.44 * scale, sides=10, radii_scale=[1.42, 0.94, 0.72, 0.52])

    for r_i in range(5):
        ang = math.radians(r_i * 72.0 + rng.uniform(-14.0, 14.0))
        dx, dz = math.cos(ang), math.sin(ang)
        px_t, pz_t = -dz, dx
        wiggle = rng.uniform(-0.22, 0.22) * scale
        root_pts = [
            (gx + dx * 0.16 * scale, gy + 1.30 * scale, gz + dz * 0.16 * scale),
            (gx + dx * 0.58 * scale + px_t * wiggle * 0.5, gy + 0.45 * scale, gz + dz * 0.58 * scale + pz_t * wiggle * 0.5),
            (gx + dx * 1.08 * scale + px_t * wiggle, gy + 0.08 * scale, gz + dz * 1.08 * scale + pz_t * wiggle),
            (gx + dx * 1.55 * scale, gy - 0.04, gz + dz * 1.55 * scale),
        ]
        add_swept_tube(bm_wood, root_pts, 0.22 * scale, 0.22 * scale, sides=7, radii_scale=[0.95, 0.82, 0.48, 0.18])
        ma = ang + math.radians(36.0)
        add_lol_grass_tuft_cluster(
            g_lit, g_shd,
            gx + math.cos(ma) * 0.85 * scale, gy, gz + math.sin(ma) * 0.85 * scale,
            scale=0.80 * scale, n_blades=6, seed=seed + 50 + r_i
        )

    top_x, top_y, top_z = trunk_pts[-1]
    for dx_l, dy_l, dz_l, rx_l, ry_l, rz_l, vmin, vmax, s_off in [
        (0.0,   0.95,  0.0,  1.95, 1.32, 1.85, 0.12, 0.65, 11),
        (-1.15, 0.22,  0.45, 1.65, 1.15, 1.55, 0.25, 0.82, 23),
        (1.18,  0.25,  0.38, 1.62, 1.12, 1.52, 0.25, 0.82, 37),
        (0.0,   0.28, -0.88, 1.68, 1.15, 1.50, 0.28, 0.85, 49),
    ]:
        add_lol_sculpted_blossom_lobe(
            bm_fol_lit, bm_fol_shade,
            top_x + dx_l * scale, top_y + dy_l * scale, top_z + dz_l * scale,
            rx=rx_l * scale, ry=ry_l * scale, rz=rz_l * scale,
            uv_v_min=vmin, uv_v_max=vmax, seed=seed + s_off
        )


def add_palia_cypress_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=1.0, seed=202):
    add_lol_rift_pine_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=0.68 * scale, seed=seed)


def add_flower_bush_cluster(bm_fol_lit, bm_fol_shade, bm_flw_purple, bm_flw_pink, bm_flw_white, gx, gy, gz, scale=1.0, seed=303):
    rng = random.Random(seed)
    add_sculpted_foliage_cloud(bm_fol_shade, gx, gy + 0.22 * scale, gz, 0.68 * scale, 0.38 * scale, 0.64 * scale, subdiv=2, seed=seed)
    add_lol_grass_tuft_cluster(bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=0.85 * scale, n_blades=7, seed=seed + 7)
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


def bake_lol_foliage_gradient(bm, is_blossom=False, is_lit_layer=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    col_layer = bm.loops.layers.color.active or bm.loops.layers.color.new("Col")
    uv_layer = bm.loops.layers.uv.active
    if not bm.verts:
        return

    for v in bm.verts:
        l_faces = v.link_faces
        if not l_faces:
            continue
        avg_nz = sum(f.normal.z for f in l_faces) / float(len(l_faces))
        for loop in v.link_loops:
            uv_y = loop[uv_layer].uv.y if uv_layer else 0.5
            if avg_nz < -0.25:
                if not is_blossom:
                    col = (0.44, 0.64, 0.66, 1.0)
                else:
                    col = (0.64, 0.52, 0.74, 1.0)
            else:
                if not is_blossom:
                    # For pine/grass: uv_y = 0.08 is tip (bright), uv_y = 0.90 is upper tuck (dark)
                    crown_lift = max(0.0, min(1.0, (1.0 - uv_y) * 0.55 + (avg_nz + 0.4) * 0.45))
                    if not is_lit_layer:
                        crown_lift *= 0.80
                    r = min(1.0, 0.58 + 0.42 * crown_lift)
                    g = min(1.0, 0.74 + 0.26 * crown_lift)
                    b = min(1.0, 0.68 + 0.16 * crown_lift)
                    col = (r, g, b, 1.0)
                else:
                    # For Spirit Blossom: texture already has the real Devoted Studios vertical gradient
                    # (top at uv_y = 0.92, bottom at uv_y = 0.08); apply gentle spherical AO & crown warmth
                    crown_lift = max(0.0, min(1.0, uv_y * 0.55 + (avg_nz + 0.4) * 0.45))
                    if not is_lit_layer:
                        crown_lift *= 0.78
                    r = min(1.0, 0.74 + 0.26 * crown_lift)
                    g = min(1.0, 0.66 + 0.30 * crown_lift)
                    b = min(1.0, 0.76 + 0.22 * crown_lift)
                    col = (r, g, b, 1.0)
            loop[col_layer] = col


def make_mesh_object(name, bm, mat, smooth_shading=False, top_hi=1.16, crev_dark=0.70, is_foliage=False, is_blossom=False, is_lit_layer=True):
    if is_foliage:
        bake_lol_foliage_gradient(bm, is_blossom=is_blossom, is_lit_layer=is_lit_layer)
    else:
        bake_lol_edge_highlights_and_crevices(bm, top_highlight=top_hi, crevice_dark=crev_dark)
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.material_index = 0
        p.use_smooth = smooth_shading
    return obj


def make_mat(name, color=(1, 1, 1, 1), tex_path=None, rough=0.88, metal=0.0, emission=None, emit_str=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
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
    if emission is not None and emit_str > 0.0:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission
            bsdf.inputs["Emission Strength"].default_value = emit_str
    return mat


def build_lorencia_lol_city_v95():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    flagstone_tex = os.path.join(BLENDER_DIR, "T_LoL_Mossy_Flagstones.png")
    weathered_stone_tex = os.path.join(BLENDER_DIR, "T_LoL_Weathered_Stone.png")
    walnut_wood_tex = os.path.join(BLENDER_DIR, "T_LoL_Walnut_Wood.png")
    rift_terrain_tex = os.path.join(BLENDER_DIR, "T_LoL_Rift_Terrain.png")
    roof_tex = os.path.join(BLENDER_DIR, "T_Palia_Terracotta_Roof.png")
    leaves_tex = os.path.join(BLENDER_DIR, "T_Real_Palia_Leaves.png")
    blossom_tex = os.path.join(BLENDER_DIR, "T_LoL_Blossom_Leaves.png")
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
    mat_fol_lit = make_mat("MI_LoL_Foliage_Lit", color=(1.04, 1.08, 0.94, 1.0), tex_path=leaves_tex)
    mat_fol_shade = make_mat("MI_LoL_Foliage_Shade", color=(0.72, 0.84, 0.76, 1.0), tex_path=leaves_tex)
    mat_blossom_lit = make_mat("MI_LoL_Blossom_Lit", color=(0.98, 0.94, 0.98, 1.0), tex_path=blossom_tex)
    mat_blossom_shade = make_mat("MI_LoL_Blossom_Shade", color=(0.74, 0.64, 0.82, 1.0), tex_path=blossom_tex)
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
        add_palia_cypress_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx_mid, 0.08, gz_mid, scale=0.95, seed=500 + g_idx)
        for f_off in [-13.0, 13.0]:
            af = math.radians(g_deg + f_off)
            add_flower_bush_cluster(
                bm_fol_lit, bm_fol_shade, bm_flw_purple, bm_flw_pink, bm_flw_white,
                fx + math.sin(af) * 10.0, 0.08, fz + math.cos(af) * 10.0,
                scale=0.92, seed=520 + g_idx * 3 + (1 if f_off > 0 else 0)
            )
        for g_off in [-7.0, 7.0]:
            ag = math.radians(g_deg + g_off)
            add_lol_grass_tuft_cluster(
                bm_fol_lit, bm_fol_shade,
                fx + math.sin(ag) * 9.8, 0.08, fz + math.cos(ag) * 9.8,
                scale=0.92, n_blades=8, seed=560 + g_idx * 5 + (1 if g_off > 0 else 0)
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
        add_lol_grass_tuft_cluster(
            bm_fol_lit, bm_fol_shade,
            fx + math.cos(ang) * 1.90, 2.85, fz + math.sin(ang) * 1.90,
            scale=0.68, n_blades=6, seed=800 + m_i
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
    # 6. 18 SPIRAL STREETLAMPS + HERALDIC BANNERS, SUMMONER'S RIFT LAYERED PINES,
    #    AND DEVOTED STUDIOS SPIRIT BLOSSOM TREE DIORAMAS (`1795472939345-download.png`)
    # ═══════════════════════════════════════════════════════════════════
    for sx_l, b_dir in [(-16.2, -1.0), (15.5, 1.0), (-9.2, 1.0), (9.2, -1.0)]:
        for lz in [-0.5, 10.5, 21.5]:
            add_arcane_streetlamp_with_banner(bm_stone_body, bm_stone_hi, bm_iron, bm_gold, bm_banner, bm_ember, sx_l, 0.0, lz, banner_dir_x=b_dir)

    add_palia_rope_lantern_post(bm_wood, bm_gold, bm_iron, bm_ember, -17.2, 0.0, 8.2, facing_x=1.0)
    add_palia_rope_lantern_post(bm_wood, bm_gold, bm_iron, bm_ember, -17.2, 0.0, 1.2, facing_x=1.0)
    add_festoon_lantern_string(bm_iron, bm_ember, (-17.2, 4.45, 8.2), (-17.2, 4.45, 1.2), sag=0.60, num_lanterns=3)

    # A. Town Trees: Full Spirit Blossom Stepped-Rock Dioramas at (-26.2, 10.5) and (23.2, -0.8) + Summoner's Rift Pines
    for ox, oz, osc, oseed, t_kind in [
        (-25.8, -1.5, 1.08, 101, "pine"),
        (-26.2, 10.5, 0.94, 102, "blossom_diorama"),  # West Tavern & Forge Spirit Blossom Diorama
        (-25.5, 23.5, 1.04, 103, "green_canopy"),
        (23.2, -0.8, 0.95, 104, "blossom_diorama"),   # East Apothecary & Windmill Spirit Blossom Diorama (Shot 3 focal point!)
        (24.8, 23.5, 1.08, 105, "pine"),
        (-16.5, 27.5, 1.10, 106, "pine"),
        (16.5, 27.5, 1.05, 107, "green_canopy"),
    ]:
        if t_kind == "blossom_diorama":
            add_lol_spirit_blossom_diorama(
                bm_stone_body, bm_stone_hi, bm_wood, bm_blossom_lit, bm_blossom_shade,
                bm_fol_lit, bm_fol_shade, bm_iron, bm_gold, bm_flw_white, bm_flw_pink,
                ox, 0.0, oz, scale=osc, seed=oseed
            )
        elif t_kind == "pine":
            add_chiseled_block(bm_stone_body, bm_stone_hi, ox, 0.0, oz, 2.5 * osc, 0.50, 2.5 * osc)
            add_lol_rift_pine_tree(bm_wood, bm_fol_lit, bm_fol_shade, ox, 0.48, oz, scale=osc * 0.92, seed=oseed)
        else:
            add_chiseled_block(bm_stone_body, bm_stone_hi, ox, 0.0, oz, 2.5 * osc, 0.50, 2.5 * osc)
            add_lol_handpainted_canopy_tree(
                bm_wood, bm_fol_lit, bm_fol_shade,
                ox, 0.48, oz, scale=osc * 0.92, seed=oseed,
                bm_grass_lit=bm_fol_lit, bm_grass_shade=bm_fol_shade
            )

    # B. Summoner's Rift Layered Pine Clusters & Outskirts Spirit Blossom Shrine Dioramas
    for px_t, pz_t, psc, pseed, p_kind in [
        (-19.5, -7.5, 1.28, 108, "pine"),
        (19.5, -7.5, 1.28, 109, "pine"),
        (-13.5, -9.8, 1.15, 118, "pine"),
        (13.5, -9.8, 1.15, 119, "pine"),
        (-28.5, -11.5, 1.42, 110, "pine"),
        (28.5, -11.5, 1.42, 111, "pine"),
        (-15.8, -19.2, 1.02, 112, "blossom_diorama"),
        (16.5, -19.5, 1.32, 113, "pine"),
        (-22.5, -24.5, 1.38, 116, "pine"),
        (21.5, -24.0, 1.02, 117, "blossom_diorama"),
        (-20.0, -31.0, 1.45, 114, "pine"),
        (20.0, -31.0, 1.45, 115, "pine"),
    ]:
        if p_kind == "pine":
            add_lol_rift_pine_tree(bm_wood, bm_fol_lit, bm_fol_shade, px_t, -0.14, pz_t, scale=psc, seed=pseed)
        else:
            add_lol_spirit_blossom_diorama(
                bm_stone_body, bm_stone_hi, bm_wood, bm_blossom_lit, bm_blossom_shade,
                bm_fol_lit, bm_fol_shade, bm_iron, bm_gold, bm_flw_white, bm_flw_pink,
                px_t, -0.14, pz_t, scale=psc, seed=pseed
            )

    # C. Staggered Chiseled Border Stones, Moss-Draped Runic Rock Ledges & Meadow Grass Tufts
    add_staggered_rift_border_stones(bm_stone_body, bm_stone_hi, -28.0, -2.5, -15.5, -2.5, step=1.5, seed=31, bm_fol_lit=bm_fol_lit, bm_fol_shade=bm_fol_shade)
    add_staggered_rift_border_stones(bm_stone_body, bm_stone_hi, 15.5, -2.5, 28.0, -2.5, step=1.5, seed=41, bm_fol_lit=bm_fol_lit, bm_fol_shade=bm_fol_shade)
    add_staggered_rift_border_stones(bm_stone_body, bm_stone_hi, -4.2, -14.8, -4.2, -34.0, step=1.5, seed=51, bm_fol_lit=bm_fol_lit, bm_fol_shade=bm_fol_shade)
    add_staggered_rift_border_stones(bm_stone_body, bm_stone_hi, 4.2, -14.8, 4.2, -34.0, step=1.5, seed=61, bm_fol_lit=bm_fol_lit, bm_fol_shade=bm_fol_shade)

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
            bm_fol_lit=bm_fol_lit, bm_fol_shade=bm_fol_shade, bm_rune=bm_water
        )

    rng_grass = random.Random(888)
    for g_idx, (gx_c, gz_c) in enumerate([
        (-8.5, -5.8), (8.5, -5.8), (-11.8, -12.5), (11.8, -12.5),
        (-7.5, -16.2), (7.5, -16.2), (-8.8, -22.5), (8.8, -22.5),
        (-14.5, -15.0), (14.5, -15.0), (-15.0, -24.0), (15.0, -24.0),
        (-6.8, -31.0), (6.8, -31.0),
    ]):
        add_lol_grass_tuft_cluster(
            bm_fol_lit, bm_fol_shade,
            gx_c + rng_grass.uniform(-0.4, 0.4), -0.14, gz_c + rng_grass.uniform(-0.4, 0.4),
            scale=rng_grass.uniform(1.05, 1.38), n_blades=8, seed=900 + g_idx
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
    make_mesh_object("Lorencia_Foliage_Lit", bm_fol_lit, mat_fol_lit, smooth_shading=True, is_foliage=True, is_blossom=False, is_lit_layer=True)
    make_mesh_object("Lorencia_Foliage_Shade", bm_fol_shade, mat_fol_shade, smooth_shading=True, is_foliage=True, is_blossom=False, is_lit_layer=False)
    make_mesh_object("Lorencia_Foliage_Blossom_Lit", bm_blossom_lit, mat_blossom_lit, smooth_shading=True, is_foliage=True, is_blossom=True, is_lit_layer=True)
    make_mesh_object("Lorencia_Foliage_Blossom_Shade", bm_blossom_shade, mat_blossom_shade, smooth_shading=True, is_foliage=True, is_blossom=True, is_lit_layer=False)
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
    print("Exported LoL / Spirit Blossom Diorama Lorencia City v9.5:", blend_path, "->", glb_path)


build_lorencia_lol_city_v95()
