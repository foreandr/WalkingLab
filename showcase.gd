extends "res://duo.gd"
# Isolated visual acceptance-test scene. Existing combat scene remains main.tscn.
# Reuses the production BLACK controller so the player's normal camera/movement/spells remain usable.
var performers: Array = []
var info: Label
var fps_elapsed: float = 0.0
var actors_started: int = 0
var preview_camera: Camera3D
var using_preview_camera: bool = false
var player_sword_on_ground: Node3D
var player_sword_in_hand: Node3D
var player_sword_label: Label3D

func _ready() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 60
	get_viewport().scaling_3d_scale = 0.8
	current_level = {"number":0, "name":"Animation acceptance test", "biome":"showcase", "battle_royale_drop":false}
	arena_half_extent = 56.0
	battle_fireball_speed = 1.0
	battle_fireball_size = 1.0
	for entry in [["move_forward",KEY_W],["move_back",KEY_S],["move_left",KEY_A],["move_right",KEY_D],["sprint",KEY_ALT],["walk",KEY_CTRL]]:
		if not InputMap.has_action(entry[0]): InputMap.add_action(entry[0])
		var key: InputEventKey = InputEventKey.new()
		key.keycode = entry[1]
		if not InputMap.action_has_event(entry[0],key): InputMap.action_add_event(entry[0],key)
	_build_flat_stage()
	player = preload("res://walking.gd").new()
	player.name = "PlayerMan"
	player.player_controlled = true
	player.actor_only = true
	player.auto_war_combat = false
	player.spawn_point = Vector3(0.0, 0.05, 16.0)
	player.character_tint = Color(0.24,0.27,0.32)
	player.demo_immortal = true
	player.infinite_mana = true
	player.ignore_spell_cooldowns = true
	var spells: Array[String] = ["fire","frost","homing","gravity","ricochet","grounding","bloom","tempest","venom","flight"]
	player.equipped_spells = spells
	add_child(player)
	player.camera.current = true
	make_label(player.actor, "YOU / FULL CONTROL", Color("fff0a5"))
	var performer = preload("res://showcase_single_performer.gd").new()
	performer.name = "SingleAnimationPerformer"
	performer.position = Vector3(0,0,-4.0)
	add_child(performer)
	performers.append(performer)
	actors_started = 1
	_build_player_sword()
	_build_camera()
	_build_hud()
	print("[SINGLE_SHOWCASE_READY] npc_count=1 steps=",performer.sequence.size()," controllable_player=true")

func _build_flat_stage() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "FlatFloor"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(112,112)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/medieval_blocks_03_diff.jpg")
	mat.uv1_scale = Vector3(24,24,1)
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	plane.material = mat
	ground.mesh = plane
	add_child(ground)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "FlatFloorCollision"
	add_child(floor_body)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(112,0.2,112)
	collider.shape = shape
	collider.position.y = -0.1
	floor_body.add_child(collider)
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055,0.075,0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.70,0.76,0.90)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,25,0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-34,-115,0)
	fill.light_energy = 0.40
	add_child(fill)

func _build_camera() -> void:
	preview_camera = Camera3D.new()
	preview_camera.fov = 42
	preview_camera.position = Vector3(3.5,3.0,2.7)
	add_child(preview_camera)
	preview_camera.current = false

func _build_player_sword() -> void:
	var sword_path: String = "res://assets/kenney_weapons/mini-arena/weapon-sword.glb"
	if not ResourceLoader.exists(sword_path):
		print("[PLAYER_SWORD_UNAVAILABLE] ",sword_path)
		return
	var packed: PackedScene = load(sword_path) as PackedScene
	if packed == null: return
	player_sword_on_ground = packed.instantiate() as Node3D
	if player_sword_on_ground == null: return
	add_child(player_sword_on_ground)
	player_sword_on_ground.position = player.actor.global_position + Vector3(1.0,0.08,-1.4)
	player_sword_on_ground.rotation_degrees = Vector3(0,0,90)
	player_sword_label = Label3D.new()
	player_sword_label.text = "SWORD - PRESS E"
	player_sword_label.font_size = 54
	player_sword_label.pixel_size = 0.0045
	player_sword_label.outline_size = 11
	player_sword_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	player_sword_label.position = Vector3(0,0.9,0)
	player_sword_on_ground.add_child(player_sword_label)

func _pickup_player_sword() -> void:
	if not is_instance_valid(player_sword_on_ground) or player_sword_in_hand != null: return
	if player.actor.global_position.distance_to(player_sword_on_ground.global_position) > 2.8: return
	var skeleton: Skeleton3D = player.skeleton
	if skeleton == null: return
	var right_hand: String = ""
	for candidate in ["mixamorig_RightHand","RightHand","hand_r","Hand_R"]:
		if skeleton.find_bone(candidate)>=0:
			right_hand = candidate
			break
	if right_hand.is_empty():
		print("[PLAYER_SWORD_ERROR] Right-hand bone missing")
		return
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.bone_name = right_hand
	attachment.name = "PlayerShowcaseSwordHand"
	skeleton.add_child(attachment)
	player_sword_on_ground.reparent(attachment,false)
	player_sword_on_ground.position = Vector3(0.03,0.47,0.0)
	player_sword_on_ground.rotation_degrees = Vector3(0,0,90)
	player_sword_label.visible = false
	player_sword_in_hand = player_sword_on_ground
	player_sword_on_ground = null
	print("[PLAYER_SHOWCASE_SWORD_PICKED_UP] key=E bone=",right_hand)

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ShowcaseHUD"
	add_child(layer)
	var top: PanelContainer = PanelContainer.new()
	top.position = Vector2(8,8)
	layer.add_child(top)
	var box: VBoxContainer = VBoxContainer.new()
	top.add_child(box)
	var title: Label = Label.new()
	title.text = "SINGLE ACTOR - ANIMATION ACCEPTANCE TEST"
	title.add_theme_font_size_override("font_size",18)
	box.add_child(title)
	var description: Label = Label.new()
	description.text = "WASD player   E pickup YOUR sword   F6 close-up camera   F7 next   F8 previous   F9 pause   F10 replay"
	description.add_theme_font_size_override("font_size",13)
	box.add_child(description)
	var notice: Label = Label.new()
	notice.text = "One demonstrator cycles through every action, picks up a real sword, swings and drops it. External rigs labelled."
	notice.add_theme_font_size_override("font_size",12)
	box.add_child(notice)
	info = Label.new()
	info.add_theme_font_size_override("font_size",13)
	box.add_child(info)

func _process(delta: float) -> void:
	fps_elapsed += delta
	if using_preview_camera and is_instance_valid(preview_camera) and not performers.is_empty():
		var target: Node3D = performers[0] as Node3D
		if is_instance_valid(target):
			preview_camera.look_at(target.global_position + Vector3.UP*1.25, Vector3.UP)
	if fps_elapsed < 0.12: return
	fps_elapsed = 0.0
	if not performers.is_empty() and is_instance_valid(performers[0]) and info != null:
		var p = performers[0]
		info.text = p.status_text() + "\nFPS: %.0f   |   ONE performer   |   F6: %s" % [Engine.get_frames_per_second(), "return to PLAYER" if using_preview_camera else "CAMERA CLOSE-UP"]

func _physics_process(_delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo: return
	if key.keycode == KEY_E:
		_pickup_player_sword()
		return
	if performers.is_empty(): return
	var p = performers[0]
	match key.keycode:
		KEY_F6:
			using_preview_camera = not using_preview_camera
			preview_camera.current = using_preview_camera
			player.camera.current = not using_preview_camera
		KEY_F7: p.next_action()
		KEY_F8: p.previous_action()
		KEY_F9: p.pause_action()
		KEY_F10: p.replay_action()
