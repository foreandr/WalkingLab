extends Node3D
# Ten real, continuously playing stationary idle loops.
# The Y Bot skeleton is driven using paths copied from its own proven animation.
# Each loop averages a full gait cycle for a balanced neutral standing base, then
# adds independent breathing/weight-shift motion. No gait clip is played.
const LABELS = ["Arms Down", "Wide Shoulders", "Arms Behind", "Hands On Hips", "Arms Crossed", "Boxer Guard", "One Hand Hip", "Ready Guard", "Military Rest", "Open Chest"]
# (arm angle, elbow adjustment, chest breathing, sway, cycle seconds)
const STYLES = [
	[0.00,0.00,0.020,0.013,3.0],
	[-0.65,-0.12,0.035,0.025,3.5],
	[0.45,-0.42,0.030,0.014,4.0],
	[0.95,0.92,0.040,0.022,3.1],
	[1.25,1.30,0.033,0.018,3.3],
	[1.70,1.65,0.055,0.032,2.7],
	[0.70,0.60,0.035,0.024,3.8],
	[1.42,1.20,0.060,0.037,2.6],
	[-0.35,-0.30,0.025,0.015,4.2],
	[-0.90,-0.18,0.045,0.024,3.2]
]

func base_rotation(source: Animation, track: int) -> Quaternion:
	# Average opposite phases of the SAME full cycle. This cancels the
	# left/right stride and arm swing that made the old lineup look like running.
	var a = source.rotation_track_interpolate(track, source.length * 0.25)
	var b = source.rotation_track_interpolate(track, source.length * 0.75)
	return a.slerp(b,0.5).normalized()

func base_position(source: Animation, track: int) -> Vector3:
	var a = source.position_track_interpolate(track, source.length * 0.25)
	var b = source.position_track_interpolate(track, source.length * 0.75)
	return (a+b)*0.5

func make_idle(source: Animation, index: int) -> Animation:
	var style = STYLES[index]
	var length = float(style[4])
	var idle = Animation.new()
	idle.length = length
	idle.loop_mode = Animation.LOOP_LINEAR
	for i in range(source.get_track_count()):
		if source.track_get_key_count(i) == 0: continue
		var kind = source.track_get_type(i)
		if kind not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]: continue
		var path = source.track_get_path(i)
		var bone = String(path).to_lower()
		var dst = idle.add_track(kind)
		idle.track_set_path(dst,path)
		if kind == Animation.TYPE_ROTATION_3D:
			var neutral = base_rotation(source,i)
			var offset = Quaternion.IDENTITY
			var motion_axis = Vector3.ZERO
			var angle = 0.0
			if bone.contains("leftarm") and not bone.contains("forearm"):
				angle = float(style[0])
				motion_axis = Vector3(0,0,float(style[2]))
			elif bone.contains("rightarm") and not bone.contains("forearm"):
				angle = -float(style[0])
				motion_axis = Vector3(0,0,-float(style[2]))
			elif bone.contains("leftforearm"):
				angle = float(style[1])
				motion_axis = Vector3(0,float(style[2])*0.4,0)
			elif bone.contains("rightforearm"):
				angle = -float(style[1])
				motion_axis = Vector3(0,-float(style[2])*0.4,0)
			elif bone.contains("spine"):
				motion_axis = Vector3(float(style[2]),float(style[3])*0.3,0)
			elif bone.contains("head") or bone.contains("neck"):
				motion_axis = Vector3(-float(style[2])*0.25,0,float(style[3])*0.25)
			if absf(angle) > 0.001:
				offset = Quaternion(Vector3(0,0,1),angle)
			for frame in range(9):
				var time = float(frame)*length/8.0
				var oscillation = sin(float(frame)*TAU/8.0)
				var movement = Quaternion.from_euler(motion_axis*oscillation)
				idle.rotation_track_insert_key(dst,time,(neutral*offset*movement).normalized())
		elif kind == Animation.TYPE_POSITION_3D:
			var pos = base_position(source,i)
			# Eliminate gait translation. Keep the character planted.
			for frame in range(9):
				idle.position_track_insert_key(dst,float(frame)*length/8.0,pos)
		elif kind == Animation.TYPE_SCALE_3D:
			var scale_value = source.scale_track_interpolate(i,source.length*0.5)
			idle.scale_track_insert_key(dst,0.0,scale_value)
			idle.scale_track_insert_key(dst,length,scale_value)
	return idle

func _ready():
	for index in range(10):
		var model = preload("res://assets/user_mixamo.glb").instantiate()
		model.position = Vector3((float(index)-4.5)*3.0,0.0,17.0)
		model.rotation.y = PI
		add_child(model)
		var players = model.find_children("*","AnimationPlayer",true,false)
		if players.is_empty(): continue
		var animator: AnimationPlayer = players[0]
		var name = "NewWalk"
		if not animator.has_animation(name):
			push_warning("IDLE_SOURCE_MISSING "+name)
			continue
		var idle = make_idle(animator.get_animation(name),index)
		var library = AnimationLibrary.new()
		library.add_animation("Standing",idle)
		animator.add_animation_library("preview",library)
		animator.play("preview/Standing")
		for part in model.find_children("*","MeshInstance3D",true,false):
			var white = StandardMaterial3D.new()
			white.albedo_color = Color.WHITE
			white.roughness = 0.82
			part.material_override = white
		var number = Label3D.new()
		number.text = str(index+1)
		number.font_size = 85
		number.pixel_size = 0.005
		number.modulate = Color(1,0.88,0.25)
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number.position = Vector3(0,2.45,0)
		model.add_child(number)
		var label = Label3D.new()
		label.text = LABELS[index]
		label.font_size = 28
		label.pixel_size = 0.005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0,2.12,0)
		model.add_child(label)
		print("STANDING_IDLE ",index+1," loops=",idle.length," tracks=",idle.get_track_count())
	print("IDLE_LINEUP_READY 10 continuously playing stationary idles")
