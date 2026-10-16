extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.set_physics_process(false)
	for clip in ["move_walk","move_run","move_sprint"]:
		var duration=g.anim.get_animation(clip).length
		var rows=[]
		for frame in range(121):
			g.sample(clip,duration*min(frame,119)/120.0)
			g.skeleton.force_update_all_bone_transforms()
			var positions=[]
			for side in ["Left","Right"]:
				var p=g.skeleton.to_global(g.skeleton.get_bone_global_pose(g.skeleton.find_bone(side+"Foot")).origin)
				positions.append(g.actor.to_local(p))
			rows.append(positions)
		var velocities=[]
		for side in range(2):
			var heights=[]
			for row in rows:heights.append(row[side].y)
			heights.sort()
			for frame in range(1,119):
				var velocity=(rows[frame][side].z-rows[frame-1][side].z)/(duration/120.0)
				if rows[frame][side].y<heights[heights.size()/2] and velocity>0.1:velocities.append(velocity)
		velocities.sort()
		print("MEASURED_STRIDE ",clip," ",velocities[velocities.size()/2]*duration if not velocities.is_empty() else 0," velocities=",velocities.size())
	quit()
