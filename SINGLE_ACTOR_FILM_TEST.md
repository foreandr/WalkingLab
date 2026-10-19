# One-person animation film test — 2026-10-19

Default scene: \`showcase.tscn\`, not production \`main.tscn\`. Only ONE showcase performer + BLACK under full player movement control.

Run \`.\RUN.bat\`: existing launcher installs the original Kenney CC0 Mini Arena Sword GLB and its original colormap, plus CC0 UAL2 and AETHER-02 where downloadable. If the files are unavailable the demo explicitly reports missing assets; it never uses procedural replacement weapon geometry.

## Film controls
- F6: switch close-up demo camera vs normal player camera
- F7: next distinct animation; F8: previous
- F9: pause/resume; F10: replay action
- WASD/Alt/Ctrl/Space/mouse: your normal BLACK controls
- E: pick up *your* ground sword when close enough. The NPC independently performs its scripted floor-sword pickup before sword attack tests.

The label and log \`[SINGLE_SHOWCASE_STEP]\` identify actual source rig and animation name. The script covers walk, jog, sprint, 4-way strafing checks, jump/double jump/landing, ninja acrobatics, forward roll, slide, parkour, backflip, side flip availability, flying loop, authored spellcasting, existing third-party fire and water effects, weapon pickup, sword idle, slash, combo and block, then drop. Sequence repeats.

Important distinctions: AETHER-02's authentic Backflip requires temporarily swapping to that sourced model within the **same actor slot**; no humanoid backflip retargeting is claimed. UAL1 and UAL2 differ by source pack. Side flip and strafe only play when actual source clips are found. Ground sword pickup presently uses the imported \`PickUp_Table\` animation (not a genuine ground retrieval mocap) and is explicitly labelled so its quality can be judged on video. Actor's hand attachment uses bone name matching, and the grasp angle still needs visual inspection. Player picks up a visible sword, but **player-driven sword attack animation is not yet integrated**; the automated NPC is the one that demonstrates all sword swings.

These are source-level edits, not a verified video-quality deliverable. Inspect latest game logs and the scene for runtime errors, missing clips, clipping, wrong sword orientation, floor penetration and blending quality.

Sword dimensions verified from the original Kenney GLB accessor bounds: length ~0.501 m, so the preview scales it by 2.1 for ~1.05 m. Ground placement and wrist orientation are calibration starting points and require filmed inspection.
