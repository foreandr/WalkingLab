extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var c=load("res://comparison.tscn").instantiate()
	root.add_child(c)
	c.set_process(false)
	for index in range(3):
		c.select_clip(index)
		var a=INF;var b=INF;var top_a=-INF;var top_b=-INF
		for frame in range(61):
			var time=c.player_a.get_animation(c.originals[index]).length*frame/60.0
			c.player_a.seek(time,true);c.player_a.advance(0)
			c.player_b.seek(time,true);c.player_b.advance(0)
			c.sk_a.force_update_all_bone_transforms();c.sk_b.force_update_all_bone_transforms()
			var pa=c.foot_a.lowest(c.foot_a.all_samples);var pb=c.foot_b.lowest(c.foot_b.all_samples)
			a=min(a,pa);b=min(b,pb);top_a=max(top_a,pa);top_b=max(top_b,pb)
		print("RAW_CONTACT ",c.originals[index]," source_range=",a,"..",top_a," target_range=",b,"..",top_b)
	quit()
