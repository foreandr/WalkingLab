extends SceneTree
func _initialize():
	var c=ConfigFile.new();c.load("res://assets/defender_retarget.glb.import")
	var source=ConfigFile.new();source.load("res://assets/character.glb.import")
	var data=source.get_value("params","_subresources")
	var node=data.nodes["PATH:Defender_Ske/Skeleton3D"]
	node["retarget/rest_fixer/retarget_method"]=0
	node["retarget/rest_fixer/overwrite_axis"]=false
	node["retarget/rest_fixer/fix_silhouette/enable"]=false
	node["retarget/rest_fixer/fix_silhouette/base_height_adjustment"]=0.0
	c.set_value("params","_subresources",data)
	c.save("res://assets/defender_retarget.glb.import")
	quit()
