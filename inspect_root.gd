extends SceneTree
func _initialize():
	var scene=load("res://assets/library.glb").instantiate()
	var player=scene.find_children("*","AnimationPlayer",true,false)[0]
	for name in ["Walk","Jog_Fwd","Sprint"]:
		var clip=player.get_animation(name)
		for t in range(clip.get_track_count()):
			if str(clip.track_get_path(t)).ends_with(":Hips"):
				print(name," ROOT ",clip.track_get_type(t)," first=",clip.track_get_key_value(t,0)," last=",clip.track_get_key_value(t,clip.track_get_key_count(t)-1))
	scene.free()
	quit()

