extends Node3D
var ai
var mannequins: Array = []
var active_war_fighters: Array = []
var active_war_projectiles: Array = []
# Uniform spatial hash rebuilt once per physics step, shared across all AI.
const WAR_GRID_CELL: float = 12.0
var war_spatial_cells: Dictionary = {}
var war_projectile_cells: Dictionary = {}
var player
var ai_label: Label3D
var player_label: Label3D
var ai_wait = 0.0
var watching_ai = false
var battle_fireball_speed: float = 1.0
var battle_fireball_size: float = 1.0
var fireball_scene: PackedScene = preload("res://assets/external_vfx/fire.tscn")
var fighter_spawn_index: int = 0
# Queue runtime spawn requests: avoid constructing ten complete rigs in one frame.
var queued_fighter_spawns: int = 0
var spawn_cooldown: float = 0.0
var spawn_last_cost_ms: float = 0.0
var spawn_peak_cost_ms: float = 0.0
var spawn_count_window: int = 0

const FIGHTER_COLORS: Array[String] = ["7962cb","21c8d6","cb668d","87be4a","e3a452","597bc5","a7945c","d46cad","6bb3a8","b4c46c"]
var announced_winner: bool = false
var battle_feed: RichTextLabel
var battle_hits: Array[String] = []
var damage_totals: Dictionary = {}
var performance_label: Label
var performance_clock: float = 0.0
var profile_clock: float = 0.0
var profile_samples: Dictionary = {}
var profile_total: Dictionary = {}
var profile_maximum: Dictionary = {}
var profile_window_frames: int = 0
var profile_frame_fps_sum: float = 0.0
var profile_frame_cpu_sum: float = 0.0
var profile_frame_physics_sum: float = 0.0
var profile_wall_ms: Array[float] = []
var profile_cpu_ms: Array[float] = []
var profile_physics_ms: Array[float] = []
var profile_last_render_usec: int = 0
var profile_living_min: int = 999999
var profile_living_max: int = 0
var profile_living_sum: int = 0
var profile_living_samples: int = 0
var profile_projectile_peak: int = 0
var profile_spatial_fighter_cells: int = 0
var profile_spatial_projectile_cells: int = 0
var profile_spatial_max_fighter_bucket: int = 0
var profile_spatial_max_projectile_bucket: int = 0

func profile_percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty(): return 0.0
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(float(ordered.size()) * fraction) - 1,0,ordered.size()-1)]

func _ready():
	# Normal gravity, animations, spells and AI timing; only travel slows.
	Engine.time_scale = 1.0
	# The user accepts a 30 FPS simulation target. Run physics at 30 Hz
	# as well, rather than simulating twice for every visible frame.
	Engine.physics_ticks_per_second = 30
	Engine.max_fps = 30
	print("[PERF_CONFIG] fps_cap=30 physics_hz=",Engine.physics_ticks_per_second," ground_foot_correction_default=false")
	# Lower internal 3D resolution without reducing UI readability.
	get_viewport().scaling_3d_scale = 0.7
	for entry in [["move_forward",KEY_W],["move_back",KEY_S],["move_left",KEY_A],["move_right",KEY_D],["sprint",KEY_ALT],["walk",KEY_CTRL]]:
		if not InputMap.has_action(entry[0]): InputMap.add_action(entry[0])
		var key = InputEventKey.new()
		key.keycode = entry[1]
		InputMap.action_add_event(entry[0],key)
	create_battle_feed()
	create_performance_hud()
	# Restore the arena and its real physics floor independently of mannequins.
	add_child(preload("res://arena_environment.gd").new())
	var floor_body := StaticBody3D.new()
	floor_body.name = "ArenaGroundCollision"
	add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(96.0,0.2,96.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	player = preload("res://walking.gd").new()
	player.name = "PlayerMan"
	player.player_controlled = true
	player.actor_only = true
	player.spawn_point = Vector3(0,0,30)
	player.character_tint = Color("101114")
	add_child(player)
	player.camera.current = true
	player.actor.rotation.y = 0.0
	player_label = make_label(player.actor,"BLACK",Color("dddddd"))
	make_boundary()
	# Initial population is built during loading, before the first playable frame.
	for batch in range(3): spawn_more_fighters(10,true)
	ai = mannequins[0]
	ai_label = null

func spawn_more_fighters(count: int = 10, immediate: bool = false) -> void:
	if not immediate:
		queued_fighter_spawns += count
		print("[SPAWN_REQUEST] queued=",count," pending=",queued_fighter_spawns," existing=",mannequins.size())
		return
	for i in range(count):
		_spawn_single_fighter()

func _spawn_single_fighter() -> void:
	var spawn_begin: int = Time.get_ticks_usec()
	var pose_enabled: bool = player.war_pose_enabled if is_instance_valid(player) else false
	
	var index: int = fighter_spawn_index
	fighter_spawn_index += 1
	var fighter = preload("res://walking.gd").new()
	fighter.name = "Fighter%02d" % (index + 1)
	fighter.autonomous_only = true
	fighter.actor_only = true
	fighter.ai_abilities = true
	fighter.animation_test_mode = "war"
	fighter.war_pose_enabled = pose_enabled
	# Distribute later batches across the arena, avoiding the player spawn.
	var angle: float = float(index) * 2.39996323
	var ring: float = 12.0 + float((index / 10) % 6) * 4.0
	fighter.spawn_point = Vector3(sin(angle)*ring,0.0,cos(angle)*ring)
	fighter.character_tint = Color(FIGHTER_COLORS[index % FIGHTER_COLORS.size()])
	add_child(fighter)
	fighter.actor.rotation.y = angle + PI
	make_label(fighter.actor,"FIGHTER %02d" % (index+1),fighter.character_tint)
	mannequins.append(fighter)
	# The arena drives this fighter from one central physics callback.
	fighter.set_physics_process(false)
	announced_winner = false
	spawn_last_cost_ms = float(Time.get_ticks_usec()-spawn_begin)/1000.0
	spawn_peak_cost_ms = maxf(spawn_peak_cost_ms,spawn_last_cost_ms)
	spawn_count_window += 1
	record_performance_sample("fighter_spawn_one",Time.get_ticks_usec()-spawn_begin)
	print("[SPAWN_DONE] fighters_total=",mannequins.size()," pending=",queued_fighter_spawns," spawn_ms=",snappedf(spawn_last_cost_ms,0.01))

func set_fireball_width(multiplier: float) -> void:
	battle_fireball_size = multiplier
	# Adjust live projectiles too, not only ones spawned after moving the slider.
	for projectile in get_tree().get_nodes_in_group("battle_fireballs"):
		if not is_instance_valid(projectile): continue
		var mover: Node = projectile.get_node_or_null("Motion")
		if mover != null: mover.blast_width = multiplier
		for child in projectile.get_children():
			if child is GPUParticles3D:
				configure_fireball_particles(child,multiplier)
	print("[STRESS_FIREBALL_SIZE] multiplier=",multiplier," live_projectiles=",get_tree().get_nodes_in_group("battle_fireballs").size())

func configure_fireball_particles(effect: GPUParticles3D, multiplier: float) -> void:
	# This imported VFX uses billboarded QuadMesh particles. Resizing the
	# billboard geometry is reliable even when scaling the emitter is not.
	var mesh: Mesh = effect.draw_pass_1
	if mesh is QuadMesh:
		if not effect.has_meta("fireball_base_quad_size"):
			effect.set_meta("fireball_base_quad_size",(mesh as QuadMesh).size)
			effect.draw_pass_1 = mesh.duplicate()
		mesh = effect.draw_pass_1
		(mesh as QuadMesh).size = effect.get_meta("fireball_base_quad_size") * multiplier
	# Preserve the original spatial scale and explosion proportions.
	effect.scale = Vector3.ONE * 3.0

func create_performance_hud() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "PerformanceHUD"
	add_child(overlay)
	performance_label = Label.new()
	performance_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	performance_label.position = Vector2(-800,72)
	performance_label.add_theme_font_size_override("font_size",16)
	performance_label.add_theme_color_override("font_color",Color("d9ffab"))
	overlay.add_child(performance_label)

func record_performance_sample(category: String, microseconds: int) -> void:
	profile_total[category] = int(profile_total.get(category,0))+microseconds
	profile_samples[category] = int(profile_samples.get(category,0))+1
	profile_maximum[category] = maxi(int(profile_maximum.get(category,0)),microseconds)

func print_performance_report() -> void:
	var fps: float = profile_frame_fps_sum/float(maxi(1,profile_window_frames))
	var frame_ms: float = profile_frame_cpu_sum/float(maxi(1,profile_window_frames))
	var physics_ms: float = profile_frame_physics_sum/float(maxi(1,profile_window_frames))
	var summary: String = "[PERF_DETAIL] fps_avg=%.1f cpu_frame_avg_ms=%.2f physics_frame_avg_ms=%.2f frames=%d" % [fps,frame_ms,physics_ms,profile_window_frames]
	summary += " [PERF_WINDOW] wall_ms_p50=%.2f wall_ms_p95=%.2f wall_ms_p99=%.2f wall_ms_max=%.2f cpu_ms_p95=%.2f physics_ms_p95=%.2f" % [
		profile_percentile(profile_wall_ms,0.50),profile_percentile(profile_wall_ms,0.95),
		profile_percentile(profile_wall_ms,0.99),profile_percentile(profile_wall_ms,1.0),
		profile_percentile(profile_cpu_ms,0.95),profile_percentile(profile_physics_ms,0.95)
	]
	summary += " [SPAWN_PROFILE] queue=%d spawned_window=%d last_ms=%.2f max_ms=%.2f" % [queued_fighter_spawns,spawn_count_window,spawn_last_cost_ms,spawn_peak_cost_ms]
	spawn_count_window = 0
	spawn_peak_cost_ms = 0.0
	summary += " [WAR_ACTIVITY] living_min=%d living_max=%d living_avg=%.1f projectile_peak=%d fighter_grid_cells=%d projectile_grid_cells=%d max_fighter_bucket=%d max_projectile_bucket=%d" % [
		0 if profile_living_samples == 0 else profile_living_min,profile_living_max,
		float(profile_living_sum)/float(maxi(1,profile_living_samples)),profile_projectile_peak,
		profile_spatial_fighter_cells,profile_spatial_projectile_cells,
		profile_spatial_max_fighter_bucket,profile_spatial_max_projectile_bucket
	]
	var categories: Array = profile_total.keys()
	categories.sort()
	for category in categories:
		var n: int = int(profile_samples.get(category,0))
		var average: float = float(profile_total[category])/float(maxi(1,n))/1000.0
		var peak: float = float(profile_maximum.get(category,0))/1000.0
		# avg is per invocation; total spans all sampled invocations, not a frame budget.
		summary += " %s={avg_ms:%.3f,max_ms:%.3f,samples:%d}" % [category,average,peak,n]
	summary += " draw_calls=%d objects=%d video_mem_mb=%.1f" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))/1048576.0
	]
	summary += " active_projectiles=%d fighters=%d fireball_size=%.2f fps_cap=%d" % [get_tree().get_nodes_in_group("battle_fireballs").size(),mannequins.size(),battle_fireball_size,Engine.max_fps]
	print(summary)
	profile_total.clear()
	profile_samples.clear()
	profile_maximum.clear()
	profile_window_frames = 0
	profile_frame_fps_sum = 0.0
	profile_frame_cpu_sum = 0.0
	profile_frame_physics_sum = 0.0
	profile_wall_ms.clear()
	profile_cpu_ms.clear()
	profile_physics_ms.clear()
	profile_living_min = 999999
	profile_living_max = 0
	profile_living_sum = 0
	profile_living_samples = 0
	profile_projectile_peak = 0
	profile_spatial_fighter_cells = 0
	profile_spatial_projectile_cells = 0
	profile_spatial_max_fighter_bucket = 0
	profile_spatial_max_projectile_bucket = 0

func _process(dt: float) -> void:
	# Incrementally build the requested fighters instead of blocking one frame
	# on ten imported rigs, animation graphs and collision bodies.
	if queued_fighter_spawns > 0:
		spawn_cooldown -= dt
		if spawn_cooldown <= 0.0:
			queued_fighter_spawns -= 1
			_spawn_single_fighter()
			# Expensive rigs get a recovery gap. Never build more than one
			# complete fighter in a displayed frame.
			spawn_cooldown = 0.10 if spawn_last_cost_ms > 20.0 else 0.0
	var render_now: int = Time.get_ticks_usec()
	if profile_last_render_usec != 0:
		profile_wall_ms.append(float(render_now-profile_last_render_usec)/1000.0)
	profile_last_render_usec = render_now
	profile_cpu_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0)
	profile_physics_ms.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.0)
	profile_window_frames += 1
	profile_frame_fps_sum += float(Engine.get_frames_per_second())
	profile_frame_cpu_sum += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
	profile_frame_physics_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
	profile_clock += dt
	if profile_clock >= 5.0:
		profile_clock = 0.0
		print_performance_report()
	performance_clock -= dt
	if performance_clock > 0.0: return
	performance_clock = 0.5
	if performance_label == null: return
	var fps: int = Engine.get_frames_per_second()
	var draw_calls: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects: int = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var frame_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var reduced: int = 0
	for fighter in mannequins:
		if is_instance_valid(fighter) and not fighter.combat_dead and fighter.war_lod_mode == "reduced":
			reduced += 1
	performance_label.text = "FPS: %d | fighters: %d | CPU: %.1f ms | physics: %.1f ms | draws: %d | objects: %d | reduced physics: %d/%d" % [fps,mannequins.size(),frame_ms,physics_ms,draw_calls,objects,reduced,mannequins.size()]

func create_battle_feed() -> void:
	var ui := CanvasLayer.new()
	ui.name = "BattleHUD"
	add_child(ui)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(12,-330)
	panel.custom_minimum_size = Vector2(310,280)
	panel.modulate.a = 0.88
	ui.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "WAR / DAMAGE"
	column.add_child(heading)
	battle_feed = RichTextLabel.new()
	battle_feed.custom_minimum_size = Vector2(290,240)
	battle_feed.scroll_following = true
	battle_feed.bbcode_enabled = false
	column.add_child(battle_feed)
	battle_feed.text = "Waiting for combat..."

func record_battle_hit(attacker: String, victim: String, region: String, amount: float, _health: float) -> void:
	var source: String = attacker if attacker != "" else "UNKNOWN"
	damage_totals[source] = float(damage_totals.get(source,0.0))+amount
	battle_hits.push_front("%s → %s  %s  -%d" % [source,victim,region.to_upper(),int(round(amount))])
	if battle_hits.size() > 11: battle_hits.resize(11)
	if battle_feed != null:
		battle_feed.text = "TOTAL DAMAGE\n"
		var leaders: Array = damage_totals.keys()
		leaders.sort_custom(func(a,b): return float(damage_totals[a]) > float(damage_totals[b]))
		for i in range(mini(3,leaders.size())):
			battle_feed.text += "%s: %d\n" % [leaders[i],int(damage_totals[leaders[i]])]
		battle_feed.text += "\nRECENT HITS\n" + "\n".join(battle_hits)

func spawn_moving_cpus() -> void:
	# Two walkers, two high-speed runners, two immediate flyers.
	var assignments := [
		{"mode":"walk","name":"WALKER 1","pos":Vector3(-11,0,2)},
		{"mode":"walk","name":"WALKER 2","pos":Vector3(-13,0,5)},
		{"mode":"sprint","name":"SPRINTER 1","pos":Vector3(-15,0,-3)},
		{"mode":"sprint","name":"SPRINTER 2","pos":Vector3(-17,0,1)},
		{"mode":"fly","name":"FLYER 1","pos":Vector3(12,0,-5)},
		{"mode":"fly","name":"FLYER 2","pos":Vector3(16,0,-6)}
	]
	for entry in assignments:
		var cpu = preload("res://walking.gd").new()
		cpu.name = String(entry["name"]).replace(" ","")
		cpu.ai_mode = String(entry["mode"])
		cpu.autonomous_only = true
		cpu.actor_only = true
		cpu.spawn_point = entry["pos"]
		cpu.route_center = Vector3.ZERO
		cpu.route_radius = 18.0 if entry["mode"] == "fly" else 25.0
		add_child(cpu)
		make_label(cpu.actor,String(entry["name"]),Color("91ddfa"))
		mannequins.append(cpu)

func make_label(body: Node3D, text: String, color: Color) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 40
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position.y = 2.25
	body.add_child(label)
	# Readable circular identity marker at each character's feet.
	var ring := MeshInstance3D.new()
	ring.name = "NameCircle"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.58
	torus.outer_radius = 0.63
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = color
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.no_depth_test = false
	ring.material_override = ring_material
	ring.position.y = 0.045
	body.add_child(ring)
	return label
func make_boundary():
	# Closed 96 x 96 metre arena: opaque visible walls and a solid roof.
	var structure := StaticBody3D.new()
	structure.name = "EnclosedArena"
	add_child(structure)
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("51606d")
	wall_material.roughness = 0.9
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("34414e")
	roof_material.roughness = 0.95
	roof_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surfaces := [
		{"name":"NorthWall","size":Vector3(96.0,55.0,1.5),"center":Vector3(0,27.5,-48)},
		{"name":"SouthWall","size":Vector3(96.0,55.0,1.5),"center":Vector3(0,27.5,48)},
		{"name":"EastWall","size":Vector3(1.5,55.0,96.0),"center":Vector3(48,27.5,0)},
		{"name":"WestWall","size":Vector3(1.5,55.0,96.0),"center":Vector3(-48,27.5,0)},
		{"name":"Ceiling","size":Vector3(96.0,1.5,96.0),"center":Vector3(0,55,0)}
	]
	for item in surfaces:
		var collider := CollisionShape3D.new()
		var solid := BoxShape3D.new()
		solid.size = item["size"]
		collider.shape = solid
		collider.position = item["center"]
		structure.add_child(collider)
		var visible_wall := MeshInstance3D.new()
		visible_wall.name = item["name"]
		var block := BoxMesh.new()
		block.size = item["size"]
		visible_wall.mesh = block
		visible_wall.material_override = roof_material if item["name"] == "Ceiling" else wall_material
		visible_wall.position = item["center"]
		structure.add_child(visible_wall)
	# Internal lights keep the enclosed battlefield visible.
	# One broad unshadowed interior lamp replaces four overlapping
	# per-object lighting passes; ambient light supplies the fill.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0,48,0)
	lamp.light_energy = 2.2
	lamp.omni_range = 85.0
	lamp.shadow_enabled = false
	add_child(lamp)

func war_nearby_fighters(position: Vector3, radius_cells: int = 1) -> Array:
	var result: Array = []
	var center := Vector2i(floori(position.x / WAR_GRID_CELL),floori(position.z / WAR_GRID_CELL))
	for x in range(center.x-radius_cells,center.x+radius_cells+1):
		for z in range(center.y-radius_cells,center.y+radius_cells+1):
			var key := Vector2i(x,z)
			if war_spatial_cells.has(key): result.append_array(war_spatial_cells[key])
	return result

func war_nearby_projectiles(position: Vector3, radius_cells: int = 2) -> Array:
	var result: Array = []
	var center := Vector2i(floori(position.x / WAR_GRID_CELL),floori(position.z / WAR_GRID_CELL))
	for x in range(center.x-radius_cells,center.x+radius_cells+1):
		for z in range(center.y-radius_cells,center.y+radius_cells+1):
			var key := Vector2i(x,z)
			if war_projectile_cells.has(key): result.append_array(war_projectile_cells[key])
	return result

func tick_war_fighters(dt: float) -> void:
	var tick_start: int = Time.get_ticks_usec()
	# One authoritative living roster shared by every fighter this tick.
	var build_start: int = Time.get_ticks_usec()
	active_war_fighters.clear()
	war_spatial_cells.clear()
	war_projectile_cells.clear()
	active_war_projectiles = get_tree().get_nodes_in_group("battle_fireballs")
	for projectile in active_war_projectiles:
		if not is_instance_valid(projectile): continue
		var at: Vector3 = projectile.global_position
		var cell := Vector2i(floori(at.x/WAR_GRID_CELL),floori(at.z/WAR_GRID_CELL))
		if not war_projectile_cells.has(cell): war_projectile_cells[cell] = []
		war_projectile_cells[cell].append(projectile)
	for fighter in mannequins:
		if is_instance_valid(fighter) and not fighter.combat_dead:
			active_war_fighters.append(fighter)
			var at: Vector3 = fighter.actor.global_position
			var cell := Vector2i(floori(at.x/WAR_GRID_CELL),floori(at.z/WAR_GRID_CELL))
			if not war_spatial_cells.has(cell): war_spatial_cells[cell] = []
			war_spatial_cells[cell].append(fighter)
	record_performance_sample("war_spatial_build",Time.get_ticks_usec()-build_start)
	var living: int = active_war_fighters.size()
	profile_living_min = mini(profile_living_min,living)
	profile_living_max = maxi(profile_living_max,living)
	profile_living_sum += living
	profile_living_samples += 1
	profile_projectile_peak = maxi(profile_projectile_peak,active_war_projectiles.size())
	profile_spatial_fighter_cells = war_spatial_cells.size()
	profile_spatial_projectile_cells = war_projectile_cells.size()
	profile_spatial_max_fighter_bucket = 0
	profile_spatial_max_projectile_bucket = 0
	for bucket in war_spatial_cells.values():
		profile_spatial_max_fighter_bucket = maxi(profile_spatial_max_fighter_bucket,bucket.size())
	for bucket in war_projectile_cells.values():
		profile_spatial_max_projectile_bucket = maxi(profile_spatial_max_projectile_bucket,bucket.size())
	var sim_start: int = Time.get_ticks_usec()
	for fighter in mannequins:
		if not is_instance_valid(fighter): continue
		if fighter.combat_dead:
			if not fighter.combat_pose_frozen: fighter.update_combat_fall(dt)
		else:
			fighter.war_simulation_tick(dt)
	record_performance_sample("war_simulation_all",Time.get_ticks_usec()-sim_start)
	# Time the complete roster update, not just sampled per-fighter calls.
	record_performance_sample("war_scheduler_total",Time.get_ticks_usec()-tick_start)

func _physics_process(_dt):
	if player == null: return
	tick_war_fighters(_dt)
	player_label.position.y = player.crouch.capsule.height+0.3
	if announced_winner: return
	var survivors: Array = []
	for fighter in mannequins:
		if is_instance_valid(fighter) and not fighter.combat_dead: survivors.append(fighter)
	if survivors.size() == 1:
		announced_winner = true
		print("[WAR WINNER] ",survivors[0].name)
		var banner := Label3D.new()
		banner.text = "WINNER"
		banner.font_size = 90
		banner.pixel_size = 0.009
		banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		banner.modulate = Color("ffd05b")
		banner.position = Vector3.UP*3.5
		survivors[0].actor.add_child(banner)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:

		if event.keycode==KEY_0:
			spawn_more_fighters()
		if event.keycode==KEY_TAB:
			watching_ai = not watching_ai
			player.camera_target = ai.actor if watching_ai else null
