# Current movement implementation — walk to jog

One native Quaternius mannequin in the existing stone arena. There is no
character retargeting. Walk and Jog_Fwd are the source clips; the original
walk's tracks, pose sampling and nominal speed are unchanged at zero blend.

The AI repeats a 20-second preview: walk 6s, transition 4s, jog 6s,
transition back 4s. A quintic ease curve has zero first/second derivatives
at transition endpoints. The same weight blends pose and target speed
(1.35 to 2.60 m/s). A continuous normalized step phase advances with speed;
the jog has a measured 0.858333-cycle offset that minimizes disagreement
between the source walk/jog foot trajectories. Pose rotations use slerp.

A continuous 3.4m-radius lap avoids corner stops during the comparison.
Physics-body travel remains velocity driven. No double root displacement.
Jump initiation/flight/landing logic is inactive; no jumps occur. Sprinting
is inactive in this focused preview. The underlying clips remain assets.

Existing final-pose ground correction remains. Proper AnimationTree and
phase-aware foot locking remain future work; this iteration does not claim
the full earlier locomotion rebuild is complete.

Speed update: MOVEMENT_MULTIPLIER=1.7 scales desired velocity and acceleration. The phase calculation uses actual speed against the original stride lengths, so cadence also scales by 1.7. The blend duration remains four seconds. Arena radius is 16.28m (previously 7.4m), and the lap radius is 9m (previously 3.4m).

Current sprint iteration: run speed is 5.967m/s (1.35x previous), sprint speed 8.05545m/s, walk unchanged at 2.295m/s. The distinct Quaternius Sprint clip blends above Jog_Fwd over four seconds with the same quintic easing of pose and velocity. A measured +0.025 cycle offset relative to the jog aligns sprint foot phases (absolute offset 0.883333). The automatic cycle now lasts 40 seconds, easing back through run to walk. Maximum target acceleration during the walk/run ramp is below the controller's 2m/s² limit. Jump logic remains inactive.
