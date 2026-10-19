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
var battle_panel: PanelContainer
var ai_wait = 0.0
var watching_ai = false
var battle_fireball_speed: float = 1.0
var battle_fireball_size: float = 1.0
var fireball_scene: PackedScene = preload("res://assets/external_vfx/fire.tscn")
const MAX_ACTIVE_FIGHTERS: int = 80
# Default: one fleeing runner, three differently constrained spellcasters.
# The previous 80-fighter stress test remains opt-in through CLI.
const TEAM_AI_FIGHTERS: int = 1
var current_level: Dictionary = {}
var royale_loot: Array[Dictionary] = []
const ROYALE_SPELLS: Array[String] = ["fire","frost","homing","ricochet","gravity","grounding","venom","tempest"]
var level_number: int = 1
const TEAM_BLUE: Color = Color("317bff")
const TEAM_RED: Color = Color("ed4451")
var status_refresh_clock: float = 0.0
var arena_half_extent: float = 5.0
var biome_features_enabled: bool = false
const LINEUP_DISTANCES: Array[int] = [1,2,4,8,16,32,64,128]
var fighter_spawn_index: int = 0
var spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Queue runtime spawn requests: avoid constructing ten complete rigs in one frame.
var queued_fighter_spawns: int = 0
var spawn_cooldown: float = 0.0
var spawn_last_cost_ms: float = 0.0
var spawn_peak_cost_ms: float = 0.0
var spawn_count_window: int = 0
# Opt-in: --flight-benchmark. Begins after the requested fighters spawn,
# then performs sixty seconds of genuine player flight physics.
var flight_benchmark_requested: bool = false
var benchmark_fighters: int = MAX_ACTIVE_FIGHTERS
var flight_benchmark_running: bool = false
var flight_benchmark_start_usec: int = 0
var flight_benchmark_last_log_second: int = -1
var flight_benchmark_unfocused_frames: int = 0
var flight_benchmark_low_draw_frames: int = 0
var flight_benchmark_origin: Vector3 = Vector3.ZERO

# Uniform white base makes anatomical damage visible on each fighter.
# Health, limb injury and deaths are authoritative; test targets are mortal.
const FIGHTER_COLOR: Color = Color.WHITE
var stress_no_deaths: bool = false
# Controlled A/B switch. Default restores Cycle 4 anatomical shader writes.
var batch_aoe_shader: bool = false
var announced_winner: bool = false
var winner_banner: Label3D = null
var battle_feed: RichTextLabel
var battle_hits: Array[String] = []
var battle_feed_dirty: bool = false
var battle_feed_refresh_clock: float = 0.0
var player_auto_attacks_window: int = 0
var player_auto_target_changes_window: int = 0
var aoe_events_window: int = 0
var aoe_fighters_window: int = 0
var aoe_regions_window: int = 0

var damage_totals: Dictionary = {}
var performance_label: Label
var performance_clock: float = 0.0
var profile_clock: float = 0.0
var profile_samples: Dictionary = {}
var profile_total: Dictionary = {}
var profile_maximum: Dictionary = {}
var profile_window_frames: int = 0
var profile_frame_fps_sum: float = 0.0
var profile_focus_frames: int = 0
var profile_unfocused_frames: int = 0
var profile_focus_fps_sum: float = 0.0
var profile_unfocused_fps_sum: float = 0.0
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
var profile_grid_stat_clock: int = 0

func profile_percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty(): return 0.0
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(float(ordered.size()) * fraction) - 1,0,ordered.size()-1)]

func _ready():
	spawn_rng.randomize()
	current_level = preload("res://level_definitions.gd").get_level(level_number)
	arena_half_extent = float(current_level.get("arena_half_extent",5.0))
	spawn_rng.seed = int(current_level["seed"])
	flight_benchmark_requested = "--flight-benchmark" in OS.get_cmdline_user_args()
	if flight_benchmark_requested:
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--benchmark-fighters="):
				var requested := argument.trim_prefix("--benchmark-fighters=")
				if not requested.is_valid_int() or int(requested) < 1 or int(requested) > MAX_ACTIVE_FIGHTERS:
					push_error("benchmark-fighters must be between 1 and %d" % MAX_ACTIVE_FIGHTERS)
					get_tree().quit(2)
					return
				benchmark_fighters = int(requested)
	batch_aoe_shader = "--batch-aoe-shader" in OS.get_cmdline_user_args()
	# Normal gravity, animations, spells and AI timing; only travel slows.
	Engine.time_scale = 1.0
	# The user accepts a 30 FPS simulation target. Run physics at 30 Hz
	# as well, rather than simulating twice for every visible frame.
	Engine.physics_ticks_per_second = 30
	Engine.max_fps = 30
	print("[PERF_CONFIG] fps_cap=30 physics_hz=",Engine.physics_ticks_per_second," ground_foot_correction_default=false stress_no_deaths=",stress_no_deaths," batch_aoe_shader=",batch_aoe_shader)
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
	var level_environment = preload("res://arena_environment.gd").new()
	level_environment.biome = String(current_level["biome"])
	level_environment.world_half_extent = arena_half_extent
	level_environment.building_defs = current_level.get("buildings",[])
	add_child(level_environment)
	var floor_body := StaticBody3D.new()
	floor_body.name = "ArenaGroundCollision"
	add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(arena_half_extent*2.0,0.2,arena_half_extent*2.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	player = preload("res://walking.gd").new()
	player.name = "PlayerMan"
	player.player_controlled = true
	player.auto_war_combat = false
	player.ai_mode = ""
	player.actor_only = true
	player.spawn_point = Vector3(-15.0,0.0,-15.0) if not flight_benchmark_requested else Vector3.ZERO
	player.character_tint = FIGHTER_COLOR
	player.team_id = ""
	if not flight_benchmark_requested:
		var level_player_spells: Array[String] = []
		level_player_spells.assign(current_level["player_spells"])
		player.equipped_spells = level_player_spells
	player.demo_immortal = not bool(current_level.get("battle_royale_drop",false))
	# Black must not inherit any scripted AI/benchmark movement in normal play.
	player.benchmark_flight_active = false
	player.benchmark_flight_axis = Vector2.ZERO
	player.benchmark_flight_direction = Vector3.ZERO
	add_child(player)
	if String(current_level.get("biome","")) == "flat_dirt":
		player.actor.add_child(preload("res://dirt_footsteps.gd").new())
	player.camera.current = true
	player_label = make_label(player.actor,"BLACK / IMMORTAL [G]",TEAM_BLUE)
	attach_status_label(player)
	if String(current_level.get("biome","")) != "grassland" and String(current_level.get("biome","")) != "flat_dirt":
		make_boundary()
	# Always show a separate autonomous locomotion demonstrator beside Black.
	ai = null
	# Keep Black player-controlled and spawn a separate autonomous motion showcase.
	set_demo_npc_enabled(false)
	if flight_benchmark_requested:
		spawn_more_fighters(benchmark_fighters)
	else:
		# Autonomous free-for-all combatants, spawned over separate frames.
		if int(current_level.get("enemy_count",0)) > 0:
			spawn_more_fighters(int(current_level["enemy_count"]), true)
	if bool(current_level.get("battle_royale_drop",false)) and not flight_benchmark_requested:
		create_royale_loot()
	elif not flight_benchmark_requested:
		create_test_spell_loot()
	print("[LEVEL_START] number=",level_number," name=",current_level["name"]," biome=",current_level["biome"]," enemies=",mannequins.size()," spells_player=",player.equipped_spells)

func set_demo_npc_enabled(enabled: bool) -> void:
	if enabled:
		if is_instance_valid(ai): return
		ai = preload("res://walking.gd").new()
		ai.name = "DemoNPC"
		ai.player_controlled = false
		ai.auto_war_combat = false
		ai.ai_mode = "sprint"
		ai.actor_only = true
		ai.spawn_point = Vector3(9,0,12)
		ai.character_tint = FIGHTER_COLOR
		add_child(ai)
		ai.camera.current = false
		ai_label = make_label(ai.actor,"MOTION DEMO / AUTO",Color("c9d6ff"))
		print("[MOTION_DEMO] NPC spawned at ",ai.spawn_point," with Black under player control")
	else:
		if is_instance_valid(ai):
			if is_instance_valid(player): player.camera_target = null
			ai.queue_free()
		ai = null
		ai_label = null

func clear_winner_announcement() -> void:
	announced_winner = false
	if is_instance_valid(winner_banner):
		winner_banner.queue_free()
	winner_banner = null

func spawn_more_fighters(count: int = 10, immediate: bool = false) -> void:
	# Cap the number of living/queued combatants, not historical total spawns.
	var living_count: int = 0
	for fighter in mannequins:
		if is_instance_valid(fighter) and not fighter.combat_dead: living_count += 1
	count = mini(count,MAX_ACTIVE_FIGHTERS-living_count-queued_fighter_spawns)
	if count <= 0: return
	clear_winner_announcement()
	if not immediate:
		queued_fighter_spawns += count
		print("[SPAWN_REQUEST] queued=",count," pending=",queued_fighter_spawns," existing=",mannequins.size())
		return
	for i in range(count):
		_spawn_single_fighter()

# Independent random war positions, rejecting crowded samples and the player/demo start.
# Kept out of benchmarking so its positional comparison remains reproducible.
func random_war_spawn() -> Vector3:
	var best: Vector3 = Vector3.ZERO
	var best_clearance: float = -1.0
	for attempt in range(64):
		var angle := spawn_rng.randf_range(-PI,PI)
		var radius := sqrt(spawn_rng.randf_range(0.0,1.0))*27.0
		var candidate := Vector3(cos(angle)*radius,0.0,sin(angle)*radius)
		var clearance: float = candidate.distance_to(Vector3(player.spawn_point.x,0.0,player.spawn_point.z))
		if is_instance_valid(ai):
			clearance = minf(clearance,candidate.distance_to(Vector3(ai.spawn_point.x,0.0,ai.spawn_point.z)))
		for other in mannequins:
			if is_instance_valid(other) and not other.combat_dead:
				var occupied: Vector3 = other.actor.global_position
				clearance = minf(clearance,candidate.distance_to(Vector3(occupied.x,0.0,occupied.z)))
		if clearance > best_clearance:
			best = candidate
			best_clearance = clearance
		if clearance >= 6.0:
			return candidate
	return best

func _spawn_single_fighter() -> void:
	var spawn_begin: int = Time.get_ticks_usec()
	var pose_enabled: bool = player.war_pose_enabled if is_instance_valid(player) else false
	
	var index: int = fighter_spawn_index
	fighter_spawn_index += 1
	var fighter = preload("res://walking.gd").new()
	fighter.name = "Fighter%02d" % (index + 1)
	fighter.autonomous_only = true
	fighter.actor_only = true
	fighter.ai_abilities = false if not flight_benchmark_requested else true
	fighter.team_battle_ai = false if not flight_benchmark_requested else true
	var duel_spells: Array[String] = []
	if flight_benchmark_requested:
		duel_spells = ["fire", "frost"]
	else:
		duel_spells.assign(current_level["enemy_spells"])
	fighter.equipped_spells = duel_spells
	fighter.animation_test_mode = "war"
	fighter.war_pose_enabled = pose_enabled
	var is_team_battle: bool = false
	var label_text: String = "FIGHTER %02d" % (index+1)
	if is_team_battle:
		var blue_spawn: Array[Vector3] = [Vector3(-9,0,24),Vector3(0,0,24),Vector3(9,0,24)]
		var red_spawn: Array[Vector3] = [Vector3(-15,0,-23),Vector3(-5,0,-26),Vector3(5,0,-26),Vector3(15,0,-23)]
		var blue_team: bool = index<3
		fighter.team_id = "blue" if blue_team else "red"
		fighter.team_battle_ai = true
		fighter.spawn_point = blue_spawn[index] if blue_team else red_spawn[index-3]
		fighter.ai_abilities = true
		label_text = ("%s %d" % ["BLUE",index+1]) if blue_team else ("%s %d" % ["RED",index-2])
	else:
		# Preserve the existing 80-fighter benchmark and manual war-spawn path.
		var angle: float = float(index) * 2.39996323
		var ring: float = 45.0 + float((index / 10) % 8) * 19.0
		if not flight_benchmark_requested:
			fighter.spawn_point = Vector3(15.0,0.0,15.0) if int(current_level.get("enemy_count",0)) == 1 else random_war_spawn()
		elif index < LINEUP_DISTANCES.size():
			var measured_distance: float = float(LINEUP_DISTANCES[index])
			fighter.spawn_point = player.spawn_point+Vector3(0.0,0.0,-measured_distance)
			fighter.animation_lineup_mode = true
			label_text = "%d m" % LINEUP_DISTANCES[index]
		else:
			fighter.spawn_point = Vector3(sin(angle)*ring,0.0,cos(angle)*ring)
	fighter.demo_immortal = not flight_benchmark_requested
	if not flight_benchmark_requested: fighter.set_meta("test_dummy",true)
	fighter.character_tint = FIGHTER_COLOR
	add_child(fighter)
	fighter.actor.rotation.y = atan2(player.actor.global_position.x-fighter.actor.global_position.x,player.actor.global_position.z-fighter.actor.global_position.z)+PI
	make_label(fighter.actor,label_text,TEAM_BLUE if fighter.team_id=="blue" else (TEAM_RED if fighter.team_id=="red" else FIGHTER_COLOR))
	if is_team_battle: attach_status_label(fighter)
	mannequins.append(fighter)
	if String(current_level.get("biome","")) == "grassland" and index < 3:
		var tower: Node = get_node_or_null("ArenaEnvironment/CentralTower")
		if tower == null:
			for child in get_children():
				if child.has_node("CentralTower"):
					tower = child.get_node("CentralTower")
					break
		if tower != null and tower.has_method("register_guard"):
			tower.register_guard(fighter)
	# The arena drives this fighter from one central physics callback.
	fighter.set_physics_process(false)
	spawn_last_cost_ms = float(Time.get_ticks_usec()-spawn_begin)/1000.0
	spawn_peak_cost_ms = maxf(spawn_peak_cost_ms,spawn_last_cost_ms)
	spawn_count_window += 1
	record_performance_sample("fighter_spawn_one",Time.get_ticks_usec()-spawn_begin)
	print("[SPAWN_DONE] fighters_total=",mannequins.size()," pending=",queued_fighter_spawns," at=",fighter.actor.global_position," spawn_ms=",snappedf(spawn_last_cost_ms,0.01))

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
	performance_label.visible = false # Diagnostics are available in Settings.
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
	summary += " [WINDOW_FOCUS] focused_frames=%d unfocused_frames=%d focused_fps=%.1f unfocused_fps=%.1f" % [profile_focus_frames,profile_unfocused_frames,profile_focus_fps_sum/float(maxi(1,profile_focus_frames)),profile_unfocused_fps_sum/float(maxi(1,profile_unfocused_frames))]
	summary += " [STRESS_CONFIG] no_deaths=%s target_fighters=%d batch_aoe_shader=%s" % [str(stress_no_deaths),MAX_ACTIVE_FIGHTERS,str(batch_aoe_shader)]
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
	summary += " [PLAYER_AUTO_COMBAT] attacks=%d target_changes=%d" % [player_auto_attacks_window,player_auto_target_changes_window]
	player_auto_attacks_window = 0
	player_auto_target_changes_window = 0
	summary += " [AOE_TOTALS] events=%d fighters_hit=%d regions_hit=%d" % [aoe_events_window,aoe_fighters_window,aoe_regions_window]
	aoe_events_window = 0
	aoe_fighters_window = 0
	aoe_regions_window = 0
	profile_total.clear()
	profile_samples.clear()
	profile_maximum.clear()
	profile_window_frames = 0
	profile_frame_fps_sum = 0.0
	profile_focus_frames = 0
	profile_unfocused_frames = 0
	profile_focus_fps_sum = 0.0
	profile_unfocused_fps_sum = 0.0
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
	if battle_panel != null:
		battle_panel.visible = Input.is_physical_key_pressed(KEY_TAB)
	battle_feed_refresh_clock -= dt
	if battle_feed_refresh_clock <= 0.0:
		battle_feed_refresh_clock = 0.2
		refresh_battle_feed()
	if flight_benchmark_requested and not flight_benchmark_running and queued_fighter_spawns == 0 and mannequins.size() == benchmark_fighters and is_instance_valid(player) and DisplayServer.get_name() != "headless" and DisplayServer.window_is_focused():
		flight_benchmark_running = true
		flight_benchmark_unfocused_frames = 0
		flight_benchmark_low_draw_frames = 0
		flight_benchmark_start_usec = Time.get_ticks_usec()
		# Start in the center of the action, clear of ground and arena walls.
		player.actor.global_position = Vector3(0.0,8.0,13.0)
		player.actor.velocity = Vector3.ZERO
		flight_benchmark_origin = player.actor.global_position
		player.benchmark_flight_active = true
		player.flight_enabled = true
		player.flight_launch_remaining = 0.0
		player.flight_clearance_time = 2.0
		player.actor.global_position.y = maxf(player.actor.global_position.y,4.0)
		print("[FLIGHT_BENCHMARK_START] duration_s=60 fighters=",mannequins.size()," position=",player.actor.global_position)
	if flight_benchmark_running:
		if not DisplayServer.window_is_focused(): flight_benchmark_unfocused_frames += 1
		if int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) < 200: flight_benchmark_low_draw_frames += 1
		var elapsed: float = float(Time.get_ticks_usec()-flight_benchmark_start_usec)/1000000.0
		if elapsed >= 60.0:
			player.benchmark_flight_active = false
			player.benchmark_flight_axis = Vector2.ZERO
			player.benchmark_flight_direction = Vector3.ZERO
			print("[FLIGHT_BENCHMARK_END] elapsed_s=%.2f position=%s displacement_m=%.2f fighters=%d living=%d unfocused_frames=%d low_draw_frames=%d valid_foreground=%s" % [
				elapsed,str(player.actor.global_position),player.actor.global_position.distance_to(flight_benchmark_origin),mannequins.size(),active_war_fighters.size(),flight_benchmark_unfocused_frames,flight_benchmark_low_draw_frames,str(flight_benchmark_unfocused_frames == 0)
			])
			flight_benchmark_running = false
			flight_benchmark_requested = false
			get_tree().quit(0)
		else:
			# A bounded central figure-eight. Steer through the *actual*
			# player controller instead of teleporting between samples.
			# Slow near each waypoint to avoid high-speed overshoot.
			var route_phase: float = elapsed * 0.19
			var destination := Vector3(11.0 * sin(route_phase),8.5 + 2.0 * sin(elapsed * 0.32),11.0 * sin(route_phase * 2.0))
			var to_destination: Vector3 = destination - player.actor.global_position
			var flat_distance: float = Vector2(to_destination.x,to_destination.z).length()
			var desired_direction: Vector3 = to_destination.normalized() if to_destination.length_squared() > 0.001 else Vector3.FORWARD
			# Movement uses the genuine physics controller, but view stays
			# inward over the center combat area, not pointed at a wall.
			player.orbit = atan2(player.actor.global_position.x,player.actor.global_position.z)
			player.elevation = -0.16
			var speed_scale: float = clampf(to_destination.length() / 6.0,0.0,0.55)
			player.benchmark_flight_direction = desired_direction * speed_scale
			player.benchmark_flight_axis = Vector2(0.0,speed_scale)
			# Keep speed bounded on a tight course: no exponential sprint boost.
			player.flight_acceleration_time = 0.0
			var whole_second: int = int(elapsed)
			if whole_second % 2 == 0 and whole_second != flight_benchmark_last_log_second:
				flight_benchmark_last_log_second = whole_second
				print("[FLIGHT_BENCHMARK_POSITION] t_s=",whole_second," xyz=",player.actor.global_position," velocity=",player.actor.velocity," living=",active_war_fighters.size()," fps=",Engine.get_frames_per_second())
	status_refresh_clock -= dt
	if status_refresh_clock<=0.0:
		status_refresh_clock = 0.15
		refresh_visible_status_labels()
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
	# Read each engine monitor once per render frame. These are native
	# monitor queries, and duplicate calls add overhead under 70-fighter load.
	var monitored_cpu_ms: float = Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
	var monitored_physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
	profile_cpu_ms.append(monitored_cpu_ms)
	profile_physics_ms.append(monitored_physics_ms)
	profile_window_frames += 1
	profile_frame_fps_sum += float(Engine.get_frames_per_second())
	if DisplayServer.window_is_focused():
		profile_focus_frames += 1
		profile_focus_fps_sum += float(Engine.get_frames_per_second())
	else:
		profile_unfocused_frames += 1
		profile_unfocused_fps_sum += float(Engine.get_frames_per_second())
	profile_frame_cpu_sum += monitored_cpu_ms
	profile_frame_physics_sum += monitored_physics_ms
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
	battle_panel = panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12,66)
	panel.custom_minimum_size = Vector2(310,280)
	panel.modulate.a = 0.88
	panel.visible = false # Only while Tab is HELD.
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

func record_aoe_event(fighters_hit: int, regions_hit: int) -> void:
	aoe_events_window += 1
	aoe_fighters_window += fighters_hit
	aoe_regions_window += regions_hit

func record_player_auto_attack(target_name: String) -> void:
	player_auto_attacks_window += 1

func record_player_auto_target_change(target_name: String) -> void:
	player_auto_target_changes_window += 1

func refresh_battle_feed() -> void:
	if not battle_feed_dirty or battle_feed == null: return
	battle_feed_dirty = false
	battle_feed.text = "TOTAL DAMAGE\n"
	var leaders: Array = damage_totals.keys()
	leaders.sort_custom(func(a,b): return float(damage_totals[a]) > float(damage_totals[b]))
	for i in range(mini(3,leaders.size())):
		battle_feed.text += "%s: %d\n" % [leaders[i],int(damage_totals[leaders[i]])]
	battle_feed.text += "\nRECENT HITS\n" + "\n".join(battle_hits)

func record_battle_hit(attacker: String, victim: String, region: String, amount: float, _health: float) -> void:
	var source: String = attacker if attacker != "" else "UNKNOWN"
	damage_totals[source] = float(damage_totals.get(source,0.0))+amount
	battle_hits.push_front("%s → %s  %s  -%d" % [source,victim,region.to_upper(),int(round(amount))])
	if battle_hits.size() > 11: battle_hits.resize(11)
	battle_feed_dirty = true

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
func attach_status_label(fighter: Node) -> void:
	var status := Label3D.new()
	status.name = "StatusEffects"
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.font_size = 36
	status.pixel_size = 0.006
	status.position.y = 2.87
	status.no_depth_test = false
	status.outline_size = 8
	status.modulate = Color("fff6ce")
	status.visible = false
	fighter.actor.add_child(status)
	fighter.status_label = status

func refresh_visible_status_labels() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.camera): return
	var watcher: Camera3D = player.camera
	var rect: Rect2 = get_viewport().get_visible_rect()
	var roster: Array = mannequins.duplicate()
	roster.append(player)
	for fighter in roster:
		if not is_instance_valid(fighter): continue
		var status: Label3D = fighter.status_label
		if status == null or not is_instance_valid(status): continue
		var at: Vector3 = fighter.actor.global_position+Vector3.UP*2.8
		var distance: float = at.distance_to(watcher.global_position)
		if distance>38.0 or watcher.is_position_behind(at):
			status.visible = false
			continue
		var screen: Vector2 = watcher.unproject_position(at)
		if not rect.has_point(screen):
			status.visible = false
			continue
		var effects: String = fighter.status_description()
		status.visible = effects!=""
		if status.visible: status.text = effects

func make_boundary():
	# Compact 100 x 100 metre pursuit cage: opaque walls and a low roof.
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
	var side: float = arena_half_extent*2.0
	var wall_height: float = 42.0
	var half_height: float = wall_height*0.5
	var surfaces := [
		{"name":"NorthWall","size":Vector3(side,wall_height,1.5),"center":Vector3(0,half_height,-arena_half_extent)},
		{"name":"SouthWall","size":Vector3(side,wall_height,1.5),"center":Vector3(0,half_height,arena_half_extent)},
		{"name":"EastWall","size":Vector3(1.5,wall_height,side),"center":Vector3(arena_half_extent,half_height,0)},
		{"name":"WestWall","size":Vector3(1.5,wall_height,side),"center":Vector3(-arena_half_extent,half_height,0)},
		{"name":"Ceiling","size":Vector3(side,1.5,side),"center":Vector3(0,wall_height,0)}
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
	lamp.position = Vector3(0,30,0)
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
	# Bucket-size statistics need sampling, not two dictionary copies each tick.
	profile_grid_stat_clock += 1
	if profile_grid_stat_clock >= 30:
		profile_grid_stat_clock = 0
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
		elif bool(current_level.get("battle_royale_drop",false)) and not fighter.actor.is_on_floor() and fighter.actor.global_position.y > 0.1:
			# Drop phase uses normal physics and ignores combat/flight AI until impact.
			fighter.flight_enabled = false
			fighter.actor.velocity.x = 0.0
			fighter.actor.velocity.z = 0.0
			fighter.actor.velocity.y = maxf(fighter.actor.velocity.y - 18.0 * dt,-42.0)
			fighter.actor.move_and_slide()
		elif not bool(fighter.get_meta("test_dummy",false)):
			fighter.war_simulation_tick(dt)
	record_performance_sample("war_simulation_all",Time.get_ticks_usec()-sim_start)
	# Time the complete roster update, not just sampled per-fighter calls.
	record_performance_sample("war_scheduler_total",Time.get_ticks_usec()-tick_start)

func _physics_process(_dt):
	if player == null: return
	update_royale_loot()
	tick_war_fighters(_dt)
	player_label.position.y = player.crouch.capsule.height+0.3
	if stress_no_deaths or announced_winner or queued_fighter_spawns>0: return
	# A solo survivor wins the free-for-all, including if BLACK was eliminated.
	if player.team_id == "":
		var survivors: Array = []
		if not player.combat_dead: survivors.append(player.name)
		for rival in mannequins:
			if is_instance_valid(rival) and not rival.combat_dead: survivors.append(rival.name)
		if bool(current_level.get("battle_royale_drop",false)) and survivors.size() <= 1 and mannequins.size() >= int(current_level.get("enemy_count",0)):
			announced_winner = true
			var name_winner: String = survivors[0] if survivors.size() == 1 else "NOBODY"
			print("[BATTLE_ROYALE_WINNER] ",name_winner)
			var victory := Label3D.new()
			victory.text = name_winner + " WINS"
			victory.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			victory.font_size = 80
			victory.position = Vector3(0,12,0)
			add_child(victory)
		return
	if flight_benchmark_requested: return
	var blue_alive: int = 0 if player.combat_dead else 1
	var red_alive: int = 0
	for fighter in mannequins:
		if not is_instance_valid(fighter) or fighter.combat_dead: continue
		if fighter.team_id=="blue": blue_alive += 1
		elif fighter.team_id=="red": red_alive += 1
	if blue_alive==0 or red_alive==0:
		announced_winner = true
		var winner: String = "BLUE" if blue_alive>0 else "RED"
		print("[TEAM_WINNER] ",winner)
		var banner := Label3D.new()
		banner.text = winner+" WINS"
		winner_banner = banner
		banner.font_size = 85
		banner.pixel_size = 0.009
		banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		banner.modulate = TEAM_BLUE if winner=="BLUE" else TEAM_RED
		banner.position = Vector3(0,6,0)
		add_child(banner)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:

		if event.keycode==KEY_0:
			spawn_more_fighters()
		# Tab is hold-to-view the war/damage feed; never switch the camera.

func create_royale_loot() -> void:
	var all_fighters: Array = [player]
	all_fighters.append_array(mannequins)
	for i in range(all_fighters.size()+5):
		var fighter: Node = all_fighters[i % all_fighters.size()]
		var boots: bool = i >= all_fighters.size() and i % 2 == 0
		var spell: String = "" if boots else ROYALE_SPELLS[i % ROYALE_SPELLS.size()]
		var target: Vector3 = fighter.spawn_point
		target.y = 0.16
		var display := Node3D.new()
		display.name = "LootBoots_%d" % i if boots else "LootRing_%s_%d" % [spell,i]
		display.position = target+Vector3(3.0 if i % 2 == 0 else -3.0,0,3.0)
		add_child(display)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.24
		torus.outer_radius = 0.39
		torus.rings = 20
		torus.ring_segments = 8
		var mesh := MeshInstance3D.new()
		mesh.mesh = torus
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color("ebbf43")
		gold.metallic = 0.65
		mesh.material_override = gold
		display.add_child(mesh)
		var light := OmniLight3D.new()
		light.light_color = Color("ffd16b")
		light.light_energy = 0.8
		light.omni_range = 3.0
		display.add_child(light)
		var label := Label3D.new()
		label.text = "SPEED BOOTS  [E]" if boots else spell.to_upper()+" RING  [E]"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = 1.7
		label.font_size = 42
		display.add_child(label)
		royale_loot.append({"spell":spell,"boots":boots,"node":display,"claimed":false})
		print("[ROYALE_RING] spell=",spell," at=",display.position)

func update_royale_loot() -> void:
	if royale_loot.is_empty(): return
	var combatants: Array = [player]
	combatants.append_array(mannequins)
	for entry in royale_loot:
		if entry["claimed"]: continue
		var item: Node3D = entry["node"]
		if not is_instance_valid(item): continue
		var closest: Node = null
		var nearest: float = 2.8
		for fighter in combatants:
			if not is_instance_valid(fighter) or fighter.combat_dead or not is_instance_valid(fighter.actor): continue
			if fighter.actor.global_position.y > 2.5: continue
			var d: float = fighter.actor.global_position.distance_to(item.global_position)
			if d < nearest:
				nearest = d
				closest = fighter
		if closest == null: continue
		if closest == player and not Input.is_physical_key_pressed(KEY_E): continue
		var spell: String = entry["spell"]
		if bool(entry.get("boots",false)):
			closest.set_meta("speed_boots",true)
		else:
			if not spell in closest.equipped_spells:
				closest.equipped_spells.append(spell)
				if closest.has_method("refresh_ring_inventory"): closest.refresh_ring_inventory()
		entry["claimed"] = true
		item.queue_free()
		print("[ROYALE_PICKUP] fighter=",closest.name," item=",("speed_boots" if bool(entry.get("boots",false)) else spell))

func spawn_ground_ring(spell: String, location: Vector3) -> void:
	var display := Node3D.new()
	display.name = "GroundRing_" + spell
	display.position = location
	add_child(display)
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.21
	torus.outer_radius = 0.34
	torus.rings = 24
	torus.ring_segments = 8
	mesh.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffcd43")
	mat.metallic = 0.75
	mesh.material_override = mat
	display.add_child(mesh)
	var label := Label3D.new()
	label.text = spell.to_upper()+" RING [E]"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.0
	label.font_size = 36
	display.add_child(label)
	royale_loot.append({"spell":spell,"boots":false,"node":display,"claimed":false})

func create_test_spell_loot() -> void:
	var spells: Array[String] = ["fire","frost","homing","gravity","ricochet","grounding","bloom","tempest","venom","flight"]
	for i in range(spells.size()):
		var a: float = float(i)*TAU/float(spells.size())
		var origin: Vector3 = player.spawn_point + Vector3(cos(a)*3.5,0.17,sin(a)*3.5)
		spawn_ground_ring(spells[i],origin)
	print("[DEV_RINGS] placed=",spells.size()," around BLACK")

func drop_inventory_ring(spell: String) -> void:
	if player == null or not spell in player.equipped_spells: return
	player.equipped_spells.erase(spell)
	var forward: Vector3 = -player.actor.global_transform.basis.z
	var location: Vector3 = player.actor.global_position + forward*2.0
	location.y = 0.17
	spawn_ground_ring(spell,location)
	player.refresh_ring_inventory()
	print("[RING_DROPPED] spell=",spell," at=",location)
