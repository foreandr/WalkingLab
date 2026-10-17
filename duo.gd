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
func weapon_piece(parent: Node3D, label: String, dimensions: Vector3, location: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.position = location
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.7
	material.roughness = 0.35
	mesh.material_override = material
	parent.add_child(mesh)

func build_weapon_display() -> void:
	# Simple props laid flat on the floor, 10 metres in front of the row.
	var steel = Color("c6d6dd")
	var wood = Color("67472c")
	for entry in [
		{"name":"Sword","x":-2.4,"length":1.15,"type":"sword"},
		{"name":"One-handed Axe","x":0.0,"length":0.85,"type":"axe"},
		{"name":"Dagger","x":2.4,"length":0.55,"type":"dagger"}
	]:
		var prop := Node3D.new()
		prop.name = String(entry["name"])
		prop.position = Vector3(float(entry["x"]),0,10.0)
		add_child(prop)
		var length: float = float(entry["length"])
		weapon_piece(prop,"Grip",Vector3(0.085,0.09,length*0.40),Vector3(0,0.13,length*0.25),wood)
		weapon_piece(prop,"Metal",Vector3(0.10,0.055,length*0.64),Vector3(0,0.13,-length*0.23),steel)
		if entry["type"] == "sword":
			weapon_piece(prop,"Crossguard",Vector3(0.36,0.075,0.08),Vector3(0,0.13,0.0),steel)
		elif entry["type"] == "axe":
			weapon_piece(prop,"Axe Head",Vector3(0.43,0.09,0.29),Vector3(0.16,0.13,-length*0.42),steel)
		else:
			weapon_piece(prop,"Guard",Vector3(0.20,0.065,0.05),Vector3(0,0.13,0.0),steel)
		var title := Label3D.new()
		title.text = String(entry["name"])
		title.font_size = 34
		title.pixel_size = 0.006
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title.position = Vector3(0,0.52,0)
		prop.add_child(title)

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
