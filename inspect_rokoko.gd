extends SceneTree
func _initialize():
	for key in ["walk","run","sprint"]:
		var root=load("res://assets/rokoko/"+key+"_original.glb").instantiate()
		var sk=root.find_children("*","Skeleton3D",true,false)[0]
		var ap=root.find_children("*","AnimationPlayer",true,false)[0]
		print("ROKOKO ",key," path=",root.get_path_to(sk)," animations=",ap.get_animation_list()," motion_scale=",sk.motion_scale," scale=",sk.scale)
		print("BONES ",range(sk.get_bone_count()).map(func(i):return sk.get_bone_name(i)))
		root.free()
	quit()
