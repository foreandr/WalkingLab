extends SceneTree
func _initialize(): call_deferred("run")
func run():
	for file in ["character","library"]:
		var scene = load("res://assets/"+file+".glb").instantiate()
		var sk = scene.find_children("*","Skeleton3D",true,false)[0]
		print("ANIMATIONS ",scene.find_children("*","AnimationPlayer",true,false)[0].get_animation_list())
		print("PATH ",file," ",scene.get_path_to(sk))
		print("BONES ",file," ",range(sk.get_bone_count()).map(func(i): return sk.get_bone_name(i)))
		scene.free()
	quit()

