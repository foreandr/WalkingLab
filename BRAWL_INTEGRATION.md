# WalkingLab: four-team kinetic brawl — 2026-10-19

This is the new default scene: **brawl_arena.tscn**. The previous animation showcase and original main.tscn are preserved as separate scenes.

## Teams
- BLUE: BLACK (player, permanently immortal) + one autonomous mortal swordfighter.
- RED: two autonomous sword/axe fighters.
- GOLD: two autonomous axe/sword fighters.
- VIOLET: two autonomous dagger/sword fighters, including an AETHER model with an authored **Backflip** (if source download succeeds).

Every mortal NPC uses the **existing** WalkingLab GDScript team-battle AI, anatomical damage, projectiles, spell effects, cast fusion, teammate healing, targeting, dodge sensing, and actual physics controller. Fights are 2v2v2v2, not teamscripted alternating demonstrations. An arena-owned 60 Hz tick updates exactly seven autonomous agents. The BLACK controller retains its existing mouse camera and controls.

## Controls
- WASD / ALT / SPACE / V / middle-mouse drag: retain BLACK movement, dash, jump/flight and orbit.
- Q: swing equipped **Kenney CC0 sword**.
- R: evade with directional physics impulse, 0.24-second invulnerability.
- HOLD B: block melee (80% damage mitigation).
- Existing number keys: finger rings and spells.
- F5: restart round.
- TAB: existing spell/damage combat feed.

## Authored assets / copyright
1. [Kenney 3D asset collection](https://github.com/shorepine/kenney): sword \`3d/mini-arena/weapon-sword.glb\`, axe \`3d/survival/tool-axe.glb\`, dagger \`3d/weapon/knife_sharp.glb\` and original kit colormaps, licensed **CC0** by Kenney. Already installed by \`assets/real_weapons/install.ps1\`, run by RUN.bat. No geometry constructed for the weapons.
2. [Quaternius Universal Animation Library 2](https://quaternius.com/packs/universalanimationlibrary2.html): CC0 authored locomotion, ninja jumps, combat, sword moves; \`assets/showcase/UAL2_Standard.glb\` downloaded by RUN.bat. \`assets/source_original.glb\` (original UAL1) provides an authored fallback.
3. [AETHER-02 model](https://github.com/RamonLinares/atlas-09/blob/main/ASSET-LICENSE.md): CC0 rig containing authored \`Backflip\`, \`DodgeRoll\`, \`Run\`, \`Sentinel\` and \`PunchCombo\`; downloaded by RUN.bat.
4. [Snaiel's Godot4ThirdPersonCombatPrototype](https://github.com/Snaiel/Godot4ThirdPersonCombatPrototype), MIT (Copyright (c) 2023 Snaiel). Design reference for responsive directional dodge / invulnerability and melee attack windows. No unmodified Snaiel source module has been copied into WalkingLab.
5. [NickTeruya FullSwordDemo](https://github.com/NickTeruya/FullSwordDemo), Godot prototype. Design reference for weapon-in-hand attachments and attack-timed hitboxes; code was studied rather than directly copied. Licence for that project's own code was NOT verified, so its code was not transplanted.

## Combat implementation
- \`brawl_arena.gd\`: authoritative four-team encounter, spawns 7 AI and BLACK, scoreboard, NPC death and restart.
- \`brawl_weapon.gd\`: bone-attached **real sourced** weapons; melee attack windows; swept sword-tip proximity; per-swing victim dedup; directional dodge impulses; jump/flight initiative; blocks and hit knockback applied to real CharacterBody3D controllers.
- \`brawl_visual.gd\`: display on NPCs uses **imported** GLB's authored AnimationPlayer tracks, never procedural limb poses, for movement, aerial maneuvers, flips (when real clips exist), and sword swings; reliable fallback to existing MIXAMO model when missing.
- \`walking.gd\`: narrowed melee approach AI, velocity impulse integration, optional fast-acrobatic flight incentive, independent of the original other arena's behavior unless \`brawl_melee\` metadata is set.
- \`combat_damage.gd\`: central receive-hit honors short dodge invulnerability windows.

## Important limitations / things to inspect
- Different imported humanoid rigs are **not** magically interchangeable. The additional NPC visual drives its own native rig; the underlying character controller/damage rig remains an internal gameplay authority. Sword is attached to the **visible** right hand if possible, with an explicitly logged harness fallback otherwise. Expect grip alignment and local sword-tip direction to require visual calibration.
- A full physics **ragdoll on death** is not integrated yet: the inherited WalkingLab death clip/fall simulation remains. Hit knockback and flight have physical velocity/collision.
- 3D proximity over swept weapon segments is an approximation, not continuous rigid-body blade-vs-limb collision. Hit timing is based on authored animation length fractions.
- The same source pack does not guarantee side-flip clips. The engine reports missing clips instead of fabricating flips.
- The first local run must download the optional UAL2/AETHER and Kenney GLBs if absent, then import them into Godot. If offline, model/weapon fallbacks are used where available.
- This repo-edit environment does not expose the user's local Windows/Godot process. At present **no local graphical gameplay test** has been performed. Validate via \`.\RUN.bat\`, inspect log lines \`[BRAWL_START]\`, \`[BRAWL_RIG_LOADED]\`, \`[BRAWL_SWING]\`, \`[BRAWL_WEAPON_HIT]\`, and \`[BRAWL_METRICS]\`.

## Animation corrective integration (verified in Godot CI)
UAL2_Standard.glb has **sword moves and NinjaJump** but omits baseline Idle/Walk/Jog/Sprint. Rig probe conclusively showed UAL1 and UAL2 each have the same 61 bones, same Armature/Skeleton3D path, and matching animation paths. The runtime now plays UAL1 locomotion and UAL2 sword/ninja source clips on a **single skeleton** by copying authored Animation resources into a separate `ual2` animation library. AETHER's independent 18-bone rig remains separate for its genuine Backflip. This avoids idle-pose sliding and avoids rotating limbs procedurally.

## Later test refinements
- True authored spellcasting now triggers on the **visible** animation rig at the projectile's cast start, rather than only on the hidden gameplay body. AETHER uses its KneelFire take where possible.
- Full native Quaternius Death01 animation, AETHER Collapse fallback, and a 0.33s minimum hit reaction interval prevent continuous spell/status damage from restarting impact poses every physics tick.
- Unsupported true side/backward strafing remains a known limitation; the fallback uses real forward authored locomotion rather than an invented lateral motion. AETHER lacks directional strafe clips. Recorded movement direction may mismatch visual facing.
