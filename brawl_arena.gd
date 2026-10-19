extends "res://showcase.gd"
# Two mortal autonomous duelists; immortal BLACK is strictly a spectator.
# Uses the production WalkingLab AI, hit-region damage, spells, and flight.
const TEAMS: Array[String] = ["red","gold"]
const COLORS: Array[Color] = [Color("ff4556"),Color("ffc247")]
var fight_roster: Array = []
var fight_hud: Label
var elapsed_round: float = 0.0
var score_clock: float = 0.0
var report_clock: float = 0.0
var fight_over: bool = false
var combat_tools: Dictionary = {}
var round_victor: String = ""

func _ready() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 60
	get_viewport().scaling_3d_scale = 0.76
	spawn_rng.randomize()
	current_level = {
		"number":0,"name":"autonomous 1v1 spectator arena",
		"biome":"arena","battle_royale_drop":false,
		"player_spells":["fire","frost","homing","gravity","ricochet","grounding","bloom","tempest","venom","flight"],
		"enemy_spells":["fire","frost","homing","gravity","ricochet","grounding","bloom","tempest","venom","flight"]
	}
	arena_half_extent = 28.0
	battle_fireball_speed = 1.35
	battle_fireball_size = 0.72
	for entry in [["move_forward",KEY_W],["move_back",KEY_S],["move_left",KEY_A],["move_right",KEY_D],["sprint",KEY_ALT],["walk",KEY_CTRL]]:
		if not InputMap.has_action(entry[0]): InputMap.add_action(entry[0])
		var e: InputEventKey = InputEventKey.new()
		e.keycode = entry[1]
		if not InputMap.action_has_event(entry[0],e): InputMap.action_add_event(entry[0],e)
	_build_flat_stage()
	_build_sealed_arena()
	create_battle_feed()
	# Game-real collision world plus original authored stage texture.
	player = preload("res://walking.gd").new()
	player.name = "PlayerMan"
	player.player_controlled = true
	player.actor_only = true
	player.auto_war_combat = false
	player.ai_mode = ""
	player.team_id = "spectator"
	player.set_meta("brawl_spectator",true)
	player.spawn_point = Vector3(0,0.05,18.0)
	player.character_tint = Color(0.12,0.14,0.17)
	player.demo_immortal = true
	player.set_meta("brawl_flight_limit",true)
	player.infinite_mana = true
	player.ignore_spell_cooldowns = true
	var black_spells: Array[String] = ["flight"]
	player.equipped_spells = black_spells
	add_child(player)
	player.camera.current = true
	_add_team_label(player,"BLACK / IMMORTAL OBSERVER",Color("a9afb7"))
	attach_status_label(player)
	# No spectator weapon: NPCs are the combatants, not BLACK.
	var formations: Array[Dictionary] = [
		{"team":0,"position":Vector3(-5.0,0.05,-1.0),"weapon":"sword","acrobat":false},
		{"team":1,"position":Vector3(5.0,0.05,1.0),"weapon":"dagger","acrobat":true}
	]
	for i in range(formations.size()):
		var setup: Dictionary = formations[i]
		var team_index: int = int(setup["team"])
		var fighter = preload("res://walking.gd").new()
		fighter.name = "%s_%02d" % [TEAMS[team_index].to_upper(),i+1]
		fighter.autonomous_only = true
		fighter.actor_only = true
		fighter.ai_abilities = true
		fighter.team_battle_ai = true
		fighter.animation_test_mode = "war"
		fighter.team_id = TEAMS[team_index]
		fighter.spawn_point = setup["position"]
		fighter.demo_immortal = false
		fighter.set_meta("brawl_flight_limit",true)
		fighter.character_tint = COLORS[team_index].lerp(Color.WHITE,0.4)
		var fighter_spells: Array[String] = []
		fighter_spells.assign(current_level["enemy_spells"])
		fighter.equipped_spells = fighter_spells
		fighter.set_meta("brawl_melee",true)
		add_child(fighter)
		_add_team_label(fighter,"%s  #%d" % [TEAMS[team_index].to_upper(),i+1],COLORS[team_index])
		attach_status_label(fighter)
		var anim_puppet = preload("res://brawl_visual.gd").new()
		anim_puppet.name = "BrawlVisual"
		anim_puppet.pilot = fighter
		anim_puppet.source_file = "res://assets/showcase/aether-02.glb" if bool(setup["acrobat"]) else "res://assets/showcase/UAL2_Standard.glb"
		fighter.actor.add_child(anim_puppet)
		_add_weapon(fighter,String(setup["weapon"]),anim_puppet)
		mannequins.append(fighter)
		fight_roster.append(fighter)
		# One arena-owned simulation clock; do not double-tick fighters.
		fighter.set_physics_process(false)
	_create_fight_hud()
	_update_fight_hud()
	print("[BRAWL_START] mode=NPC_1V1 npc_count=",mannequins.size()," spectator=BLACK excluded_from_targeting=true")


func _build_sealed_arena() -> void:
	# One continuous collision perimeter with explicit finite thickness,
	# sufficient height to contain ALL flight and jumps, and a solid roof.
	# No invisible teleport boundaries.
	const WALL_HEIGHT: float = 26.0
	const WALL_THICKNESS: float = 1.8
	var wall_body: StaticBody3D = StaticBody3D.new()
	wall_body.name = "SealedArenaWallsAndCeiling"
	add_child(wall_body)
	var side: float = arena_half_extent * 2.0
	var barriers: Array[Dictionary] = [
		{"name":"North","size":Vector3(side+WALL_THICKNESS*2,WALL_HEIGHT,WALL_THICKNESS),"at":Vector3(0,WALL_HEIGHT*0.5,-arena_half_extent)},
		{"name":"South","size":Vector3(side+WALL_THICKNESS*2,WALL_HEIGHT,WALL_THICKNESS),"at":Vector3(0,WALL_HEIGHT*0.5,arena_half_extent)},
		{"name":"West","size":Vector3(WALL_THICKNESS,WALL_HEIGHT,side),"at":Vector3(-arena_half_extent,WALL_HEIGHT*0.5,0)},
		{"name":"East","size":Vector3(WALL_THICKNESS,WALL_HEIGHT,side),"at":Vector3(arena_half_extent,WALL_HEIGHT*0.5,0)},
		{"name":"Ceiling","size":Vector3(side+WALL_THICKNESS*2,1.4,side+WALL_THICKNESS*2),"at":Vector3(0,WALL_HEIGHT,0)}
	]
	var wall_material: StandardMaterial3D = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.20,0.25,0.33)
	wall_material.roughness = 0.88
	for part in barriers:
		var shape: CollisionShape3D = CollisionShape3D.new()
		var geometry: BoxShape3D = BoxShape3D.new()
		geometry.size = part["size"]
		shape.shape = geometry
		shape.position = part["at"]
		wall_body.add_child(shape)
		var surface: MeshInstance3D = MeshInstance3D.new()
		surface.name = String(part["name"]) + "Wall"
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = part["size"]
		surface.mesh = mesh
		surface.position = part["at"]
		surface.material_override = wall_material
		wall_body.add_child(surface)
	print("[BRAWL_BARRIERS] side=",side,"m height=",WALL_HEIGHT,"m roof=SOLID collision_shapes=",barriers.size())

func _add_weapon(fighter, weapon_kind: String, driver) -> void:
	var gear = preload("res://brawl_weapon.gd").new()
	gear.name = "BrawlGear"
	gear.pilot = fighter
	gear.arena = self
	gear.kind = weapon_kind
	gear.visual_driver = driver
	fighter.add_child(gear)
	combat_tools[fighter.name] = gear

func _add_team_label(fighter,title: String,color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.text = title
	label.modulate = color
	label.font_size = 44
	label.pixel_size = 0.0045
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0,2.32,0)
	fighter.actor.add_child(label)

func _create_fight_hud() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	ui.name = "SpectatorDuelUI"
	add_child(ui)
	var root: PanelContainer = PanelContainer.new()
	root.position = Vector2(10,10)
	ui.add_child(root)
	var stack: VBoxContainer = VBoxContainer.new()
	root.add_child(stack)
	var headline: Label = Label.new()
	headline.text = "THE GAME  |  NPC DUEL  |  BLACK OBSERVING"
	headline.add_theme_font_size_override("font_size",17)
	stack.add_child(headline)
	var guide: Label = Label.new()
	guide.text = "BLACK: WASD roam | MIDDLE DRAG camera | V fly (5s max) | F5 restart | NPCs fight one another"
	guide.add_theme_font_size_override("font_size",12)
	stack.add_child(guide)
	fight_hud = Label.new()
	fight_hud.add_theme_font_size_override("font_size",15)
	stack.add_child(fight_hud)

func _physics_process(dt: float) -> void:
	if not is_instance_valid(player): return
	tick_war_fighters(dt)
	# Only the two mortal duelists determine the winner.
	if fight_over: return
	for fighter in mannequins:
		if is_instance_valid(fighter) and fighter.combat_dead:
			for rival in mannequins:
				if is_instance_valid(rival) and not rival.combat_dead:
					fight_over = true
					round_victor = rival.name + " WINS"
					print("[BRAWL_COMPLETE] ",round_victor," elapsed=",snappedf(elapsed_round,0.1))
					break
			break

func _process(dt: float) -> void:
	elapsed_round += dt
	score_clock -= dt
	if score_clock <= 0.0:
		score_clock = 0.2
		_update_fight_hud()
		refresh_visible_status_labels()
		report_clock += 0.2
		if report_clock >= 5.0:
			report_clock = 0.0
			var hit_count: int = 0
			var swings: int = 0
			for gear in combat_tools.values():
				if is_instance_valid(gear):
					hit_count += gear.total_hits
					swings += gear.combo_number
			print("[BRAWL_METRICS] fps=",Engine.get_frames_per_second()," time=",snappedf(elapsed_round,0.1)," active=",active_war_fighters.size()," hits=",hit_count," swings=",swings," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	# Retain legacy combat feed without the mass-benchmark profiler.
	battle_feed_refresh_clock -= dt
	if battle_feed_refresh_clock <= 0.0:
		battle_feed_refresh_clock = 0.2
		refresh_battle_feed()

func _update_fight_hud() -> void:
	if fight_hud == null: return
	var parts: Array[String] = []
	for i in range(TEAMS.size()):
		var count: int = 0
		for fighter in mannequins:
			if is_instance_valid(fighter) and not fighter.combat_dead and fighter.team_id == TEAMS[i]:
				count += 1
		parts.append("%s %d/1" % [TEAMS[i].to_upper(),count])
	fight_hud.text = "  |  ".join(parts)+"\nFPS %d  |  elapsed %.0fs  |  BLACK SPECTATOR  |  flight %.1f/5.0s%s" % [Engine.get_frames_per_second(),elapsed_round,player.brawl_flight_elapsed if is_instance_valid(player) else 0.0,"\n"+round_victor if fight_over else ""]

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	var k: InputEventKey = event as InputEventKey
	if not k.pressed or k.echo: return
	if not is_instance_valid(player): return
	if k.keycode == KEY_F5: get_tree().reload_current_scene()

func _unhandled_input(_event: InputEvent) -> void:
	# Let walking.gd keep all of BLACK's original camera, movement, and spells.
	pass
