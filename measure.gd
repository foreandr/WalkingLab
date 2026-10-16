extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.set_physics_process(false)
	var previous = {}
	var speeds = []
	for frame in range(ceili(g.anim.get_animation("move_sprint").length*60)):
		g.sample("move_sprint",frame/60.0)
		g.skeleton.force_update_all_bone_transforms()
		for side in ["Left","Right"]:
			var p = g.skeleton.get_bone_global_pose(g.skeleton.find_bone(side+"Foot")).origin
			if previous.has(side) and p.y<0.19:
				var v = (p.z-previous[side].z)*60
				if v>0.2: speeds.append(v)
			previous[side] = p
	var sum = 0.0
	for v in speeds: sum += v
	print("STANCE_SPEED ",sum/max(1,speeds.size())," samples=",speeds.size())
	quit()


