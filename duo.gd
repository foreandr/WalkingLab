extends Node3D
var ai
var mannequins: Array = []
var player
var ai_label: Label3D
var player_label: Label3D
var ai_wait = 0.0
var watching_ai = false
func _ready():
	for entry in [["move_forward",KEY_W],["move_back",KEY_S],["move_left",KEY_A],["move_right",KEY_D],["sprint",KEY_ALT],["walk",KEY_CTRL]]:
		if not InputMap.has_action(entry[0]): InputMap.add_action(entry[0])
		var key = InputEventKey.new()
		key.keycode = entry[1]
		InputMap.action_add_event(entry[0],key)
	ai = preload("res://walking.gd").new()
	ai.name = "AutonomousMan"
	ai.autonomous_only = true
	ai.stationary_only = true
	ai.route_center = Vector3(0,0,0)
	ai.route_radius = 20.0
	ai.spawn_point = Vector3(-2.4,0,0)
	ai.character_tint = Color("e1d5c2")
	add_child(ai)
	player = preload("res://walking.gd").new()
	player.name = "PlayerMan"
	player.player_controlled = true
	player.actor_only = true
	player.spawn_point = Vector3(0,0,13)
	player.character_tint = Color("bdcedf")
	add_child(player)
	player.camera.current = true
	ai_label = make_label(ai.actor,"AI",Color("ffbf69"))
	player_label = make_label(player.actor,"YOU",Color("75d8ff"))
	make_boundary()
	# Opponent remains stationary across the arena; only its selected idle loops.
	ai.actor.rotation.y = PI
	mannequins.append(ai)
	for index in range(2):
		var extra = preload("res://walking.gd").new()
		extra.name = "IdleMannequin" + str(index+2)
		extra.autonomous_only = true
		extra.stationary_only = true
		extra.actor_only = true
		extra.spawn_point = Vector3(float(index)*2.4,0,0)
		extra.character_tint = Color("c9d2cc") if index == 0 else Color("d6c8d1")
		add_child(extra)
		extra.actor.rotation.y = PI
		make_label(extra.actor,"AI " + str(index+2),Color("ffbf69"))
		mannequins.append(extra)
	build_weapon_display()
	build_water_basin()
func build_water_basin() -> void:
	# Open-top physical test tank; thick walls and floor, no roof.
	var world := preload("res://water_system.gd").new()
	world.name = "WaterSystem"
	add_child(world)
	var center: Vector3 = world.BASIN_CENTER
	var width: float = world.INSIDE_WIDTH
	var depth: float = world.INSIDE_DEPTH
	var height: float = world.WALL_HEIGHT
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.48,0.51,0.55)
	stone.roughness = 0.9
	for part in [
		{"name":"Floor","size":Vector3(width+0.4,0.20,depth+0.4),"pos":Vector3(0,-0.10,0)},
		{"name":"West","size":Vector3(0.20,height,depth+0.40),"pos":Vector3(-width*0.5-0.10,height*0.5,0)},
		{"name":"East","size":Vector3(0.20,height,depth+0.40),"pos":Vector3(width*0.5+0.10,height*0.5,0)},
		{"name":"North","size":Vector3(width+0.40,height,0.20),"pos":Vector3(0,height*0.5,-depth*0.5-0.10)},
		{"name":"South","size":Vector3(width+0.40,height,0.20),"pos":Vector3(0,height*0.5,depth*0.5+0.10)}
	]:
		var body := StaticBody3D.new()
		body.name = "Basin" + String(part["name"])
		body.position = center + part["pos"]
		add_child(body)
		var mesh := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = part["size"]
		mesh.mesh = shape
		mesh.material_override = stone
		body.add_child(mesh)
		var collider := CollisionShape3D.new()
		var collision_box := BoxShape3D.new()
		collision_box.size = part["size"]
		collider.shape = collision_box
		body.add_child(collider)
	var label := Label3D.new()
	label.text = "WATER FILL TEST  /  PRESS 2"
	label.font_size = 42
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = center + Vector3(0,2.8,0)
	add_child(label)

func make_label(body: Node3D, text: String, color: Color) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 40
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position.y = 2.1
	body.add_child(label)
	return label
func build_weapon_display() -> void:
	# External CC0 weapons only: no primitive geometry and no material overrides.
	# The real-weapon pack contains finished steel/handle materials and its
	# original scenes are flat on +Y-up ground. Kenney is a textured fallback.
	var assets = [
		{"name":"Arming Sword","x":-3.6,"z":10.0,"file":"arming_sword.glb","fallback":"res://assets/kenney_weapons/mini-arena/weapon-sword.glb"},
		{"name":"Knightly Sword","x":-1.8,"z":9.8,"file":"knightly_sword.glb","optional":true},
		{"name":"Greatsword","x":0.0,"z":10.0,"file":"greatsword.glb","optional":true},
		{"name":"Bearded Axe","x":1.8,"z":9.8,"file":"bearded_axe.glb","fallback":"res://assets/kenney_weapons/survival/tool-axe.glb"},
		{"name":"Rondel Dagger","x":3.6,"z":10.0,"file":"rondel_dagger.glb","fallback":"res://assets/kenney_weapons/weapon/knife_sharp.glb"}
	]
	for entry in assets:
		var path = "res://assets/real_weapons/" + String(entry["file"])
		var using_kenney = false
		if not ResourceLoader.exists(path):
			if entry.has("fallback") and ResourceLoader.exists(String(entry["fallback"])):
				path = String(entry["fallback"])
				using_kenney = true
			elif entry.get("optional",false):
				continue
			else:
				push_warning("WEAPON_ASSET_MISSING " + path)
				continue
		var packed = load(path)
		if not packed is PackedScene:
			push_warning("WEAPON_ASSET_NOT_SCENE " + path)
			continue
		var scene: Node3D = packed.instantiate()
		scene.name = String(entry["name"])
		scene.position = Vector3(float(entry["x"]),0.045,float(entry["z"]))
		if using_kenney:
			# Old Kenney files have a different authoring orientation.
			scene.rotation.x = PI * 0.5
			scene.position.y = 0.15
		add_child(scene)
		var title := Label3D.new()
		title.name = String(entry["name"]) + "Label"
		title.text = String(entry["name"])
		title.font_size = 32
		title.pixel_size = 0.004
		title.modulate = Color("e5e3d9")
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title.no_depth_test = false
		title.position = Vector3(float(entry["x"]),0.40,float(entry["z"])+0.60)
		add_child(title)

func make_boundary():
	var boundary = StaticBody3D.new()
	boundary.name = "ArenaBoundary"
	add_child(boundary)
	for i in range(64):
		var angle = i*TAU/64.0
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(TAU*58.0/64.0+0.15,3.0,0.5)
		collision.shape = shape
		collision.position = Vector3(sin(angle)*58.0,1.5,cos(angle)*58.0)
		collision.rotation.y = angle
		boundary.add_child(collision)
func _physics_process(dt):
	if ai==null or player==null: return
	ai_label.position.y = ai.crouch.capsule.height+0.3
	player_label.position.y = player.crouch.capsule.height+0.3
	ai_label.text = "AI"

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:

		if event.keycode==KEY_TAB:
			watching_ai = not watching_ai
			player.camera_target = ai.actor if watching_ai else null
