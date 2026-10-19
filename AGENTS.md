# WalkingLab / THE GAME — Repository Rules

## MANDATORY: Use existing authored assets, never generate content meshes

**Do not create or hand-model meshes, geometry, textures, vegetation, buildings, terrain props, equipment, effects, or character models yourself.** Do not substitute procedural primitives (BoxMesh, SphereMesh, CylinderMesh, PrismMesh, TorusMesh, custom triangle arrays, SurfaceTool or hand-written mesh construction) for real production art.

**Use assets that an external artist or asset publisher has already built.** Find a suitable licensed asset, confirm its provenance and license, download/import it into the Godot project, and instantiate or batch it as needed. Favor real grass/vegetation packs, modular environment packs, authored terrain meshes and professionally created props.

Procedural systems **may** distribute, rotate, scale, animate, cull or instance downloaded authored assets. They may also handle collision, gameplay triggers and placement. The prohibition concerns inventing the underlying visible art geometry or textures.

If no suitable asset is obtainable, **say so instead of quietly inventing or approximating one.** Do not invent download URLs or claim an asset was verified when it was not.

### Why this rule exists
The previous manually generated grass consisted of crude triangular spikes instead of plausible grass. The user explicitly rejected this approach and requires reusable, externally authored art for all future biome and environment construction.

### Existing technical debt
Some pre-existing scripts (for example `dirt_landforms.gd`, `biome_map.gd`, `central_tower.gd` and older arena code) generate geometric primitives. Those are **not** a precedent or an exception: replace their visible content with sourced assets when revisiting those features. Preserve working gameplay/collision while migrating visual art.

### Additional project workflow
- Actually edit and commit the code in `foreandr/WalkingLab` rather than sending patch instructions.
- Inspect existing scripts and reuse game systems before replacing them.
- Keep changes efficient for large-scale Battle Royale combat.
- Be explicit about what was committed, what was downloaded, and what has not been runtime-tested.
