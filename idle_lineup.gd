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
		var best_score := 0
		# Imported FBXs often contain a long, static "Take 001" and a real
		# "mixamo.com" animation. Duration alone is NOT evidence of motion.
		for candidate in animators:
			var animator: AnimationPlayer = candidate
			for name in animator.get_animation_list():
				if name == "RESET": continue
				var clip: Animation = animator.get_animation(name)
				var changing_tracks := 0
				var rotation_tracks := 0
				for k in range(clip.get_track_count()):
					if clip.track_get_type(k) != Animation.TYPE_ROTATION_3D: continue
					rotation_tracks += 1
					if clip.track_get_key_count(k) < 2: continue
					var start_q: Quaternion = clip.track_get_key_value(k,0)
					var animated := false
					for sample in [1, clip.track_get_key_count(k) / 2, clip.track_get_key_count(k) - 1]:
						var other: Quaternion = clip.track_get_key_value(k,int(sample))
						if absf(start_q.dot(other)) < 0.99999:
							animated = true
							break
					if animated: changing_tracks += 1
				print("MIXAMO_TAKE_SCAN ",filename," take=",name," tracks=",clip.get_track_count(),
					" rotation_tracks=",rotation_tracks," moving=",changing_tracks," length=",clip.length)
				var score = changing_tracks * 100 + rotation_tracks
				if score > best_score:
					best_score = score
					duration = clip.length
					chosen_clip = name
					chosen_player = animator
		if chosen_player == null:
			print("MIXAMO_IDLE_NO_MOTION ",filename," (all imported takes lack varying skeleton rotations)")
			model.free()
			continue
		# Keep the imported animation and its imported rig together.
		# This eliminates the 0/65 failed retarget problem.
		var clip: Animation = chosen_player.get_animation(chosen_clip)
		clip.loop_mode = Animation.LOOP_LINEAR
		model.position = Vector3((float(shown)-float(mini(filenames.size(),LIMIT)-1)*0.5)*3.3, 0.0, 17.0)
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
			" duration=",duration," tracks=",clip.get_track_count()," motion_score=",best_score," meshes=",meshes.size())
		shown += 1
	print("MIXAMO_IDLE_STUDIO_READY ",shown," / ",filenames.size()," supplied idle FBX files")
