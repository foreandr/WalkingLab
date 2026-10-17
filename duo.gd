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
	ai.spawn_point = Vector3(-1.8,0,6)
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
	ai_label = make_label(ai.actor,"MANNEQUIN",Color("ffbf69"))
	player_label = make_label(player.actor,"YOU",Color("ff2020"))
	make_boundary()
	# Keep only two CPU characters: one static reference and one
	# autonomous character with the same fire, water and flight abilities.
	ai.actor.rotation.y = PI
	mannequins.append(ai)
	var caster = preload("res://walking.gd").new()
	caster.name = "SpellcasterAI"
	caster.autonomous_only = true
	caster.stationary_only = true
	caster.actor_only = true
	caster.spawn_point = Vector3(1.8,0,6)
	caster.character_tint = Color("c9d2cc")
	add_child(caster)
	caster.actor.rotation.y = PI
	make_label(caster.actor,"MANNEQUIN",Color("ffbf69"))
	mannequins.append(caster)
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
	var boundary = StaticBody3D.new()
	boundary.name = "ArenaBoundary"
	add_child(boundary)
	for i in range(64):
		var angle = i*TAU/64.0
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(TAU*580.0/64.0+0.15,3.0,0.5)
		collision.shape = shape
		collision.position = Vector3(sin(angle)*580.0,1.5,cos(angle)*580.0)
		collision.rotation.y = angle
		boundary.add_child(collision)
func _physics_process(dt):
	if ai==null or player==null: return
	ai_label.position.y = ai.crouch.capsule.height+0.3
	player_label.position.y = player.crouch.capsule.height+0.3
	ai_label.text = "MANNEQUIN"

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:

		if event.keycode==KEY_TAB:
			watching_ai = not watching_ai
			player.camera_target = ai.actor if watching_ai else null
