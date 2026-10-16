extends RefCounted
# Additive, procedural combat poses on the current Y Bot skeleton.
# Replace with same-rig authored clips later; hit timing and targeting can remain.
const PUNCH_DURATION = 0.34
const COMBO_WINDOW = 0.65
const RANGE = 1.12
const HIT_RADIUS = 0.49
var host
var skeleton: Skeleton3D
var joints = {}
var attack_time = 10.0
var attack_index = -1
var combo_timer = 0.0
var hit_done = false
var reaction_time = 10.0
var reaction_side = 1.0
var reaction_height = 1.45
var reaction_force = 0.0
var idle_clock = 0.0

func setup(owner):
	host = owner
	skeleton = owner.skeleton
	for i in range(skeleton.get_bone_count()):
		var name = String(skeleton.get_bone_name(i)).to_lower().replace("mixamorig", "").replace(":", "").replace("_", "")
		for key in ["spine", "spine1", "spine2", "neck", "head", "leftshoulder", "rightshoulder", "leftarm", "rightarm", "leftforearm", "rightforearm"]:
			if name == key:
				joints[key] = i
	print("COMBAT_JOINTS ", joints.keys())

func punch():
	if not host.player_controlled or host.crouch.active(): return
	if attack_time < PUNCH_DURATION * 0.54: return
	attack_index = (attack_index + 1) % 4 if combo_timer > 0.0 else 0
	attack_time = 0.0
	combo_timer = COMBO_WINDOW
	hit_done = false

func receive_hit(hit_point: Vector3, incoming: Vector3):
	reaction_time = 0.0
	reaction_height = hit_point.y - host.actor.global_position.y
	reaction_side = 1.0 if host.actor.global_basis.x.dot(incoming) >= 0.0 else -1.0
	reaction_force = 1.0
	# The visible reaction is skeletal; the body's capsule remains stable.

func update(dt: float, targets: Array):
	idle_clock += dt
	attack_time += dt
	reaction_time += dt
	combo_timer = maxf(0.0, combo_timer - dt)
	if attack_time > PUNCH_DURATION or hit_done: return
	if attack_time < PUNCH_DURATION * 0.38: return
	hit_done = true
	var hand = "left" if attack_index % 2 == 0 else "right"
	var hand_bone = get_bone("leftforearm" if hand == "left" else "rightforearm")
	var strike_origin = host.actor.global_position + Vector3.UP * 1.35
	if hand_bone >= 0:
		strike_origin = skeleton.global_transform * skeleton.get_bone_global_pose(hand_bone).origin
	var forward = -host.actor.global_basis.z
	var candidate = null
	var nearest = INF
	for target in targets:
		if target == host: continue
		var delta = target.actor.global_position - host.actor.global_position
		var along = delta.dot(forward)
		if along < 0.15 or along > RANGE + 0.55: continue
		var side_distance = (delta - forward * along).length()
		if side_distance > HIT_RADIUS + 0.3: continue
		if delta.length_squared() < nearest:
			nearest = delta.length_squared()
			candidate = target
	if candidate != null:
		var head_high = attack_index % 4 != 2
		var impact = candidate.actor.global_position + Vector3.UP * (1.56 if head_high else 1.23)
		candidate.combat.receive_hit(impact, forward)
		print("PUNCH_HIT ", host.name, " -> ", candidate.name, " height=", impact.y)

func get_bone(key: String) -> int:
	return int(joints.get(key, -1))

func additive(key: String, axis: Vector3, radians: float):
	var i = get_bone(key)
	if i < 0: return
	var previous = skeleton.get_bone_pose_rotation(i)
	skeleton.set_bone_pose_rotation(i, previous * Quaternion(axis.normalized(), radians))

func pose():
	# Called strictly after AnimationTree.advance(), before the ground support pass.
	var breathe = sin(idle_clock * 1.7) * 0.008
	additive("spine2", Vector3.RIGHT, breathe)
	if attack_time <= PUNCH_DURATION:
		var t = clampf(attack_time / PUNCH_DURATION, 0.0, 1.0)
		var extension = sin(PI * pow(t, 0.72))
		var side = -1.0 if attack_index % 2 == 0 else 1.0
		var arm = "left" if side < 0 else "right"
		# Guard -> shoulder drive -> extension -> guarded recovery.
		additive(arm + "arm", Vector3.RIGHT, -0.8 * extension)
		additive(arm + "forearm", Vector3.RIGHT, -0.5 * extension)
		additive("spine1", Vector3.UP, side * 0.22 * extension)
		additive("spine2", Vector3.RIGHT, -0.10 * extension)
	if reaction_time < 0.44:
		var u = clampf(reaction_time / 0.44, 0.0, 1.0)
		var snap = sin(PI * pow(u, 0.65)) * reaction_force
		var head_hit = reaction_height >= 1.38
		additive("spine1", Vector3.RIGHT, 0.18 * snap)
		additive("spine2", Vector3.UP, reaction_side * 0.18 * snap)
		if head_hit:
			additive("neck", Vector3.RIGHT, 0.17 * snap)
			additive("head", Vector3.RIGHT, 0.28 * snap)
			additive("head", Vector3.UP, reaction_side * 0.16 * snap)
		else:
			additive("spine2", Vector3.RIGHT, 0.21 * snap)
			additive("leftshoulder" if reaction_side < 0.0 else "rightshoulder", Vector3.RIGHT, 0.25 * snap)
