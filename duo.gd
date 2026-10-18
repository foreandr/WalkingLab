extends Node3D
var ai
var mannequins: Array = []
var player
var ai_label: Label3D
var player_label: Label3D
var ai_wait = 0.0
var watching_ai = false
var battle_fireball_speed: float = 1.0
var announced_winner: bool = false
var battle_feed: RichTextLabel
var battle_hits: Array[String] = []
var damage_totals: Dictionary = {}
var performance_label: Label
var performance_clock: float = 0.0
func _ready():
	# Normal gravity, animations, spells and AI timing; only travel slows.
	Engine.time_scale = 1.0
	# Lower internal 3D resolution without reducing UI readability.
	get_viewport().scaling_3d_scale = 0.7
	for entry in [["move_forward",KEY_W],["move_back",KEY_S],["move_left",KEY_A],["move_right",KEY_D],["sprint",KEY_ALT],["walk",KEY_CTRL]]:
		if not InputMap.has_action(entry[0]): InputMap.add_action(entry[0])
		var key = InputEventKey.new()
		key.keycode = entry[1]
		InputMap.action_add_event(entry[0],key)
	create_battle_feed()
	create_performance_hud()
	# Restore the arena and its real physics floor independently of mannequins.
	add_child(preload("res://arena_environment.gd").new())
	var floor_body := StaticBody3D.new()
	floor_body.name = "ArenaGroundCollision"
	add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(80.0,0.2,80.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	player = preload("res://walking.gd").new()
	player.name = "PlayerMan"
	player.player_controlled = true
	player.actor_only = true
	player.spawn_point = Vector3(0,0,30)
	player.character_tint = Color("101114")
	add_child(player)
	player.camera.current = true
	player.actor.rotation.y = 0.0
	player_label = make_label(player.actor,"BLACK",Color("dddddd"))
	make_boundary()
	var palette: Array[String] = ["7962cb","21c8d6","cb668d","87be4a","e3a452","597bc5","a7945c","d46cad","6bb3a8","b4c46c"]
	for i in range(10):
		var fighter = preload("res://walking.gd").new()
		fighter.name = "Fighter%02d" % (i+1)
		fighter.autonomous_only = true
		fighter.actor_only = true
		fighter.ai_abilities = true
		fighter.animation_test_mode = "war"
		fighter.spawn_point = Vector3(sin(i*TAU/10.0)*16.0,0,cos(i*TAU/10.0)*23.0)
		fighter.character_tint = Color(palette[i])
		add_child(fighter)
		fighter.actor.rotation.y = i*TAU/10.0+PI
		make_label(fighter.actor,"FIGHTER %02d" % (i+1),fighter.character_tint)
		mannequins.append(fighter)
	ai = mannequins[0]
	ai_label = null

func create_performance_hud() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "PerformanceHUD"
	add_child(overlay)
	performance_label = Label.new()
	performance_label.position = Vector2(14,10)
	performance_label.add_theme_font_size_override("font_size",16)
	performance_label.add_theme_color_override("font_color",Color("d9ffab"))
	overlay.add_child(performance_label)

func _process(dt: float) -> void:
	performance_clock -= dt
	if performance_clock > 0.0: return
	performance_clock = 0.5
	if performance_label == null: return
	var fps: int = Engine.get_frames_per_second()
	var draw_calls: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects: int = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var frame_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var reduced: int = 0
	for fighter in mannequins:
		if is_instance_valid(fighter) and not fighter.combat_dead and fighter.war_lod_mode == "reduced":
			reduced += 1
	performance_label.text = "FPS: %d | CPU: %.1f ms | physics: %.1f ms | draws: %d | objects: %d | reduced physics: %d/%d" % [fps,frame_ms,physics_ms,draw_calls,objects,reduced,mannequins.size()]

func create_battle_feed() -> void:
	var ui := CanvasLayer.new()
	ui.name = "BattleHUD"
	add_child(ui)
	var panel := PanelContainer.new()
	panel.position = Vector2(12,100)
	panel.custom_minimum_size = Vector2(310,280)
	panel.modulate.a = 0.88
	ui.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "WAR / DAMAGE"
	column.add_child(heading)
	battle_feed = RichTextLabel.new()
	battle_feed.custom_minimum_size = Vector2(290,240)
	battle_feed.scroll_following = true
	battle_feed.bbcode_enabled = false
	column.add_child(battle_feed)
	battle_feed.text = "Waiting for combat..."

func record_battle_hit(attacker: String, victim: String, region: String, amount: float, _health: float) -> void:
	var source: String = attacker if attacker != "" else "UNKNOWN"
	damage_totals[source] = float(damage_totals.get(source,0.0))+amount
	battle_hits.push_front("%s → %s  %s  -%d" % [source,victim,region.to_upper(),int(round(amount))])
	if battle_hits.size() > 11: battle_hits.resize(11)
	if battle_feed != null:
		battle_feed.text = "TOTAL DAMAGE\n"
		var leaders: Array = damage_totals.keys()
		leaders.sort_custom(func(a,b): return float(damage_totals[a]) > float(damage_totals[b]))
		for i in range(mini(3,leaders.size())):
			battle_feed.text += "%s: %d\n" % [leaders[i],int(damage_totals[leaders[i]])]
		battle_feed.text += "\nRECENT HITS\n" + "\n".join(battle_hits)

func spawn_moving_cpus() -> void:
	# Two walkers, two high-speed runners, two immediate flyers.
	var assignments := [
		{"mode":"walk","name":"WALKER 1","pos":Vector3(-11,0,2)},
		{"mode":"walk","name":"WALKER 2","pos":Vector3(-13,0,5)},
		{"mode":"sprint","name":"SPRINTER 1","pos":Vector3(-15,0,-3)},
		{"mode":"sprint","name":"SPRINTER 2","pos":Vector3(-17,0,1)},
		{"mode":"fly","name":"FLYER 1","pos":Vector3(12,0,-5)},
		{"mode":"fly","name":"FLYER 2","pos":Vector3(16,0,-6)}
	]
	for entry in assignments:
		var cpu = preload("res://walking.gd").new()
		cpu.name = String(entry["name"]).replace(" ","")
		cpu.ai_mode = String(entry["mode"])
		cpu.autonomous_only = true
		cpu.actor_only = true
		cpu.spawn_point = entry["pos"]
		cpu.route_center = Vector3.ZERO
		cpu.route_radius = 18.0 if entry["mode"] == "fly" else 25.0
		add_child(cpu)
		make_label(cpu.actor,String(entry["name"]),Color("91ddfa"))
		mannequins.append(cpu)

func make_label(body: Node3D, text: String, color: Color) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 40
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position.y = 2.25
	body.add_child(label)
	# Readable circular identity marker at each character's feet.
	var ring := MeshInstance3D.new()
	ring.name = "NameCircle"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.58
	torus.outer_radius = 0.63
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = color
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.no_depth_test = false
	ring.material_override = ring_material
	ring.position.y = 0.045
	body.add_child(ring)
	return label
func make_boundary():
	# Closed 80 x 80 metre arena: opaque visible walls and a solid roof.
	var structure := StaticBody3D.new()
	structure.name = "EnclosedArena"
	add_child(structure)
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("51606d")
	wall_material.roughness = 0.9
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("34414e")
	roof_material.roughness = 0.95
	roof_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surfaces := [
		{"name":"NorthWall","size":Vector3(80.0,55.0,1.5),"center":Vector3(0,27.5,-40)},
		{"name":"SouthWall","size":Vector3(80.0,55.0,1.5),"center":Vector3(0,27.5,40)},
		{"name":"EastWall","size":Vector3(1.5,55.0,80.0),"center":Vector3(40,27.5,0)},
		{"name":"WestWall","size":Vector3(1.5,55.0,80.0),"center":Vector3(-40,27.5,0)},
		{"name":"Ceiling","size":Vector3(80.0,1.5,80.0),"center":Vector3(0,55,0)}
	]
	for item in surfaces:
		var collider := CollisionShape3D.new()
		var solid := BoxShape3D.new()
		solid.size = item["size"]
		collider.shape = solid
		collider.position = item["center"]
		structure.add_child(collider)
		var visible_wall := MeshInstance3D.new()
		visible_wall.name = item["name"]
		var block := BoxMesh.new()
		block.size = item["size"]
		visible_wall.mesh = block
		visible_wall.material_override = roof_material if item["name"] == "Ceiling" else wall_material
		visible_wall.position = item["center"]
		structure.add_child(visible_wall)
	# Internal lights keep the enclosed battlefield visible.
	# One broad unshadowed interior lamp replaces four overlapping
	# per-object lighting passes; ambient light supplies the fill.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0,48,0)
	lamp.light_energy = 2.2
	lamp.omni_range = 85.0
	lamp.shadow_enabled = false
	add_child(lamp)

func _physics_process(_dt):
	if player == null: return
	player_label.position.y = player.crouch.capsule.height+0.3
	if announced_winner: return
	var survivors: Array = []
	for fighter in mannequins:
		if is_instance_valid(fighter) and not fighter.combat_dead: survivors.append(fighter)
	if survivors.size() == 1:
		announced_winner = true
		print("[WAR WINNER] ",survivors[0].name)
		var banner := Label3D.new()
		banner.text = "WINNER"
		banner.font_size = 90
		banner.pixel_size = 0.009
		banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		banner.modulate = Color("ffd05b")
		banner.position = Vector3.UP*3.5
		survivors[0].actor.add_child(banner)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:

		if event.keycode==KEY_TAB:
			watching_ai = not watching_ai
			player.camera_target = ai.actor if watching_ai else null
