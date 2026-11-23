import os
import sys
import math
import random
import bpy
import bmesh
import mathutils

# ═══════════════════════════════════════════════════════════════════════════
# PALIA (KILIMA VILLAGE) & LEAGUE OF LEGENDS INSPIRED FANTASY TOWN SQUARE (v7)
# Built in Blender 5.3.0 with:
# - Real AI hand-painted seamless textures (Golden Cobblestones, Sunlit Meadow
#   Grass, Terracotta Roof Shingles, Honey-Walnut Timber, Cream Stucco, and
#   Painterly Canopy Leaves)
# - Real high-detail smooth-shaded 3D trees (organic flared-root spline trunks,
#   sweeping limbs, and subdivided normal-smoothed billowing icosphere leaf clouds,
#   plus slender Italian Cypresses and flowering purple lupine & hydrangea beds)
# - 100% disjoint polar-sector cobblestone ring-road & radiating pathways over
#   lush meadow grass (mathematically zero overlapping floor faces = zero Z-fighting!)
# - Iconic Palia Village Landmarks from image.png & image-2.png:
#   1. Central 4-Legged Stone-&-Timber Mossy Chalice Fountain & Circular Flower Garden
#   2. Grand Curved-Gable Half-Timbered Town Hall & Soaring White Clocktower Spire
#   3. East 6-Sail Windmill Tower, Wooden Porch Deck & Apothecary/Vault Cottages
#   4. West Half-Timbered Village Tavern Porch & Hanzo's Timber-Beam Blacksmith Forge
#   5. Rope-Wrapped Timber Lantern Posts & Overhead Festoon String Bell Lanterns
# ═══════════════════════════════════════════════════════════════════════════

PROJECT_DIR = "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel"
BLENDER_DIR = os.path.join(PROJECT_DIR, "blender")
OUT_GLB_DIR = os.path.join(PROJECT_DIR, "addons/lorencia_town")

os.makedirs(BLENDER_DIR, exist_ok=True)
os.makedirs(OUT_GLB_DIR, exist_ok=True)


def gpos(gx, gy, gz):
    return mathutils.Vector((float(gx), float(-gz), float(gy)))


def assign_world_uvs(bm, faces, tile_scale=0.22):
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


def add_box(bm, gx, gy, gz, sx, sy, sz, rot_y_deg=0.0, taper_top=1.0, tile_scale=0.22):
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


def add_cylinder(bm, gx, gy, gz, rad_bot, rad_top, height, segs, rot_y_deg=0.0, tile_scale=0.22):
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


def add_swept_tube(bm, pts_3d, rad_x, rad_y, sides=8, close_loop=False, radii_scale=None, tile_scale=0.25):
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


def add_annulus_sector(bm, cx, cz, r_in, r_out, deg_start, deg_end, segs=12, y_bot=-0.06, y_top=0.0, tile_scale=0.22):
    """
    Builds a non-overlapping 3D polar cobblestone ring/sector slab in [r_in, r_out] x [deg_start, deg_end].
    Because adjacent sectors share exact boundaries and never overlap in interior area,
    Z-fighting is mathematically impossible!
    """
    top_in = []
    top_out = []
    bot_in = []
    bot_out = []
    for i in range(segs + 1):
        t = float(i) / float(segs)
        ang = math.radians(deg_start + t * (deg_end - deg_start))
        s_a = math.sin(ang)
        c_a = math.cos(ang)
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


def add_sculpted_foliage_cloud(bm, gx, gy, gz, rx, ry, rz, subdiv=2, seed=42, tile_scale=0.32):
    """
    Creates a smooth, volumetric Palia/Ghibli-style foliage cloud lobe from a subdivided
    icosphere with soft organic harmonic puffs (rendered with smooth vertex normals!).
    """
    ret = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    verts = ret["verts"]
    faces = list({f for v in verts for f in v.link_faces})
    center = gpos(gx, gy, gz)
    ph1 = (seed * 1.37) % 6.28
    ph2 = (seed * 2.91) % 6.28
    for v in verts:
        nx, ny, nz = v.co.x, v.co.y, v.co.z
        # Soft organic cloud puffs so it looks like billowy painted leaf clusters, never a geometric primitive
        puff = 1.0 + 0.14 * math.sin(nx * 3.2 + ph1) * math.cos(ny * 3.2 + ph2) + 0.08 * math.sin(nz * 4.0 + nx * 2.5)
        # Flatten the bottom slightly like real sunlit cumulus tree boughs
        z_squash = 0.72 if nz < 0.0 else 1.05
        v.co = center + mathutils.Vector((nx * rx * puff, ny * rz * puff, nz * ry * puff * z_squash))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    assign_world_uvs(bm, faces, tile_scale=tile_scale)


def add_palia_oak_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=1.0, seed=101):
    """
    Builds a high-detail, organic Palia-style village oak tree with:
    - 4 curved root buttresses flaring into the earth
    - Smooth-shaded S-curved gnarled trunk & 4 sweeping primary limbs
    - 13 overlapping subdivided icosphere leaf-cloud lobes in two sunlit/shaded canopy layers
    """
    rng = random.Random(seed)
    # 1. Curved Main Trunk Spline
    lean_x = rng.uniform(-0.35, 0.35) * scale
    lean_z = rng.uniform(-0.35, 0.35) * scale
    trunk_pts = [
        (gx, gy - 0.1, gz),
        (gx + lean_x * 0.3, gy + 1.0 * scale, gz + lean_z * 0.3),
        (gx + lean_x * 0.8, gy + 2.2 * scale, gz + lean_z * 0.8),
        (gx + lean_x, gy + 3.4 * scale, gz + lean_z),
    ]
    add_swept_tube(bm_wood, trunk_pts, 0.48 * scale, 0.48 * scale, sides=10, radii_scale=[1.35, 0.92, 0.72, 0.54])

    # 2. 4 Flared Root Buttresses at the base
    for r_i in range(4):
        ang = math.radians(r_i * 90.0 + rng.uniform(-18.0, 18.0))
        dx, dz = math.cos(ang), math.sin(ang)
        root_pts = [
            (gx + dx * 0.95 * scale, gy - 0.08, gz + dz * 0.95 * scale),
            (gx + dx * 0.52 * scale, gy + 0.35 * scale, gz + dz * 0.52 * scale),
            (gx + dx * 0.18 * scale, gy + 1.15 * scale, gz + dz * 0.18 * scale),
        ]
        add_swept_tube(bm_wood, root_pts, 0.22 * scale, 0.22 * scale, sides=7, radii_scale=[0.45, 0.85, 1.0])

    # 3. 4 Sweeping Primary Branches & Multi-Tiered Billowing Foliage Clouds
    top_x, top_y, top_z = trunk_pts[-1]
    branch_dirs = [
        (-1.45, 0.85),
        (1.48, 0.78),
        (-0.85, -1.35),
        (1.10, -1.25),
    ]
    for b_idx, (bx_d, bz_d) in enumerate(branch_dirs):
        end_x = top_x + bx_d * scale
        end_y = top_y + rng.uniform(1.05, 1.45) * scale
        end_z = top_z + bz_d * scale
        b_pts = [
            (top_x, top_y - 0.3 * scale, top_z),
            (0.5 * (top_x + end_x), top_y + 0.45 * scale, 0.5 * (top_z + end_z)),
            (end_x, end_y, end_z),
        ]
        add_swept_tube(bm_wood, b_pts, 0.24 * scale, 0.24 * scale, sides=8, radii_scale=[1.0, 0.72, 0.40])
        # Lower shaded canopy cloud + upper sunlit canopy cloud on each bough
        add_sculpted_foliage_cloud(bm_fol_shade, end_x, end_y - 0.15 * scale, end_z, 1.75 * scale, 1.15 * scale, 1.65 * scale, subdiv=2, seed=seed + b_idx * 7)
        add_sculpted_foliage_cloud(bm_fol_lit, end_x * 0.92 + gx * 0.08, end_y + 0.48 * scale, end_z * 0.92 + gz * 0.08, 1.55 * scale, 1.05 * scale, 1.50 * scale, subdiv=2, seed=seed + b_idx * 13)

    # Central Main Canopy Crown Clouds
    add_sculpted_foliage_cloud(bm_fol_shade, top_x, top_y + 0.85 * scale, top_z, 2.35 * scale, 1.35 * scale, 2.25 * scale, subdiv=2, seed=seed + 51)
    add_sculpted_foliage_cloud(bm_fol_lit, top_x, top_y + 1.55 * scale, top_z, 2.05 * scale, 1.25 * scale, 1.95 * scale, subdiv=2, seed=seed + 63)
    add_sculpted_foliage_cloud(bm_fol_lit, top_x - 0.55 * scale, top_y + 1.95 * scale, top_z + 0.35 * scale, 1.45 * scale, 0.95 * scale, 1.40 * scale, subdiv=2, seed=seed + 79)


def add_palia_cypress_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx, gy, gz, scale=1.0, seed=202):
    """
    Builds the slender, tapered conical Italian Cypress trees seen around the Palia
    fountain square and entrance steps in image.png!
    """
    add_cylinder(bm_wood, gx, gy, gz, 0.18 * scale, 0.12 * scale, 1.2 * scale, 8)
    tiers = [
        (0.75, 0.78, 1.15, False),
        (1.45, 0.68, 1.10, True),
        (2.15, 0.56, 1.05, False),
        (2.80, 0.42, 0.95, True),
        (3.40, 0.26, 0.85, True),
    ]
    for idx, (ty, rad, th, is_lit) in enumerate(tiers):
        target = bm_fol_lit if is_lit else bm_fol_shade
        add_sculpted_foliage_cloud(target, gx, gy + ty * scale, gz, rad * scale, th * 0.65 * scale, rad * scale, subdiv=2, seed=seed + idx * 11)


def add_flower_bush_cluster(bm_fol_shade, bm_flw_purple, bm_flw_pink, bm_flw_white, gx, gy, gz, scale=1.0, seed=303):
    """
    Builds a lush flowering garden shrub with purple lupine spikes and pink/white
    hydrangea clusters (matching the flower beds in the foreground & fountain ring of image.png!).
    """
    rng = random.Random(seed)
    add_sculpted_foliage_cloud(bm_fol_shade, gx, gy + 0.28 * scale, gz, 0.72 * scale, 0.42 * scale, 0.68 * scale, subdiv=1, seed=seed)
    # Purple lupine vertical flower spikes
    for _ in range(3):
        lx = gx + rng.uniform(-0.38, 0.38) * scale
        lz = gz + rng.uniform(-0.38, 0.38) * scale
        add_cylinder(bm_flw_purple, lx, gy + 0.35 * scale, lz, 0.11 * scale, 0.03 * scale, 0.55 * scale, 6)
    # Pink & white hydrangea puffs
    for bm_f in (bm_flw_pink, bm_flw_white):
        fx = gx + rng.uniform(-0.42, 0.42) * scale
        fz = gz + rng.uniform(-0.42, 0.42) * scale
        add_sculpted_foliage_cloud(bm_f, fx, gy + 0.45 * scale, fz, 0.22 * scale, 0.18 * scale, 0.22 * scale, subdiv=1, seed=seed + 19)


def add_palia_chalice_fountain(
    bm_stone, bm_stucco, bm_wood, bm_water, bm_fol_lit, bm_fol_shade,
    bm_flw_purple, bm_flw_pink, bm_flw_white, fx=0.0, fz=11.5
):
    """
    Directly modeled after the centerpiece fountain in Palia's Kilima Village Square (image.png):
    - Circular stone-and-timber bench ring (r = 4.2m) with 4 cardinal bench segments
    - Lush circular flower & water garden pool at the base
    - 4 curved white-stone buttress legs arching upward to hold the giant mossy
      wood-and-stone Chalice Bowl at y = 2.4m..3.7m with hanging green moss fronds!
    """
    # Inner water pool & stone curb ring (r = 3.6m)
    add_cylinder(bm_stone, fx, 0.0, fz, 3.85, 3.70, 0.36, 24)
    add_cylinder(bm_water, fx, 0.28, fz, 3.45, 3.45, 0.10, 24)
    # Central rocky mound inside the basin covered in flowers & shrubs
    add_sculpted_foliage_cloud(bm_stone, fx, 0.35, fz, 2.2, 0.65, 2.2, subdiv=2, seed=701)
    for i in range(8):
        ang = (float(i) / 8.0) * 2.0 * math.pi
        add_flower_bush_cluster(
            bm_fol_shade, bm_flw_purple, bm_flw_pink, bm_flw_white,
            fx + math.cos(ang) * 2.35, 0.25, fz + math.sin(ang) * 2.35,
            scale=0.88, seed=710 + i
        )

    # 4 Curved Wooden-and-Stone Park Benches around the Fountain Rim (r = 4.25m)
    for b_deg in [45.0, 135.0, 225.0, 315.0]:
        add_annulus_sector(bm_stone, fx, fz, 3.85, 4.45, b_deg - 26.0, b_deg + 26.0, segs=6, y_bot=0.0, y_top=0.44)
        add_annulus_sector(bm_wood, fx, fz, 3.82, 4.52, b_deg - 27.0, b_deg + 27.0, segs=6, y_bot=0.44, y_top=0.52)

    # ★ 4 ANGLED WHITE-STONE BUTTRESS LEGS holding up the Elevated Chalice Basin ★
    for leg_i in range(4):
        ang = math.radians(45.0 + leg_i * 90.0)
        dx, dz = math.cos(ang), math.sin(ang)
        leg_pts = [
            (fx + dx * 3.15, 0.15, fz + dz * 3.15),
            (fx + dx * 2.45, 1.35, fz + dz * 2.45),
            (fx + dx * 1.65, 2.55, fz + dz * 1.65),
            (fx + dx * 1.25, 3.05, fz + dz * 1.25),
        ]
        add_swept_tube(bm_stucco, leg_pts, 0.42, 0.46, sides=8, radii_scale=[1.15, 0.95, 0.85, 0.75])

    # ★ ELEVATED CARVED WOOD-&-STONE CHALICE BOWL (y = 2.35m..3.75m) ★
    add_cylinder(bm_stone, fx, 2.25, fz, 1.25, 1.95, 0.65, 16)
    add_cylinder(bm_wood, fx, 2.85, fz, 1.95, 2.25, 0.85, 16)
    add_cylinder(bm_stone, fx, 3.65, fz, 2.32, 2.28, 0.14, 16)
    add_cylinder(bm_water, fx, 3.55, fz, 2.05, 2.05, 0.12, 16)

    # Cascading Green Moss & Ivy Garlands hanging over the rim of the Chalice Bowl!
    for m_i in range(7):
        ang = (float(m_i) / 7.0) * 2.0 * math.pi + 0.3
        mx = fx + math.cos(ang) * 2.15
        mz = fz + math.sin(ang) * 2.15
        add_sculpted_foliage_cloud(bm_fol_lit if (m_i % 2 == 0) else bm_fol_shade, mx, 3.25, mz, 0.62, 0.78, 0.62, subdiv=1, seed=800 + m_i)


def add_palia_rope_lantern_post(bm_wood, bm_gold, bm_iron, bm_ember, gx, gy, gz, facing_x=1.0, facing_z=0.0):
    """
    Directly modeled after the foreground wooden lantern posts in image.png:
    - Heavy square walnut timber post with beveled cap
    - 3D golden-hemp rope coils wrapped around the upper post
    - Iron & timber brackets suspending glowing warm-yellow teardrop/bell lanterns!
    """
    add_box(bm_wood, gx, gy, gz, 0.46, 0.45, 0.46)
    add_box(bm_wood, gx, gy + 0.45, gz, 0.34, 4.35, 0.34)
    add_box(bm_wood, gx, gy + 4.80, gz, 0.44, 0.16, 0.44, taper_top=0.75)

    # 3D Rope Coils wrapped around the timber post at y = 3.85..4.35
    for r_y in [3.90, 4.02, 4.14, 4.26]:
        add_cylinder(bm_gold, gx, gy + r_y, gz, 0.25, 0.25, 0.09, 10)

    # Bracket arm & hanging warm golden bell lantern
    bx = gx + facing_x * 0.65
    bz = gz + facing_z * 0.65
    add_box(bm_iron, gx + facing_x * 0.32, gy + 4.10, gz + facing_z * 0.32, 0.72 if abs(facing_x) > 0.5 else 0.10, 0.09, 0.72 if abs(facing_z) > 0.5 else 0.10)
    add_cylinder(bm_iron, bx, gy + 3.92, bz, 0.24, 0.06, 0.18, 10)
    # Teardrop glowing paper/glass bell lantern
    add_sculpted_foliage_cloud(bm_ember, bx, gy + 3.58, bz, 0.26, 0.36, 0.26, subdiv=1, seed=91)


def add_festoon_lantern_string(bm_iron, bm_ember, p0, p1, sag=0.75, num_lanterns=3):
    """
    Strings an overhead catenary cable with glowing golden bell lanterns between two posts
    (matching the overhead hanging lanterns in the foreground of image.png!).
    """
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
        add_sculpted_foliage_cloud(bm_ember, lx, ly - 0.42, lz, 0.24, 0.34, 0.24, subdiv=1, seed=120 + l_i)


def add_palia_grand_town_hall_and_clocktower(
    bm_stucco, bm_stone, bm_wood, bm_terracotta, bm_gold, bm_iron, bm_glass, bm_ember,
    gx=0.0, gz=-7.2
):
    """
    Directly modeled after the Grand Curved-Gable Town Hall & White Clocktower Spire
    at the top of Palia's Kilima Village Square in image.png & image-2.png!
    """
    # 1. Wide Stepped Stone Terrace & Entrance Staircase (z = -2.2 to -11.5)
    add_box(bm_stone, gx, 0.0, gz, 19.5, 0.75, 8.8)
    for st_i in range(4):
        add_box(bm_stone, gx, 0.0, gz + 4.4 + (3 - st_i) * 0.65, 6.8, (st_i + 1) * 0.18, 0.70)

    # 2. Ground-Floor Half-Timbered Colonnade & Sweeping Terracotta Lower Eaves
    add_box(bm_stucco, gx, 0.75, gz, 17.6, 4.4, 7.4)
    # Dark-walnut vertical half-timber beams along the front facade
    for bx_o in [-8.4, -5.6, -2.8, 2.8, 5.6, 8.4]:
        add_box(bm_wood, gx + bx_o, 0.75, gz + 3.72, 0.38, 4.4, 0.38)
    add_box(bm_wood, gx, 4.95, gz + 3.72, 18.0, 0.36, 0.42)
    # Arched Ground-Floor Windows
    for wx_o in [-7.0, -4.2, 4.2, 7.0]:
        add_3d_mullioned_window_z(bm_glass, bm_iron, bm_gold, gx + wx_o, 1.45, gz + 3.70, 2.1, 2.6)
    # Lower Terracotta Roof Skirt over the ground floor porch
    add_box(bm_terracotta, gx - 5.6, 5.15, gz + 2.2, 7.2, 1.45, 4.2, taper_top=0.72)
    add_box(bm_terracotta, gx + 5.6, 5.15, gz + 2.2, 7.2, 1.45, 4.2, taper_top=0.72)

    # ★ SWEEPING CURVED TIMBER ENTRANCE ARCH over the Town Hall Steps (image.png!) ★
    arch_pts = []
    for i in range(15):
        ang = (float(i) / 14.0) * math.pi
        ax = gx - math.cos(ang) * 3.2
        ay = 3.2 + math.sin(ang) * 3.4
        arch_pts.append((ax, ay, gz + 4.2))
    add_swept_tube(bm_wood, arch_pts, 0.34, 0.38, sides=8)
    add_swept_tube(bm_terracotta, [(p[0], p[1] + 0.32, p[2] - 0.3) for p in arch_pts], 0.45, 0.25, sides=6)

    # 3. Second Story Cream-Stucco & Half-Timbered Gable Hall (y = 5.15..10.4)
    add_box(bm_stucco, gx, 5.15, gz - 0.3, 14.4, 4.8, 6.2)
    for wx_2 in [-5.0, -2.8, 2.8, 5.0]:
        add_3d_mullioned_window_z(bm_glass, bm_iron, bm_gold, gx + wx_2, 6.1, gz + 2.82, 1.45, 2.1)
    for bx_2 in [-6.8, -3.9, -1.6, 1.6, 3.9, 6.8]:
        add_box(bm_wood, gx + bx_2, 5.15, gz + 2.84, 0.34, 4.8, 0.34)

    # ★ MASSIVE SEMICIRCULAR CURVED-TIMBER MAIN GABLE ROOF (image.png!) ★
    gable_pts = []
    for i in range(17):
        ang = (float(i) / 16.0) * math.pi
        rx = gx - math.cos(ang) * 7.8
        ry = 8.8 + math.sin(ang) * 4.4
        gable_pts.append((rx, ry, gz + 3.0))
    add_swept_tube(bm_wood, gable_pts, 0.44, 0.48, sides=8)
    # Terracotta main roof volume behind the curved timber gable arch
    add_cylinder(bm_terracotta, gx, 9.2, gz - 0.3, 7.4, 4.2, 3.8, 12)

    # ★ SOARING WHITE-STUCCO & TIMBER CLOCKTOWER SPIRE (y = 11.5..23.5, image.png & image-2.png!) ★
    add_box(bm_wood, gx, 11.2, gz - 0.2, 4.4, 3.2, 4.2)
    add_3d_mullioned_window_z(bm_glass, bm_iron, bm_gold, gx, 11.8, gz + 1.92, 2.2, 1.9)
    # Tall Cylindrical White-Stucco Tower Shaft
    add_cylinder(bm_stucco, gx, 14.4, gz - 0.2, 1.95, 1.75, 5.4, 16)
    add_cylinder(bm_wood, gx, 16.6, gz - 0.2, 2.05, 2.02, 0.28, 16)
    add_cylinder(bm_wood, gx, 19.6, gz - 0.2, 2.15, 2.25, 1.25, 16)
    # Glowing Golden Clock Face on the South side of the Clocktower
    add_cylinder(bm_ember, gx, 19.8, gz + 1.95, 0.72, 0.72, 0.16, 12)
    add_cylinder(bm_gold, gx, 19.75, gz + 1.90, 0.85, 0.85, 0.12, 12)
    # Flared Conical Terracotta Clocktower Roof Spire
    add_cylinder(bm_terracotta, gx, 20.85, gz - 0.2, 2.85, 0.12, 3.2, 16)
    add_cylinder(bm_gold, gx, 24.0, gz - 0.2, 0.16, 0.03, 0.85, 8)


def add_3d_mullioned_window_z(bm_glass, bm_iron, bm_gold, gx, gy, gz, width_x, height):
    """Window facing South/North (+Z / -Z)."""
    add_box(bm_glass, gx, gy, gz, width_x, height, 0.10)
    add_box(bm_iron, gx - width_x * 0.48, gy, gz, 0.09, height, 0.16)
    add_box(bm_iron, gx + width_x * 0.48, gy, gz, 0.09, height, 0.16)
    add_box(bm_iron, gx, gy + height - 0.08, gz, width_x, 0.09, 0.16)
    add_box(bm_iron, gx, gy, gz, width_x, 0.09, 0.16)
    add_box(bm_iron, gx, gy, gz, 0.07, height, 0.15)
    for frac in [0.35, 0.68]:
        add_box(bm_iron, gx, gy + height * frac, gz, width_x, 0.07, 0.15)


def add_palia_windmill_and_east_village(
    bm_stucco, bm_stone, bm_wood, bm_terracotta, bm_gold, bm_iron, bm_glass, bm_water, bm_ember,
    gx=24.5, gz=13.5
):
    """
    Directly inspired by the right side of image-2.png:
    - Raised wooden deck porch with railings, stacked oak barrels, and the open-air
      Apothecary & Vault merchant counters
    - Warm terracotta-roofed half-timbered village cottages with curved roof ridges
    - Iconic cylindrical white-stucco Windmill Tower with 6 wooden-and-canvas sails!
    """
    # Raised Wooden Deck Porch along x = 18.2..23.5, z = 2.0..20.5
    add_box(bm_stone, 20.5, 0.0, 11.2, 6.2, 0.18, 19.5)
    add_box(bm_wood, 20.5, 0.18, 11.2, 6.0, 0.08, 19.2)

    # Half-Timbered East Village Hall behind the porch (x = 26.2)
    add_box(bm_stone, 26.5, 0.0, 11.2, 6.6, 1.15, 18.5)
    add_box(bm_stucco, 26.5, 1.15, 11.2, 6.2, 4.8, 18.0)
    for z_beam in range(3, 21, 3):
        add_box(bm_wood, 23.35, 1.15, float(z_beam), 0.36, 4.8, 0.36)
    add_box(bm_wood, 23.35, 5.75, 11.2, 0.40, 0.36, 18.4)
    # Sweeping Terracotta Pitched Roofs
    add_box(bm_terracotta, 26.5, 5.95, 11.2, 7.6, 2.8, 19.2, taper_top=0.52)
    add_box(bm_wood, 26.5, 8.70, 11.2, 0.45, 0.42, 19.6)

    # ★ ICONIC PALIA WINDMILL TOWER & 6 SAILS at (23.2, 0.0, 16.8) (image-2.png right side!) ★
    wx, wz = 23.2, 16.8
    add_cylinder(bm_stone, wx, 0.0, wz, 2.65, 2.45, 2.2, 12)
    add_cylinder(bm_stucco, wx, 2.2, wz, 2.35, 1.95, 6.4, 14)
    for b_i in range(6):
        ang = (float(b_i) / 6.0) * 2.0 * math.pi
        add_box(bm_wood, wx + math.cos(ang) * 2.15, 2.2, wz + math.sin(ang) * 2.15, 0.28, 6.4, 0.28)
    add_cylinder(bm_wood, wx, 8.5, wz, 2.25, 2.25, 0.45, 14)
    add_cylinder(bm_terracotta, wx, 8.95, wz, 2.65, 0.15, 2.2, 14)

    # Windmill Rotor Hub facing West-Northwest toward the Town Square
    hub_x, hub_y, hub_z = wx - 2.15, 7.8, wz
    add_cylinder(bm_wood, hub_x, hub_y - 0.35, hub_z, 0.45, 0.45, 0.70, 10)
    for sail_i in range(6):
        s_ang = math.radians(sail_i * 60.0 + 15.0)
        dy = math.sin(s_ang)
        dz = math.cos(s_ang)
        # Wooden sail spar (4.8m long)
        spar_pts = [
            (hub_x - 0.2, hub_y + dy * 0.4, hub_z + dz * 0.4),
            (hub_x - 0.5, hub_y + dy * 4.8, hub_z + dz * 4.8),
        ]
        add_swept_tube(bm_wood, spar_pts, 0.11, 0.11, sides=6)
        # Cream canvas sail blade along the spar
        blade_pts = [
            (hub_x - 0.35, hub_y + dy * 1.4, hub_z + dz * 1.4),
            (hub_x - 0.52, hub_y + dy * 4.6, hub_z + dz * 4.6),
        ]
        add_swept_tube(bm_stucco, blade_pts, 0.06, 0.52, sides=4)

    # Open-Air Apothecary Counter (+18.2, 0.26, 5.2) & Vault Chests (+18.8, 0.26, 15.8) on the Wooden Porch!
    add_box(bm_wood, 18.2, 0.26, 5.2, 1.10, 0.92, 5.6)
    add_box(bm_wood, 18.2, 1.16, 5.2, 1.26, 0.11, 5.8)
    for pz_c in [-1.8, 0.0, 1.8]:
        add_cylinder(bm_water if pz_c == 0.0 else bm_ember, 18.2, 1.27, 5.2 + pz_c, 0.22, 0.12, 0.45, 8)

    for cz_o in [-2.2, 0.0, 2.2]:
        add_box(bm_wood, 19.2, 0.26, 15.8 + cz_o, 1.12, 0.84, 1.50)
        add_box(bm_gold, 19.2, 0.68, 15.8 + cz_o, 1.18, 0.16, 1.56)


def add_palia_west_tavern_and_forge(
    bm_stucco, bm_stone, bm_wood, bm_terracotta, bm_roof_violet, bm_gold, bm_iron, bm_glass, bm_water, bm_ember
):
    """
    Builds the West Village District in cozy Palia half-timbered style:
    - Lumen's Half-Timbered Tavern Cottage & Covered Wooden Porch (-21.5, 0, 4.2)
    - Hanzo's Open-Beam Village Blacksmith Forge & River-Stone Chimney (-22.5, 0, 16.8)
      with the 0.94m Anvil at (-17.8, 0, 16.5)!
    """
    # 1. Lumen's Half-Timbered Village Tavern Cottage (-26.5, 0, 4.2) & Open Porch (-21.5, 0, 4.2)
    add_box(bm_stone, -26.8, 0.0, 4.2, 6.4, 1.1, 10.6)
    add_box(bm_stucco, -26.8, 1.1, 4.2, 6.0, 4.6, 10.2)
    add_box(bm_roof_violet, -26.8, 5.7, 4.2, 7.2, 2.7, 11.2, taper_top=0.48)
    add_box(bm_wood, -26.8, 8.35, 4.2, 0.44, 0.40, 11.6)

    # Open-Air Tavern Wooden Deck & Bar Counter (-21.5, 0, 3.8)
    tx, tz = -21.5, 3.8
    add_box(bm_wood, tx, 0.0, tz, 8.6, 0.16, 8.4)
    add_box(bm_wood, tx - 0.2, 0.16, tz - 1.1, 5.2, 0.86, 0.86)
    add_box(bm_wood, tx - 0.2, 1.00, tz - 1.1, 5.45, 0.11, 1.02)
    add_box(bm_gold, tx - 0.2, 0.94, tz - 1.1, 5.48, 0.06, 1.04)
    add_box(bm_wood, tx - 2.4, 0.16, tz + 0.7, 0.86, 0.86, 3.2)
    add_box(bm_wood, tx - 2.4, 1.00, tz + 0.7, 1.02, 0.11, 3.35)
    for mx_o in [-1.4, 0.0, 1.3]:
        add_cylinder(bm_ember, tx + mx_o, 1.11, tz - 1.1, 0.12, 0.10, 0.26, 6)
    for kz in [-2.0, -0.3, 1.4]:
        add_cylinder(bm_wood, tx - 3.6, 0.52, tz + kz, 0.46, 0.46, 0.98, 10)
        add_cylinder(bm_gold, tx - 3.6, 0.68, tz + kz, 0.48, 0.48, 0.08, 10)
        add_cylinder(bm_gold, tx - 3.6, 1.14, tz + kz, 0.48, 0.48, 0.08, 10)
    for t_z in [1.0, 3.0]:
        tbx, tbz = tx + 1.6, tz + t_z
        add_box(bm_wood, tbx, 0.16, tbz, 2.2, 0.64, 1.10)
        add_box(bm_wood, tbx, 0.78, tbz, 2.4, 0.09, 1.25)
        add_box(bm_wood, tbx, 0.16, tbz - 0.85, 2.1, 0.42, 0.38)
        add_box(bm_wood, tbx, 0.16, tbz + 0.85, 2.1, 0.42, 0.38)

    # 2. Hanzo's Half-Timbered Blacksmith Forge Cottage & Open Smelting Hearth (-22.5, 0, 16.8)
    sx, sz = -22.5, 16.8
    add_box(bm_stone, -26.8, 0.0, sz, 6.2, 1.2, 9.6)
    add_box(bm_stucco, -26.8, 1.2, sz, 5.8, 4.4, 9.2)
    add_box(bm_terracotta, -26.8, 5.6, sz, 7.0, 2.6, 10.2, taper_top=0.48)
    # Stone Smelting Furnace & Tall Chimney
    add_box(bm_stone, sx - 2.2, 0.0, sz, 2.8, 4.5, 4.2)
    add_cylinder(bm_stone, sx - 2.4, 4.5, sz, 0.92, 0.72, 4.8, 10)
    add_box(bm_ember, sx - 0.85, 0.82, sz, 0.40, 1.30, 2.00)

    # ★ TRUE-SCALE 1:1 BLACKSMITH ANVIL at (-17.8, 0.0, 16.5) ★
    ax, az = -17.8, 16.5
    add_cylinder(bm_stone, ax, 0.0, az, 0.82, 0.74, 0.16, 10)
    add_cylinder(bm_wood, ax, 0.16, az, 0.54, 0.50, 0.46, 10)
    add_cylinder(bm_gold, ax, 0.40, az, 0.56, 0.56, 0.08, 10)
    add_box(bm_iron, ax, 0.62, az, 0.68, 0.18, 0.94)
    add_box(bm_iron, ax, 0.80, az, 0.52, 0.24, 1.38)
    add_box(bm_iron, ax, 0.88, az + 0.82, 0.32, 0.14, 0.48, taper_top=0.6)
    add_box(bm_ember, ax, 1.04, az - 0.1, 0.24, 0.07, 0.50)

    add_box(bm_stone, sx + 1.2, 0.0, sz + 2.8, 1.20, 0.72, 2.25)
    add_box(bm_water, sx + 1.2, 0.66, sz + 2.8, 0.92, 0.10, 1.92)
    for wz_r in [-3.0, 3.0]:
        add_box(bm_wood, sx + 0.4, 0.0, sz + wz_r, 2.4, 1.88, 0.34)
        add_box(bm_iron, sx + 0.4, 0.74, sz + wz_r, 2.0, 0.96, 0.14)


def bake_lol_edge_highlights_and_crevices(bm, top_highlight=1.18, crevice_dark=0.66):
    """
    Point 2 of the League of Legends Pipeline:
    Bakes soft hand-painted highlights onto top/convex edges and darker tones into
    crevices and ground-contact bases directly into vertex colors (COLOR_0) so the
    diffuse painting carries the 3D form without relying on harsh real-time engine lights!
    """
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

        # Base vertical painterly gradient (darker grounded base -> brighter crown)
        shade = 0.84 + 0.18 * h_ratio

        # Soft painted highlight on top convex edges!
        if has_up and has_side:
            shade = max(shade, top_highlight)
        elif has_up and h_ratio > 0.72:
            shade = max(shade, 1.08)

        # Darker painted tones in crevices, overhangs, and ground contact!
        if has_down and has_side:
            shade = min(shade, crevice_dark + 0.08)
        if v.co.z < 0.14 and has_side and not has_up:
            shade = min(shade, crevice_dark)

        # Warm sunlit highlight tint vs cool violet-umber crevice tint
        if shade >= 1.0:
            r = min(1.0, shade * 1.00)
            g = min(1.0, shade * 0.98)
            b = min(1.0, shade * 0.93)
        else:
            r = shade * 0.96
            g = shade * 0.95
            b = min(1.0, shade * 1.04)

        for loop in v.link_loops:
            loop[col_layer] = (r, g, b, 1.0)


def make_mesh_object(name, bm, mat, smooth_shading=False, top_hi=1.18, crev_dark=0.66):
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


def make_mat(name, color=(1, 1, 1, 1), tex_path=None, rough=0.86, metal=0.0, emission=None, emit_str=0.0):
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


def pick_tex(real_name, fallback_name):
    rp = os.path.join(BLENDER_DIR, real_name)
    if os.path.exists(rp):
        return rp
    return os.path.join(BLENDER_DIR, fallback_name)


def build_palia_kilima_lorencia_town():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    cobble_tex = pick_tex("T_Real_Palia_Cobble.png", "T_LoL_Mossy_Flagstones.png")
    grass_tex = pick_tex("T_LoL_Ground_Canvas_2K.png", "T_Real_Palia_Grass.png")
    terracotta_tex = pick_tex("T_Real_Palia_Terracotta.png", "T_Palia_Terracotta_Roof.png")
    wood_tex = pick_tex("T_Real_Palia_Wood.png", "T_LoL_Walnut_Wood.png")
    stucco_tex = pick_tex("T_Real_Palia_Stucco.png", "T_LoL_Weathered_Stone.png")
    stone_tex = pick_tex("T_Real_Palia_Stone.png", "T_LoL_Weathered_Stone.png")
    leaves_tex = pick_tex("T_Real_Palia_Leaves.png", "T_LoL_Rift_Terrain.png")

    mat_cobble = make_mat("MI_Palia_Cobblestone", color=(1.0, 0.98, 0.94, 1.0), tex_path=cobble_tex, rough=0.88)
    mat_grass = make_mat("MI_Palia_Meadow_Grass", color=(1.0, 0.98, 0.94, 1.0), tex_path=grass_tex, rough=0.90)
    mat_stucco = make_mat("MI_Palia_Cream_Stucco", color=(1.0, 0.97, 0.92, 1.0), tex_path=stucco_tex, rough=0.86)
    mat_stone = make_mat("MI_Palia_River_Stone", color=(0.94, 0.90, 0.84, 1.0), tex_path=stone_tex, rough=0.88)
    mat_terracotta = make_mat("MI_Palia_Terracotta_Roof", color=(1.0, 0.96, 0.92, 1.0), tex_path=terracotta_tex, rough=0.82)
    mat_roof_violet = make_mat("MI_Palia_Violet_Roof", color=(0.74, 0.62, 0.88, 1.0), tex_path=terracotta_tex, rough=0.84)
    mat_wood = make_mat("MI_Palia_Walnut_Wood", color=(1.0, 0.96, 0.92, 1.0), tex_path=wood_tex, rough=0.84)
    mat_iron = make_mat("MI_Palia_Wrought_Iron", color=(0.22, 0.26, 0.28, 1.0), rough=0.42, metal=0.35)
    mat_gold = make_mat("MI_Palia_Rope_And_Gold", color=(0.88, 0.72, 0.36, 1.0), rough=0.45, metal=0.25)
    mat_glass = make_mat("MI_Palia_Window_Glass", color=(0.34, 0.56, 0.68, 1.0), rough=0.22)
    mat_water = make_mat("MI_Lorencia_Water", color=(0.24, 0.80, 0.88, 1.0), rough=0.16, emission=(0.18, 0.70, 0.82, 1.0), emit_str=0.55)
    mat_ember = make_mat("MI_Lorencia_Ember", color=(1.0, 0.82, 0.34, 1.0), rough=0.30, emission=(1.0, 0.72, 0.22, 1.0), emit_str=1.45)
    mat_fol_lit = make_mat("MI_Palia_Foliage_Lit", color=(0.88, 0.98, 0.76, 1.0), tex_path=leaves_tex, rough=0.86)
    mat_fol_shade = make_mat("MI_Palia_Foliage_Shade", color=(0.56, 0.76, 0.48, 1.0), tex_path=leaves_tex, rough=0.88)
    mat_flw_purple = make_mat("MI_Palia_Flowers_Purple", color=(0.58, 0.34, 0.88, 1.0), rough=0.80)
    mat_flw_pink = make_mat("MI_Palia_Flowers_Pink", color=(0.94, 0.48, 0.72, 1.0), rough=0.80)
    mat_flw_white = make_mat("MI_Palia_Flowers_White", color=(0.98, 0.96, 0.90, 1.0), rough=0.80)

    bm_cobble = bmesh.new()
    bm_grass = bmesh.new()
    bm_stucco = bmesh.new()
    bm_stone = bmesh.new()
    bm_terracotta = bmesh.new()
    bm_roof_violet = bmesh.new()
    bm_wood = bmesh.new()
    bm_iron = bmesh.new()
    bm_gold = bmesh.new()
    bm_glass = bmesh.new()
    bm_water = bmesh.new()
    bm_ember = bmesh.new()
    bm_fol_lit = bmesh.new()
    bm_fol_shade = bmesh.new()
    bm_flw_purple = bmesh.new()
    bm_flw_pink = bmesh.new()
    bm_flw_white = bmesh.new()

    # ═══════════════════════════════════════════════════════════════════
    # 1. NON-TILED 1:1 PAINTED GROUND CANVAS & DISJOINT COBBLESTONE NETWORK
    #    (Point 3: Ground is a large painted plane mapped 1:1, NOT a repeating tile grid!)
    # ═══════════════════════════════════════════════════════════════════
    fx, fz = 0.0, 11.5
    # Map the 120m x 120m ground plane 1:1 (UV 0..1) onto T_LoL_Ground_Canvas_2K.png!
    ret_g = bmesh.ops.create_cube(bm_grass, size=1.0)
    g_verts = ret_g["verts"]
    g_faces = list({f for v in g_verts for f in v.link_faces})
    g_center = gpos(0.0, -0.15, -12.0)
    for v in g_verts:
        v.co = g_center + mathutils.Vector((v.co.x * 120.0, v.co.y * 120.0, v.co.z * 0.20))
    bmesh.ops.recalc_face_normals(bm_grass, faces=g_faces)
    uv_g = bm_grass.loops.layers.uv.active or bm_grass.loops.layers.uv.new("UVMap")
    for f in g_faces:
        for loop in f.loops:
            co = loop.vert.co
            u_c = max(0.0, min(1.0, (co.x + 60.0) / 120.0))
            # co.y = -gz -> gz = -co.y; canvas v_norm = (48.0 - gz) / 120.0 -> Blender UV V = 1.0 - v_norm
            gz_c = -co.y
            v_norm = max(0.0, min(1.0, (48.0 - gz_c) / 120.0))
            loop[uv_g].uv = (u_c, 1.0 - v_norm)

    # Point 3: Separate low-poly chiseled League of Legends cliff ledges & boulders with painted edge highlights!
    for rx, rz, rw, rd, rh, rseed in [
        (-22.5, -10.5, 4.2, 2.8, 1.65, 601),
        (22.5, -10.5, 4.2, 2.8, 1.65, 602),
        (-10.5, -18.5, 3.4, 2.4, 1.25, 603),
        (10.8, -19.5, 3.4, 2.4, 1.25, 604),
        (-12.5, -28.5, 3.8, 2.6, 1.55, 605),
        (12.8, -29.5, 3.8, 2.6, 1.55, 606),
        (-21.5, 25.5, 3.6, 2.4, 1.15, 607),
        (21.5, 25.5, 3.6, 2.4, 1.15, 608),
    ]:
        add_sculpted_foliage_cloud(bm_stone, rx, 0.25, rz, rw, rh, rd, subdiv=1, seed=rseed, tile_scale=0.22)

    # 1A. Inner Circular Cobblestone Ring-Walk around the Chalice Fountain (r = 4.5m .. 8.2m)
    add_annulus_sector(bm_cobble, fx, fz, 4.5, 8.2, 0.0, 360.0, segs=32, y_bot=-0.06, y_top=0.0, tile_scale=0.22)

    # 1B. 4 Cardinal Cobblestone Avenues connecting Inner Ring (r = 8.2m) to Outer Ring (r = 12.6m)
    #     Leaves 4 Crescent Green Lawn Garden Islands at NE, SE, SW, NW!
    for c_deg in [0.0, 90.0, 180.0, 270.0]:
        add_annulus_sector(bm_cobble, fx, fz, 8.2, 12.6, c_deg - 22.0, c_deg + 22.0, segs=6, y_bot=-0.06, y_top=0.0, tile_scale=0.22)

    # 1C. Low Curved Stone-&-Timber Garden Curbs & Flowering Plants inside the 4 Crescent Lawn Islands!
    for g_idx, g_deg in enumerate([45.0, 135.0, 225.0, 315.0]):
        add_annulus_sector(bm_stone, fx, fz, 8.25, 8.65, g_deg - 21.0, g_deg + 21.0, segs=6, y_bot=-0.05, y_top=0.28)
        add_annulus_sector(bm_stone, fx, fz, 12.15, 12.55, g_deg - 21.0, g_deg + 21.0, segs=6, y_bot=-0.05, y_top=0.28)
        ang_r = math.radians(g_deg)
        gx_mid = fx + math.sin(ang_r) * 10.4
        gz_mid = fz + math.cos(ang_r) * 10.4
        add_palia_cypress_tree(bm_wood, bm_fol_lit, bm_fol_shade, gx_mid, -0.05, gz_mid, scale=0.95, seed=500 + g_idx)
        for f_off in [-14.0, 14.0]:
            af = math.radians(g_deg + f_off)
            add_flower_bush_cluster(
                bm_fol_shade, bm_flw_purple, bm_flw_pink, bm_flw_white,
                fx + math.sin(af) * 10.2, -0.05, fz + math.cos(af) * 10.2,
                scale=1.05, seed=520 + g_idx * 3 + (1 if f_off > 0 else 0)
            )

    # 1D. Outer Circular Cobblestone Village Promenade Ring (r = 12.6m .. 16.6m)
    add_annulus_sector(bm_cobble, fx, fz, 12.6, 16.6, 0.0, 360.0, segs=36, y_bot=-0.06, y_top=0.0, tile_scale=0.22)

    # 1E. Outer District Forecourts (strictly outside r = 16.6m -> zero overlap with Outer Ring!)
    # South Arrival Forecourt (deg -26..+26, r = 16.6..21.5)
    add_annulus_sector(bm_cobble, fx, fz, 16.6, 21.5, -26.0, 26.0, segs=8, y_bot=-0.06, y_top=0.0, tile_scale=0.22)
    # East Windmill & Apothecary Forecourt (deg 52..128, r = 16.6..19.5)
    add_annulus_sector(bm_cobble, fx, fz, 16.6, 19.5, 52.0, 128.0, segs=10, y_bot=-0.06, y_top=0.0, tile_scale=0.22)
    # West Tavern & Blacksmith Forge Forecourt (deg 232..308, r = 16.6..21.5)
    add_annulus_sector(bm_cobble, fx, fz, 16.6, 21.5, 232.0, 308.0, segs=10, y_bot=-0.06, y_top=0.0, tile_scale=0.22)

    # 1F. Twin Northern Bypass Cobblestone Paths flanking the Grand Town Hall out to the North Bridge!
    #     (Deg 142..165 and 195..218 from r = 16.6..24.5, plus northern bridge approach!)
    add_annulus_sector(bm_cobble, fx, fz, 16.6, 24.5, 140.0, 162.0, segs=5, y_bot=-0.06, y_top=0.0, tile_scale=0.22)
    add_annulus_sector(bm_cobble, fx, fz, 16.6, 24.5, 198.0, 220.0, segs=5, y_bot=-0.06, y_top=0.0, tile_scale=0.22)
    # Northern Outskirts Path beyond the Village Bridge (z = -20.5 to -27.7) & Boss Colosseum (z = -42.0)
    add_box(bm_cobble, 0.0, -0.06, -24.1, 7.2, 0.06, 7.2, tile_scale=0.22)
    add_cylinder(bm_cobble, 0.0, -0.06, -42.0, 14.2, 14.0, 0.06, 16, rot_y_deg=11.25, tile_scale=0.22)

    # ═══════════════════════════════════════════════════════════════════
    # 2. CENTRAL PALIA 4-LEGGED CHALICE FOUNTAIN & FLOWER GARDEN (0, 0, 11.5)
    # ═══════════════════════════════════════════════════════════════════
    add_palia_chalice_fountain(
        bm_stone, bm_stucco, bm_wood, bm_water, bm_fol_lit, bm_fol_shade,
        bm_flw_purple, bm_flw_pink, bm_flw_white, fx=fx, fz=fz
    )

    # ═══════════════════════════════════════════════════════════════════
    # 3. GRAND CURVED-GABLE TOWN HALL & CLOCKTOWER SPIRE (0, 0, -7.2)
    # ═══════════════════════════════════════════════════════════════════
    add_palia_grand_town_hall_and_clocktower(
        bm_stucco, bm_stone, bm_wood, bm_terracotta, bm_gold, bm_iron, bm_glass, bm_ember,
        gx=0.0, gz=-7.2
    )

    # ═══════════════════════════════════════════════════════════════════
    # 4. EAST VILLAGE: 6-SAIL WINDMILL TOWER, WOODEN PORCH & APOTHECARY
    # ═══════════════════════════════════════════════════════════════════
    add_palia_windmill_and_east_village(
        bm_stucco, bm_stone, bm_wood, bm_terracotta, bm_gold, bm_iron, bm_glass, bm_water, bm_ember
    )

    # ═══════════════════════════════════════════════════════════════════
    # 5. WEST VILLAGE: LUMEN'S HALF-TIMBERED TAVERN & HANZO'S FORGE
    # ═══════════════════════════════════════════════════════════════════
    add_palia_west_tavern_and_forge(
        bm_stucco, bm_stone, bm_wood, bm_terracotta, bm_roof_violet, bm_gold, bm_iron, bm_glass, bm_water, bm_ember
    )

    # ═══════════════════════════════════════════════════════════════════
    # 6. ROPE-WRAPPED TIMBER LANTERN POSTS & OVERHEAD STRING BELL LANTERNS
    # ═══════════════════════════════════════════════════════════════════
    lantern_posts = [
        (-5.6, 20.2, 1.0, 0.0),
        (5.6, 20.2, -1.0, 0.0),
        (-5.6, 2.8, 1.0, 0.0),
        (5.6, 2.8, -1.0, 0.0),
        (-13.8, 14.5, 1.0, 0.0),
        (-13.8, 7.5, 1.0, 0.0),
        (13.8, 14.5, -1.0, 0.0),
        (13.8, 7.5, -1.0, 0.0),
    ]
    for lpx, lpz, lfx, lfz in lantern_posts:
        add_palia_rope_lantern_post(bm_wood, bm_gold, bm_iron, bm_ember, lpx, 0.0, lpz, facing_x=lfx, facing_z=lfz)

    # Overhead Festoon String Lanterns arching across the South & North Walkways and Side Lanes!
    add_festoon_lantern_string(bm_iron, bm_ember, (-5.6, 4.65, 20.2), (5.6, 4.65, 20.2), sag=0.85, num_lanterns=4)
    add_festoon_lantern_string(bm_iron, bm_ember, (-5.6, 4.65, 2.8), (5.6, 4.65, 2.8), sag=0.85, num_lanterns=4)
    add_festoon_lantern_string(bm_iron, bm_ember, (-13.8, 4.65, 14.5), (-13.8, 4.65, 7.5), sag=0.65, num_lanterns=3)
    add_festoon_lantern_string(bm_iron, bm_ember, (13.8, 4.65, 14.5), (13.8, 4.65, 7.5), sag=0.65, num_lanterns=3)

    # ═══════════════════════════════════════════════════════════════════
    # 7. HIGH-DETAIL SMOOTH-SHADED PALIA OAK TREES, CYPRESSES & FLOWER BEDS
    # ═══════════════════════════════════════════════════════════════════
    oak_placements = [
        # Framing the Grand Town Hall & Clocktower (just like image.png!)
        (-13.2, -4.5, 1.25, 101),
        (13.2, -4.5, 1.25, 102),
        (-17.8, -1.2, 1.15, 103),
        (17.8, -1.2, 1.15, 104),
        # Framing the South Village Square Entrance & Outer Promenade
        (-15.5, 22.8, 1.20, 105),
        (15.5, 22.8, 1.20, 106),
        (-9.8, 25.5, 1.10, 107),
        (9.8, 25.5, 1.10, 108),
        # Framing the Northern Hunting Valley & Bridge + Outer Meadow Grove
        (-12.5, -16.5, 1.30, 109),
        (12.5, -16.5, 1.30, 110),
        (-16.5, -26.5, 1.35, 111),
        (16.5, -26.5, 1.35, 112),
        (-26.5, -14.5, 1.45, 113),
        (26.5, -14.5, 1.45, 114),
        (-28.0, -28.0, 1.50, 115),
        (28.0, -28.0, 1.50, 116),
    ]
    for ox, oz, osc, oseed in oak_placements:
        add_palia_oak_tree(bm_wood, bm_fol_lit, bm_fol_shade, ox, -0.05, oz, scale=osc, seed=oseed)

    for cx_p, cz_p, csc, cseed in [
        (-8.8, -1.8, 1.1, 201),
        (8.8, -1.8, 1.1, 202),
        (-4.5, 21.8, 0.95, 203),
        (4.5, 21.8, 0.95, 204),
    ]:
        add_palia_cypress_tree(bm_wood, bm_fol_lit, bm_fol_shade, cx_p, -0.05, cz_p, scale=csc, seed=cseed)
        add_flower_bush_cluster(bm_fol_shade, bm_flw_purple, bm_flw_pink, bm_flw_white, cx_p, -0.05, cz_p + 1.2, scale=1.0, seed=cseed + 50)

    # ═══════════════════════════════════════════════════════════════════
    # 8. NORTHERN VILLAGE TIMBER BRIDGE (z = -12.5 to -20.5) & BOSS RUINS
    # ═══════════════════════════════════════════════════════════════════
    for pz_plank in range(-13, -21, -1):
        add_box(bm_wood, 0.0, 0.02, float(pz_plank) - 0.3, 6.8, 0.14, 0.86)
    for side in [-1.0, 1.0]:
        add_box(bm_stone, side * 3.45, -0.05, -16.5, 0.58, 0.52, 8.4)
        add_box(bm_wood, side * 3.45, 0.92, -16.5, 0.34, 0.16, 8.4)
        for post_z in [-13.0, -16.5, -20.0]:
            add_box(bm_wood, side * 3.45, -0.05, post_z, 0.48, 1.38, 0.48)
            add_sculpted_foliage_cloud(bm_ember, side * 3.45, 1.48, post_z, 0.22, 0.28, 0.22, subdiv=1, seed=900)

    # Ancient Boss Colosseum Columns at z = -42.0
    for i in range(12):
        ang = (float(i) / 12.0) * (2.0 * math.pi)
        if math.sin(ang) > 0.65:
            continue
        px = math.cos(ang) * 14.0
        pz = -42.0 + math.sin(ang) * 14.0
        h_pil = 6.2 if (i % 2 == 0) else 4.4
        add_cylinder(bm_stone, px, -0.05, pz, 0.90, 0.74, h_pil, 12)
        if i % 2 == 0:
            bx = math.cos(ang) * 12.0
            bz = -42.0 + math.sin(ang) * 12.0
            add_cylinder(bm_stone, bx, -0.05, bz, 0.48, 0.36, 1.35, 8)
            add_sculpted_foliage_cloud(bm_ember, bx, 1.50, bz, 0.32, 0.36, 0.32, subdiv=1, seed=950 + i)

    make_mesh_object("Lorencia_Mossy_Flagstones", bm_cobble, mat_cobble, smooth_shading=False)
    make_mesh_object("Lorencia_Rift_Terrain", bm_grass, mat_grass, smooth_shading=False)
    make_mesh_object("Lorencia_Stone_Wall", bm_stucco, mat_stucco, smooth_shading=True)
    make_mesh_object("Lorencia_Stone_Body", bm_stone, mat_stone, smooth_shading=True)
    make_mesh_object("Lorencia_Terracotta", bm_terracotta, mat_terracotta, smooth_shading=True)
    make_mesh_object("Lorencia_Mansard_Roofs", bm_roof_violet, mat_roof_violet, smooth_shading=True)
    make_mesh_object("Lorencia_Walnut_Wood", bm_wood, mat_wood, smooth_shading=True)
    make_mesh_object("Lorencia_Wrought_Iron", bm_iron, mat_iron, smooth_shading=True)
    make_mesh_object("Lorencia_Gold_Brass", bm_gold, mat_gold, smooth_shading=True)
    make_mesh_object("Lorencia_Window_Glass", bm_glass, mat_glass, smooth_shading=False)
    make_mesh_object("Lorencia_Water", bm_water, mat_water, smooth_shading=True)
    make_mesh_object("Lorencia_Embers", bm_ember, mat_ember, smooth_shading=True)
    # Smooth shading on all tree canopies & flowers so they look soft and volumetric like Palia!
    make_mesh_object("Lorencia_Foliage_Lit", bm_fol_lit, mat_fol_lit, smooth_shading=True)
    make_mesh_object("Lorencia_Foliage_Shade", bm_fol_shade, mat_fol_shade, smooth_shading=True)
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
    print("Exported Palia-Inspired Kilima/Lorencia Village Square v7:", blend_path, "->", glb_path)


build_palia_kilima_lorencia_town()
