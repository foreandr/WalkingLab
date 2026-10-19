# Animation / spell acceptance test (19 October 2026)

This is a separate scene, NOT a rewrite of the simulation / combat code.
Original battle scene is still `main.tscn`. The temporary default is `showcase.tscn`.

Launch the normal **.\RUN.bat**. It installs the CC0 Quaternius UAL2 Standard animation library on the user's Windows PC (if missing), performs the existing Godot import step, and opens the flat-floor animation showcase with ten autonomous performers plus the normal player-controlled BLACK controller.

What is real:
- UAL1 animation clips already committed in `assets/source_original.glb`.
- UAL2 animation clips imported at launch from the original standard asset GLB (8 MB). Source: https://quaternius.com/packs/universalanimationlibrary2.html; CC0.
- Spell shoot / idle / enter / exit from UAL1.
- Fire and water particles from the existing third-party VFX scenes `assets/external_vfx/fire.tscn`, `water.tscn`.
- Ninja jumps, sword combos, sliding and climbing where their UAL2 names exist.

Do not confuse **double jump mechanics using a source Jump clip twice** with an authored acrobatic flip. If the CC0 libraries do not contain a genuine backflip, side flip, or lateral strafe, the on-screen actor displays `NOT IN LICENSED PACK` and prints `[SHOWCASE_MISSING_CLIP]`; it does **not** play a forward jog or fake limb rotations. We still need to license/download actual flip and lateral-strafe clips and validate retargeting.

This builds a visual test, not playable opponents or a measured 60-FPS guarantee. Visual motion/blending and Windows Godot runtime have not been tested in this cloud session. Inspect the newest `logs/run_*.log` and the scene itself to accept/reject the demo.

To restore the original default arena: change `project.godot` `run/main_scene` back to `res://main.tscn`. Never delete the existing scene or source files.
