extends SceneTree
func _initialize():
	for key in ["walk","run","sprint"]:
		var root=load("res://assets/rokoko/"+key+"_original.glb").instantiate()
		var player=root.find_children("*","AnimationPlayer",true,false)[0]
		var clip=player.get_animation("Root")
		print(key," duration=",clip.length," tracks=",clip.get_track_count())
		for track in range(clip.get_track_count()):
			if ":LeftShin" in str(clip.track_get_path(track)) or ":Hips" in str(clip.track_get_path(track)):
				print("TRACK ",clip.track_get_path(track)," type=",clip.track_get_type(track)," keys=",clip.track_get_key_count(track)," first=",clip.track_get_key_value(track,0)," last=",clip.track_get_key_value(track,clip.track_get_key_count(track)-1))
		root.free()
	quit()
