extends Node
# Six independent anatomical hit pools. The visible limb markers follow Mixamo bones.
const REGIONS = ["head","torso","left_arm","right_arm","left_leg","right_leg"]
var hp: Dictionary = {}
var owner_actor: CharacterBody3D
var skeleton: Skeleton3D
var markers: Dictionary = {}
var dead: bool = false

var shader_material: ShaderMaterial
var bone_map: Dictionary = {}
const BONES = {"head":"Head","torso":"Spine2","left_arm":"LeftForeArm","right_arm":"RightForeArm","left_leg":"LeftLeg","right_leg":"RightLeg"}

func setup(body: CharacterBody3D, rig: Skeleton3D) -> void:
	owner_actor = body
	skeleton = rig
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://damage_skin.gdshader")
	var owner_controller: Node = body.get_parent()
	shader_material.set_shader_parameter("base_color",owner_controller.get("character_tint"))
	for part in owner_controller.get("visual").find_children("*","MeshInstance3D",true,false):
		part.material_override = shader_material
	for region in REGIONS:
		hp[region] = 100.0
		bone_map[region] = -1
		for i in range(skeleton.get_bone_count()):
			if String(skeleton.get_bone_name(i)).to_lower().ends_with(String(BONES[region]).to_lower()):
				bone_map[region] = i
				break
	update_damage_colors()

func bone_position(region: String) -> Vector3:
	var index: int = int(bone_map[region])
	if index < 0: return owner_actor.global_position + Vector3.UP
	return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin

func _process(_dt: float) -> void:
	if skeleton == null or not is_instance_valid(skeleton): return
	for region in REGIONS:
		shader_material.set_shader_parameter(region+"_world",bone_position(region))

func update_damage_colors() -> void:
	shader_material.set_shader_parameter("region_hp",Vector3(float(hp["head"]),float(hp["torso"]),float(hp["left_arm"])))
	shader_material.set_shader_parameter("leg_hp",Vector3(float(hp["right_arm"]),float(hp["left_leg"]),float(hp["right_leg"])))

func region_at(world_point: Vector3) -> String:
	# Prefer the nearest animated body region, so moving arms and legs
	# remain hittable instead of relying on fixed capsule coordinates.
	var nearest: String = ""
	var nearest_distance: float = INF
	for region in ["head","left_arm","right_arm","left_leg","right_leg"]:
		var distance_to_bone: float = world_point.distance_to(bone_position(region))
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
	update_damage_colors()
	print("[DAMAGE] ",owner_actor.get_parent().name," ",region," -",amount," HP=",remaining)
	if remaining <= 0.0:
		dead = true
		owner_actor.get_parent().set_process_input(false)
		owner_actor.get_parent().set_physics_process(false)
		print("[DEFEATED] ",owner_actor.get_parent().name," ",region)
