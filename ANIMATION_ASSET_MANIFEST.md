# Animation asset manifest — current mannequin build

Current scene: main.tscn. Renderer: Godot 4.7.2 Compatibility, 1280x720.
Current model and skeleton: assets/source_original.glb, Quaternius UAL1
Standard. Source archive retained in work/ual-standard.zip off desktop.
https://quaternius.com/packs/universalanimationlibrary.html
CC0 1.0; included QUATERNIUS-LICENSE.txt. White material override only.

| Runtime alias | Actual imported clip | Seconds | Use |
|---|---|---:|---|
| move_idle | Idle | 2.500 | idle loop |
| move_walk | Walk | 1.333 | walk loop |
| move_run | Jog_Fwd | 0.933 | jog loop |
| move_sprint | Sprint | 0.667 | sprint loop |
| move_takeoff | Jump_Start | 1.333 | preparation / extension |
| move_jump | Jump | 2.500 | airborne pose loop |
| move_land | Jump_Land | 1.267 | landing / recovery |

Original GLB names contain _Loop on looping takes; Godot removes that
suffix on import. Bone names remain original: root, pelvis, spine_01..03,
thigh_l/r, calf_l/r, foot_l/r, ball_l/r and the upper-body/finger chains.
No BoneMap, profile rest changes, rig transfer, or animation-track conversion
is used in the current mannequin runtime. Animation aliases duplicate the
original clips without modifying their tracks.

The source file is the in-place version. Physics-body velocity drives
horizontal travel; there is no second root-motion displacement.
Godot imports these Quaternius clips at their GLB timestamps (24 fps
sampling convention); the displayed durations come from AnimationPlayer.

Known limitation: current preparation 0.45s and recovery 0.45s are controller
settings, not proven takeoff/landing events extracted from source footage.
Jump synchronization and AnimationTree rebuild remain unvalidated.

Evaluated alternative: authentic Rokoko 16-walk/run FBX pack, captured by
Sam Lazarus, 30 fps, commercial project use permitted on the publisher page:
https://www.rokoko.com/resources/rokoko-mocap-16-free-walk-and-run-cycle-animations
Original archive and inspection are preserved off desktop. User requested
returning to the prior animation set; Rokoko is not active in this build.

Current active preview includes the original Sprint clip (0.666667s) as a distinct third gait. Run and sprint use their own native tracks; neither is fabricated from leg rotations. Jog foot phase offset: 0.858333. Sprint offset: 0.883333. The paired native mannequin remains active.
