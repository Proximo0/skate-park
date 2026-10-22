# VRoid source models

Ready-made anime characters (VRM 0.x, made in VRoid Studio by the VRoid project / pixiv) for the skater's
placeholder bodies, plus the godot-vrm importer addon. Downloaded 2026-10-22.

| Folder | File | Source | Licence embedded in the .vrm |
|---|---|---|---|
| base_female | Base_Female.vrm | opengameart.org/sites/default/files/base_female.zip | CC0 |
| base_male | Base_Male.vrm | opengameart.org/sites/default/files/base_male.zip | CC0 |
| hairsample_female | HairSample_Female.vrm | opengameart.org/sites/default/files/hairsample_female.zip | CC0 |
| avatarsample_d_0 | AvatarSample_D.vrm | opengameart.org/sites/default/files/avatarsample_d_0.zip | VRoid Hub licence: everyone, commercial, modification, redistribution allowed, no credit |
| avatarsample_e | AvatarSample_E.vrm | opengameart.org/sites/default/files/avatarsample_e.zip | same VRoid Hub licence |
| avatarsample_f | AvatarSample_F.vrm | opengameart.org/sites/default/files/avatarsample_f.zip | same VRoid Hub licence |
| avatarsample_g | AvatarSample_G.vrm | opengameart.org/sites/default/files/avatarsample_g.zip | same VRoid Hub licence |
| sendagaya_shino | Sendagaya Shino.vrm | opengameart.org/sites/default/files/sendagaya_shino.zip | same VRoid Hub licence |
| sakurada_fumiriya | Sakurada Fumiriya.vrm | opengameart.org/sites/default/files/sakurada_fumiriya.zip | same VRoid Hub licence |

The opengameart page (opengameart.org/content/vroid-studio-cc0-models) lists all of them as CC0; the six avatar
samples carry VRoid Hub's permissive licence in their own metadata (the URL is in each file's `meta.otherLicenseUrl`).
The game is rated Teen; the "sexual/violent expression: allow" flags in that licence are permissions, not content.

`godot-vrm/addons/` is V-Sekai's godot-vrm (github.com/V-Sekai/godot-vrm, master, MIT) with Godot-MToon-Shader.
To use it, copy `godot-vrm/addons/*` to `res://addons/` and enable the VRM plugin.

`assets_src/.gdignore` keeps Godot from importing these sources or parsing the inactive addon copy.
