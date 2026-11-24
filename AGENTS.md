# Workspace Instructions (AGENTS.md)

## Hand-Painted Environment, Trees & Grass Style (League of Legends / Summoner's Rift)
- Always build 3D trees, bushes, and grass tufts using **RGBA Alpha-Cutout Leaf Cluster Cards** (`T_LoL_Blossom_Leaves.png`, `T_Real_Palia_Leaves.png`, `T_LoL_Grass_Tuft_Alpha.png` with `ALPHA_SCISSOR_THRESHOLD = 0.42`) and **Spherical Normal Transfer** (`v.normal = normalize(v.co - cloud_center + vec3(0, 0, 0.55))`) — never use solid opaque spheres, cones, or opaque polygon spikes for foliage.
- Never clone the same tree body shape across the map. Give every tree instance a distinct body-shape archetype and silhouette (`add_tree_shape_elder_hollow_shrine`, `add_tree_shape_windswept_canal_bonsai`, `add_tree_shape_twin_forked_sakura`, `add_tree_shape_twisted_upright_willow_blossom`, `add_tree_shape_multi_limb_emerald_oak`, and 4 distinct conifer variants in `add_tree_shape_varied_conifer_pine`) with unique trunk curvature, branch count, lean direction, and canopy cloud proportions.
- Derive foliage alpha-card atlases (`1024x1024` 2x2 RGBA) from chroma-keyed Riot Games / Devoted Studios hand-painted leaf bouquets (`RGB(178, 100, 136)` -> `RGB(148, 74, 128)` -> `RGB(114, 62, 112)` for Spirit Blossom; color-graded to `RGB(148, 184, 90)` -> `RGB(72, 124, 74)` -> `RGB(28, 62, 54)` for Summoner's Rift green foliage) with color-dilated transparent borders.
- Build meadow and grass terrain textures (`T_LoL_Rift_Terrain.png`) by high-pass normalizing the Summoner's Rift meadow reference (removing macro brightness gradients so tiling never creates stripes), torus-blending edges, stamping soft-opacity CC0 hand-painted grass-blade clusters, and applying dual-scale rotated UV blending in `arcane_town_painterly.gdshader`.
- Place 3D intersecting alpha-cutout grass tuft cards (`add_lol_alpha_grass_tuft`) along rock ledges, tree roots, garden islands, and stone border curbs, and carve glowing cyan-turquoise spiral runes into Summoner's Rift rock monoliths.
- Use matte shading (`specular_disabled`, `EMISSION = vec3(0.0)`, `ROUGHNESS >= 0.90`) with upward-biased foliage normals (`normalize(NORMAL + vec3(0.0, 0.48, 0.0))`) and hue-shifted vertex colors (`COLOR_0`) so real-time lights never wash out the hand-painted textures.

## Camera & Verification Rules
- Never modify player camera angles, FOV, or projection unless explicitly asked.
- Always keep floors non-overlapping (`y = 0.00` town stone tiles above `y = -0.14` Rift terrain) to prevent Z-fighting and flickering.
- Always verify 3D changes live in Godot on Metal and inspect the captured screenshots before finishing.
