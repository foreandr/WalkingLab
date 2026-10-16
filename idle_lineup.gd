extends Node3D
# Mixamo idle audition. Each FBX is displayed ON ITS OWN imported character and
# skeleton. Retargeting is deliberately not attempted in this preview.
# Import a clip with skin from Mixamo; add it to assets/custom_idle or Downloads.
const LIMIT := 10

func is_idle_candidate(filename: String) -> bool:
	var lower = filename.to_lower()
	return lower.ends_with(".fbx") and lower.contains("idle") and not lower.contains(" to ") and not lower.contains("transition")

func _ready() -> void:
	var filenames: Array[String] = []
	for file in DirAccess.get_files_at("res://assets/custom_idle"):
		if is_idle_candidate(file): filenames.append(file)
	filenames.sort_custom(func(a: String,b: String) -> bool:
		if a == "Idle.fbx": return true
		if b == "Idle.fbx": return false
		return a.naturalnocasecmp_to(b) < 0)
	var shown := 0
	for filename in filenames:
		if shown >= LIMIT: break
		var path = "res://assets/custom_idle/" + filename
		if not ResourceLoader.exists(path):
			print("MIXAMO_IDLE_NOT_IMPORTED ", filename)
			continue
		var packed = load(path)
		if not packed is PackedScene:
			print("MIXAMO_IDLE_BAD_SCENE ", filename)
			continue
		var model: Node3D = packed.instantiate()
		var animators = model.find_children("*", "AnimationPlayer", true, false)
		var meshes = model.find_children("*", "MeshInstance3D", true, false)
		if animators.is_empty() or meshes.is_empty():
			print("MIXAMO_IDLE_REJECTED ",filename," animation_players=",animators.size()," meshes=",meshes.size(),
				" (download WITH SKIN to preview the native skeleton)")
			model.free()
			continue
		var chosen_player: AnimationPlayer = null
		var chosen_clip := ""
		var duration := -1.0
		for candidate in animators:
			var animator: AnimationPlayer = candidate
			for name in animator.get_animation_list():
				if name == "RESET": continue
				var clip = animator.get_animation(name)
				if clip.length > duration and clip.get_track_count() > 0:
					duration = clip.length
					chosen_clip = name
					chosen_player = animator
		if chosen_player == null:
			print("MIXAMO_IDLE_NO_MOTION ",filename)
			model.free()
			continue
		# Keep the imported animation and its imported rig together.
		# This eliminates the 0/65 failed retarget problem.
		var clip: Animation = chosen_player.get_animation(chosen_clip)
		clip.loop_mode = Animation.LOOP_LINEAR
		model.position = Vector3((float(shown)-4.5)*3.3, 0.0, 17.0)
		model.rotation.y = PI
		add_child(model)
		for animator in animators: animator.stop()
		for part in meshes:
			var white := StandardMaterial3D.new()
			white.albedo_color = Color.WHITE
			white.roughness = 0.82
			part.material_override = white
		chosen_player.play(chosen_clip)
		var marker := Label3D.new()
		marker.text = str(shown + 1)
		marker.font_size = 85
		marker.pixel_size = 0.005
		marker.modulate = Color(1,0.87,0.27)
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.position = Vector3(0,2.5,0)
		model.add_child(marker)
		var description := Label3D.new()
		description.text = filename.get_basename()
		description.font_size = 27
		description.pixel_size = 0.005
		description.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		description.position = Vector3(0,2.12,0)
		model.add_child(description)
		print("MIXAMO_IDLE_PLAYING #",shown+1," file=",filename," take=",chosen_clip,
			" duration=",duration," tracks=",clip.get_track_count()," meshes=",meshes.size())
		shown += 1
	print("MIXAMO_IDLE_STUDIO_READY ",shown," / ",filenames.size()," supplied idle FBX files")
