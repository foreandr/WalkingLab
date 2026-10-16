extends Node3D
var originals = ["Walk","Jog_Fwd","Sprint","Idle","Jump_Start","Jump","Jump_Land"]
var targets = ["move_walk","move_run","move_sprint","move_idle","move_takeoff","move_jump","move_land"]
var source: Node3D
var target: Node3D
var player_a: AnimationPlayer
var player_b: AnimationPlayer
var sk_a: Skeleton3D
var sk_b: Skeleton3D
var helper
var camera: Camera3D
var label: Label
var status: Label
var which = 0
var clock = 0.0
var rate = 1.0
var paused = false
var side_view = false
var inspect_mode = false
var frame = 0
var ui_visible = true
var foot_a = preload("res://foot_ground.gd").new()
var foot_b = preload("res://foot_ground.gd").new()
var min_a = INF
var min_b = INF
func _ready():
	inspect_mode = "--comparison-capture" in OS.get_cmdline_user_args()
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8f9da5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d2d7dc")
	env.ambient_light_energy = 0.5
	world.environment = env
	add_child(world)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(40,40)
	floor_mesh.mesh = plane
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("707a7a")
	material.roughness = 1
	floor_mesh.material_override = material
	add_child(floor_mesh)
	var grid = ImmediateMesh.new()
	var grid_instance = MeshInstance3D.new()
	grid_instance.mesh = grid
	var grid_material = StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.albedo_color = Color("a9b7b4")
	grid_instance.material_override = grid_material
	add_child(grid_instance)
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-10,11):
		grid.surface_add_vertex(Vector3(i,0.002,-10));grid.surface_add_vertex(Vector3(i,0.002,10))
		grid.surface_add_vertex(Vector3(-10,0.002,i));grid.surface_add_vertex(Vector3(10,0.002,i))
	grid.surface_end()
	source = load("res://assets/source_original.glb").instantiate()
	target = load("res://assets/character.glb").instantiate()
	add_child(source);add_child(target)
	source.position.x = -1.35
	target.position.x = 1.35
	source.rotation.y = PI
	target.rotation.y = PI
	player_a = source.find_children("*","AnimationPlayer",true,false)[0]
	player_b = target.find_children("*","AnimationPlayer",true,false)[0]
	sk_a = source.find_children("*","Skeleton3D",true,false)[0]
	sk_b = target.find_children("*","Skeleton3D",true,false)[0]
	player_a.callback_mode_process = 2
	player_b.callback_mode_process = 2
	helper = load("res://walking.gd").new()
	helper.skeleton = sk_b
	helper.anim = player_b
	helper.install_library()
	foot_a.setup(source,sk_a);foot_b.setup(target,sk_b)
	camera = Camera3D.new()
	camera.fov = 43
	add_child(camera)
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var panel = ColorRect.new()
	panel.color = Color(0.025,0.04,0.05,0.88)
	panel.size = Vector2(1280,125)
	canvas.add_child(panel)
	label = Label.new()
	label.position = Vector2(25,15)
	label.add_theme_font_size_override("font_size",20)
	canvas.add_child(label)
	status = Label.new()
	status.position = Vector2(25,646)
	status.add_theme_font_size_override("font_size",17)
	canvas.add_child(status)
	select_clip(0)
func select_clip(index):
	which = index
	clock = 0
	min_a = INF;min_b = INF
	player_a.play(originals[which],0,0)
	player_b.play(targets[which],0,0)
func _process(dt):
	if inspect_mode:
		frame += 1
		var section = mini(5,frame/180)
		var desired_clip = section%3
		if desired_clip!=which: select_clip(desired_clip)
		side_view = section>=3
	if not paused: clock += dt*rate
	var length = player_a.get_animation(originals[which]).length
	var t = fmod(clock,length)
	player_a.seek(t,true);player_a.advance(0)
	player_b.seek(t,true);player_b.advance(0)
	# Deliberately no foot correction, root movement, IK or pose edits in this comparison.
	if frame%10==0:
		sk_a.force_update_all_bone_transforms();sk_b.force_update_all_bone_transforms()
		min_a = min(min_a,foot_a.lowest(foot_a.all_samples))
		min_b = min(min_b,foot_b.lowest(foot_b.all_samples))
	source.position = Vector3(0,0,-1.35) if side_view else Vector3(-1.35,0,0)
	target.position = Vector3(0,0,1.35) if side_view else Vector3(1.35,0,0)
	var focus = Vector3(0,0.95,0)
	camera.position = Vector3(4.9,2.2,6.6) if not side_view else Vector3(7.6,1.65,0)
	camera.look_at(focus)
	label.text = "WALKING LAB - CURRENT  |  MILESTONE A / SOURCE COMPARISON\nLEFT: untouched Quaternius rig     RIGHT: retargeted Defender (no grounding fix)\n%s  |  %.2fx playback  |  %s view  |  %d FPS"%[originals[which],rate,"SIDE" if side_view else "3/4",Engine.get_frames_per_second()]
	status.text = "1 walk  2 jog  3 sprint  4 idle  5 takeoff  6 air  7 landing   |   Space pause   T slow   V view\nDiagnostic in-place playback. No controller movement. Floor minimum: source %.3fm / target %.3fm"%[min_a,min_b]
	if inspect_mode:
		var directory = OS.get_environment("COMPARISON_SHOTS")
		if directory!="" and frame%60==30: get_viewport().get_texture().get_image().save_png(directory.path_join("comparison-%04d.png"%frame))
		if frame>=1080:
			print("COMPARISON_CAPTURE frames=",frame," source_min=",min_a," target_min=",min_b)
			get_tree().quit()
func _unhandled_input(event):
	if inspect_mode:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode>=KEY_1 and event.keycode<=KEY_7:select_clip(event.keycode-KEY_1)
		if event.keycode==KEY_SPACE:paused = not paused
		if event.keycode==KEY_T:rate = 0.25 if rate==1 else 1.0
		if event.keycode==KEY_V:side_view = not side_view
		if event.keycode==KEY_F3:
			ui_visible = not ui_visible
			label.visible = ui_visible;status.visible = ui_visible
func _exit_tree():
	if helper:helper.free()

