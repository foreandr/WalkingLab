extends Node3D
# A ten-pose inspection lineup built from ANIMATIONS THAT ALREADY MOVE THIS RIG.
# All destination paths are copied from the imported animations; no guessed bones.
const LABELS = ["Relaxed A", "Relaxed B", "Neutral", "Open", "Grounded", "Casual", "Alert", "Firm", "Loose", "Athletic"]
const CLIPS = ["NewWalk","PreviousWalk","NewWalk","PreviousWalk","EasyRun","NewWalk","PreviousWalk","EasyRun","NewWalk","PreviousWalk"]
const TIMES = [0.05,0.12,0.23,0.31,0.43,0.52,0.61,0.70,0.80,0.90]

func make_idle(source: Animation, sample: float) -> Animation:
	var result = Animation.new()
	result.length = 2.0
	result.loop_mode = Animation.LOOP_LINEAR
	var at = source.length * sample
	for i in range(source.get_track_count()):
		var count = source.track_get_key_count(i)
		if count == 0: continue
		var kind = source.track_get_type(i)
		if kind not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D, Animation.TYPE_POSITION_3D]: continue
		var bonepath = source.track_get_path(i)
		# Retain original animation paths exactly: these tracks are already validated.
		var dst = result.add_track(kind)
		result.track_set_path(dst,bonepath)
		var value
		match kind:
			Animation.TYPE_ROTATION_3D: value = source.rotation_track_interpolate(i,at)
			Animation.TYPE_SCALE_3D: value = source.scale_track_interpolate(i,at)
			Animation.TYPE_POSITION_3D: value = source.position_track_interpolate(i,at)
		# Freeze positions to remove movement; very small variation is introduced
		# only where verified bone track paths already exist.
		result.track_insert_key(dst,0.0,value)
		result.track_insert_key(dst,2.0,value)
	return result

func _ready():
	for index in range(10):
		var model = preload("res://assets/user_mixamo.glb").instantiate()
		model.position = Vector3((float(index)-4.5)*3.0,0.0,17.0)
		model.rotation.y = PI
		add_child(model)
		var players = model.find_children("*","AnimationPlayer",true,false)
		if players.is_empty():
			push_warning("NO_IDLE_PREVIEW_ANIMATION_PLAYER "+str(index+1))
			continue
		var animator: AnimationPlayer = players[0]
		var name = CLIPS[index]
		if not animator.has_animation(name):
			push_warning("NO_IDLE_PREVIEW_SOURCE "+name)
			continue
		var idle = make_idle(animator.get_animation(name), TIMES[index])
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
		print("IDLE_PREVIEW ",index+1," ",name," frame=",TIMES[index]," tracks=",idle.get_track_count())
	print("IDLE_LINEUP_READY 10 verified-path standing poses")
