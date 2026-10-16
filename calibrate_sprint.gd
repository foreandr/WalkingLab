extends SceneTree
func _initialize():call_deferred("run")
func run():
	var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	var clips=[]
	for clip in ["move_run","move_sprint"]:
		var values=[]
		for frame in range(120):
			g.sample(clip,g.anim.get_animation(clip).length*frame/120.0)
			g.skeleton.force_update_all_bone_transforms()
			var feet=[]
			for side in ["l","r"]:feet.append(g.skeleton.get_bone_global_pose(g.skeleton.find_bone("foot_"+side)).origin)
			values.append(feet)
		clips.append(values)
	var best=INF;var shift=0
	for offset in range(120):
		var error=0.0
		for frame in range(120):
			for side in range(2):
				var a=clips[0][frame][side];var b=clips[1][(frame+offset)%120][side]
				error+=pow(a.z-b.z,2)+pow(a.y-b.y,2)*0.4
		if error<best:best=error;shift=offset
	print("SPRINT_RELATIVE_PHASE ",shift/120.0," score=",best)
	quit()

