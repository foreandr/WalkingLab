# External game-ready weapon models

These are downloaded by `RUN.bat` through `install.ps1`. Models are NOT
generated or built from Godot primitive shapes.

## Main source: 3DAssets.dev

Pack: https://3dassets.dev/packs/swords-shields-and-melee-arms
Licence: CC0 1.0 Universal (https://creativecommons.org/publicdomain/zero/1.0/)
Creator / publisher: 3DAssets.dev; site discloses AI-assisted modelling.

- Arming Sword, original GLB: https://cdn.3dassets.dev/assets/38880/v1/model.glb
- Knightly Arming Sword, original GLB: https://cdn.3dassets.dev/assets/38881/v1/model.glb
- Greatsword, Bearded Axe and Rondel Dagger: selected by exact model name
  from the official manifest:
  https://3dassets.dev/api/v1/packs/swords-shields-and-melee-arms

These models contain their own physically based material colours and
are supplied already lying flat with metre units. Their publisher describes
them as game-ready; this is NOT a claim of photorealistic texture scans.

## Fall back: Kenney

Original Kenney CC0 library: https://github.com/shorepine/kenney
Author: Kenney (https://kenney.nl)
Licence: CC0 1.0 Universal.

The fallback sword, axe, and dagger have separate kit folders inside
`assets/kenney_weapons/`. The axe and sword each reference a kit-relative
`Textures/colormap.png`. Their original textures MUST be downloaded
alongside the models; they cannot share a single generic colormap.

The installer validates GLB/PNG file signatures and imports assets on first
launch. Downloaded model files stay local and are excluded from Git.
