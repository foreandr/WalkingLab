extends Node
# Six independent anatomical hit pools. The visible limb markers follow Mixamo bones.
const REGIONS = ["head","torso","left_arm","right_arm","left_leg","right_leg"]
var hp: Dictionary = {}
var owner_actor: CharacterBody3D
var skeleton: Skeleton3D
var markers: Dictionary = {}
var dead: bool = false

func setup(body: CharacterBody3D, rig: Skeleton3D) -> void:
	owner_actor = body
	skeleton = rig
	for region in REGIONS:
		hp[region] = 100.0
		var marker := MeshInstance3D.new()
		marker.name = "Damage_" + region
		var mesh := SphereMesh.new()
		mesh.radius = 0.15 if region == "head" else (0.24 if region == "torso" else 0.115)
		mesh.height = mesh.radius * 2.0
		marker.mesh = mesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0,0.2,0.1,0.0)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = material
		owner_actor.add_child(marker)
		markers[region] = marker

func _process(_dt: float) -> void:
	if skeleton == null or not is_instance_valid(skeleton): return
	for region in REGIONS:
		var target_name: String = {"head":"Head","torso":"Spine2","left_arm":"LeftForeArm","right_arm":"RightForeArm","left_leg":"LeftLeg","right_leg":"RightLeg"}[region]
		var index: int = -1
		for i in range(skeleton.get_bone_count()):
			if String(skeleton.get_bone_name(i)).to_lower().ends_with(target_name.to_lower()):
				index = i
				break
		if index >= 0:
			(markers[region] as MeshInstance3D).global_position = skeleton.global_transform * skeleton.get_bone_global_pose(index).origin

func region_at(world_point: Vector3) -> String:
	# Prefer the nearest animated body region, so moving arms and legs
	# remain hittable instead of relying on fixed capsule coordinates.
	var nearest: String = ""
	var nearest_distance: float = INF
	for region in ["head","left_arm","right_arm","left_leg","right_leg"]:
		var indicator: MeshInstance3D = markers[region]
		var distance_to_bone: float = world_point.distance_to(indicator.global_position)
		if distance_to_bone < nearest_distance:
			nearest_distance = distance_to_bone
			nearest = region
	if nearest_distance < 0.28: return nearest
	var local: Vector3 = owner_actor.global_transform.affine_inverse() * world_point
	if local.y >= 1.52: return "head"
	if local.y >= 0.95:
		if local.x < -0.23: return "left_arm"
		if local.x > 0.23: return "right_arm"
		return "torso"
	if local.x < 0.0: return "left_leg"
	return "right_leg"

func receive_hit(world_point: Vector3, amount: float) -> void:
	if dead: return
	var region: String = region_at(world_point)
	hp[region] = maxf(0.0,float(hp[region])-amount)
	var remaining: float = float(hp[region])
	var marker: MeshInstance3D = markers[region]
	var mat: StandardMaterial3D = marker.material_override
	# 100-80: clear; 80-60: yellow; 60-20: orange; under 20: red.
	var color := Color(1.0,0.1,0.07,0.72)
	if remaining >= 80.0: color.a = 0.0
	elif remaining >= 60.0: color = Color(1.0,0.88,0.1,0.60)
	elif remaining >= 20.0: color = Color(1.0,0.38,0.05,0.68)
	mat.albedo_color = color
	print("[DAMAGE] ",owner_actor.get_parent().name," ",region," -",amount," HP=",remaining)
	if remaining <= 0.0:
		dead = true
		owner_actor.get_parent().set_process_input(false)
		owner_actor.get_parent().set_physics_process(false)
		print("[DEFEATED] ",owner_actor.get_parent().name," ",region)
