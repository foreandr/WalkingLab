extends Node3D
@export var player_controlled = false
@export var actor_only = false
@export var autonomous_only = false
@export var stationary_only = false
var idle_variants: Array[String] = []
var jab_ready := false
var jab_cooldown := 0.0
var jab_aim_remaining := 0.0
var jab_aim_target := Vector3.ZERO
var jab_left_arm := -1
var jab_left_forearm := -1
var jab_left_hand := -1
var jab_right_arm := -1
var jab_right_forearm := -1
var jab_right_hand := -1
var controlled_arm := "right"
var jab_aim_strength := 0.0
const CAST_DURATION: float = 1.10
const CAST_RELEASE: float = 0.76
var cast_aim_point: Vector3 = Vector3.ZERO
var cast_shot_direction: Vector3 = Vector3.FORWARD
var cast_elapsed: float = -1.0
var cast_released: bool = false
var cast_arm_name: String = ""
var cast_last_hand: Vector3 = Vector3.ZERO
var cast_hand_velocity: Vector3 = Vector3.ZERO
var cursor_reticle: Control
var was_moving_for_idle := false
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
var native_idle_model: Node3D
var native_idle_playing := false
var native_idle_source_rig: Skeleton3D
var native_idle_driver: AnimationPlayer
var native_idle_bones: Array = []
var native_idle_weight := 0.0
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
var orbit = 0.0 # Player begins facing the stationary opponent along -Z
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
		box.size = Vector3(200,0.2,200)
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
	
	if player_controlled or stationary_only: choose_random_idle()
	print("CROUCH_CLIPS ",player.get_animation_list())
	tree = AnimationTree.new()
	visual.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.tree_root = graph
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	if player_controlled:
		for bone_i in range(skeleton.get_bone_count()):
			var bone_label = normalized_idle_bone(String(skeleton.get_bone_name(bone_i)))
			if bone_label == "leftarm": jab_left_arm = bone_i
			if bone_label == "leftforearm": jab_left_forearm = bone_i
			if bone_label == "lefthand": jab_left_hand = bone_i
			if bone_label == "rightarm": jab_right_arm = bone_i
			if bone_label == "rightforearm": jab_right_forearm = bone_i
			if bone_label == "righthand": jab_right_hand = bone_i
		print("JAB_IK_BONES arm=",jab_left_arm," forearm=",jab_left_forearm," hand=",jab_left_hand)
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
	if player_controlled:
		# Fixed screen-center reticle. All elements ignore mouse input.
		var reticle := Control.new()
		reticle.set_anchors_preset(Control.PRESET_TOP_LEFT)
		cursor_reticle = reticle
		reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(reticle)
		for segment in [
			Rect2(-2.0,-17.0,4.0,12.0),
			Rect2(-2.0,5.0,4.0,12.0),
			Rect2(-17.0,-2.0,12.0,4.0),
			Rect2(5.0,-2.0,12.0,4.0)
		]:
			var outline := ColorRect.new()
			outline.color = Color(0.02,0.025,0.03,0.9)
			outline.position = segment.position-Vector2(1,1)
			outline.size = segment.size+Vector2(2,2)
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			reticle.add_child(outline)
			var stroke := ColorRect.new()
			stroke.color = Color(1.0,0.93,0.20,1.0)
			stroke.position = segment.position
			stroke.size = segment.size
			stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
			reticle.add_child(stroke)
		var dot := ColorRect.new()
		dot.color = Color.WHITE
		dot.position = Vector2(-2,-2)
		dot.size = Vector2(4,4)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reticle.add_child(dot)
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
		controls.text = "WASD move | Alt sprint | Shift swap aim arm | Left-click reach | Ctrl walk | C crouch | Middle-drag camera (right-drag also works) | 1 fireball"
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
	if stationary_only:
		tree.advance(dt)
		feet.use_full_support = false
		feet.resolve(true)
		return
	var step = dt*(0.35 if slow else 1.0)
	clock += step
	jab_cooldown = maxf(0.0,jab_cooldown-step)
	jab_aim_remaining = maxf(0.0,jab_aim_remaining-step)
	jab_aim_strength = move_toward(jab_aim_strength,1.0 if player_controlled else 0.0,step*8.0)
	if player_controlled: update_cursor_aim()
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
	if player_controlled:
		var moving_now = speed > 0.12 or crouch.active()
		if was_moving_for_idle and not moving_now: choose_random_idle()
		was_moving_for_idle = moving_now
	tree.advance(step)
	if player_controlled:
		adjust_jab_arm()
		update_cast_motion(step)
	feet.use_full_support = crouch_driving or crouch.active()
	feet.resolve(player_controlled and speed < 0.12 and not crouch.active())
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
		hud.text = "YOU  |  %s  |  %.1f m/s\nWASD move  |  Alt sprint  |  Shift switch arm  |  Left click reach  |  Ctrl walk  |  C crouch\nMiddle drag camera (right drag also works)  |  Tab watch AI\nMouse X/Y aim on a fixed forward plane | Shift swap arms" % [player_state,speed]
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
	var simplified = name.to_lower().replace(":", "").replace("_", "").replace(" ", "")
	simplified = simplified.replace("mixamorig", "")
	while simplified.length() > 0 and simplified.unicode_at(0) >= 48 and simplified.unicode_at(0) <= 57:
		simplified = simplified.substr(1)
	return simplified

func make_standing_idle(player: AnimationPlayer):
	# Import as many of the user's authored FBX idle motions as match the Y Bot.
	# These all run on the ORIGINAL Y Bot mesh in the standing blend-tree slot.
	var source_template: Animation = player.get_animation("NewWalk")
	var destination_paths := {}
	for t in range(source_template.get_track_count()):
		if source_template.track_get_type(t) != Animation.TYPE_ROTATION_3D: continue
		var target_path = source_template.track_get_path(t)
		if target_path.get_subname_count() == 0: continue
		var n = normalized_idle_bone(String(target_path.get_subname(target_path.get_subname_count()-1)))
		destination_paths[n] = target_path
	var library = AnimationLibrary.new()
	idle_variants.clear()
	var wanted = ["Idle (3).fbx", "Breathing Idle.fbx", "Idle (2).fbx", "Offensive Idle.fbx", "Neutral Idle.fbx"]
	for filename in wanted:
		var path = "res://assets/custom_idle/" + filename
		if not ResourceLoader.exists(path): continue
		var packed = load(path)
		if not packed is PackedScene: continue
		var root = packed.instantiate()
		var animators = root.find_children("*","AnimationPlayer",true,false)
		var rigs = root.find_children("*","Skeleton3D",true,false)
		if animators.is_empty() or rigs.is_empty():
			root.free()
			continue
		var src_rig: Skeleton3D = rigs[0]
		var src_bones := {}
		for i in range(src_rig.get_bone_count()):
			src_bones[normalized_idle_bone(String(src_rig.get_bone_name(i)))] = i
		var dest_bones := {}
		for i in range(skeleton.get_bone_count()):
			dest_bones[normalized_idle_bone(String(skeleton.get_bone_name(i)))] = i
		var best = -1
		var motion: Animation = null
		for animator in animators:
			for name in animator.get_animation_list():
				if name == "RESET": continue
				var candidate: Animation = animator.get_animation(name)
				var score := 0
				for t in range(candidate.get_track_count()):
					if candidate.track_get_type(t) != Animation.TYPE_ROTATION_3D or candidate.track_get_key_count(t) < 2: continue
					var first: Quaternion = candidate.track_get_key_value(t,0)
					var mid: Quaternion = candidate.track_get_key_value(t,int(candidate.track_get_key_count(t)/2))
					if absf(first.dot(mid)) < 0.99999: score += 1
				if score > best:
					best = score
					motion = candidate
		if motion != null and best > 0:
			var idle = Animation.new()
			idle.length = motion.length
			idle.loop_mode = Animation.LOOP_LINEAR
			var tracks := 0
			for t in range(motion.get_track_count()):
				if motion.track_get_type(t) != Animation.TYPE_ROTATION_3D: continue
				var sp = motion.track_get_path(t)
				if sp.get_subname_count() == 0: continue
				var n = normalized_idle_bone(String(sp.get_subname(sp.get_subname_count()-1)))
				if not destination_paths.has(n) or not src_bones.has(n) or not dest_bones.has(n): continue
				var src_index: int = src_bones[n]
				var dst_index: int = dest_bones[n]
				var src_rest = src_rig.get_bone_rest(src_index).basis.get_rotation_quaternion()
				var dst_rest = skeleton.get_bone_rest(dst_index).basis.get_rotation_quaternion()
				var correction: Quaternion = (dst_rest.inverse() * src_rest).normalized()
				var out = idle.add_track(Animation.TYPE_ROTATION_3D)
				idle.track_set_path(out,destination_paths[n])
				# The imported Mixamo Hips rotation uses the source character's root
				# orientation. Applying it on the Y Bot turns the entire body sideways.
				# Lock only the target root to its own known-upright standing orientation;
				# all other joints retain their imported idle motion.
				if n == "hips":
					var upright: Quaternion = Quaternion.IDENTITY
					for template_track in range(source_template.get_track_count()):
						if source_template.track_get_type(template_track) == Animation.TYPE_ROTATION_3D and source_template.track_get_path(template_track) == destination_paths[n]:
							upright = source_template.rotation_track_interpolate(template_track, source_template.length * 0.48)
							break
					idle.rotation_track_insert_key(out,0.0,upright)
					idle.rotation_track_insert_key(out,idle.length,upright)
				elif filename == "Neutral Idle.fbx" and (n.begins_with("spine") or n == "neck" or n == "head"):
					# Keep the imported idle upright on the destination skeleton.
					# Use the proven upright Y Bot torso/head orientation only for
					# these joints; keep its arms and other motion as imported.
					var neutral: Quaternion = Quaternion.IDENTITY
					for template_track in range(source_template.get_track_count()):
						if source_template.track_get_type(template_track) == Animation.TYPE_ROTATION_3D and source_template.track_get_path(template_track) == destination_paths[n]:
							neutral = source_template.rotation_track_interpolate(template_track, source_template.length * 0.48)
							break
					idle.rotation_track_insert_key(out,0.0,neutral)
					idle.rotation_track_insert_key(out,idle.length,neutral)
				else:
					for k in range(motion.track_get_key_count(t)):
						var rot: Quaternion = motion.track_get_key_value(t,k)
						idle.rotation_track_insert_key(out,motion.track_get_key_time(t,k),(correction*rot*correction.inverse()).normalized())
				tracks += 1
			if tracks >= 12:
				var id = "Idle3" if filename == "Idle (3).fbx" else ("BreathingIdle" if filename == "Breathing Idle.fbx" else ("Idle1" if filename == "Idle (2).fbx" else ("Idle2" if filename == "Offensive Idle.fbx" else "Idle0")))
				library.add_animation(id,idle)
				idle_variants.append("manual/"+id)
				print("IDLE_REGISTERED ",filename," name=",id," tracks=",tracks," length=",idle.length)
			else:
				print("IDLE_REJECTED ",filename," mapped_tracks=",tracks)
		root.free()
	if idle_variants.is_empty():
		push_warning("No compatible idle FBX installed; put Idle (3).fbx in Downloads and rerun RUN.bat.")
		var fallback = Animation.new()
		fallback.length = 1.0
		fallback.loop_mode = Animation.LOOP_LINEAR
		var at = source_template.length * 0.48
		for t in range(source_template.get_track_count()):
			if source_template.track_get_key_count(t) == 0: continue
			var kind = source_template.track_get_type(t)
			if kind not in [Animation.TYPE_ROTATION_3D,Animation.TYPE_POSITION_3D,Animation.TYPE_SCALE_3D]: continue
			var value
			match kind:
				Animation.TYPE_ROTATION_3D: value = source_template.rotation_track_interpolate(t,at)
				Animation.TYPE_POSITION_3D: value = source_template.position_track_interpolate(t,at)
				Animation.TYPE_SCALE_3D: value = source_template.scale_track_interpolate(t,at)
			var out = fallback.add_track(kind)
			fallback.track_set_path(out,source_template.track_get_path(t))
			fallback.track_insert_key(out,0.0,value)
			fallback.track_insert_key(out,1.0,value)
		library.add_animation("Fallback",fallback)
		idle_variants.append("manual/Fallback")
	player.add_animation_library("manual",library)

func install_left_jab(player: AnimationPlayer, graph: AnimationNodeBlendTree) -> void:
	# One imported, upper-body-only Mixamo punch. Preserve the original rig,
	# locomotion, feet, hip orientation, and random standing idle selection.
	var path = "res://assets/custom_idle/Punching.fbx"
	if not ResourceLoader.exists(path):
		push_warning("LEFT_JAB_MISSING: place Punching.fbx in Downloads and run RUN.bat")
		return
	var packed = load(path)
	if not packed is PackedScene: return
	var root = packed.instantiate()
	var animators = root.find_children("*","AnimationPlayer",true,false)
	var rigs = root.find_children("*","Skeleton3D",true,false)
	if animators.is_empty() or rigs.is_empty():
		root.free()
		push_warning("LEFT_JAB_FBX_NO_SKELETON")
		return
	var source_rig: Skeleton3D = rigs[0]
	var source_bones := {}
	for i in range(source_rig.get_bone_count()):
		source_bones[normalized_idle_bone(String(source_rig.get_bone_name(i)))] = i
	var dest_bones := {}
	for i in range(skeleton.get_bone_count()):
		dest_bones[normalized_idle_bone(String(skeleton.get_bone_name(i)))] = i
	var valid_paths := {}
	var reference: Animation = player.get_animation("NewWalk")
	for i in range(reference.get_track_count()):
		if reference.track_get_type(i) != Animation.TYPE_ROTATION_3D: continue
		var p = reference.track_get_path(i)
		if p.get_subname_count() == 0: continue
		var n = normalized_idle_bone(String(p.get_subname(p.get_subname_count()-1)))
		valid_paths[n] = p
	var chosen: Animation = null
	var best := 0
	for animator in animators:
		for name in animator.get_animation_list():
			if name == "RESET": continue
			var candidate: Animation = animator.get_animation(name)
			var moving := 0
			for i in range(candidate.get_track_count()):
				if candidate.track_get_type(i) != Animation.TYPE_ROTATION_3D or candidate.track_get_key_count(i) < 2: continue
				var first: Quaternion = candidate.track_get_key_value(i,0)
				var mid: Quaternion = candidate.track_get_key_value(i,int(candidate.track_get_key_count(i)/2))
				if absf(first.dot(mid)) < 0.99999: moving += 1
			if moving > best:
				best = moving
				chosen = candidate
	if chosen == null:
		root.free()
		push_warning("LEFT_JAB_NO_ANIMATED_TAKE")
		return
	var clip = Animation.new()
	clip.length = chosen.length
	clip.loop_mode = Animation.LOOP_NONE
	var tracks := 0
	for i in range(chosen.get_track_count()):
		if chosen.track_get_type(i) != Animation.TYPE_ROTATION_3D: continue
		var p = chosen.track_get_path(i)
		if p.get_subname_count() == 0: continue
		var n = normalized_idle_bone(String(p.get_subname(p.get_subname_count()-1)))
		# Leave legs, pelvis and translation strictly on the locomotion controller.
		if n == "hips" or n.contains("leg") or n.contains("foot") or n.contains("toe"): continue
		# The left arm is NOT animated by the punch clip. Its pose is
		# exclusively guided by the mouse-directed two-joint IK.
		if n.begins_with("left") and (n.contains("arm") or n.contains("hand") or n.contains("shoulder") or n.contains("finger") or n.contains("thumb")): continue
		if not valid_paths.has(n) or not source_bones.has(n) or not dest_bones.has(n): continue
		var from_index: int = source_bones[n]
		var to_index: int = dest_bones[n]
		var from_rest: Quaternion = source_rig.get_bone_rest(from_index).basis.get_rotation_quaternion()
		var to_rest: Quaternion = skeleton.get_bone_rest(to_index).basis.get_rotation_quaternion()
		var correction = (to_rest.inverse()*from_rest).normalized()
		var track = clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,valid_paths[n])
		for k in range(chosen.track_get_key_count(i)):
			var q: Quaternion = chosen.track_get_key_value(i,k)
			clip.rotation_track_insert_key(track,chosen.track_get_key_time(i,k),(correction*q*correction.inverse()).normalized())
		tracks += 1
	root.free()
	if tracks < 6:
		push_warning("LEFT_JAB_TOO_FEW_TRACKS " + str(tracks))
		return
	var lib := AnimationLibrary.new()
	lib.add_animation("LeftJab",clip)
	player.add_animation_library("combat",lib)
	var jab_node := AnimationNodeAnimation.new()
	jab_node.animation = "combat/LeftJab"
	graph.add_node("JabClip",jab_node)
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.09
	shot.fadeout_time = 0.16
	# OneShot normally blends its overlay against the whole skeleton's rest
	# pose. Filter it to ONLY the jab's authored upper-body tracks. Everything
	# else, including hips, legs and feet, stays on the Posture base input.
	shot.filter_enabled = true
	for track_index in range(clip.get_track_count()):
		shot.set_filter_path(clip.track_get_path(track_index), true)
	graph.add_node("JabOneShot",shot)
	# Rewire from the leaf toward the graph output. Godot 4 disallows
	# connecting a node as a source while that node is already the output root.
	graph.disconnect_node("output",0)
	graph.connect_node("JabOneShot",0,"Posture")
	graph.connect_node("JabOneShot",1,"JabClip")
	graph.connect_node("output",0,"JabOneShot")
	jab_ready = true
	print("LEFT_JAB_READY duration=",clip.length," upper_body_tracks=",tracks)

func update_cursor_aim() -> void:
	if camera == null or actor == null: return
	var cursor = get_viewport().get_mouse_position()
	var bounds = get_viewport().get_visible_rect().size
	cursor = Vector2(clampf(cursor.x,0.0,bounds.x),clampf(cursor.y,0.0,bounds.y))
	if cursor_reticle != null: cursor_reticle.position = cursor
	var origin: Vector3 = camera.project_ray_origin(cursor)
	var direction: Vector3 = camera.project_ray_normal(cursor)
	jab_aim_target = origin + direction * 20.0

func rotate_arm_joint_toward(bone: int, hand: int, goal: Vector3, weight: float) -> void:
	# Cyclic coordinate descent: turn this joint so the CURRENT hand position
	# points toward the target. All vectors are skeleton-local coordinates.
	skeleton.force_update_all_bone_transforms()
	var pivot: Vector3 = skeleton.get_bone_global_pose(bone).origin
	var tip: Vector3 = skeleton.get_bone_global_pose(hand).origin
	var present: Vector3 = tip - pivot
	var intended: Vector3 = goal - pivot
	if present.length_squared() < 0.00001 or intended.length_squared() < 0.00001: return
	var angle = present.angle_to(intended)
	if angle < 0.001: return
	var axis = present.cross(intended)
	if axis.length_squared() < 0.000001: return
	# Rotate only a bounded amount per solve to preserve the jab silhouette.
	var global_delta = Quaternion(axis.normalized(),minf(angle,0.65)*weight)
	var parent = skeleton.get_bone_parent(bone)
	var parent_orientation = Quaternion.IDENTITY if parent < 0 else skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var local_delta = parent_orientation.inverse()*global_delta*parent_orientation
	var old_rotation = skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone,(local_delta*old_rotation).normalized())

func adjust_jab_arm() -> void:
	# Fist-directed two-bone IK, layered over the original Mixamo jab.
	# The actor, pelvis, torso and both legs remain completely untouched.
	var aiming_arm: String = cast_arm_name if cast_elapsed >= 0.0 else controlled_arm
	var arm = jab_right_arm if aiming_arm == "right" else jab_left_arm
	var forearm = jab_right_forearm if aiming_arm == "right" else jab_left_forearm
	var hand = jab_right_hand if aiming_arm == "right" else jab_left_hand
	if arm < 0 or forearm < 0 or hand < 0: return
	if jab_aim_strength < 0.001: return
	skeleton.force_update_all_bone_transforms()
	var shoulder: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(arm).origin
	var elbow: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(forearm).origin
	var wrist: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hand).origin
	var reach = shoulder.distance_to(elbow) + elbow.distance_to(wrist)
	if reach < 0.1: return
	# The cursor defines the shared arm + spell target. The hand reaches
	# along the direction from shoulder to that cursor's world-space ray.
	# The same forward aim vector is used for projectile release.
	var aim_world: Vector3 = cast_aim_point if cast_elapsed >= 0.0 else get_cursor_world_target()
	var shot: Vector3 = (aim_world - shoulder).normalized()
	var local_shot: Vector3 = actor.global_basis.inverse() * shot
	local_shot.z = minf(local_shot.z,-0.12)
	shot = (actor.global_basis * local_shot.normalized()).normalized()
	var goal_world_position: Vector3 = shoulder + shot * reach * 0.75
	var goal_actor: Vector3 = actor.global_transform.affine_inverse() * goal_world_position
	# No drawback: start at the ordinary aiming pose and extend directly
	# toward the cursor over a long smooth stroke. Release at full extension.
	if cast_elapsed >= 0.0:
		var phase: float = clampf(cast_elapsed / CAST_DURATION,0.0,1.0)
		var extension: float = 0.0
		if phase < 0.69:
			extension = 0.34 * smoothstep(0.0,0.69,phase)
		elif phase < 0.79:
			extension = 0.34
		else:
			extension = 0.34 * (1.0-smoothstep(0.79,1.0,phase))
		goal_actor += actor.global_basis.inverse() * shot * (extension * reach)
	# Only disallow a hand target behind the character; crossing the chest
	# in front is intentional to preserve full lateral aiming.
	goal_actor.z = minf(goal_actor.z,-0.30)
	var goal_world: Vector3 = actor.global_transform * goal_actor
	var goal_local: Vector3 = skeleton.global_transform.affine_inverse() * goal_world
	# The selected arm follows an XY target on a depth-locked plane.
	var influence = jab_aim_strength
	if influence < 0.002: return
	# Solve the upper arm first. The elbow is kept outside the torso, not
	# merely the wrist: a wrist-only target can still fold through the ribs.
	var base_arm: Quaternion = skeleton.get_bone_pose_rotation(arm)
	var base_forearm: Quaternion = skeleton.get_bone_pose_rotation(forearm)
	for iteration in range(5):
		rotate_arm_joint_toward(arm,hand,goal_local,influence)
		rotate_arm_joint_toward(forearm,hand,goal_local,influence)
		skeleton.force_update_all_bone_transforms()
		var elbow_world: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(forearm).origin
		var hand_world: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hand).origin
		var elbow_actor: Vector3 = actor.global_transform.affine_inverse() * elbow_world
		var hand_actor: Vector3 = actor.global_transform.affine_inverse() * hand_world
		# No same-side restriction: the right hand can aim left and vice versa.
		# Reject only joints that swing substantially behind the character.
		# Small front-of-chest overlap is allowed to avoid a frozen aim arc.
		var elbow_clear: bool = elbow_actor.z <= 0.14
		var hand_clear: bool = hand_actor.z <= -0.10
		if elbow_clear and hand_clear:
			base_arm = skeleton.get_bone_pose_rotation(arm)
			base_forearm = skeleton.get_bone_pose_rotation(forearm)
			continue
		# Reject unsafe CCD rotation, keeping the last collision-free pose.
		skeleton.set_bone_pose_rotation(arm,base_arm)
		skeleton.set_bone_pose_rotation(forearm,base_forearm)
		skeleton.force_update_all_bone_transforms()
		break
	# Keep Godot bone transforms synchronized for foot solver and skinning.
	skeleton.force_update_all_bone_transforms()

func throw_left_jab() -> void:
	# Procedural reach only. No imported punching animation.
	if jab_cooldown > 0.0 or crouch.active(): return
	update_cursor_aim()
	jab_aim_remaining = 0.45
	jab_cooldown = 0.45
	print("ARM_REACH ",controlled_arm)

func get_cursor_world_target() -> Vector3:
	var cursor: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(cursor)
	var ray_direction: Vector3 = camera.project_ray_normal(cursor)
	# Fixed aiming distance produces a stable direction regardless of
	# arbitrary floor intersections, including aiming above the horizon.
	return ray_origin + ray_direction * 40.0

func cast_fireball() -> void:
	# No mana or separate body animation. Brief cast action, one arm only.
	if cast_elapsed >= 0.0 or crouch.active(): return
	if not ResourceLoader.exists("res://assets/external_vfx/fire.tscn"): return
	cast_arm_name = controlled_arm
	cast_aim_point = get_cursor_world_target()
	var hand_id: int = jab_right_hand if cast_arm_name == "right" else jab_left_hand
	if hand_id < 0: return
	skeleton.force_update_all_bone_transforms()
	cast_last_hand = skeleton.global_transform * skeleton.get_bone_global_pose(hand_id).origin
	cast_hand_velocity = Vector3.ZERO
	cast_elapsed = 0.0
	cast_released = false

func update_cast_motion(dt: float) -> void:
	if cast_elapsed < 0.0: return
	var hand_id: int = jab_right_hand if cast_arm_name == "right" else jab_left_hand
	if hand_id < 0:
		cast_elapsed = -1.0
		return
	skeleton.force_update_all_bone_transforms()
	var hand_now: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hand_id).origin
	if dt > 0.00001:
		var instantaneous: Vector3 = (hand_now - cast_last_hand) / dt
		cast_hand_velocity = cast_hand_velocity.lerp(instantaneous,0.65)
	cast_last_hand = hand_now
	cast_elapsed += dt
	if not cast_released and cast_elapsed >= CAST_RELEASE:
		cast_released = true
		release_fireball(hand_now)
	if cast_elapsed >= CAST_DURATION:
		cast_elapsed = -1.0
		cast_arm_name = ""

func release_fireball(hand_world: Vector3) -> void:
	var arm_id: int = jab_right_arm if cast_arm_name == "right" else jab_left_arm
	if arm_id < 0: return
	# Aim at the SAME world target captured at cast start. This direction
	# is measured from the palm so the projectile actually hits the cursor.
	var raw_direction: Vector3 = (cast_aim_point - hand_world).normalized()
	var local_direction: Vector3 = actor.global_basis.inverse() * raw_direction
	local_direction.z = minf(local_direction.z,-0.10)
	var travel: Vector3 = (actor.global_basis * local_direction.normalized()).normalized()
	# Measure actual animated hand velocity and project it along the shot.
	var launch_speed: float = clampf(cast_hand_velocity.dot(travel),3.0,25.0)
	var projectile := Node3D.new()
	projectile.name = "Fireball"
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = hand_world + travel * 0.20
	# Existing third-party VFX, not procedurally built fire.
	var fire_visual: GPUParticles3D = preload("res://assets/external_vfx/fire.tscn").instantiate()
	projectile.add_child(fire_visual)
	fire_visual.emitting = true
	fire_visual.restart()
	var mover = preload("res://assets/external_vfx/fireball_motion.gd").new()
	mover.name = "Motion"
	mover.travel_direction = travel
	mover.travel_speed = launch_speed
	mover.owner_rid = actor.get_rid()
	projectile.add_child(mover)
	print("FIREBALL_RELEASE ",cast_arm_name," speed_mps=",snappedf(launch_speed,0.1))

func choose_random_idle():
	# Historical name retained for existing callers. Idle (3).fbx preferred for everyone; never swap.
	if idle_variants.is_empty() or crouch.standing_idle_node == null: return
	var chosen: String = idle_variants[0]
	if String(crouch.standing_idle_node.animation) == chosen: return
	crouch.standing_idle_node.animation = chosen
	print("IDLE_FIXED ",name," ",chosen)

func _unhandled_input(event):
	if autonomous_only: return
	if player_controlled:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_C: crouch.toggle()
			if event.keycode==KEY_1: cast_fireball()
			if event.keycode==KEY_SHIFT:
				if cast_elapsed < 0.0:
					controlled_arm = "left" if controlled_arm == "right" else "right"
				print("CONTROLLED_ARM ",controlled_arm)
			if event.keycode==KEY_F11: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		if event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))):
			orbit -= event.relative.x*0.006
			elevation = clamp(elevation-event.relative.y*0.004,-0.8,0.15)
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT: throw_left_jab()
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









