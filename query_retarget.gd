extends SceneTree
func _initialize():
	for p in ClassDB.class_get_property_list("RetargetModifier3D"):
		if "profile" in p.name or "pose" in p.name or "copy" in p.name or "target" in p.name:print("RETARGET_PROPERTY ",p)
	quit()
