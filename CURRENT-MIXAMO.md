# Arena — player and AI

Open **Arena - CURRENT** on the desktop. There are exactly two male Y Bot mannequins in one arena: **YOU** (blue label) and **AI** (yellow label). Your inputs affect only YOU. The AI independently demonstrates crouching, standing, crouch-to-run, forward running, and backward movement. It repeats the crouch showcase after a period of ordinary locomotion.

## Player controls

| Input | Behavior |
|---|---|
| WASD | Camera-relative movement; W runs forward, S uses backward motion, A/D turn and move sideways while standing |
| Shift + movement | Sprint: up to 12 m/s forward, capped at 7 m/s backward |
| Ctrl + movement | Walk at 2.295 m/s |
| C | Toggle crouch / stand using the supplied transitions |
| WASD while crouched | Move in all four directions, facing the camera's forward direction |
| Shift while crouched | Play Crouched To Sprinting and finish in the **6 m/s run** |
| Right-drag | Orbit the camera |
| Mouse wheel | Zoom |
| Tab | Watch the AI / return camera to YOU |
| V | Replay the AI crouch showcase |
| F11 | Toggle full screen |

Without Shift or Ctrl, forward movement targets 6 m/s and backward movement targets 4.2 m/s. Releasing movement keys smoothly stops the player. Acceleration changes the animation blend continuously through the available speed bands. Diagonal input is normalized. The standing idle is held from the final authored Crouch To Stand pose.

**Crouch-to-run now ends at 6 m/s for both characters.** For the player, holding Shift through that transition stays at 6; release Shift and press it again to request the faster ordinary sprint. With no movement input, the player slows to a stop after the transition instead of taking over an AI route.

Crouched sideways/forward movement is 0.95 m/s; crouched backward movement is 1.15 m/s. Left and backward use the supplied native loops. **Right is mirrored from the supplied left loop; forward is time-reversed from the supplied backward loop.** These are temporary derived clips in assets/crouch_derived.glb, not additional mocap downloads. Dedicated forward/right crouch clips can replace them later.

## AI

The AI keeps its own animation graph, movement clocks, crouch state, capsule, ground checks, and showcase. Player C/WASD/Shift do not control it. It uses a 20-metre-radius route offset inside the shared 120-metre arena, with its original forward speeds (2.295, 4, 6, 8, 10, 12 m/s) and backward speeds (1.4, 4.2, 7 m/s). The removed Sprint.fbx remains absent from active playback. Its crouch launch enters the retained Running.fbx animation at 6 m/s.

The characters have separate capsule colliders and collide with each other. A boundary collider keeps the player inside the arena. The body root is constrained to the flat floor at zero after movement, including wall contacts. Crouch collision height follows the animated head, with the bottom held at the floor. Full-body ground support covers hands and knees during crouch; lighter foot support is used for ordinary standing locomotion. This is a flat-floor demo without uneven-terrain IK or overhead-obstacle clearance logic. Jumping remains disabled.

## Editing

- **duo.gd** — main scene setup, input bindings, player/AI roles, labels, AI showcase repetition, arena boundary, camera switching.
- **walking.gd** — reusable character controller, player acceleration, standing gait blending, AI routing, camera, collisions, and input handling.
- **crouch_controller.gd** — authored crouch transitions, crouched movement, 6 m/s recovery, capsule height, and AI showcase.
- **foot_ground.gd** — animated ground support.
- **arena_environment.gd** — arena and lighting.
- **project.godot** — open in Godot to run edited source.

The desktop shortcut uses the exported **Arena-sprint-buildup-current.pck**. Source edits require another export to appear there. Earlier source is saved in work/duo-backup.

Original male, backward, and crouch animation files remain backed up in work/native-male-originals, work/backward-originals, and work/crouch-originals. The native character is the actual male Mixamo Y Bot (Alpha_Surface and Alpha_Joints), fitted in rest space to the supplied male motion rig. Original asset source: https://github.com/aabeling/something-with-threejs/blob/master/Ybot.fbx . Adobe Mixamo assets remain subject to Adobe's terms. The existing older forward walk is retained. Derived crouch generation is recorded in work/build_crouch_derived.py.

## Validation

The input test covered idle, W running, Shift sprinting and release, stopping, S backward movement and its sprint cap, crouch entry, all four crouched directions, standing, crouch launch, the held-Shift 6 m/s limit, and a fresh Shift press reaching 12 m/s. It also verified exactly two skeletons and one environment, camera switching, and the AI's independent 6 m/s crouch exit. Sampled body vertices stayed above the floor, with a minimum of 0.00131 m in that sequence.

A collision test stopped the player against the AI with about 0.525 m between capsule centres and stopped the player at the boundary without going below the floor. Rendered views of both characters, standing idle, movement, and all four crouched directions were inspected. These checks do not establish a guaranteed frame rate or replace the user's judgment of motion quality.

Packaged runtime smoke test passed with exit 0, both actors and their animation libraries loaded, and no runtime errors.

## Progressive sprint

Hold Shift while moving forward: speed and animation build smoothly from 6 to 8 to 10 to 12 m/s, three seconds per stage (nine seconds total once running). Each stage uses a smooth easing curve and the existing continuous gait blend. Releasing Shift eases back to 6 m/s. Stopping, crouching, walking, or reversing resets buildup; standing still or pushing against a wall cannot charge it. Sideways-only movement does not build forward sprint. Backward sprint remains capped at 7 m/s. Crouch launch stays at 6 until Shift is released and pressed again. Adjust SPRINT_STAGE_SECONDS in walking.gd to change buildup time.


Progressive sprint validation: automated controls test passed, including 8/10/12 m/s buildup checkpoints, release, backwards, all crouch directions, and held-Shift crouch-launch lock. Packaged runtime smoke test passed without script errors.

