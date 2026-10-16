extends SceneTree
func _initialize():
	var c=ConfigFile.new()
	c.load("res://assets/character.glb.import")
	var options=c.get_value("params","_subresources")
	var node=options.nodes["PATH:Defender_Ske/Skeleton3D"]
	node["retarget/rest_fixer/fix_silhouette/filter"]=[&"LeftFoot",&"RightFoot",&"LeftToes",&"RightToes"]
	node["retarget/rest_fixer/fix_silhouette/base_height_adjustment"]=0.085
	node["retarget/rest_fixer/fix_silhouette/threshold"] = 1.0
	c.set_value("params","_subresources",options)
	c.save("res://assets/character.glb.import")
	quit()



