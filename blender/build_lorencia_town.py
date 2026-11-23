import os
import sys
import math
import random
import bpy
import bmesh
import mathutils

# ═══════════════════════════════════════════════════════════════════════════
# LEAGUE OF LEGENDS / SUMMONER'S RIFT & SPIRIT BLOSSOM CITY (v9.2)
# - Authentic Summoner's Rift Layered Pine / Conifer Trees (`add_lol_rift_pine_tree`)
#   with wide concave-flared bough skirts, 6-7 bold chunky pointed leaf-frond prongs
#   per tier, deep viridian-teal under-tier shadow bands, hooked windswept apexes,
#   and flanking sub-spires (`Captura de Tela 2026-11-23 às 19.03.45.png` & `image.png`).
# - Authentic Riot Games / Devoted Studios Spirit Blossom & Broadleaf Trees
#   (`add_lol_handpainted_canopy_tree` + `add_lol_billowing_canopy_dome`) with
#   rounded billowing multi-ring scalloped canopy clouds (zero sharp cone spikes!),
#   S-curved trunks, and arched surface root tendrils (`image-2.png`).
# - Smooth gouache Summoner's Rift meadow grass (`tile_scale = 0.065`), 3D hand-painted
#   grass-blade tuft clusters, and moss-capped runic rock monoliths (`image.png`).
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
    Creates `n_blades` broad, curved, tapering lance-shaped 3D grass fronds flaring outward
    with dark viridian-teal bases (`UV.v = 0.15`) and warm chartreuse tips (`UV.v = 0.92`).
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
            v_bl: (0.35, 0.12),
            v_br: (0.65, 0.12),
            v_ml: (0.38, 0.52),
            v_mr: (0.62, 0.52),
            v_tip: (0.50, 0.94),
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

    # Thick moss-draped grass skirt capping the rock ledge + 3D grass tufts (`image.png`)
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

    # Glowing cyan-turquoise spiral rune carved on the rock monolith side (`image.png`)
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
    - Concave flared bell-skirt geometry: steep upper neck (`r_mid = 0.44 * r_outer`) that flares
      outward strongly into `n_tips` (6-8) big, bold, chunky pointed leaf-frond prongs!
    - Single 0..1 UV wrap around the skirt so the broad vertical gouache leaf plumes on
      `T_Real_Palia_Leaves.png` align directly with each chunky leaf prong (zero speckle noise!).
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

        # Concave flare: narrower mid-neck (`0.42..0.48`) so the lower skirt sweeps outward like a fir bough
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
        mid_uvs.append((u_coord, 0.45))
        rim_uvs.append((u_coord, 0.94 if is_tip else 0.64))

    out_faces = []
    shd_faces = []
    for k in range(total_pts):
        nk = (k + 1) % total_pts
        u0 = mid_uvs[k][0]
        u1 = 1.0 if nk == 0 else mid_uvs[nk][0]

        f_top = bm_outer.faces.new((mid_verts[k], mid_verts[nk], v_apex))
        f_skirt = bm_outer.faces.new((rim_out_verts[k], rim_out_verts[nk], mid_verts[nk], mid_verts[k]))
        out_faces.extend([f_top, f_skirt])

        f_top.loops[0][uv_out].uv = (u0, 0.45)
        f_top.loops[1][uv_out].uv = (u1, 0.45)
        f_top.loops[2][uv_out].uv = (0.5 * (u0 + u1), 0.10)

        f_skirt.loops[0][uv_out].uv = (u0, rim_uvs[k][1])
        f_skirt.loops[1][uv_out].uv = (u1, rim_uvs[nk][1])
        f_skirt.loops[2][uv_out].uv = (u1, 0.45)
        f_skirt.loops[3][uv_out].uv = (u0, 0.45)

        f_under = bm_under_shade.faces.new((rim_shd_verts[nk], rim_shd_verts[k], v_under_center))
        shd_faces.append(f_under)
        for loop in f_under.loops:
            loop[uv_shd].uv = (0.5, 0.08)

    bmesh.ops.recalc_face_normals(bm_outer, faces=out_faces)
    bmesh.ops.recalc_face_normals(bm_under_shade, faces=shd_faces)


def add_lol_rift_pine_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=1.0, seed=101):
    """
    Summoner's Rift Layered Pine / Conifer Cluster (`Captura de Tela 2026-11-23 às 19.03.45.png` & `image.png`):
    - Wide, deeply overlapping concave-flared bough skirts with 6-8 bold, chunky pointed leaf prongs,
      deep viridian-teal under-skirt shadow pockets, and a curved windswept pointed apex tip.
    - Flanked by 2-3 smaller clustered sub-pine spires tucked around its base.
    """
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

    # 6 deeply overlapping, wide-flared pine skirts climbing to a curved windswept hooked apex
    tiers = [
        # (y_base, r_outer, r_inner_ratio, h_cone, tip_drop, n_tips, use_lit_outer)
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
        # Stronger apex hook on the top tier to match the curved tip in Captura de Tela 2026-11-23 às 19.03.45.png
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

    # 2-3 smaller clustered sub-pine spires at the base (`Captura de Tela 2026-11-23 às 19.03.45.png`)
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


def add_lol_billowing_canopy_dome(bm_lit, bm_shade, cx, cy, cz, rx, ry, rz, n_lobes=8, seed=42):
    """
    Riot Games / Devoted Studios (`image-2.png`) Billowing Rounded Canopy Cloud-Dome:
    Instead of a pointed cone, constructs a smooth, plump, rounded 4-ring dome cap on top
    with two shingled scalloped leaf-frond skirts cascading down the sides and a dark
    concave under-canopy shadow belly (`bm_shade`).
    """
    rng = random.Random(seed)
    segs = n_lobes * 2
    uv_lit = bm_lit.loops.layers.uv.active or bm_lit.loops.layers.uv.new("UVMap")
    uv_shd = bm_shade.loops.layers.uv.active or bm_shade.loops.layers.uv.new("UVMap")

    # Top center vertex of the rounded dome (flat/rounded crown, NEVER a sharp cone spike!)
    v_top = bm_lit.verts.new(gpos(cx, cy + ry * 0.92, cz))
    v_under = bm_shade.verts.new(gpos(cx, cy + ry * 0.08, cz))

    # 3 concentric rings forming a plump, rounded ellipsoid dome + scalloped drooping leaf-tuft rim
    ring_specs = [
        # (r_scale, y_offset_ratio, uv_v, lobe_amp)
        (0.45, 0.78, 0.22, 0.04),
        (0.82, 0.46, 0.48, 0.08),
        (1.04, -0.08, 0.88, 0.14),
    ]
    rings = []
    ring_uvs = []
    shd_rim = []

    for r_idx, (r_sc, y_rat, uv_v, l_amp) in enumerate(ring_specs):
        r_verts = []
        r_u = []
        for k in range(segs):
            is_lobe_tip = (k % 2 == 0)
            frac = float(k) / float(segs)
            ang = frac * 2.0 * math.pi + rng.uniform(-0.04, 0.04)
            ca, sa = math.cos(ang), math.sin(ang)

            lobe_r = (1.0 + l_amp) if is_lobe_tip else (1.0 - l_amp * 0.85)
            lobe_y = (-l_amp * 0.95) if (r_idx == 2 and is_lobe_tip) else (l_amp * 0.45 if r_idx == 2 else 0.0)
            jit = rng.uniform(0.95, 1.05)

            wx = cx + ca * rx * r_sc * lobe_r * jit
            wz = cz + sa * rz * r_sc * lobe_r * jit
            wy = cy + ry * (y_rat + lobe_y)

            r_verts.append(bm_lit.verts.new(gpos(wx, wy, wz)))
            r_u.append((frac, uv_v + (0.06 if (r_idx == 2 and is_lobe_tip) else 0.0)))
            if r_idx == 2:
                shd_rim.append(bm_shade.verts.new(gpos(wx * 0.94 + cx * 0.06, wy - 0.04, wz * 0.94 + cz * 0.06)))
        rings.append(r_verts)
        ring_uvs.append(r_u)

    lit_faces = []
    shd_faces = []
    for k in range(segs):
        nk = (k + 1) % segs
        u0 = float(k) / float(segs)
        u1 = 1.0 if nk == 0 else float(nk) / float(segs)

        # Dome cap ring 0
        f0 = bm_lit.faces.new((rings[0][k], rings[0][nk], v_top))
        f0.loops[0][uv_lit].uv = (u0, ring_uvs[0][k][1])
        f0.loops[1][uv_lit].uv = (u1, ring_uvs[0][nk][1])
        f0.loops[2][uv_lit].uv = (0.5 * (u0 + u1), 0.12)
        lit_faces.append(f0)

        # Dome mid & outer scalloped skirt rings
        for r_idx in range(2):
            fa = bm_lit.faces.new((rings[r_idx + 1][k], rings[r_idx + 1][nk], rings[r_idx][nk], rings[r_idx][k]))
            fa.loops[0][uv_lit].uv = (u0, ring_uvs[r_idx + 1][k][1])
            fa.loops[1][uv_lit].uv = (u1, ring_uvs[r_idx + 1][nk][1])
            fa.loops[2][uv_lit].uv = (u1, ring_uvs[r_idx][nk][1])
            fa.loops[3][uv_lit].uv = (u0, ring_uvs[r_idx][k][1])
            lit_faces.append(fa)

        # Recessed dark under-canopy shadow skirt (`bm_shade`)
        fu = bm_shade.faces.new((shd_rim[nk], shd_rim[k], v_under))
        for loop in fu.loops:
            loop[uv_shd].uv = (0.5, 0.12)
        shd_faces.append(fu)

    bmesh.ops.recalc_face_normals(bm_lit, faces=lit_faces)
    bmesh.ops.recalc_face_normals(bm_shade, faces=shd_faces)


def add_lol_handpainted_canopy_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=1.0, seed=101, bm_grass_lit=None, bm_grass_shade=None):
    """
    Riot Games / Devoted Studios (`image-2.png`) Hand-Painted Broadleaf & Spirit Blossom Tree:
    - S-curved gnarled trunk with 5 arched surface root tendrils snaking out over the ground/stone.
    - Overlapping rounded billowing canopy cloud-domes (`add_lol_billowing_canopy_dome`) that form
      a lush, soft-contoured umbrella silhouette (zero sharp cone spikes!).
    """
    rng = random.Random(seed)
    g_lit = bm_grass_lit if bm_grass_lit is not None else bm_fol_lit
    g_shd = bm_grass_shade if bm_grass_shade is not None else bm_fol_shade

    lean_x = rng.uniform(-0.45, 0.45) * scale
    lean_z = rng.uniform(-0.45, 0.45) * scale
    trunk_pts = [
        (gx, gy - 0.08, gz),
        (gx - lean_x * 0.25, gy + 1.05 * scale, gz - lean_z * 0.25),
        (gx + lean_x * 0.45, gy + 2.20 * scale, gz + lean_z * 0.45),
        (gx + lean_x, gy + 3.30 * scale, gz + lean_z),
    ]
    add_swept_tube(bm_wood, trunk_pts, 0.44 * scale, 0.44 * scale, sides=10, radii_scale=[1.42, 0.94, 0.72, 0.52])

    # 5 arched surface root tendrils snaking over the stone/earth (`image-2.png`)
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
    branch_dirs = [(-1.45, 0.80), (1.48, 0.75), (-0.82, -1.35), (1.10, -1.22)]
    for b_idx, (bx_d, bz_d) in enumerate(branch_dirs):
        end_x = top_x + bx_d * scale
        end_y = top_y + rng.uniform(0.85, 1.20) * scale
        end_z = top_z + bz_d * scale
        b_pts = [
            (top_x, top_y - 0.25 * scale, top_z),
            (0.5 * (top_x + end_x), top_y + 0.40 * scale, 0.5 * (top_z + end_z)),
            (end_x, end_y, end_z),
        ]
        add_swept_tube(bm_wood, b_pts, 0.22 * scale, 0.22 * scale, sides=8, radii_scale=[1.0, 0.70, 0.38])
        # Lower shadow cushion + rounded upper billowing dome
        add_lol_billowing_canopy_dome(
            bm_fol_shade, bm_fol_shade,
            end_x, end_y - 0.12 * scale, end_z,
            rx=1.80 * scale, ry=0.95 * scale, rz=1.72 * scale,
            n_lobes=8, seed=seed + b_idx * 17
        )
        add_lol_billowing_canopy_dome(
            bm_fol_lit, bm_fol_shade,
            end_x * 0.94 + top_x * 0.06, end_y + 0.24 * scale, end_z * 0.94 + top_z * 0.06,
            rx=1.68 * scale, ry=1.02 * scale, rz=1.62 * scale,
            n_lobes=8, seed=seed + b_idx * 23
        )

    # Grand rounded upper crown dome (`image-2.png`)
    add_lol_billowing_canopy_dome(
        bm_fol_shade, bm_fol_shade,
        top_x, top_y + 0.92 * scale, top_z,
        rx=2.35 * scale, ry=1.18 * scale, rz=2.25 * scale,
        n_lobes=10, seed=seed + 83
    )
    add_lol_billowing_canopy_dome(
        bm_fol_lit, bm_fol_shade,
        top_x, top_y + 1.32 * scale, top_z,
        rx=2.12 * scale, ry=1.24 * scale, rz=2.04 * scale,
        n_lobes=9, seed=seed + 97
    )


def add_palia_cypress_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=1.0, seed=202):
    """Compact Summoner's Rift Layered Pine Spire for the 4 Central Plaza Garden Islands."""
    add_lol_rift_pine_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=0.68 * scale, seed=seed)


def add_flower_bush_cluster(bm_fol_lit, bm_fol_shade, bm_flw_purple, bm_flw_pink, bm_flw_white, gx, gy, gz, scale=1.0, seed=303):
    rng = random.Random(seed)
    add_lol_billowing_canopy_dome(
        bm_fol_lit, bm_fol_shade,
        gx, gy + 0.22 * scale, gz,
        rx=0.72 * scale, ry=0.42 * scale, rz=0.68 * scale,
        n_lobes=7, seed=seed
    )
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
            if avg_nz < -0.20:
                if not is_blossom:
                    col = (0.44, 0.64, 0.66, 1.0)
                else:
                    col = (0.62, 0.50, 0.74, 1.0)
            else:
                crown_lift = max(0.0, min(1.0, (0.45 + uv_y * 0.45) * 0.60 + (avg_nz + 0.4) * 0.40))
                if not is_lit_layer:
                    crown_lift *= 0.80
                if not is_blossom:
                    r = min(1.0, 0.58 + 0.42 * crown_lift)
                    g = min(1.0, 0.74 + 0.26 * crown_lift)
                    b = min(1.0, 0.68 + 0.16 * crown_lift)
                    col = (r, g, b, 1.0)
                else:
                    r = min(1.0, 0.78 + 0.22 * crown_lift)
                    g = min(1.0, 0.64 + 0.32 * crown_lift)
                    b = min(1.0, 0.80 + 0.18 * crown_lift)
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


def build_lorencia_lol_city_v9():
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
    mat_blossom_lit = make_mat("MI_LoL_Blossom_Lit", color=(1.04, 0.98, 1.02, 1.0), tex_path=blossom_tex)
    mat_blossom_shade = make_mat("MI_LoL_Blossom_Shade", color=(0.82, 0.68, 0.86, 1.0), tex_path=blossom_tex)
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

    # Region A: Central Sunspire Rotunda, East Merchant/Vault Quarter & South Belvedere (x = -11.4..+31.0, z = -3.0..+31.0)
    add_box(bm_flagstones, 9.8, -0.08, 14.0, 42.4, 0.08, 34.0, tile_scale=0.24)
    # Region B: West Artisan Quarter across the Aqueduct Canal (x = -32.4..-15.0, z = -3.0..+28.0)
    add_box(bm_flagstones, -23.7, -0.08, 12.5, 17.4, 0.08, 31.0, tile_scale=0.24)
    # Region C: Northern Outskirts Highway (z = -14.5..-27.7)
    add_box(bm_flagstones, 0.0, -0.08, -21.1, 7.6, 0.08, 13.2, tile_scale=0.24)
    # Region D: Ancient Boss Colosseum Piazza (z = -42.0, radius = 14.2)
    add_cylinder(bm_flagstones, 0.0, -0.08, -42.0, 14.2, 14.0, 0.08, 16, rot_y_deg=11.25, tile_scale=0.24)

    # ★ HOLLOW 8-POINTED RUNETERRA COMPASS-STAR STONE INLAY around (0, 0, 11.5) ★
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

    # ★ 4 CRESCENT GREEN LAWN GARDEN ISLANDS (r = 8.4..11.8m at 45°, 135°, 225°, 315°) ★
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
    #    DEVOTED STUDIOS BILLOWING CANOPY / SPIRIT BLOSSOM TREES & 3D GRASS TUFTS
    # ═══════════════════════════════════════════════════════════════════
    for sx_l, b_dir in [(-16.2, -1.0), (15.5, 1.0), (-9.2, 1.0), (9.2, -1.0)]:
        for lz in [-0.5, 10.5, 21.5]:
            add_arcane_streetlamp_with_banner(bm_stone_body, bm_stone_hi, bm_iron, bm_gold, bm_banner, bm_ember, sx_l, 0.0, lz, banner_dir_x=b_dir)

    add_palia_rope_lantern_post(bm_wood, bm_gold, bm_iron, bm_ember, -17.2, 0.0, 8.2, facing_x=1.0)
    add_palia_rope_lantern_post(bm_wood, bm_gold, bm_iron, bm_ember, -17.2, 0.0, 1.2, facing_x=1.0)
    add_festoon_lantern_string(bm_iron, bm_ember, (-17.2, 4.45, 8.2), (-17.2, 4.45, 1.2), sag=0.60, num_lanterns=3)

    # A. Town Trees: Mix of Summoner's Rift Layered Pines & Devoted Studios Billowing Broadleaf / Spirit Blossom Trees
    for ox, oz, osc, oseed, t_kind in [
        (-25.8, -1.5, 1.08, 101, "pine"),
        (-26.5, 10.5, 1.12, 102, "blossom"),  # Billowing Spirit Blossom sakura tree beside Lumen's Tavern & Forge
        (-25.5, 23.5, 1.08, 103, "green_canopy"),
        (24.5, -1.5, 1.06, 104, "blossom"),   # Billowing Spirit Blossom sakura tree framing East Apothecary & Windmill
        (24.8, 23.5, 1.08, 105, "pine"),
        (-16.5, 27.5, 1.10, 106, "pine"),
        (16.5, 27.5, 1.10, 107, "green_canopy"),
    ]:
        add_chiseled_block(bm_stone_body, bm_stone_hi, ox, 0.0, oz, 2.5 * osc, 0.50, 2.5 * osc)
        if t_kind == "pine":
            add_lol_rift_pine_tree(bm_wood, bm_fol_lit, bm_fol_shade, ox, 0.48, oz, scale=osc * 0.92, seed=oseed)
        elif t_kind == "blossom":
            add_lol_handpainted_canopy_tree(
                bm_wood, bm_blossom_lit, bm_blossom_shade,
                ox, 0.48, oz, scale=osc * 0.92, seed=oseed,
                bm_grass_lit=bm_fol_lit, bm_grass_shade=bm_fol_shade
            )
        else:
            add_lol_handpainted_canopy_tree(
                bm_wood, bm_fol_lit, bm_fol_shade,
                ox, 0.48, oz, scale=osc * 0.92, seed=oseed,
                bm_grass_lit=bm_fol_lit, bm_grass_shade=bm_fol_shade
            )

    # B. Summoner's Rift Layered Pine / Conifer Clusters & Outskirts Spirit Blossom Shrine Trees
    for px_t, pz_t, psc, pseed, p_kind in [
        (-19.5, -7.5, 1.28, 108, "pine"),
        (19.5, -7.5, 1.28, 109, "pine"),
        (-13.5, -9.8, 1.15, 118, "pine"),
        (13.5, -9.8, 1.15, 119, "pine"),
        (-28.5, -11.5, 1.42, 110, "pine"),
        (28.5, -11.5, 1.42, 111, "pine"),
        (-16.5, -19.5, 1.22, 112, "blossom"),
        (16.5, -19.5, 1.32, 113, "pine"),
        (-22.5, -24.5, 1.38, 116, "pine"),
        (22.5, -24.5, 1.22, 117, "blossom"),
        (-20.0, -31.0, 1.45, 114, "pine"),
        (20.0, -31.0, 1.45, 115, "pine"),
    ]:
        if p_kind == "pine":
            add_lol_rift_pine_tree(bm_wood, bm_fol_lit, bm_fol_shade, px_t, -0.14, pz_t, scale=psc, seed=pseed)
        else:
            add_lol_handpainted_canopy_tree(
                bm_wood, bm_blossom_lit, bm_blossom_shade,
                px_t, -0.14, pz_t, scale=psc * 0.95, seed=pseed,
                bm_grass_lit=bm_fol_lit, bm_grass_shade=bm_fol_shade
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
    print("Exported LoL / Summoner's Rift & Spirit Blossom Lorencia City v9.2:", blend_path, "->", glb_path)


build_lorencia_lol_city_v9()
