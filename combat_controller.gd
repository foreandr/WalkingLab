extends RefCounted
# Skeletal combat overlay for the Mixamo Y Bot. No alternate skeleton is loaded.
const DURATION = 0.38
const COMBO_WINDOW = 0.72
const MAX_REACH = 2.05
const FLASH_DURATION = 0.32
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
var reaction_region = "chest"
var idle_clock = 0.0
var guard_weight = 0.0
var flash_time = 0.0
var flash_region = ""
var markers = {}

const REGIONS = {
	"head": ["head", Vector3(0, 0.12, 0), 0.17],
	"left_shoulder": ["leftarm", Vector3.ZERO, 0.18],
	"right_shoulder": ["rightarm", Vector3.ZERO, 0.18],
	"chest": ["spine2", Vector3(0, 0.10, -0.10), 0.29],
	"back": ["spine2", Vector3(0, 0.10, 0.13), 0.27]
}

func setup(owner):
	host = owner
	skeleton = owner.skeleton
	for i in range(skeleton.get_bone_count()):
		var name = String(skeleton.get_bone_name(i)).to_lower().replace("mixamorig", "").replace(":", "").replace("_", "")
		for key in ["hips", "spine", "spine1", "spine2", "neck", "head", "leftshoulder", "rightshoulder", "leftarm", "rightarm", "leftforearm", "rightforearm"]:
			if name == key: joints[key] = i
	for region in REGIONS:
		var indicator = MeshInstance3D.new()
		var mesh = SphereMesh.new()
		mesh.radius = REGIONS[region][2]
		mesh.height = mesh.radius * 2.0
		indicator.mesh = mesh
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.04, 0.025, 0.0)
		mat.no_depth_test = false
		indicator.material_override = mat
		indicator.visible = false
		host.actor.add_child(indicator)
		markers[region] = indicator
	print("COMBAT_JOINTS ", joints.keys())

func bone_index(key: String) -> int:
	return int(joints.get(key, -1))

func rotate_bone(key: String, axis: Vector3, angle: float):
	var index = bone_index(key)
	if index < 0: return
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index) * Quaternion(axis, angle))

func region_point(region: String) -> Vector3:
	var definition = REGIONS[region]
	var i = bone_index(definition[0])
	if i < 0:
		return host.actor.global_position + Vector3.UP * (1.6 if region == "head" else 1.3)
	return skeleton.global_transform * skeleton.get_bone_global_pose(i) * definition[1]

func punch():
	if not host.player_controlled or host.crouch.active(): return
	if attack_time < DURATION * 0.58: return
	attack_index = (attack_index + 1) % 4 if combo_timer > 0.0 else 0
	attack_time = 0.0
	combo_timer = COMBO_WINDOW
	hit_done = false
	if not host.boxing_assets.available.is_empty():
		var clips = ["Lead_Jab", "Cross_Punch", "Hook_Punch", "Right_Hook"]
		var chosen = clips[attack_index]
		if host.boxing_assets.available.has(chosen):
			host.tree.set("parameters/BoxingChoice/transition_request", chosen)

func receive_hit(region: String, incoming: Vector3):
	reaction_time = 0.0
	reaction_region = region
	reaction_height = region_point(region).y - host.actor.global_position.y
	reaction_side = 1.0 if host.actor.global_basis.x.dot(incoming) >= 0.0 else -1.0
	flash_region = region
	flash_time = FLASH_DURATION
	print("HIT_REGION ", host.name, " ", region)

func update(dt: float, targets: Array):
	idle_clock += dt
	attack_time += dt
	reaction_time += dt
	combo_timer = maxf(0.0, combo_timer - dt)
	flash_time = maxf(0.0, flash_time - dt)
	guard_weight = move_toward(guard_weight, 1.0 if host.player_controlled and not host.crouch.active() else 0.0, dt * 6.0)
	if attack_time > DURATION or hit_done or not host.player_controlled: return
	if attack_time < DURATION * 0.43: return
	hit_done = true
	var forward = -host.actor.global_basis.z
	var viewport_center = host.camera.get_viewport().get_visible_rect().size * 0.5
	var best_target = null
	var best_region = ""
	var best_score = INF
	for target in targets:
		if target == host: continue
		var delta = target.actor.global_position - host.actor.global_position
		var horizontal = Vector3(delta.x, 0.0, delta.z)
		if horizontal.length() > MAX_REACH + 0.5: continue
		if horizontal.dot(forward) < -0.2: continue
		for region in REGIONS:
			var point = target.combat.region_point(region)
			if host.camera.is_position_behind(point): continue
			var screen = host.camera.unproject_position(point)
			var pixels = screen.distance_to(viewport_center)
			# The camera is third-person: allow an aim-assist cone, not a tiny 3D ray.
			var score = pixels / (88.0 if region == "head" else 125.0)
			if score < best_score:
				best_score = score
				best_target = target
				best_region = region
	if best_target != null and best_score < 3.5:
		best_target.combat.receive_hit(best_region, forward)
		print("PUNCH_HIT ", host.name, " -> ", best_target.name, " region=", best_region)
	else:
		print("PUNCH_MISS: no reachable target close to crosshair")

func pose():
	# Called after the animation tree applies its current pose.
	var breathing = sin(idle_clock * 1.8) * 0.012
	rotate_bone("spine2", Vector3.RIGHT, breathing)
	var g = guard_weight
	if g > 0.001:
		# High guard, elbows tucked, torso slightly bladed.
		rotate_bone("spine1", Vector3.UP, 0.12 * g)
		rotate_bone("leftarm", Vector3.RIGHT, -0.70 * g)
		rotate_bone("rightarm", Vector3.RIGHT, -0.70 * g)
		rotate_bone("leftforearm", Vector3.RIGHT, -1.12 * g)
		rotate_bone("rightforearm", Vector3.RIGHT, -1.12 * g)
		rotate_bone("leftshoulder", Vector3.UP, -0.13 * g)
		rotate_bone("rightshoulder", Vector3.UP, 0.13 * g)
	if attack_time < DURATION and (not host.player_controlled or host.boxing_assets.available.is_empty()):
		var t = clampf(attack_time / DURATION, 0.0, 1.0)
		var drive = smoothstep(0.02, 0.42, t) * (1.0 - smoothstep(0.48, 1.0, t))
		var side = -1.0 if attack_index % 2 == 0 else 1.0
		var arm = "left" if side < 0.0 else "right"
		var other = "right" if side < 0.0 else "left"
		var power = 1.0 if attack_index % 2 == 0 else 1.15
		rotate_bone("spine1", Vector3.UP, side * 0.35 * drive)
		rotate_bone("spine2", Vector3.UP, side * 0.18 * drive)
		rotate_bone("spine2", Vector3.RIGHT, -0.10 * drive)
		rotate_bone(arm + "arm", Vector3.RIGHT, -1.05 * drive * power)
		rotate_bone(arm + "forearm", Vector3.RIGHT, 0.85 * drive)
		rotate_bone("leftshoulder" if side < 0.0 else "rightshoulder", Vector3.UP, side * 0.12 * drive)
		rotate_bone(other + "forearm", Vector3.RIGHT, -0.15 * drive)
	if reaction_time < 0.5:
		var t = clampf(reaction_time / 0.5, 0.0, 1.0)
		var recoil = sin(PI * pow(t, 0.65))
		rotate_bone("spine1", Vector3.RIGHT, 0.18 * recoil)
		rotate_bone("spine2", Vector3.UP, reaction_side * 0.20 * recoil)
		if reaction_region == "head":
			rotate_bone("neck", Vector3.RIGHT, 0.18 * recoil)
			rotate_bone("head", Vector3.RIGHT, 0.27 * recoil)
			rotate_bone("head", Vector3.UP, reaction_side * 0.23 * recoil)
		else:
			rotate_bone("spine2", Vector3.RIGHT, 0.18 * recoil)
			if reaction_region == "left_shoulder" or reaction_region == "right_shoulder":
				rotate_bone("leftshoulder" if reaction_region == "left_shoulder" else "rightshoulder", Vector3.RIGHT, 0.3 * recoil)

func update_flash():
	for region in markers:
		var indicator: MeshInstance3D = markers[region]
		if region != flash_region or flash_time <= 0.0:
			indicator.visible = false
			continue
		indicator.visible = true
		indicator.global_position = region_point(region)
		var material: StandardMaterial3D = indicator.material_override
		material.albedo_color = Color(1.0, 0.025, 0.02, 0.77 * pow(flash_time / FLASH_DURATION, 1.4))
