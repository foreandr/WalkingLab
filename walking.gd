extends Node3D
@export var player_controlled = false
@export var actor_only = false
@export var autonomous_only = false
var spawn_point = Vector3(0,0,40)
var route_center = Vector3.ZERO
var route_radius = 40.0
var character_tint = Color("d5d9dd")
var manual_input = Vector2.ZERO
var manual_launch_lock = false
var manual_sprint_clock = 0.0
# Seconds per smooth 6 -> 8 -> 10 -> 12 m/s sprint stage.
# Above 12 m/s, keep the final FastRun clip and gain 0.2 m/s per stage duration.
const ENDLESS_SPRINT_GAIN = 0.2
const SPRINT_STAGE_SECONDS = 3.0
var manual_heading = 0.0
var camera_target: CharacterBody3D

const LABELS = ["WALK", "EASY RUN", "RUN", "STANDARD RUN", "FAST RUN", "QUICK RUN"]
const NAMES = ["PreviousWalk", "EasyRun", "Run", "StandardRun", "QuickRun", "FastRun"]
const SPEEDS = [2.295,4.0,6.0,8.0,10.0,12.0]
const STRIDES = [1.8247359725,2.0463959811,2.9254565804,3.0925173375,3.5791259432,2.8810510397]
const FILE_LABELS = ["previous walk", "Running (1).fbx", "Running.fbx", "Standard Run.fbx", "Fast Run.fbx", "Running (3).fbx"]
const BACK_NAMES = ["BackWalk", "BackRun", "BackQuickRun"]
const BACK_LABELS = ["BACKWARD WALK", "BACKWARD RUN", "QUICK BACKWARD RUN"]
const BACK_FILES = ["Walking Backwards.fbx", "Running Backward.fbx", "Run Backward.fbx"]
const BACK_SPEEDS = [1.4,4.2,7.0]
const BACK_STRIDES = [1.2861592747,1.9162409005,1.9161717009]
const LAP_RADIUS = 40.0
var actor: CharacterBody3D
var visual: Node3D
var skeleton: Skeleton3D
var tree: AnimationTree
var camera: Camera3D
var hud: Label
var feet = preload("res://foot_ground.gd").new()
var crouch = preload("res://crouch_controller.gd").new()
var camera_focus_height = 1.05
var clock = 0.0
var speed = 0.0
var blend = 0.0
var paused = false
var slow = false
var orbit = 0.72
var elevation = -0.18
var distance = 5.8
var frame = 0
var test = false
var min_sole = INF
var min_body = INF
var max_lift = 0.0
var traveled = 0.0
var seen = {}
var max_step = 0.0
var started = 0
var walk_choice = 0.0
var walk_target = 0.0
var mode_clock = 0.0
var backward = true
var back_blend = 0.0
var direction_weight = 1.0
var signed_speed = -BACK_SPEEDS[0]
var turning = false
var turn_time = 0.0
var turn_target = false
var turn_start_speed = 0.0
var turn_start_weight = 0.0
var turn_start_forward = 0.0
var turn_start_back = 0.0
var backward_distance = 0.0
var minimum_facing_alignment = 1.0
func _ready():
	test = "--autotest" in OS.get_cmdline_user_args()
	if "--new-walk" in OS.get_cmdline_user_args():
		walk_target = 1.0
		walk_choice = 1.0
		backward = false
		direction_weight = 0.0
		signed_speed = SPEEDS[0]
	started = Time.get_ticks_msec()
	if not actor_only:
		add_child(preload("res://arena_environment.gd").new())
		var floor_body = StaticBody3D.new()
		add_child(floor_body)
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(600,0.2,600)
		shape.shape = box
		shape.position.y = -0.1
		floor_body.add_child(shape)
	actor = CharacterBody3D.new()
	add_child(actor)
	actor.position = spawn_point
	actor.rotation.y = -PI/2
	actor.floor_snap_length = 0.12
	actor.safe_margin = 0.003
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	actor.add_child(collision)
	visual = preload("res://assets/user_mixamo.glb").instantiate()
	actor.add_child(visual)
	visual.rotation.y = PI
	skeleton = visual.find_children("*","Skeleton3D",true,false)[0]
	var player: AnimationPlayer = visual.find_children("*","AnimationPlayer",true,false)[0]
	if player.has_animation("Sprint"): player.get_animation_library("").remove_animation("Sprint")
	install_backwards(player)
	print("MIXAMO_CLIPS ",player.get_animation_list())
	var white = StandardMaterial3D.new()
	white.albedo_color = character_tint
	white.roughness = 0.8
	for part in visual.find_children("*","MeshInstance3D",true,false): part.material_override = white
	var space = AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = float(NAMES.size()-1)
	space.sync = true
	for i in range(NAMES.size()):
		var clip_name = NAMES[i]
		if not player.has_animation(clip_name): clip_name += "_Loop"
		assert(player.has_animation(clip_name),"Missing animation: "+clip_name)
		player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
		var clip = AnimationNodeAnimation.new()
		clip.animation = clip_name
		if i==0:
			var walk_graph = AnimationNodeBlendTree.new()
			walk_graph.add_node("Previous",clip)
			var new_walk = AnimationNodeAnimation.new()
			new_walk.animation = "NewWalk"
			player.get_animation("NewWalk").loop_mode = Animation.LOOP_LINEAR
			walk_graph.add_node("New",new_walk)
			var choice = AnimationNodeBlend2.new()
			choice.sync = true
			walk_graph.add_node("Choice",choice)
			walk_graph.connect_node("Choice",0,"Previous")
			walk_graph.connect_node("Choice",1,"New")
			walk_graph.connect_node("output",0,"Choice")
			space.add_blend_point(walk_graph,0.0,-1,"Walk")
		else: space.add_blend_point(clip,float(i),-1,NAMES[i])
	var back_space = AnimationNodeBlendSpace1D.new()
	back_space.min_space = 0.0
	back_space.max_space = 2.0
	back_space.sync = true
	for i in range(3):
		var clip = AnimationNodeAnimation.new()
		clip.animation = "back/"+BACK_NAMES[i]
		back_space.add_blend_point(clip,float(i),-1,BACK_NAMES[i])
	var graph = AnimationNodeBlendTree.new()
	graph.add_node("Gaits",space)
	graph.add_node("BackGaits",back_space)
	var direction_blend = AnimationNodeBlend2.new()
	direction_blend.sync = true
	graph.add_node("Direction",direction_blend)
	graph.connect_node("Direction",0,"Gaits")
	graph.connect_node("Direction",1,"BackGaits")
	graph.add_node("Cadence",AnimationNodeTimeScale.new())
	graph.connect_node("Cadence",0,"Direction")
	crouch.setup(self,player,graph)
	print("CROUCH_CLIPS ",player.get_animation_list())
	tree = AnimationTree.new()
	visual.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.tree_root = graph
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	feet.setup(visual,skeleton)
	camera = Camera3D.new()
	camera.fov = 52 if player_controlled else 46
	add_child(camera)
	camera.current = not autonomous_only
	var canvas = CanvasLayer.new()
	add_child(canvas)
	canvas.visible = not autonomous_only
	var backing = ColorRect.new()
	backing.position = Vector2(20,18)
	backing.size = Vector2(760,115)
	backing.color = Color(0.04,0.06,0.07,0.83)
	canvas.add_child(backing)
	hud = Label.new()
	hud.position = Vector2(36,26)
	hud.add_theme_font_size_override("font_size",18)
	canvas.add_child(hud)
	var controls = Label.new()
	controls.position = Vector2(28,675)
	controls.text = "C crouch/stand | Shift launch | V showcase | B direction | Space pause | T slow | Right-drag orbit"
	canvas.add_child(controls)
	if player_controlled:
		backward = false
		direction_weight = 0.0
		signed_speed = 0.0
		actor.rotation.y = orbit
		manual_heading = orbit
		distance = 6.5
		controls.text = "WASD move | Hold Shift to build sprint | Ctrl walk | C crouch | V AI showcase | Tab watch AI | Right-drag camera"
	update_camera()
	if not player_controlled and "--crouch-demo" in OS.get_cmdline_user_args(): crouch.start_showcase()
func smooth_gait(t: float) -> float:
	return t*t*t*(t*(t*6.0-15.0)+10.0)
func install_backwards(player: AnimationPlayer):
	install_motion_library(player,"res://assets/backward_motions.glb","back",BACK_NAMES,BACK_NAMES)
func install_motion_library(player: AnimationPlayer, resource_path: String, library_name: String, clip_names: Array, loops: Array):
	var source = load(resource_path).instantiate()
	var source_player: AnimationPlayer = source.find_children("*","AnimationPlayer",true,false)[0]
	var source_skeleton: Skeleton3D = source.find_children("*","Skeleton3D",true,false)[0]
	assert(source_skeleton.get_bone_count()==skeleton.get_bone_count(),"Backward rig differs")
	for index in range(skeleton.get_bone_count()):
		var name = skeleton.get_bone_name(index)
		assert(source_skeleton.find_bone(name)>=0,"Missing backward bone: "+name)
	var library = AnimationLibrary.new()
	var target_path = player.get_node(player.root_node).get_path_to(skeleton)
	for name in clip_names:
		var source_name = name if source_player.has_animation(name) else name+"_Loop"
		assert(source_player.has_animation(source_name),"Missing backward clip: "+name)
		var clip = source_player.get_animation(source_name).duplicate(true)
		for index in range(clip.get_track_count()-1,-1,-1):
			var path = clip.track_get_path(index)
			if path.get_subname_count()==0:
				clip.remove_track(index)
				continue
			var bone = String(path.get_subname(0))
			assert(skeleton.find_bone(bone)>=0,"Unknown backward animation bone: "+bone)
			clip.track_set_path(index,NodePath(String(target_path)+":"+bone))
		clip.loop_mode = Animation.LOOP_LINEAR if name in loops else Animation.LOOP_NONE
		library.add_animation(name,clip)
	player.add_animation_library(library_name,library)
	source.free()
func schedule(at: float, sequence: Array) -> Dictionary:
	var segment = int(at/10.0)%sequence.size()
	var a = sequence[segment]
	var b = sequence[(segment+1)%sequence.size()]
	var weight = smooth_gait(clamp((fmod(at,10.0)-6.0)/4.0,0.0,1.0))
	return {"a":a,"b":b,"weight":weight,"blend":lerp(float(a),float(b),weight)}
func band_value(values: Array, at: float) -> float:
	var low = int(floor(at))
	return lerp(float(values[low]),float(values[mini(low+1,values.size()-1)]),at-low)
func begin_direction_change(target_backward: bool):
	turning = true
	turn_time = 0.0
	turn_target = target_backward
	turn_start_speed = signed_speed
	turn_start_weight = direction_weight
	turn_start_forward = blend
	turn_start_back = back_blend
func _physics_process(dt):
	if paused: return
	var step = dt*(0.35 if slow else 1.0)
	clock += step
	var active = {}
	var old_blend = blend
	var old_back_blend = back_blend
	var was_turning = turning
	if player_controlled:
		manual_input = Input.get_vector("move_left","move_right","move_back","move_forward")
		if manual_input.length()>0.01:
			var camera_forward = Vector3(-sin(orbit),0,-cos(orbit))
			var camera_right = Vector3(cos(orbit),0,-sin(orbit))
			var desired = camera_forward*manual_input.y+camera_right*manual_input.x
			if manual_input.y< -0.1: desired = -desired
			manual_heading = atan2(-desired.x,-desired.z)
		if not Input.is_action_pressed("sprint"): manual_launch_lock = false
		if Input.is_action_just_pressed("sprint") and crouch.active():
			manual_launch_lock = true
			crouch.sprint()
	var crouch_driving = crouch.update(step)
	if player_controlled:
		var building_sprint = not crouch_driving and not crouch.active() and not manual_launch_lock and Input.is_action_pressed("sprint") and not Input.is_action_pressed("walk") and manual_input.y>0.1
		if not building_sprint:
			manual_sprint_clock = 0.0
		elif signed_speed>=SPEEDS[2]-0.05 and actor.get_real_velocity().length()>SPEEDS[2]*0.7:
			manual_sprint_clock += step
	if crouch_driving:
		signed_speed = crouch.forward_speed
	elif player_controlled:
		var target_speed = manual_target_speed()
		signed_speed = move_toward(signed_speed,target_speed,step*(8.0 if target_speed==0.0 else 6.0))
		backward = signed_speed<0.0
		direction_weight = move_toward(direction_weight,1.0 if backward else 0.0,step*4.0)
		blend = speed_band(SPEEDS,abs(signed_speed))
		back_blend = speed_band(BACK_SPEEDS,abs(signed_speed))
	elif turning:
		turn_time += step
		var weight = smooth_gait(clamp(turn_time/4.0,0.0,1.0))
		blend = lerp(turn_start_forward,0.0,weight)
		back_blend = lerp(turn_start_back,0.0,weight)
		direction_weight = lerp(turn_start_weight,1.0 if turn_target else 0.0,weight)
		signed_speed = lerp(turn_start_speed,-BACK_SPEEDS[0] if turn_target else SPEEDS[0],weight)
		if turn_time>=4.0:
			turning = false
			backward = turn_target
			mode_clock = 0.0
	else:
		mode_clock += step
		if backward:
			active = schedule(mode_clock,[0,1,2,1])
			back_blend = active.blend
			blend = 0.0
			direction_weight = 1.0
			signed_speed = -band_value(BACK_SPEEDS,back_blend)
			seen[BACK_LABELS[active.a]] = true
		else:
			active = schedule(mode_clock,[0,1,2,3,4,5,4,3,2,1])
			blend = active.blend
			back_blend = 0.0
			direction_weight = 0.0
			signed_speed = band_value(SPEEDS,blend)
			seen[LABELS[active.a]] = true
		if mode_clock>=(40.0 if backward else 100.0): begin_direction_change(not backward)
	max_step = max(max_step,max(abs(blend-old_blend),abs(back_blend-old_back_blend)))
	var side_speed = crouch.lateral_speed if crouch_driving else 0.0
	speed = Vector2(side_speed,signed_speed).length()
	walk_choice = move_toward(walk_choice,walk_target,step/4.0)
	var forward_strides = STRIDES.duplicate()
	forward_strides[0] = lerp(STRIDES[0],1.646443612,walk_choice)
	var stride = lerp(band_value(forward_strides,blend),band_value(BACK_STRIDES,back_blend),direction_weight)
	tree.set("parameters/Gaits/Walk/Choice/blend_amount",walk_choice)
	tree.set("parameters/Gaits/blend_position",blend)
	tree.set("parameters/BackGaits/blend_position",back_blend)
	tree.set("parameters/Direction/blend_amount",direction_weight)
	tree.set("parameters/Cadence/scale",speed/stride)
	if player_controlled: tree.set("parameters/StandingMove/blend_amount",smooth_gait(clamp(speed/0.85,0.0,1.0)))
	tree.advance(step)
	feet.use_full_support = crouch_driving or crouch.active()
	feet.resolve()
	crouch.update_capsule(step)
	if test and frame%60==0: min_body = min(min_body,feet.lowest(feet.all_samples))
	min_sole = min(min_sole,feet.minimum)
	max_lift = max(max_lift,feet.lift)
	var radial = Vector3(actor.position.x-route_center.x,0,actor.position.z-route_center.z)
	var angle = atan2(radial.x,radial.z)
	var tangent = Vector3(cos(angle),0,-sin(angle))
	var movement_sign = -1.0 if signed_speed<0.0 else 1.0
	# The body keeps facing the same tangent while its travel reverses.
	var facing = tangent*max(speed,0.1)-radial.normalized()*(radial.length()-route_radius)*2.0*movement_sign
	if player_controlled:
		if crouch_driving and crouch.state in ["crouched","settle"]:
			actor.rotation.y = rotate_toward(actor.rotation.y,orbit,step*5.0)
		elif not crouch_driving or crouch.state in ["brake","recover","standing"]:
			actor.rotation.y = rotate_toward(actor.rotation.y,manual_heading,step*5.0)
	elif crouch_driving and crouch.state in ["crouched","settle"] and speed>0.01:
		var travel_direction = -tangent*speed-radial.normalized()*(radial.length()-route_radius)*2.0
		var local_yaw = atan2(-side_speed,signed_speed)
		var target_yaw = atan2(-travel_direction.x,-travel_direction.z)-local_yaw
		actor.rotation.y = rotate_toward(actor.rotation.y,target_yaw,step*1.8)
	elif not crouch_driving or crouch.state in ["brake","recover","standing"]:
		actor.rotation.y = rotate_toward(actor.rotation.y,atan2(-facing.x,-facing.z),step*(1.2 if crouch_driving else 2.8))
	actor.velocity = (-actor.global_basis.z*signed_speed+actor.global_basis.x*side_speed)*(0.35 if slow else 1.0)
	actor.velocity.y = -0.3
	actor.move_and_slide()
	# This arena has a flat floor at zero, including at wall contacts.
	if actor.position.y<0.0:
		actor.position.y = 0.0
		actor.velocity.y = 0.0
	if backward and not turning and not crouch_driving:
		backward_distance += speed*step
		minimum_facing_alignment = min(minimum_facing_alignment,(-actor.global_basis.z).dot(tangent))
	traveled += speed*step
	update_camera()
	if player_controlled:
		var player_state = crouch.state.to_upper() if crouch.active() else ("IDLE" if speed<0.05 else ("BACKWARD" if backward else ("SPRINTING" if speed>8.0 else "RUNNING")))
		hud.text = "YOU  |  %s  |  %.1f m/s\nWASD move   |   Hold Shift: build sprint   |   Ctrl walk   |   C crouch\nV replays the AI showcase   |   Tab watches AI\nCrouch launch: 6 m/s | Release Shift before sprinting faster" % [player_state,speed]
	elif crouch_driving:
		hud.text = crouch.status()
	elif was_turning or turning:
		hud.text = "MALE Y BOT  |  CHANGING DIRECTION\n%.2f m/s   |   easing through a stop\nB changes direction   |   AI automatically demonstrates both\nW compares the two walks" % speed
	else:
		var names = BACK_LABELS if backward else LABELS
		var files = BACK_FILES if backward else FILE_LABELS
		hud.text = "MALE Y BOT  |  %s -> %s\n%.2f m/s   |   %s   |   blend %.0f%%\nFile: %s\nB changes direction   |   W compares walks" % [names[active.a],names[active.b],speed,"BACKWARD" if backward else "FORWARD",active.weight*100,files[active.a] if backward or active.a!=0 or walk_choice<0.5 else "Walking.fbx"]
func update_camera():
	var subject = camera_target if camera_target!=null else actor
	var subject_controller = subject.get_parent().crouch if camera_target!=null else crouch
	var focus_target = subject_controller.capsule.height*0.58 if subject_controller.capsule!=null else 1.05
	camera_focus_height = lerp(camera_focus_height,focus_target,0.06)
	var focus = subject.global_position+Vector3.UP*camera_focus_height
	camera.position = focus+Vector3(sin(orbit)*cos(elevation),-sin(elevation),cos(orbit)*cos(elevation))*distance
	camera.look_at(focus)
func _process(_dt):
	frame += 1
	var shots = OS.get_environment("WALK_SHOTS")
	if shots!="" and frame in [180,540,780,1140,1380,1740,1980,2340,2580,2940]:
		get_viewport().get_texture().get_image().save_png(shots+"/mixamo-%04d.png"%frame)
	if test and clock>=(10.0 if "--new-walk" in OS.get_cmdline_user_args() else 149.0):
		print("BACKWARD_TEST gaits=",seen," traveled=",traveled," min_sole=",min_sole," min_body=",min_body," backward_distance=",backward_distance," facing_alignment=",minimum_facing_alignment," max_lift=",max_lift," max_blend_step=",max_step," wall_seconds=",(Time.get_ticks_msec()-started)/1000.0)
		get_tree().quit(0 if max_lift<0.15 and min_sole>=0.0059 and min_body>=0.0 else 1)
func manual_target_speed() -> float:
	if manual_input.length()<0.01: return 0.0
	var sprinting = Input.is_action_pressed("sprint") and not manual_launch_lock
	if manual_input.y< -0.1: return -BACK_SPEEDS[2] if sprinting else -BACK_SPEEDS[1]
	if Input.is_action_pressed("walk"): return SPEEDS[0]
	if not sprinting or manual_input.y<=0.1: return SPEEDS[2]
	var progress = manual_sprint_clock / SPRINT_STAGE_SECONDS
	if progress >= 3.0:
		return SPEEDS[5] + (progress - 3.0) * ENDLESS_SPRINT_GAIN
	var stage = mini(int(progress),2)
	return lerp(float(SPEEDS[2+stage]),float(SPEEDS[3+stage]),smooth_gait(progress-stage))
func speed_band(values: Array, value: float) -> float:
	for index in range(values.size()-1):
		if value<=values[index+1]: return clamp(float(index)+(value-values[index])/(values[index+1]-values[index]),0.0,float(values.size()-1))
	return float(values.size()-1)
func normalized_idle_bone(name: String) -> String:
	return name.to_lower().replace("mixamorig", "").replace(":", "").replace("_", "").replace(" ", "")

func make_standing_idle(player: AnimationPlayer):
	# Use only the proven compatible Y Bot library.
	# The external Idle.fbx currently imports zero matching bone tracks.
	# Freeze a neutral weight-transfer frame from a genuine walk cycle:
	# arms hang apart, rather than folding across the pelvis.
	var source = player.get_animation("NewWalk")
	var idle = Animation.new()
	idle.length = 1.0
	idle.loop_mode = Animation.LOOP_LINEAR
	var pose_time = source.length * 0.48
	for t in range(source.get_track_count()):
		if source.track_get_key_count(t) == 0: continue
		var kind = source.track_get_type(t)
		if kind not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]: continue
		var value
		match kind:
			Animation.TYPE_POSITION_3D: value = source.position_track_interpolate(t, pose_time)
			Animation.TYPE_ROTATION_3D: value = source.rotation_track_interpolate(t, pose_time)
			Animation.TYPE_SCALE_3D: value = source.scale_track_interpolate(t, pose_time)
		var target = idle.add_track(kind)
		idle.track_set_path(target, source.track_get_path(t))
		idle.track_insert_key(target, 0.0, value)
		idle.track_insert_key(target, 1.0, value)
	var library = AnimationLibrary.new()
	library.add_animation("StandIdle", idle)
	player.add_animation_library("manual", library)
	print("IDLE_POSE NewWalk frame=", pose_time, " tracks=", idle.get_track_count())

func _unhandled_input(event):
	if autonomous_only: return
	if player_controlled:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_C: crouch.toggle()
			if event.keycode==KEY_F11: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			orbit -= event.relative.x*0.006
			elevation = clamp(elevation-event.relative.y*0.004,-0.8,0.15)
		if event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance = max(3.0,distance-0.4)
			if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance = min(22.0,distance+0.4)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_SPACE: paused = not paused
		if event.keycode==KEY_T: slow = not slow
		if event.keycode==KEY_W: walk_target = 1.0-walk_target
		if event.keycode==KEY_B:
			if crouch.active(): crouch.toggle_direction()
			else: begin_direction_change(not (turn_target if turning else backward))
		if event.keycode==KEY_C: crouch.toggle()
		if event.keycode==KEY_SHIFT: crouch.sprint()
		if event.keycode==KEY_V: crouch.start_showcase()
		if event.keycode==KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		orbit -= event.relative.x*0.006
		elevation = clamp(elevation-event.relative.y*0.004,-0.8,0.15)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance = max(2.5,distance-0.4)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance = min(18.0,distance+0.4)
	update_camera()









