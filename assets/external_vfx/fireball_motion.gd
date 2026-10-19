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
# The flame-wave and target streams use the SAME impact radius as damage.
# Impact applies to each target when its animated fire reaches that target.
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

func launch_visible_aoe_stream(impact: Node3D, source: GPUParticles3D, origin: Vector3, target_point: Vector3, victim: Node, hit_regions: Array[String], damage_amount: float) -> void:
	# Copy the imported flame effect, not a generated mesh or fake hitbox.
	# Emission follows the actual radial route; damage arrives with the fire.
	if source == null or victim == null or not is_instance_valid(victim): return
	var ember := source.duplicate() as GPUParticles3D
	impact.add_child(ember)
	ember.global_position = origin
	ember.local_coords = false
	ember.scale = Vector3.ONE*0.74
	ember.amount = 22
	ember.lifetime = 0.30
	ember.one_shot = false
	ember.fixed_fps = 30
	ember.emitting = true
	ember.restart()
	var distance_to_hit: float = origin.distance_to(target_point)
	var travel_time: float = clampf(distance_to_hit/15.0,0.12,0.74)
	# Build the endpoint effect while the projectile is still valid. Delayed
	# callbacks belong to surviving impact/damage nodes, NOT this soon-freed
	# projectile's script instance.
	var endpoint := ember.duplicate() as GPUParticles3D
	impact.add_child(endpoint)
	endpoint.global_position = target_point
	endpoint.local_coords = false
	endpoint.scale = Vector3.ONE*0.92
	endpoint.amount = 28
	endpoint.lifetime = 0.48
	endpoint.one_shot = true
	endpoint.explosiveness = 1.0
	endpoint.emitting = false
	var damage: Node = victim.get_node_or_null("DamageSystem")
	var trajectory := impact.create_tween()
	trajectory.tween_property(ember,"global_position",target_point,travel_time).set_trans(Tween.TRANS_LINEAR)
	trajectory.tween_callback(Callable(ember,"set_emitting").bind(false))
	trajectory.tween_callback(Callable(endpoint,"set_emitting").bind(true))
	trajectory.tween_callback(Callable(endpoint,"restart"))
	if damage != null:
		trajectory.tween_callback(Callable(damage,"receive_aoe_regions").bind(hit_regions.duplicate(),damage_amount,attacker_name))
	if victim.has_method("apply_spell_status"):
		trajectory.tween_callback(Callable(victim,"apply_spell_status").bind(spell_type,origin))

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
	# Keep the imported VFX. A physically radial emitter now reaches the
	# outer damage boundary instead of flashing a few pixels at the origin.
	# Its radius and velocity are configured below after blast_radius is known.
	if attacker_name == "PlayerMan":
		var flash := OmniLight3D.new()
		flash.light_color = spell_color
		flash.light_energy = 2.0
		flash.omni_range = 6.0
		impact.add_child(flash)
	var cleanup := impact.create_tween()
	cleanup.tween_interval(1.65)
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
	if source != null:
		var wave := source.duplicate() as GPUParticles3D
		impact.add_child(wave)
		wave.global_position = position
		wave.scale = Vector3.ONE*0.75
		wave.local_coords = false
		wave.one_shot = true
		wave.explosiveness = 1.0
		wave.lifetime = 0.75
		wave.amount = clampi(ceili(blast_radius*32.0),70,280)
		wave.fixed_fps = 30
		var wave_material: ParticleProcessMaterial = wave.process_material.duplicate(true) as ParticleProcessMaterial
		if wave_material != null:
			wave_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			wave_material.emission_sphere_radius = 0.28
			wave_material.gravity = Vector3.ZERO
			wave_material.direction = Vector3.UP
			wave_material.spread = 180.0
			wave_material.initial_velocity_min = blast_radius/0.61
			wave_material.initial_velocity_max = blast_radius/0.48
			wave.process_material = wave_material
		wave.emitting = true
		wave.restart()
	var affected_fighters: int = 0
	var struck: Dictionary = {}
	var arc_candidates: Array = []
	var affected_regions: int = 0
	# Arena spatial hash avoids testing the entire 60-fighter roster on
	# every impact. Fall back to the scene group outside arena mode.
	var query_radius: float = maxf(blast_radius,11.0 if spell_type == "arc" else 0.0)
	var candidates: Array = scene.war_nearby_fighters(position,maxi(1,int(ceil((query_radius + 3.0) / scene.WAR_GRID_CELL)))) if scene != null and scene.has_method("war_nearby_fighters") else projectile.get_tree().get_nodes_in_group("combat_fighters")
	if scene != null:
		# The central battle roster excludes the manually controlled player
		# and optional motion demo. Both are still mortal spell targets.
		if attacker_name != "PlayerMan":
			var player_target: Node = scene.get_node_or_null("PlayerMan")
			if is_instance_valid(player_target): candidates.append(player_target)
		var demo_target: Node = scene.get_node_or_null("DemoNPC")
		if is_instance_valid(demo_target) and attacker_name != "DemoNPC":
			candidates.append(demo_target)
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
		# Flame physically expands to every AOE victim, and its impact is
		# synchronized with the delayed damage callback on arrival.
		if spell_type=="fire" and source != null:
			launch_visible_aoe_stream(impact,source,position,damage.bone_position("torso"),fighter,hit_regions,impact_damage)
		else:
			damage.receive_aoe_regions(hit_regions,impact_damage,attacker_name)
			if fighter.has_method("apply_spell_status"): fighter.apply_spell_status(spell_type,position)
			if source != null:
				# Other spell colours also extend outward toward their victims.
				var matching_fire := source.duplicate() as GPUParticles3D
				impact.add_child(matching_fire)
				matching_fire.global_position = damage.bone_position("torso")
				matching_fire.scale = Vector3.ONE*0.78
				matching_fire.amount = 18
				matching_fire.one_shot = true
				matching_fire.lifetime = 0.50
				matching_fire.emitting = true
				matching_fire.restart()
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
