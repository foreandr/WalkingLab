extends Node
# Motion only. All fire appearance comes from the original third-party VFX.
var travel_direction: Vector3 = Vector3.FORWARD
var travel_speed: float = 3.0
var battle_base_speed: float = 0.0
var owner_rid: RID
var attacker_name: String = ""
var blast_width: float = 1.0
# Player spells share the proven swept projectile / imported VFX, but each
# supplies an independently tuned impact and status effect.
var spell_type: String = "fire"
var spell_color: Color = Color("ff9b4f")
const LIFETIME: float = 25.0
var lived: float = 0.0
var profile_tick: int = 0
var cached_ray: PhysicsRayQueryParameters3D
var cached_sphere: SphereShape3D
var cached_sphere_query: PhysicsShapeQueryParameters3D
var cached_spectator_rid: RID
var cached_excludes: Array[RID] = []

func _physics_process(delta: float) -> void:
	profile_tick += 1
	var sampled: bool = (profile_tick & 31) == 0
	var profile_start: int = Time.get_ticks_usec() if sampled else 0
	var projectile: Node3D = get_parent() as Node3D
	if projectile == null: return
	var effective_speed: float = travel_speed
	if battle_base_speed <= 0.0:
		match spell_type:
			"arc": effective_speed *= 1.7
			"gravity": effective_speed *= 0.7
			"leech": effective_speed *= 1.3
			"comet": effective_speed *= 1.2
			"bloom": effective_speed *= 0.8
			"tempest": effective_speed *= 1.4
			"venom": effective_speed *= 1.1
	if battle_base_speed > 0.0:
		var scene: Node = projectile.get_tree().current_scene
		if scene != null: effective_speed = battle_base_speed * float(scene.get("battle_fireball_speed"))
	var displacement: Vector3 = travel_direction * effective_speed * delta
	var space: PhysicsDirectSpaceState3D = projectile.get_world_3d().direct_space_state
	# Reuse physics query resources for the lifetime of each projectile.
	# Avoid allocating a new ray, exclusion array, and (for wide shots)
	# sphere resource on every physics tick.
	if cached_ray == null:
		cached_ray = PhysicsRayQueryParameters3D.new()
		# Never hit the caster, but enemy spells CAN hit the human player.
		if owner_rid.is_valid(): cached_excludes.append(owner_rid)
		cached_ray.exclude = cached_excludes
	cached_ray.from = projectile.global_position
	cached_ray.to = projectile.global_position + displacement
	var hit: Dictionary = space.intersect_ray(cached_ray)
	if not hit.is_empty():
		explode(projectile,hit["position"])
		projectile.queue_free()
		return
	# For enlarged fireballs, the visible body of the projectile must be
	# collidable too. Query spheres along this physics step, preserving the
	# swept center ray above for narrow/high-speed shots.
	if blast_width > 1.0:
		var width_radius: float = 0.45 * blast_width
		if cached_sphere == null:
			cached_sphere = SphereShape3D.new()
			cached_sphere_query = PhysicsShapeQueryParameters3D.new()
			cached_sphere_query.shape = cached_sphere
			cached_sphere_query.exclude = cached_excludes
		cached_sphere.radius = width_radius
		var segments: int = mini(6,maxi(1,int(ceil(displacement.length() / maxf(width_radius,0.5)))))
		for segment in range(segments):
			var probe: Vector3 = projectile.global_position + displacement * (float(segment + 1) / float(segments))
			cached_sphere_query.transform = Transform3D(Basis.IDENTITY,probe)
			var overlaps: Array[Dictionary] = space.intersect_shape(cached_sphere_query,1)
			if not overlaps.is_empty():
				explode(projectile,probe)
				projectile.queue_free()
				return
	if sampled:
		var scene_for_profile: Node = projectile.get_tree().current_scene
		if scene_for_profile != null and scene_for_profile.has_method("record_performance_sample"):
			scene_for_profile.record_performance_sample("projectile_ray",Time.get_ticks_usec()-profile_start)
	projectile.global_position += displacement
	lived += delta
	if lived >= LIFETIME:
		projectile.queue_free()

func explode(projectile: Node3D, position: Vector3) -> void:
	var scene: Node = projectile.get_tree().current_scene
	# The source effect is already 3x. Explosion is 5x that size.
	var impact := Node3D.new()
	impact.name = spell_type.capitalize()+"Impact"
	scene.add_child(impact)
	impact.global_position = position
	var source: GPUParticles3D = null
	for child in projectile.get_children():
		if child is GPUParticles3D:
			source = child
			break
	if source != null:
		var burst: GPUParticles3D = source.duplicate() as GPUParticles3D
		impact.add_child(burst)
		burst.scale = source.scale * (6.0 if spell_type=="gravity" else 5.0)
		burst.amount = mini(4,maxi(2,int(burst.amount / 2)))
		burst.fixed_fps = 30
		burst.one_shot = true
		burst.emitting = true
		burst.restart()
	if attacker_name == "PlayerMan":
		var flash := OmniLight3D.new()
		flash.light_color = spell_color
		flash.light_energy = 2.0
		flash.omni_range = 6.0
		impact.add_child(flash)
	var cleanup := impact.create_tween()
	cleanup.tween_interval(0.6)
	cleanup.tween_callback(impact.queue_free)
	# The blast intersects each anatomical region independently. A large
	# fireball can hit multiple body pools on one fighter in one explosion.
	var base_radius: float = 5.0
	var impact_damage: float = 32.0
	match spell_type:
		"fire":
			base_radius = 4.0
			impact_damage = 30.0 # + burning damage over time
		"frost":
			base_radius = 5.5
			impact_damage = 18.0 # + heavy movement slow
		"arc":
			base_radius = 2.8
			impact_damage = 26.0 # + lightning jumps to further targets
		"gravity":
			base_radius = 6.5
			impact_damage = 10.0 # + physical pull toward the blast
		"leech":
			base_radius = 4.0
			impact_damage = 24.0 # + health/mana siphon for the caster
		"comet":
			base_radius = 2.8
			impact_damage = 70.0 # Focused, heavy impact
		"bloom":
			base_radius = 6.0
			impact_damage = 12.0 # Caster regenerates for six seconds
		"tempest":
			base_radius = 6.4
			impact_damage = 16.0 # Physically throws targets away from impact
		"venom":
			base_radius = 4.4
			impact_damage = 10.0 # Long-lasting poison damage
	var blast_radius: float = base_radius * blast_width
	var affected_fighters: int = 0
	var struck: Dictionary = {}
	var arc_candidates: Array = []
	var affected_regions: int = 0
	# Arena spatial hash avoids testing the entire 60-fighter roster on
	# every impact. Fall back to the scene group outside arena mode.
	var query_radius: float = maxf(blast_radius,11.0 if spell_type == "arc" else 0.0)
	var candidates: Array = scene.war_nearby_fighters(position,maxi(1,int(ceil((query_radius + 3.0) / scene.WAR_GRID_CELL)))) if scene != null and scene.has_method("war_nearby_fighters") else projectile.get_tree().get_nodes_in_group("combat_fighters")
	if scene != null and attacker_name != "PlayerMan":
		# Player is controlled outside the war scheduler's mannequin roster.
		var player_target: Node = scene.get_node_or_null("PlayerMan")
		if is_instance_valid(player_target): candidates.append(player_target)
	for fighter in candidates:
		if not is_instance_valid(fighter): continue
		if fighter.player_controlled and attacker_name=="PlayerMan": continue
		var body: CharacterBody3D = fighter.actor as CharacterBody3D
		if body == null or body.get_rid() == owner_rid: continue
		var damage: Node = fighter.get_node_or_null("DamageSystem")
		if damage == null or damage.dead: continue
		# Arc looks farther for chain targets, without damaging them until the
		# direct blast has resolved. Every projectile keeps the spatial broadphase.
		var radius_sq: float = body.global_position.distance_squared_to(position)
		if spell_type == "arc" and radius_sq <= 121.0: arc_candidates.append(fighter)
		if radius_sq > pow(blast_radius + 3.0,2.0): continue
		var hit_regions: Array[String] = []
		for region in damage.REGIONS:
			var bone_point: Vector3 = damage.bone_position(region)
			var region_radius: float = 0.48 if region == "torso" else (0.32 if region == "head" else 0.34)
			if bone_point.distance_squared_to(position) <= pow(blast_radius + region_radius,2.0):
				hit_regions.append(region)
		if hit_regions.is_empty(): continue
		affected_fighters += 1
		struck[body.get_instance_id()] = true
		damage.receive_aoe_regions(hit_regions,impact_damage,attacker_name)
		if fighter.has_method("apply_spell_status"): fighter.apply_spell_status(spell_type,position)
		affected_regions += hit_regions.size()
	if spell_type == "arc":
		# Jump to up to three extra distinct enemies outside the direct blast.
		arc_candidates.sort_custom(func(a,b): return a.actor.global_position.distance_squared_to(position)<b.actor.global_position.distance_squared_to(position))
		var chains: int = 0
		for candidate in arc_candidates:
			if chains>=3: break
			if not is_instance_valid(candidate) or candidate.combat_dead: continue
			var target_body: CharacterBody3D = candidate.actor
			if struck.has(target_body.get_instance_id()): continue
			var target_damage: Node = candidate.get_node_or_null("DamageSystem")
			if target_damage == null or target_damage.dead: continue
			target_damage.receive_region_hit("torso",target_damage.bone_position("torso"),18.0,attacker_name)
			struck[target_body.get_instance_id()] = true
			chains += 1
			affected_fighters += 1
			affected_regions += 1
	if spell_type == "leech" and attacker_name == "PlayerMan" and affected_fighters>0:
		var caster: Node = scene.get_node_or_null("PlayerMan")
		if caster != null and caster.has_method("heal_from_spell"):
			caster.heal_from_spell(7.0*float(affected_fighters))
	if scene != null and scene.has_method("record_aoe_event"):
		scene.record_aoe_event(affected_fighters,affected_regions)
	elif scene == null or not bool(scene.get("stress_no_deaths")):
		print("[AOE_REGIONS] fighters=",affected_fighters," body_regions=",affected_regions," radius=",blast_radius)
