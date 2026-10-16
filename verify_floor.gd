extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.set_physics_process(false)
	var minimum = INF
	var max_correction = 0.0
	var failures = 0
	var samples = 0
	for rate in [30,60,120]:
		for frame in range(rate*23):
			g._physics_process(1.0/rate)
			if frame%3==0:
				var bottom = g.feet.lowest(g.feet.all_samples)
				minimum = min(minimum,bottom)
				max_correction = max(max_correction,g.feet.lift)
				if bottom< -0.001 or g.actor.position.y< -0.001: failures += 1
				samples += 1
	print("FLOOR_VERIFY failures=",failures," full_mesh_checks=",samples," min_vertex_y=",minimum," max_lift=",max_correction," jumps=",g.jumps," landings=",g.landings," gaits=",g.seen_gaits.keys())
	quit(1 if failures else 0)
