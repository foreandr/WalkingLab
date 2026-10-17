extends RefCounted
const SNEAK_SPEED = 0.95
const BACKWARD_SPEED = 1.15
var host
var standing_idle_node: AnimationNodeAnimation
var meta = {}
var action: AnimationNodeAnimation
var previous_action: AnimationNodeAnimation
var state = "standing"
var phase_time = 0.0
var action_name = "Idle"
var action_fade = 1.0
var posture = 0.0
var move_weight = 0.0
var move_direction = 0.0
var direction_override = -1.0
var lateral_speed = 0.0
var forward_speed = 0.0
var held_velocity = Vector2.ZERO
var exit_request = ""
var exit_kind = "Stand"
var recovery_start = Vector2.ZERO
var showcase = false
var demo_phase = 0
var demo_wait = 0.0
var seen = {}
var capsule: CapsuleShape3D
var collision: CollisionShape3D
var head_bone = -1
var manual_motion = Vector2.ZERO
func setup(owner_node, player: AnimationPlayer, graph: AnimationNodeBlendTree):
	host = owner_node
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/crouch_manifest.json"))
	host.install_motion_library(player,"res://assets/crouch_motions.glb","crouch",["Enter","Stand","Launch","SneakLeft","CrouchBack","Idle"],["SneakLeft","CrouchBack","Idle"])
	action = AnimationNodeAnimation.new()
	action.animation = "crouch/Idle"
	previous_action = AnimationNodeAnimation.new()
	previous_action.animation = "crouch/Idle"
	graph.add_node("CrouchAction",action)
	graph.add_node("CrouchFrom",previous_action)
	graph.add_node("CrouchSeek",AnimationNodeTimeSeek.new())
	graph.add_node("CrouchFromSeek",AnimationNodeTimeSeek.new())
	graph.connect_node("CrouchSeek",0,"CrouchAction")
	graph.connect_node("CrouchFromSeek",0,"CrouchFrom")
	var action_blend = AnimationNodeBlend2.new()
	action_blend.sync = true
	graph.add_node("CrouchActionBlend",action_blend)
	graph.connect_node("CrouchActionBlend",0,"CrouchFromSeek")
	graph.connect_node("CrouchActionBlend",1,"CrouchSeek")
	for entry in [["CrouchLeft","SneakLeft"],["CrouchBack","CrouchBack"]]:
		var clip = AnimationNodeAnimation.new()
		clip.animation = "crouch/"+entry[1]
		graph.add_node(entry[0],clip)
	var moving = AnimationNodeBlend2.new()
	moving.sync = true
	graph.add_node("CrouchDirection",moving)
	graph.connect_node("CrouchDirection",0,"CrouchLeft")
	graph.connect_node("CrouchDirection",1,"CrouchBack")
	var moving_source = "CrouchDirection"
	if host.player_controlled:
		host.install_motion_library(player,"res://assets/crouch_derived.glb","derived_crouch",["Right","Forward"],["Right","Forward"])
		var space = AnimationNodeBlendSpace2D.new()
		space.min_space = Vector2(-1,-1)
		space.max_space = Vector2(1,1)
		space.sync = true
		for entry in [["crouch/SneakLeft",Vector2(-1,0)],["derived_crouch/Right",Vector2(1,0)],["derived_crouch/Forward",Vector2(0,1)],["crouch/CrouchBack",Vector2(0,-1)],["crouch/Idle",Vector2.ZERO]]:
			var clip = AnimationNodeAnimation.new()
			clip.animation = entry[0]
			space.add_blend_point(clip,entry[1],-1,String(entry[0]).replace("/","_"))
		graph.add_node("PlayerCrouch",space)
		moving_source = "PlayerCrouch"
	graph.add_node("CrouchCadence",AnimationNodeTimeScale.new())
	graph.connect_node("CrouchCadence",0,moving_source)
	var choice = AnimationNodeBlend2.new()
	choice.sync = true
	graph.add_node("CrouchChoice",choice)
	graph.connect_node("CrouchChoice",0,"CrouchActionBlend")
	graph.connect_node("CrouchChoice",1,"CrouchCadence")
	var posture_blend = AnimationNodeBlend2.new()
	posture_blend.sync = true
	graph.add_node("Posture",posture_blend)
	var standing_source = "Cadence"
	if host.player_controlled or host.stationary_only:
		host.make_standing_idle(player)
		var idle = AnimationNodeAnimation.new()
		idle.animation = host.idle_variants[0]
		standing_idle_node = idle
		graph.add_node("StandingIdle",idle)
		var standing_move = AnimationNodeBlend2.new()
		standing_move.sync = true
		graph.add_node("StandingMove",standing_move)
		graph.connect_node("StandingMove",0,"StandingIdle")
		graph.connect_node("StandingMove",1,"Cadence")
		standing_source = "StandingMove"
	graph.connect_node("Posture",0,standing_source)
	graph.connect_node("Posture",1,"CrouchChoice")
	graph.connect_node("output",0,"Posture")
	collision = host.actor.get_children().filter(func(n): return n is CollisionShape3D)[0]
	capsule = collision.shape
	for index in range(host.skeleton.get_bone_count()):
		if host.skeleton.get_bone_name(index).ends_with("Head"): head_bone = index
func active() -> bool: return state!="standing"
func smooth_step(t: float) -> float:
	t = clamp(t,0.0,1.0)
	return t*t*t*(t*(t*6.0-15.0)+10.0)
func change_state(next_state: String):
	state = next_state
	phase_time = 0.0
	seen[state] = true
func pick_action(name: String):
	previous_action.animation = "crouch/"+action_name
	host.tree.set("parameters/CrouchFromSeek/seek_request",0.0 if action_name=="Idle" else float(meta[action_name].length))
	action_name = name
	action.animation = "crouch/"+name
	host.tree.set("parameters/CrouchSeek/seek_request",0.0)
	action_fade = 0.0
	seen[name] = true
func toggle(manual = true):
	if manual: showcase = false
	if not active():
		held_velocity = Vector2(0,host.signed_speed)
		forward_speed = host.signed_speed
		lateral_speed = 0.0
		host.turning = false
		exit_request = ""
		direction_override = -1.0
		manual_motion = Vector2.ZERO
		change_state("brake")
	elif state in ["crouched","Enter","brake"]: request_exit("Stand",false)
func sprint(manual = true):
	if manual: showcase = false
	if active() and state in ["crouched","Enter","brake"]: request_exit("Launch",false)
func request_exit(kind: String, manual = true):
	if manual: showcase = false
	exit_request = kind
	if kind=="Launch" and host.player_controlled: host.manual_launch_lock = true
	if state=="crouched":
		exit_kind = kind
		held_velocity = Vector2(lateral_speed,forward_speed)
		pick_action("Idle")
		change_state("settle")
func toggle_direction():
	showcase = false
	direction_override = 1.0 if move_direction<0.5 else 0.0
func start_showcase():
	showcase = true
	demo_phase = 0
	demo_wait = 0.0
	if active(): request_exit("Stand",false)
func update_demo(dt):
	if not showcase: return
	if demo_phase==0 and state=="standing":
		toggle(false)
		demo_phase = 1
	elif demo_phase==1 and state=="crouched":
		demo_wait += dt
		if demo_wait>=11.0:
			request_exit("Stand",false)
			demo_phase = 2
			demo_wait = 0.0
	elif demo_phase==2 and state=="standing":
		demo_wait += dt
		if demo_wait>=2.0:
			toggle(false)
			demo_phase = 3
			demo_wait = 0.0
	elif demo_phase==3 and state=="crouched":
		demo_wait += dt
		if demo_wait>=4.0:
			sprint(false)
			demo_phase = 4
	elif demo_phase==4 and state=="standing":
		showcase = false
		demo_phase = 5
func root_position(name: String, at: float) -> Vector2:
	var points = meta[name].root_motion
	var fraction = clamp(at/float(meta[name].length),0.0,1.0)*(points.size()-1)
	var index = int(floor(fraction))
	var a = points[index]
	var b = points[mini(index+1,points.size()-1)]
	return Vector2(a[1],a[2]).lerp(Vector2(b[1],b[2]),fraction-index)
func root_velocity(name: String, before: float, after: float, dt: float) -> Vector2:
	return (root_position(name,after)-root_position(name,before))/max(dt,0.0001)
func update(dt: float) -> bool:
	update_demo(dt)
	var driving = active()
	if not driving:
		posture = 0.0
		lateral_speed = 0.0
		forward_speed = host.signed_speed
	else:
		var before = phase_time
		phase_time += dt * (10.0 if state in ["settle","Stand","recover"] and exit_kind == "Stand" else 1.0)
		match state:
			"brake":
				var braking_time = clamp(held_velocity.length()/4.0,0.55,2.5)
				var weight = smooth_step(phase_time/braking_time)
				forward_speed = held_velocity.y*(1.0-weight)
				lateral_speed = 0.0
				if phase_time>=braking_time:
					pick_action("Enter")
					change_state("Enter")
			"Enter":
				posture = smooth_step(phase_time/0.22)
				move_weight = 0.0
				var velocity = root_velocity("Enter",before,phase_time,dt)
				lateral_speed = velocity.x
				forward_speed = velocity.y
				if phase_time+0.000001>=float(meta.Enter.length):
					pick_action("Idle")
					change_state("crouched")
			"crouched":
				posture = 1.0
				move_weight = smooth_step(phase_time/1.2)
				if host.player_controlled:
					var desired = host.manual_input*(BACKWARD_SPEED if host.manual_input.y<0.0 else SNEAK_SPEED)
					manual_motion = manual_motion.move_toward(desired,dt*3.0)
					var entry_weight = smooth_step(phase_time/1.2)
					lateral_speed = manual_motion.x*entry_weight
					forward_speed = manual_motion.y*entry_weight
					move_weight = entry_weight*smooth_step(clamp(manual_motion.length()/0.25,0.0,1.0))
					move_direction = abs(manual_motion.y)/max(0.001,abs(manual_motion.x)+abs(manual_motion.y))
					var point = Vector2(manual_motion.x/SNEAK_SPEED,manual_motion.y/(BACKWARD_SPEED if manual_motion.y<0.0 else SNEAK_SPEED)).limit_length()
					host.tree.set("parameters/PlayerCrouch/blend_position",point)
					if lateral_speed< -0.1: seen["SneakLeft"] = true
					if lateral_speed>0.1: seen["DerivedRight"] = true
					if forward_speed< -0.1: seen["CrouchBack"] = true
					if forward_speed>0.1: seen["DerivedForward"] = true
				else:
					if direction_override>=0.0: move_direction = move_toward(move_direction,direction_override,dt/2.0)
					else:
						var cycle = fmod(phase_time,16.0)
						move_direction = smooth_step((cycle-4.0)/4.0) if cycle<8.0 else 1.0-smooth_step((cycle-12.0)/4.0)
					var local_velocity = Vector2(-(1.0-move_direction),-move_direction).normalized()*lerp(SNEAK_SPEED,BACKWARD_SPEED,move_direction)*move_weight
					lateral_speed = local_velocity.x
					forward_speed = local_velocity.y
					if move_direction<0.2: seen["SneakLeft"] = true
					if move_direction>0.8: seen["CrouchBack"] = true
				if exit_request!="": request_exit(exit_request,false)
			"settle":
				var weight = smooth_step(phase_time/0.65)
				move_weight = 1.0-weight
				lateral_speed = held_velocity.x*(1.0-weight)
				forward_speed = held_velocity.y*(1.0-weight)
				if phase_time>=0.65:
					pick_action(exit_kind)
					change_state(exit_kind)
			"Stand", "Launch":
				move_weight = 0.0
				posture = 1.0
				var velocity = root_velocity(state,before,phase_time,dt)
				lateral_speed = velocity.x
				forward_speed = velocity.y
				if phase_time+0.000001>=float(meta[state].length):
					recovery_start = Vector2(lateral_speed,forward_speed)
					if state=="Launch":
						host.backward = false
						host.direction_weight = 0.0
						host.blend = 2.0
						host.back_blend = 0.0
						host.mode_clock = 20.0
					else:
						host.blend = 0.0
						host.back_blend = 0.0
						host.direction_weight = 1.0 if host.backward else 0.0
						host.mode_clock = 0.0
						if host.player_controlled:
							var desired = host.manual_target_speed()
							host.backward = desired<0.0
							host.direction_weight = 1.0 if host.backward else 0.0
							host.blend = host.speed_band(host.SPEEDS,abs(desired))
							host.back_blend = host.speed_band(host.BACK_SPEEDS,abs(desired))
					if host.player_controlled and host.manual_input.length()<0.01: host.manual_heading = host.actor.rotation.y
					exit_request = ""
					change_state("recover")
			"recover":
				var weight = smooth_step(phase_time/1.0)
				posture = 1.0-weight
				var target_speed = (host.manual_target_speed() if host.player_controlled and exit_kind!="Launch" else (-host.BACK_SPEEDS[0] if host.backward else host.SPEEDS[int(host.blend)]))
				forward_speed = lerp(recovery_start.y,target_speed,weight)
				lateral_speed = recovery_start.x*(1.0-weight)
				if phase_time>=1.0:
					posture = 0.0
					change_state("standing")
					host.turning = false
	action_fade += dt
	host.tree.set("parameters/CrouchActionBlend/blend_amount",smooth_step(action_fade/0.18))
	host.tree.set("parameters/CrouchChoice/blend_amount",move_weight)
	host.tree.set("parameters/CrouchDirection/blend_amount",move_direction)
	var stride = lerp(float(meta.SneakLeft.stride),float(meta.CrouchBack.stride),move_direction)
	host.tree.set("parameters/CrouchCadence/scale",Vector2(lateral_speed,forward_speed).length()/max(0.001,stride) if state=="crouched" or state=="settle" else 0.0)
	host.tree.set("parameters/Posture/blend_amount",posture)
	return driving
func update_capsule(dt):
	var height = 1.8
	if head_bone>=0 and active():
		var head = host.skeleton.global_transform*host.skeleton.get_bone_global_pose(head_bone)
		height = clamp(head.origin.y-host.actor.position.y+0.22,1.0,1.8)
	capsule.height = move_toward(capsule.height,height,dt*4.0)
	collision.position.y = capsule.height*0.5
func status() -> String:
	var file = str(meta[action_name].file)
	if state=="crouched": file = "Crouch Walk Back.fbx" if move_direction>0.5 else "Crouched Sneaking Left.fbx"
	return "MALE Y BOT  |  CROUCH: %s\nFile: %s\nC crouch / stand   |   Shift crouch to sprint\nB crouch sideways / backward   |   V full crouch showcase" % [state.to_upper(),file]

