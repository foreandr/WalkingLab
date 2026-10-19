extends "res://duo.gd"
# Isolated visual acceptance-test scene. Existing combat scene remains main.tscn.
# Reuses the production BLACK controller so the player's normal camera/movement/spells remain usable.
var performers: Array[Node3D] = []
var info: Label
var fps_elapsed: float = 0.0
var actors_started: int = 0

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
	var source1: String = "res://assets/source_original.glb"
	var source2: String = "res://assets/showcase/UAL2_Standard.glb"
	var newer_available: bool = ResourceLoader.exists(source2)
	for i in range(10):
		var performer: Node3D = preload("res://showcase_performer.gd").new()
		performer.name = "Performer%02d" % (i+1)
		performer.performer_index = i
		# UAL1 is already tracked; UAL2 is downloaded by RUN.bat.
		performer.source_file = source2 if newer_available and i in [3,5,8,9] else source1
		performer.position = Vector3(float((i%5)-2)*6.5,0.0,-7.0-float(i/5)*14.0)
		add_child(performer)
		performers.append(performer)
	actors_started = performers.size()
	_build_hud()
	print("[ANIMATION_SHOWCASE] count=",actors_started, " player=controlled", " ual1=",source1," ual2_available=",newer_available," fps_target=60")
	if not newer_available:
		push_warning("[SHOWCASE] UAL2 is not installed: RUN.bat should download it; parkour/combo performers will report missing clips until import succeeds.")

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
	title.text = "ANIMATION + SPELL SHOWCASE  |  10 AUTOMATED PERFORMERS"
	title.add_theme_font_size_override("font_size",18)
	box.add_child(title)
	var description: Label = Label.new()
	description.text = "WASD move   ALT sprint   CTRL walk   SPACE jump / fly   Mouse camera  |  Player controls unchanged"
	description.add_theme_font_size_override("font_size",13)
	box.add_child(description)
	var notice: Label = Label.new()
	notice.text = "Only source animation clips are played. Missing flips / strafes are marked honestly above the performer."
	notice.add_theme_font_size_override("font_size",12)
	box.add_child(notice)
	info = Label.new()
	info.add_theme_font_size_override("font_size",13)
	box.add_child(info)

func _process(delta: float) -> void:
	fps_elapsed += delta
	if fps_elapsed < 0.5: return
	fps_elapsed = 0.0
	var missing: int = 0
	for p in performers:
		if is_instance_valid(p): missing += p.missing_clips.size()
	if info != null:
		info.text = "FPS %.0f  |  NPCs %d/10  |  Unavailable authored actions %d  |  60 FPS target" % [Engine.get_frames_per_second(),performers.size(),missing]

func _physics_process(_delta: float) -> void:
	# The player simulates normally in walking.gd; NPCs are animation test actors.
	pass

func _unhandled_input(_event: InputEvent) -> void:
	# Preserve the player controller's own independent input handling.
	pass
