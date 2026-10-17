extends Node3D
@export var player_controlled = false
@export var actor_only = false
@export var autonomous_only = false
@export var stationary_only = false
var idle_variants: Array[String] = []
var jab_ready := false
var jab_cooldown := 0.0
var jab_aim_remaining := 0.0
var jab_aim_heading := 0.0
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
	if player_controlled: install_left_jab(player,graph)
	if player_controlled or stationary_only: choose_random_idle()
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
	if player_controlled:
		# Fixed screen-center reticle. All elements ignore mouse input.
		var reticle := Control.new()
		reticle.set_anchors_preset(Control.PRESET_CENTER)
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
	if stationary_only:
		tree.advance(dt)
		feet.use_full_support = false
		feet.resolve(true)
		return
	var step = dt*(0.35 if slow else 1.0)
	clock += step
	jab_cooldown = maxf(0.0,jab_cooldown-step)
	jab_aim_remaining = maxf(0.0,jab_aim_remaining-step)
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
		if jab_aim_remaining > 0.0 and not crouch_driving:
			# Keep the jab facing the screen-center camera ray for its duration.
			actor.rotation.y = rotate_toward(actor.rotation.y,jab_aim_heading,step*15.0)
		elif crouch_driving and crouch.state in ["crouched","settle"]:
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
	var wanted = ["Neutral Idle.fbx","Idle (2).fbx","Idle (1)(1).fbx"]
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
					# Idle0 contains a pronounced backwards bend after retargeting.
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
				var id = "Idle" + str([0,1,4][idle_variants.size()])
				library.add_animation(id,idle)
				idle_variants.append("manual/"+id)
				print("IDLE_REGISTERED ",filename," name=",id," tracks=",tracks," length=",idle.length)
			else:
				print("IDLE_REJECTED ",filename," mapped_tracks=",tracks)
		root.free()
	if idle_variants.is_empty():
		push_warning("No imported Mixamo idles matched. Using fallback pose.")
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

func throw_left_jab() -> void:
	if not jab_ready or jab_cooldown > 0.0: return
	if crouch.active(): return
	# Project the center-of-screen aim ray into the ground plane. We rotate
	# the whole character in yaw, leaving feet/hip/leg animations untouched.
	# Vertical punch retargeting is intentionally not attempted here.
	var screen_center = get_viewport().get_visible_rect().size * 0.5
	var ray_origin: Vector3 = camera.project_ray_origin(screen_center)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_center)
	var target_point = ray_origin + ray_direction * 35.0
	var aim = target_point - (actor.global_position + Vector3.UP * 1.25)
	aim.y = 0.0
	if aim.length_squared() > 0.001:
		jab_aim_heading = atan2(-aim.x,-aim.z)
		manual_heading = jab_aim_heading
		jab_aim_remaining = 0.45
	tree.set("parameters/JabOneShot/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	jab_cooldown = 0.4
	print("LEFT_JAB_TRIGGERED")

func choose_random_idle():
	if idle_variants.is_empty() or crouch.standing_idle_node == null: return
	var current: String = String(crouch.standing_idle_node.animation)
	var options = idle_variants.filter(func(path): return path != current)
	if options.is_empty(): options = idle_variants.duplicate()
	var chosen: String = options.pick_random()
	crouch.standing_idle_node.animation = chosen
	print("IDLE_SELECTED ",name," ",chosen)

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









