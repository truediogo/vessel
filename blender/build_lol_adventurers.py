import bpy
import bmesh
import math
import mathutils
import os

# League of Legends-Style Heroic Stylized Adventurer Generator v2 (Blender 5.3.0)
# Uses bmesh.ops.bisect_plane for razor-clean, zero-sawtooth cloth/armor rims,
# full shoulder-to-neck Tunic & Mantle coverage, and smoothed rounded boot toe-boxes.

PROJECT_DIR = "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel"
CHARS_DIR = os.path.join(PROJECT_DIR, "addons/quaternius_chars")
BLENDER_DIR = os.path.join(PROJECT_DIR, "blender")
OUT_GLB_DIR = os.path.join(PROJECT_DIR, "addons/lol_adventurers")

os.makedirs(BLENDER_DIR, exist_ok=True)
os.makedirs(OUT_GLB_DIR, exist_ok=True)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def make_pbr_material(name, tex_path, roughness=0.75, metallic=0.05):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        tex_node = nodes.new("ShaderNodeTexImage")
        tex_node.image = bpy.data.images.load(tex_path)
        links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def bisect_keep(bm, plane_co, plane_no):
    """Slice all faces/edges in bm by plane (plane_co, plane_no) and delete geometry on the negative side of plane_no."""
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(
        bm,
        geom=geom,
        dist=0.00005,
        plane_co=plane_co,
        plane_no=plane_no,
        clear_inner=True,
        clear_outer=False,
    )


def create_clean_shell(base_obj, name, planes, extra_face_filter, displace_fn, uv_fn, mat, solidify_thickness=0.009, smooth_iters=2, smooth_filter=None):
    """Duplicate base_obj, slice cleanly along each (plane_co, plane_no) in planes using bisect_plane,
    apply optional extra_face_filter, smooth vertices, displace along normals, project UVs, and solidify."""
    bpy.ops.object.select_all(action="DESELECT")
    base_obj.select_set(True)
    bpy.context.view_layer.objects.active = base_obj
    bpy.ops.object.duplicate()
    piece = bpy.context.active_object
    piece.name = name
    piece.data.name = name + "_Mesh"

    bm = bmesh.new()
    bm.from_mesh(piece.data)

    # 1. Exact planar bisections (preserves interpolated bone weights along cut edges!)
    for p_co, p_no in planes:
        bisect_keep(bm, p_co, p_no)

    # 2. Optional extra face filter
    if extra_face_filter is not None:
        bm.faces.ensure_lookup_table()
        to_del = [f for f in bm.faces if not extra_face_filter(f.calc_center_median())]
        if to_del:
            bmesh.ops.delete(bm, geom=to_del, context="FACES")

    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")

    bm.normal_update()

    # 3. Optional vertex smoothing (e.g. to round out individual toes into a solid boot toe-box)
    if smooth_iters > 0:
        verts_to_smooth = [v for v in bm.verts if (smooth_filter is None or smooth_filter(v.co))]
        if verts_to_smooth:
            for _ in range(smooth_iters):
                bmesh.ops.smooth_vert(bm, verts=verts_to_smooth, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bm.normal_update()

    # 4. Displace vertices outward
    for v in bm.verts:
        v.co = displace_fn(v.co.copy(), v.normal.copy())

    bm.normal_update()

    # 5. Project clean UVs
    uv_layer = bm.loops.layers.uv.active
    if not uv_layer:
        uv_layer = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            loop[uv_layer].uv = uv_fn(loop.vert.co)

    bm.to_mesh(piece.data)
    bm.free()

    piece.data.materials.clear()
    piece.data.materials.append(mat)
    for poly in piece.data.polygons:
        poly.material_index = 0
        poly.use_smooth = True

    if solidify_thickness > 0.0001:
        sol = piece.modifiers.new(name="Solidify", type="SOLIDIFY")
        sol.thickness = solidify_thickness
        sol.offset = 1.0
        sol.use_rim = True
        bpy.context.view_layer.objects.active = piece
        bpy.ops.object.modifier_move_to_index(modifier=sol.name, index=0)
        bpy.ops.object.modifier_apply(modifier=sol.name)

    return piece


def build_adventurer(in_gltf, out_blend, out_glb, is_female=False, tunic_tex="", armor_tex=""):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=in_gltf)

    for obj in list(bpy.data.objects):
        if "icosphere" in obj.name.lower():
            bpy.data.objects.remove(obj, do_unlink=True)

    body_obj = next(o for o in bpy.data.objects if o.type == "MESH" and "superhero" in o.name.lower())
    mat_tunic = make_pbr_material("MI_Adventurer_Tunic", tunic_tex, roughness=0.82, metallic=0.02)
    mat_armor = make_pbr_material("MI_Adventurer_Armor", armor_tex, roughness=0.48, metallic=0.22)

    # Coordinate thresholds (Z is up, X is left/right, -Y is front)
    collar_top_z = 1.535 if not is_female else 1.488
    mantle_bot_z = 1.355 if not is_female else 1.310
    waist_z = 0.985 if not is_female else 0.960
    tunic_hem_z = 0.775 if not is_female else 0.755
    knee_z = 0.445 if not is_female else 0.430
    sleeve_x = 0.365 if not is_female else 0.305
    bracer_in_x = 0.455 if not is_female else 0.385
    bracer_out_x = 0.680 if not is_female else 0.618

    # ─── 0. HEROIC LEAGUE PROPORTION RESHAPE ON BASE BODY ───
    bm_base = bmesh.new()
    bm_base.from_mesh(body_obj.data)
    for v in bm_base.verts:
        co = v.co
        if co.z < 0.08:
            co.z = max(0.002, co.z + 0.009)
        if 1.15 <= co.z <= 1.52 and abs(co.x) < 0.34:
            t = (co.z - 1.15) / 0.37
            co.x *= (1.0 + 0.08 * t)
            co.y *= (1.0 + 0.05 * t)
        if abs(co.x) > 0.25 and 1.28 <= co.z <= 1.58:
            arm_z = 1.455 if not is_female else 1.418
            arm_y = 0.068 if not is_female else 0.055
            co.y = arm_y + (co.y - arm_y) * 1.14
            co.z = arm_z + (co.z - arm_z) * 1.14
        if co.z < 0.50:
            leg_x = (0.114 if not is_female else 0.111) * (1.0 if co.x >= 0 else -1.0)
            leg_y = 0.055 if co.z > 0.12 else 0.0
            co.x = leg_x + (co.x - leg_x) * 1.16
            if co.z > 0.12:
                co.y = leg_y + (co.y - leg_y) * 1.16
    bm_base.normal_update()
    bm_base.to_mesh(body_obj.data)
    bm_base.free()

    # ─── 1A. STARTER TUNIC (Full torso + shoulders + short sleeves, razor-clean bisected hem & cuffs) ───
    tunic_planes = [
        ((0, 0, tunic_hem_z), (0, 0, 1)),      # Flat laser-clean bottom tunic hem
        ((0, 0, collar_top_z), (0, 0, -1)),    # Flat collar top at base of neck
        ((sleeve_x, 0, 0), (-1, 0, 0)),        # Left short-sleeve cuff cut
        ((-sleeve_x, 0, 0), (1, 0, 0)),        # Right short-sleeve cuff cut
    ]
    def disp_tunic(co, n):
        if co.z < waist_z:
            t = clamp((waist_z - co.z) / (waist_z - tunic_hem_z), 0.0, 1.0)
            flare = 0.016 * (t ** 1.15)
            rad = mathutils.Vector((co.x * 1.15, (co.y - 0.02) * 1.25, 0.0))
            if rad.length > 0.001:
                rad.normalize()
                return co + n * 0.009 + rad * (0.006 + flare)
        cuff = 0.005 if abs(co.x) > (sleeve_x - 0.04) else 0.0
        return co + n * (0.010 + cuff)

    def uv_tunic(co):
        u = clamp((co.x + 0.40) / 0.80, 0.02, 0.98)
        t = clamp((co.z - tunic_hem_z) / (collar_top_z - tunic_hem_z), 0.0, 1.0)
        return (u, 0.425 + t * 0.555)

    create_clean_shell(body_obj, "Adventurer_Tunic", tunic_planes, None, disp_tunic, uv_tunic, mat_tunic, solidify_thickness=0.007, smooth_iters=2)

    # ─── 1B. ADVENTURER BREECHES (Laser-clean waist & below-knee cuts) ───
    breeches_planes = [
        ((0, 0, knee_z - 0.05), (0, 0, 1)),
        ((0, 0, waist_z + 0.02), (0, 0, -1)),
        ((0.24, 0, 0), (-1, 0, 0)),
        ((-0.24, 0, 0), (1, 0, 0)),
    ]
    def disp_breeches(co, n):
        bag = math.sin(clamp((co.z - (knee_z - 0.05)) / (waist_z - knee_z + 0.05), 0.0, 1.0) * math.pi) * 0.007
        return co + n * (0.007 + bag)

    def uv_breeches(co):
        u = clamp((co.x + 0.25) / 0.50, 0.02, 0.98)
        t = clamp((co.z - (knee_z - 0.05)) / (waist_z - (knee_z - 0.05)), 0.0, 1.0)
        return (u, 0.02 + t * 0.38)

    create_clean_shell(body_obj, "Adventurer_Breeches", breeches_planes, None, disp_breeches, uv_breeches, mat_tunic, solidify_thickness=0.005, smooth_iters=1)

    # ─── 2A. HEROIC SHOULDER MANTLE & COWL (Full shoulder & trap coverage up to neck!) ───
    # Slightly angled bottom cut (lower on back/chest, sweeping over shoulders) + clean collar top
    mantle_planes = [
        ((0, 0, mantle_bot_z), (0, 0, 1)),
        ((0, 0, collar_top_z + 0.012), (0, 0, -1)),
        ((sleeve_x - 0.025, 0, 0), (-1, -0.05, 0.18)),
        ((-sleeve_x + 0.025, 0, 0), (1, -0.05, 0.18)),
    ]
    def disp_mantle(co, n):
        t_top = clamp((co.z - mantle_bot_z) / (collar_top_z + 0.012 - mantle_bot_z), 0.0, 1.0)
        rim = 0.006 if (t_top < 0.16 or t_top > 0.84) else 0.0
        out = co + n * (0.017 + rim)
        out.x *= 1.06
        return out

    def uv_mantle(co):
        u = clamp((co.x + 0.38) / 0.76, 0.02, 0.98)
        t = clamp((co.z - mantle_bot_z) / (collar_top_z + 0.012 - mantle_bot_z), 0.0, 1.0)
        return (u, 0.755 + t * 0.235)

    create_clean_shell(body_obj, "Adventurer_Mantle", mantle_planes, None, disp_mantle, uv_mantle, mat_armor, solidify_thickness=0.011, smooth_iters=3)

    # ─── 2B. CHUNKY FOREARM BRACERS (Clean vertical bisections at elbow & wrist for both arms) ───
    for side_name, sign in [("L", 1.0), ("R", -1.0)]:
        b_planes = [
            ((0, 0, 1.25), (0, 0, 1)),
            ((0, 0, 1.62), (0, 0, -1)),
            ((sign * bracer_in_x, 0, 0), (sign * 1.0, 0, 0)),
            ((sign * bracer_out_x, 0, 0), (-sign * 1.0, 0, 0)),
        ]
        def disp_bracer(co, n):
            span = bracer_out_x - bracer_in_x
            t = clamp((abs(co.x) - bracer_in_x) / max(0.01, span), 0.0, 1.0)
            cuff_flare = 0.006 if (t < 0.18 or t > 0.82) else 0.0
            return co + n * (0.014 + cuff_flare)

        def uv_bracer(co):
            span = bracer_out_x - bracer_in_x
            t = clamp((abs(co.x) - bracer_in_x) / max(0.01, span), 0.0, 1.0)
            u = clamp((co.y + 0.16) / 0.32, 0.02, 0.98)
            return (u, 0.505 + t * 0.235)

        create_clean_shell(body_obj, "Adventurer_Bracers_" + side_name, b_planes, None, disp_bracer, uv_bracer, mat_armor, solidify_thickness=0.010, smooth_iters=2)

    # ─── 2C. WIDE BUCKLED BELT (Clean V-angled top & bottom planes for League fantasy belt silhouette!) ───
    belt_low = waist_z - 0.048
    belt_high = waist_z + 0.042
    belt_planes = [
        ((0, 0, belt_low), (0, 0, 1)),
        ((0, 0, belt_high), (0, 0, -1)),
        ((0.23, 0, 0), (-1, 0, 0)),
        ((-0.23, 0, 0), (1, 0, 0)),
    ]
    def disp_belt(co, n):
        buckle = 0.009 if (co.y < -0.05 and abs(co.x) < 0.055) else 0.0
        rad = mathutils.Vector((co.x * 1.15, (co.y - 0.02) * 1.22, 0.0))
        if rad.length > 0.001:
            rad.normalize()
        return co + n * 0.011 + rad * (0.011 + buckle)

    def uv_belt(co):
        if co.y < 0.02:
            u = clamp(0.5 + (co.x / 0.32), 0.05, 0.95)
        else:
            u = 0.05 if co.x < 0 else 0.95
        t = clamp((co.z - belt_low) / (belt_high - belt_low), 0.0, 1.0)
        return (u, 0.255 + t * 0.235)

    create_clean_shell(body_obj, "Adventurer_Belt", belt_planes, None, disp_belt, uv_belt, mat_armor, solidify_thickness=0.011, smooth_iters=2)

    # ─── 2D. CHUNKY CUFFED ADVENTURER BOOTS (Clean top cut + smoothed rounded leather toe-box!) ───
    boot_planes = [
        ((0, 0, knee_z), (0, 0, -1)),
    ]
    def disp_boots(co, n):
        t = clamp(co.z / knee_z, 0.0, 1.0)
        cuff = 0.015 * ((t - 0.74) / 0.26) if t > 0.74 else 0.0
        # For the foot/toe box (co.z < 0.085), push outward into a solid rounded boot toe
        toe_boost = 0.006 if co.z < 0.085 else 0.0
        out = co + n * (0.012 + cuff + toe_boost)
        if out.z < 0.035:
            out.z = max(0.001, co.z)
        return out

    def uv_boots(co):
        u = clamp((co.x + 0.25) / 0.50, 0.02, 0.98)
        t = clamp(co.z / knee_z, 0.0, 1.0)
        return (u, 0.005 + t * 0.238)

    create_clean_shell(
        body_obj,
        "Adventurer_Boots",
        boot_planes,
        None,
        disp_boots,
        uv_boots,
        mat_armor,
        solidify_thickness=0.009,
        smooth_iters=10,
        smooth_filter=lambda co: co.z < 0.11,
    )

    # ─── 3. CULL COVERED UNDER-SKIN FACES ON BASE BODY ───
    bm_cull = bmesh.new()
    bm_cull.from_mesh(body_obj.data)
    bm_cull.faces.ensure_lookup_table()
    cull_faces = []
    for f in bm_cull.faces:
        c = f.calc_center_median()
        if c.z < waist_z + 0.01:
            cull_faces.append(f)
        elif (waist_z <= c.z <= collar_top_z - 0.025) and (abs(c.x) <= sleeve_x - 0.030):
            cull_faces.append(f)
        elif (1.28 <= c.z <= 1.58) and (bracer_in_x + 0.025 <= abs(c.x) <= bracer_out_x - 0.025):
            cull_faces.append(f)
    bmesh.ops.delete(bm_cull, geom=cull_faces, context="FACES")
    loose = [v for v in bm_cull.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm_cull, geom=loose, context="VERTS")
    bm_cull.normal_update()
    bm_cull.to_mesh(body_obj.data)
    bm_cull.free()

    for img in list(bpy.data.images):
        if img.source == "FILE":
            ap = bpy.path.abspath(img.filepath)
            if os.path.exists(ap):
                img.pack()
            else:
                bpy.data.images.remove(img)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    bpy.ops.export_scene.gltf(
        filepath=out_glb,
        export_format="GLB",
        export_apply=False,
        export_skins=True,
        export_materials="EXPORT",
    )
    print("Exported League Adventurer v2:", out_blend, "->", out_glb)


tunic_png = os.path.join(BLENDER_DIR, "T_LoL_Adventurer_Tunic.png")
armor_png = os.path.join(BLENDER_DIR, "T_LoL_Adventurer_Armor.png")

build_adventurer(
    os.path.join(CHARS_DIR, "Superhero_Male_FullBody.gltf"),
    os.path.join(BLENDER_DIR, "LoL_Male_Adventurer.blend"),
    os.path.join(OUT_GLB_DIR, "LoL_Male_Adventurer.glb"),
    is_female=False,
    tunic_tex=tunic_png,
    armor_tex=armor_png,
)

build_adventurer(
    os.path.join(CHARS_DIR, "Superhero_Female_FullBody.gltf"),
    os.path.join(BLENDER_DIR, "LoL_Female_Adventurer.blend"),
    os.path.join(OUT_GLB_DIR, "LoL_Female_Adventurer.glb"),
    is_female=True,
    tunic_tex=tunic_png,
    armor_tex=armor_png,
)
