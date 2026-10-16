extends Node3D
var ai
var player
var ai_label: Label3D
var player_label: Label3D
var ai_wait = 0.0
var watching_ai = false
func _ready():
	for entry in [["move_forward",KEY_W],["move_back",KEY_S],["move_left",KEY_A],["move_right",KEY_D],["sprint",KEY_SHIFT],["walk",KEY_CTRL]]:
		if not InputMap.has_action(entry[0]): InputMap.add_action(entry[0])
		var key = InputEventKey.new()
		key.keycode = entry[1]
		InputMap.action_add_event(entry[0],key)
	ai = preload("res://walking.gd").new()
	ai.name = "AutonomousMan"
	ai.autonomous_only = true
	ai.route_center = Vector3(0,0,12)
	ai.route_radius = 20.0
	ai.spawn_point = Vector3(0,0,32)
	ai.character_tint = Color("e1d5c2")
	add_child(ai)
	player = preload("res://walking.gd").new()
	player.name = "PlayerMan"
	player.player_controlled = true
	player.actor_only = true
	player.spawn_point = Vector3(3,0,32)
	player.character_tint = Color("bdcedf")
	add_child(player)
	player.camera.current = true
	ai_label = make_label(ai.actor,"AI",Color("ffbf69"))
	player_label = make_label(player.actor,"YOU",Color("75d8ff"))
	make_boundary()
	var lineup = preload("res://idle_lineup.gd").new()
	lineup.name = "IdleLineup"
	add_child(lineup)
	ai.crouch.start_showcase()
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
func make_boundary():
	var boundary = StaticBody3D.new()
	boundary.name = "ArenaBoundary"
	add_child(boundary)
	for i in range(64):
		var angle = i*TAU/64.0
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(TAU*174.0/64.0+0.15,3.0,0.5)
		collision.shape = shape
		collision.position = Vector3(sin(angle)*174.0,1.5,cos(angle)*174.0)
		collision.rotation.y = angle
		boundary.add_child(collision)
func _physics_process(dt):
	if ai==null or player==null: return
	ai_label.position.y = ai.crouch.capsule.height+0.3
	player_label.position.y = player.crouch.capsule.height+0.3
	ai_label.text = "AI"
	if ai.crouch.showcase or ai.crouch.active(): ai_wait = 0.0
	else:
		ai_wait += dt
		if ai_wait>=145.0:
			ai.crouch.start_showcase()
			ai_wait = 0.0
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_V: ai.crouch.start_showcase()
		if event.keycode==KEY_TAB:
			watching_ai = not watching_ai
			player.camera_target = ai.actor if watching_ai else null
