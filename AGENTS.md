# Workspace Instructions (AGENTS.md)

## Hand-Painted Environment, Trees & Grass Style (League of Legends / Summoner's Rift)
- Always build 3D trees and foliage in authentic hand-painted *League of Legends* (*Summoner's Rift* / *Spirit Blossom*) style — never use spherical blobs or recolored stone-block textures on tree canopies.
- Build conifer/pine trees (`add_lol_rift_pine_tree`) from 5–7 overlapping flared conical bough skirts with serrated, downward-drooping pointed leaf-tuft silhouettes, slightly curved apex tips, and 2–3 smaller flanking sub-spires at the base.
- Build Spirit-Blossom shrine tree dioramas (`add_lol_spirit_blossom_diorama`) on stepped mossy chiseled rock ledges (never square brick boxes) with 3 arched wishbone root legs straddling a dark hollow root cave, 7 snaking surface root tendrils, hanging white paper shide talisman streamers under the left bough, sacred shimenawa rope-bound stones, flanking smaller companion blossom trees, and a deep 6-lobe cascading feathered sakura canopy (`add_lol_sculpted_blossom_lobe` + 3D feathered leaf fans `add_lol_3d_feathered_leaf_fan`, zero radial cone spokes) textured from the Devoted Studios dusty-rose to dusky-plum leaf palette (`RGB(178, 100, 136)` -> `RGB(148, 74, 128)` -> `RGB(114, 62, 112)`).
- Paint foliage diffuse textures (`T_Real_Palia_Leaves.png`, `T_LoL_Blossom_Leaves.png`) with shingled lance/V-shaped leaf-clump brushstrokes and a clear top-to-bottom value and hue gradient: warm sunlit chartreuse-olive tips `RGB(148, 184, 92)` (or sakura rose-peach `RGB(240, 146, 196)`), mid-jade body `RGB(76, 128, 76)`, and deep cool viridian-teal under-tier shadow pockets `RGB(26, 54, 50)`.
- Paint meadow and grass terrain textures (`T_LoL_Rift_Terrain.png`) as 100% periodic seamless painterly canvases blending deep forest-teal shadow grass `RGB(44, 80, 64)`, emerald meadow `RGB(70, 114, 68)`, and sunlit chartreuse-sage clearings `RGB(114, 152, 86)` with wrapped directional grass-blade tuft brushstrokes — never overlay stone-tile mortar cracks on grass or create terrain divider seams.
- Place 3D hand-painted grass-blade tuft clusters (`add_lol_grass_tuft_cluster`) and moss-draped grass skirts along rock ledges, tree roots, garden islands, and stone border curbs, and carve glowing cyan-turquoise spiral runes into Summoner's Rift rock monoliths.
- Use matte shading (`specular_disabled`, `EMISSION = vec3(0.0)`, `ROUGHNESS >= 0.90`) with upward-biased foliage normals (`normalize(NORMAL + vec3(0.0, 0.38, 0.0))`) and hue-shifted vertex colors (`COLOR_0`) so real-time lights never wash out the hand-painted textures.

## Camera & Verification Rules
- Never modify player camera angles, FOV, or projection unless explicitly asked.
- Always keep floors non-overlapping (`y = 0.00` town stone tiles above `y = -0.14` Rift terrain) to prevent Z-fighting and flickering.
- Always verify 3D changes live in Godot on Metal and inspect the captured screenshots before finishing.
