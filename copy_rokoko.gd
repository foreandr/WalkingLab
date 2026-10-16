extends SceneTree
func _initialize():
	for key in ["walk","run","sprint"]:
		var from="res://assets/rokoko/"+key+"_original.glb"
		var to="res://assets/rokoko/"+key+"_mapped.glb"
		DirAccess.copy_absolute(ProjectSettings.globalize_path(from),ProjectSettings.globalize_path(to))
	quit()
