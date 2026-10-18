extends Node
# Six independent anatomical hit pools. The visible limb markers follow Mixamo bones.
const REGIONS = ["head","torso","left_arm","right_arm","left_leg","right_leg"]
var hp: Dictionary = {}
var owner_actor: CharacterBody3D
var skeleton: Skeleton3D
var markers: Dictionary = {}
var dead: bool = false
var visual_update_clock: float = 0.0
var damage_visual_profile_counter: int = 0
var aoe_batch_active: bool = false

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
	for region in REGIONS:
		var marker := MeshInstance3D.new()
		marker.name = "Hitbox_" + region
		var sphere := SphereMesh.new()
		sphere.radius = 0.32 if region == "head" else (0.48 if region == "torso" else 0.34)
		sphere.height = sphere.radius * 2.0
		marker.mesh = sphere
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.1,0.86,1.0,0.13)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		marker.material_override = material
		owner_actor.add_child(marker)
		# Test hitbox overlays are expensive transparent draws; disable in wars.
		marker.visible = owner_controller.get("animation_test_mode") != "war"
		markers[region] = marker

func apply_damage_material() -> void:
	if shader_material == null or owner_actor == null: return
	var character_visual: Node3D = owner_actor.get_parent().get("visual") as Node3D
	if character_visual == null: return
	for part in character_visual.find_children("*","MeshInstance3D",true,false):
		part.material_override = shader_material

func bone_position(region: String) -> Vector3:
	var index: int = int(bone_map[region])
	if index < 0: return owner_actor.global_position + Vector3.UP
	return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin

func _process(dt: float) -> void:
	if skeleton == null or not is_instance_valid(skeleton): return
	# Once the dead fighter has settled, its damage colors and bone markers
	# are static; stop all per-frame material/bone polling permanently.
	if dead:
		var owner_controller: Node = owner_actor.get_parent() if is_instance_valid(owner_actor) else null
		if owner_controller != null and bool(owner_controller.get("combat_pose_frozen")):
			set_process(false)
			return
	# Damage regions are visual feedback, not collision physics.
	# Updating at 15 Hz saves bone transforms and shader updates during wars.
	visual_update_clock -= dt
	if visual_update_clock > 0.0: return
	visual_update_clock = 1.0/(8.0 if owner_actor.get_parent().get("animation_test_mode") == "war" else 15.0)
	damage_visual_profile_counter += 1
	var sample_visual: bool = (damage_visual_profile_counter & 31) == 0
	var visual_start_usec: int = Time.get_ticks_usec() if sample_visual else 0
	skeleton.force_update_all_bone_transforms()
	for region in REGIONS:
		var location: Vector3 = bone_position(region)
		shader_material.set_shader_parameter(region+"_world",location)
		if (markers[region] as MeshInstance3D).visible:
			(markers[region] as MeshInstance3D).global_position = location
	if sample_visual:
		var arena: Node = get_tree().current_scene
		if arena != null and arena.has_method("record_performance_sample"):
			arena.record_performance_sample("damage_visual_refresh",Time.get_ticks_usec()-visual_start_usec)

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
	if nearest_distance < 0.54: return nearest
	var local: Vector3 = owner_actor.global_transform.affine_inverse() * world_point
	if local.y >= 1.52: return "head"
	if local.y >= 0.95:
		if local.x < -0.23: return "left_arm"
		if local.x > 0.23: return "right_arm"
		return "torso"
	if local.x < 0.0: return "left_leg"
	return "right_leg"

# Direct anatomical damage is used for multi-region AOE. The ordinary
# receive_hit entry point still resolves a single impact to one region.
func scene_debug_damage() -> bool:
	var arena: Node = get_tree().current_scene
	return arena == null or not bool(arena.get("stress_no_deaths"))

func receive_region_hit(region: String, world_point: Vector3, amount: float, attacker: String = "", show_number: bool = true) -> void:
	if dead or not hp.has(region): return
	# Stress-test mode retains injuries, reactions and damage accounting,
	# but vital organs never reach zero and no fighter can be defeated.
	var stress_immortal: bool = false
	var arena: Node = get_tree().current_scene
	if arena != null:
		stress_immortal = bool(arena.get("stress_no_deaths"))
	var floor_hp: float = 1.0 if stress_immortal else 0.0
	var previous_hp: float = float(hp[region])
	hp[region] = maxf(floor_hp,previous_hp-amount)
	if show_number: show_damage_number(world_point,amount,region)
	flash_hit_region(region)
	var remaining: float = float(hp[region])
	# In immortal battles damaged regions soon reach 1 HP. Re-uploading
	# identical shader uniforms for every further impact is wasted work.
	# Hits, reactions, numbers, death rules and damage totals still execute.
	if remaining != previous_hp and (not aoe_batch_active or arena == null or not bool(arena.get("batch_aoe_shader"))):
		update_damage_colors()
	# Avoid thousands of console writes during immortal stress tests.
	# The arena aggregates hit counts and damage per reporting window.
	if not stress_immortal: print("[DAMAGE] ",owner_actor.get_parent().name," ",region," -",amount," HP=",remaining)
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("record_battle_hit"):
		scene.record_battle_hit(attacker,owner_actor.get_parent().name,region,amount,remaining)
	if not dead and owner_actor.get_parent().has_method("combat_react"):
		owner_actor.get_parent().combat_react(region,amount,remaining)
	if not stress_immortal and remaining <= 0.0 and region in ["head","torso"] and not aoe_batch_active:
		dead = true
		if owner_actor.get_parent().has_method("combat_die"):
			owner_actor.get_parent().combat_die(region)
		print("[DEFEATED] ",owner_actor.get_parent().name," ",region)

func receive_aoe_regions(regions: Array[String], amount: float, attacker: String = "") -> void:
	if dead or regions.is_empty(): return
	# Resolve every intersected pool before applying fatality, so head/torso
	# damage cannot suppress arm and leg hits from the same explosion.
	aoe_batch_active = true
	var first_number: bool = true
	for region in regions:
		if hp.has(region):
			receive_region_hit(region,bone_position(region),amount,attacker,first_number)
			first_number = false
	aoe_batch_active = false
	# Cycle 4 compatibility by default. Opt-in batch mode only for paired A/B.
	var scene_for_batch: Node = get_tree().current_scene
	var batch_shader: bool = bool(scene_for_batch.get("batch_aoe_shader")) if scene_for_batch != null else false
	if batch_shader: update_damage_colors()
	var arena: Node = get_tree().current_scene
	if arena != null and bool(arena.get("stress_no_deaths")): return
	for vital in ["head","torso"]:
		if float(hp[vital]) <= 0.0:
			dead = true
			if owner_actor.get_parent().has_method("combat_die"):
				owner_actor.get_parent().combat_die(vital)
			print("[DEFEATED] ",owner_actor.get_parent().name," ",vital)
			break

func receive_hit(world_point: Vector3, amount: float, attacker: String = "") -> void:
	if dead: return
	receive_region_hit(region_at(world_point),world_point,amount,attacker)

func flash_hit_region(region: String) -> void:
	var marker: MeshInstance3D = markers[region]
	if not marker.visible: return
	var mat: StandardMaterial3D = marker.material_override
	mat.albedo_color = Color(1.0,0.95,0.18,0.78)
	var flash := create_tween()
	flash.tween_property(mat,"albedo_color",Color(0.1,0.86,1.0,0.13),0.3)

func show_damage_number(point: Vector3, amount: float, region: String) -> void:
	var label := Label3D.new()
	label.text = "%s  -%d" % [region.to_upper().replace("_"," "),int(round(amount))]
	label.font_size = 48
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color("ffe2a0")
	get_tree().current_scene.add_child(label)
	label.global_position = point
	var motion := label.create_tween().set_parallel(true)
	motion.tween_property(label,"global_position",point+Vector3.UP*1.5,0.9)
	motion.tween_property(label,"modulate:a",0.0,0.9)
	motion.chain().tween_callback(label.queue_free)

func movement_penalty() -> float:
	var legs: float = minf(float(hp["left_leg"]),float(hp["right_leg"]))
	if legs <= 0.0: return 0.35
	if legs < 40.0: return 0.65
	return 1.0
