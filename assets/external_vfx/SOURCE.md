# Fireball VFX: existing third-party game asset

**Visual effect (scene, shaders and particles):**
- Author: marinho
- Repository: https://github.com/marinho/godot-visual-effects
- Original scene: https://github.com/marinho/godot-visual-effects/blob/main/particles/fire.tscn
- License: MIT for original particles and code, per repository README

**Original fire particle texture:**
- Kenney Particle Pack by Kenney
- https://kenney.nl/assets/particle-pack
- Texture URL: https://raw.githubusercontent.com/marinho/godot-visual-effects/main/addons/kenney_particle_pack/fire_01.png
- Kenney licensing: CC0 1.0

WalkingLab preserves the third-party fire scene as an asset and only remaps its
texture path to the locally downloaded original texture. Script code moves
the asset through the world and handles projectile collisions/lifetime.
The game never draws a replacement fireball or authors a new particle system.

The texture is installed by RUN.bat. Asset download requires a working
GitHub connection on first run; no mana or cast cooldown.
