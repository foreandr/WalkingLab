extends RefCounted
# Physics-driven jump built for the existing Mixamo rig. No cross-rig clips.
const GRAVITY = 18.0
const LAUNCH_SPEED = 6.5
const ANTICIPATION_SECONDS = 0.105
const RECOVERY_SECONDS = 0.22
const INPUT_BUFFER_SECONDS = 0.14
const COYOTE_SECONDS = 0.08
var mode = "grounded"
var phase = 0.0
var buffer = 0.0
var grace = 0.0
var vertical_offset = 0.0
var bank = 0.0

func request_jump():
	buffer = INPUT_BUFFER_SECONDS

func before_move(dt: float, body: CharacterBody3D, crouched: bool):
	buffer = maxf(0.0, buffer - dt)
	var on_ground = body.is_on_floor() or body.position.y <= 0.005
	grace = COYOTE_SECONDS if on_ground else maxf(0.0, grace - dt)
	if crouched:
		buffer = 0.0
	if mode == "grounded" and buffer > 0.0 and grace > 0.0 and not crouched:
		mode = "anticipation"
		phase = 0.0
		buffer = 0.0
	if mode == "anticipation":
		phase += dt
		body.velocity.y = -0.2
		if phase >= ANTICIPATION_SECONDS:
			mode = "airborne"
			phase = 0.0
			grace = 0.0
			body.velocity.y = LAUNCH_SPEED
	elif mode == "airborne":
		body.velocity.y -= GRAVITY * dt
	else:
		body.velocity.y = -0.3

func after_move(dt: float, body: CharacterBody3D):
	if mode == "airborne" and body.velocity.y <= 0.0 and (body.is_on_floor() or body.position.y <= 0.005):
		mode = "landing"
		phase = 0.0
	elif mode == "landing":
		phase += dt
		if phase >= RECOVERY_SECONDS:
			mode = "grounded"
			phase = 0.0

func apply_visual(dt: float, model: Node3D, turn_error: float, horizontal_speed: float):
	var squash_target = 0.0
	if mode == "anticipation":
		squash_target = -0.07
	elif mode == "landing":
		squash_target = -0.05 * (1.0 - clampf(phase / RECOVERY_SECONDS, 0.0, 1.0))
	vertical_offset = move_toward(vertical_offset, squash_target, dt * 0.9)
	model.scale.y = 1.0 + vertical_offset
	var desired_bank = clampf(turn_error * minf(horizontal_speed / 6.0, 1.0) * 0.12, -0.12, 0.12)
	if mode == "airborne":
		desired_bank *= 0.4
	bank = move_toward(bank, desired_bank, dt * 1.2)
	model.rotation.z = bank
