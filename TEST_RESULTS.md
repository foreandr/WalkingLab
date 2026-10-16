# Tests — current walk to jog iteration

Large runtime and evidence files are attached to the
[project-assets release](https://github.com/foreandr/WalkingLab/releases/tag/project-assets):
[WalkingLab.exe](https://github.com/foreandr/WalkingLab/releases/download/project-assets/WalkingLab.exe),
[rokoko-native-retarget.avi](https://github.com/foreandr/WalkingLab/releases/download/project-assets/rokoko-native-retarget.avi),
[run-to-sprint.avi](https://github.com/foreandr/WalkingLab/releases/download/project-assets/run-to-sprint.avi),
[source-retarget-comparison.avi](https://github.com/foreandr/WalkingLab/releases/download/project-assets/source-retarget-comparison.avi),
and [walk-to-jog.avi](https://github.com/foreandr/WalkingLab/releases/download/project-assets/walk-to-jog.avi).

Functional run: Godot 4.7.2, headless, fixed 60 steps/s, 2,400 frames.
Actual results: jumps=0, landings=0; walk/transition/jog all exercised.
Maximum consecutive blend change=0.00781214 at 60 steps/s. Corrected sole
minimum=0.006m; body minimum=0.0m. This does not establish visual quality.

The original walk clip is unchanged. A cyclic foot-trajectory comparison
of the actual native Walk and Jog_Fwd clips selected a jog phase offset of
0.858333 cycles. The gradual pose/speed ramp lasts four seconds.

Evidence: [walk-to-jog.avi](https://github.com/foreandr/WalkingLab/releases/download/project-assets/walk-to-jog.avi), fixed-rate 60 FPS capture. Movie encoding
FPS must not be confused with ordinary gameplay performance.

Known limitations: existing ground-height correction; no completed
AnimationTree/foot-locking overhaul; no slopes/stairs validation. This
iteration only addresses removing jumps and easing walk into jog.

Visual inspection: captured frames at 5.5, 7.5, 8.5, 9.5 and 11 seconds were opened. The posture progressively changes from upright walking to the authored jogging arm/leg pose. A user visual-quality judgment is still pending. The movie includes encoding overhead and its HUD FPS is not the actual runtime benchmark. Native packaged smoke launch exited 0 with no script errors.

Faster/larger update: fixed-60-step 2,400-frame run recorded 133.8327m travel, compared with 78.7253m previously (1.70x). Jumps=0. Corrected sole minimum=0.006m and body minimum=0.0m. Rendered frame at 180 was inspected: white mannequin remains alone and the expanded stone arena is visible.

Smooth sprint iteration: fixed-60-step 2,400-frame run exercised walk, walk/run transition, run, run/sprint transition and sprint. Peak speed=8.05545m/s, jumps=0, minimum corrected sole=0.006m, minimum body=0.0m. Maximum consecutive weight change=0.00781214. Captured 24-second [evidence/run-to-sprint.avi](https://github.com/foreandr/WalkingLab/releases/download/project-assets/run-to-sprint.avi); opened frames at 14.5, 17, 18, 19, 20.5 and 22 seconds. These show the run blending into the separate forward-leaning sprint pose. Subjective quality remains for user review. Movie capture includes encoding overhead, not a runtime FPS benchmark. Native packed smoke launch exited 0 with no script errors.
