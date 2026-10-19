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
var caster_team: String = ""
var homing_target: CharacterBody3D = null
var homing_scan_left: float = 0.0
var ricochet_last_hit_ms: Dictionary = {}
var ricochet_effect_cooldown: float = 0.0
const RICOCHET_DAMAGE: float = 19.0
const RICOCHET_HIT_COOLDOWN_MS: int = 850
const RICOCHET_COLLISION_LIMIT: int = 4
# Homing missiles have a finite chase window. Their particle size, glow,
# emission, and swept hit radius all decay over the same four seconds.
const HOMING_LIFETIME: float = 4.0
const HOMING_HIT_RADIUS: float = 0.36
const HOMING_MIN_RADIUS: float = 0.035
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
	var projectile: Node3D = get_parent() as Node3D
	if projectile == null: return
	if spell_type=="ricochet":
		update_ricochet(projectile,delta)
		return
	if spell_type=="homing":
		# Outrunning the missile for four seconds defeats it outright.
		# Do not extend its time even if it switches targets.
		lived += delta
		if lived >= HOMING_LIFETIME:
			projectile.queue_free()
			return
		update_homing_visuals(projectile)
		update_homing_direction(projectile,delta)
	profile_tick += 1
	var sampled: bool = (profile_tick & 31) == 0
	var profile_start: int = Time.get_ticks_usec() if sampled else 0
	var effective_speed: float = travel_speed
	if battle_base_speed <= 0.0:
		match spell_type:
			"gravity": effective_speed *= 0.7
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
		# Never hit the caster; allied bodies are transparent to their spells.
		if owner_rid.is_valid(): cached_excludes.append(owner_rid)
		if caster_team!="":
			for fighter in projectile.get_tree().get_nodes_in_group("combat_fighters"):
				if is_instance_valid(fighter) and String(fighter.get("team_id"))==caster_team:
					var ally_body: CharacterBody3D = fighter.get("actor") as CharacterBody3D
					if ally_body!=null and ally_body.get_rid()!=owner_rid:
						cached_excludes.append(ally_body.get_rid())
		cached_ray.exclude = cached_excludes
	cached_ray.from = projectile.global_position
	cached_ray.to = projectile.global_position + displacement
	var hit: Dictionary = space.intersect_ray(cached_ray)
	if not hit.is_empty():
		if spell_type=="homing":
			finish_homing_impact(projectile,hit["position"],hit.get("collider"))
		else:
			explode(projectile,hit["position"])
		projectile.queue_free()
		return
	# For enlarged fireballs, the visible body of the projectile must be
	# collidable too. Query spheres along this physics step, preserving the
	# swept center ray above for narrow/high-speed shots.
	if blast_width > 1.0 or spell_type=="homing":
		# The physical envelope tapers with the visible missile. A nearly
		# vanished missile cannot retain a large invisible collision sphere.
		var width_radius: float = 0.45 * blast_width
		if spell_type=="homing":
			width_radius = maxf(HOMING_MIN_RADIUS,HOMING_HIT_RADIUS*(1.0-lived/HOMING_LIFETIME))
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
				if spell_type=="homing":
					finish_homing_impact(projectile,probe,overlaps[0].get("collider"))
				else:
					explode(projectile,probe)
				projectile.queue_free()
				return
	if sampled:
		var scene_for_profile: Node = projectile.get_tree().current_scene
		if scene_for_profile != null and scene_for_profile.has_method("record_performance_sample"):
			scene_for_profile.record_performance_sample("projectile_ray",Time.get_ticks_usec()-profile_start)
	projectile.global_position += displacement
	if spell_type!="homing":
		lived += delta
		if lived >= LIFETIME:
			projectile.queue_free()

func update_homing_visuals(projectile: Node3D) -> void:
	# Shrink the actual imported particle effect, not just a decorative shell.
	# Both the emission rate and rendered particles taper steadily to zero.
	var remaining: float = clampf(1.0-lived/HOMING_LIFETIME,0.0,1.0)
	var taper: float = maxf(0.025,pow(remaining,1.25))
	projectile.scale = Vector3.ONE*taper
	for child in projectile.get_children():
		if child is GPUParticles3D:
			var particles: GPUParticles3D = child as GPUParticles3D
			particles.amount_ratio = remaining
			particles.transparency = 1.0-remaining
		elif child is OmniLight3D:
			(child as OmniLight3D).light_energy = 1.25*remaining*remaining

func finish_homing_impact(projectile: Node3D, hit_point: Vector3, collider: Object) -> void:
	# The FIRST thing struck consumes the shot, whether its intended mark,
	# another fighter, a pillar, the ground, or the arena walls/ceiling.
	# Structures block damage rather than triggering a large splash.
	if collider is CharacterBody3D:
		var fighter_body: CharacterBody3D = collider as CharacterBody3D
		if fighter_body.get_rid()!=owner_rid:
			var controller: Node = fighter_body.get_parent()
			var injury: Node = controller.get_node_or_null("DamageSystem") if controller!=null else null
			if injury!=null and not injury.dead and (caster_team=="" or String(controller.get("team_id"))!=caster_team):
				injury.receive_hit(hit_point,38.0,attacker_name)
	# Small imported-particle impact, no lingering damage or AOE.
	ricochet_spark(projectile,hit_point)

func update_homing_direction(projectile: Node3D, delta: float) -> void:
	# Track living targets, not their positions when the cast was started.
	# Find a new target if the current opponent dies or disappears.
	var target_valid: bool = is_instance_valid(homing_target)
	if target_valid:
		var controller: Node = homing_target.get_parent()
		var damage: Node = controller.get_node_or_null("DamageSystem") if controller != null else null
		target_valid = damage != null and not damage.dead
	if not target_valid:
		homing_target = null
		homing_scan_left -= delta
		if homing_scan_left<=0.0:
			homing_scan_left = 0.2
			var best_score: float = INF
			for fighter in projectile.get_tree().get_nodes_in_group("combat_fighters"):
				if not is_instance_valid(fighter) or fighter.combat_dead: continue
				var body: CharacterBody3D = fighter.get("actor") as CharacterBody3D
				if body == null or body.get_rid()==owner_rid: continue
				if caster_team!="" and String(fighter.get("team_id"))==caster_team: continue
				var heading: Vector3 = body.global_position+Vector3.UP-projectile.global_position
				var range_m: float = heading.length()
				if range_m<0.1 or range_m>110.0: continue
				var facing: float = travel_direction.dot(heading/range_m)
				if facing<0.10: continue
				var score: float = range_m+(1.0-facing)*45.0
				if score<best_score:
					best_score = score
					homing_target = body
	if is_instance_valid(homing_target):
		var aim: Vector3 = homing_target.global_position+Vector3.UP*1.05
		var distance_m: float = projectile.global_position.distance_to(aim)
		# Short velocity lead avoids the tail chase when runners strafe.
		aim += homing_target.velocity*clampf(distance_m/36.0,0.0,0.48)
		var toward: Vector3 = aim-projectile.global_position
		if toward.length_squared()>0.01:
			travel_direction = travel_direction.slerp(toward.normalized(),clampf(delta*7.5,0.0,1.0)).normalized()

func ricochet_spark(projectile: Node3D, point: Vector3) -> void:
	if ricochet_effect_cooldown>0.0: return
	ricochet_effect_cooldown = 0.22
	var source: GPUParticles3D = null
	for child in projectile.get_children():
		if child is GPUParticles3D:
			source = child
			break
	if source == null: return
	var scene: Node = projectile.get_tree().current_scene
	if scene == null: return
	var flash := Node3D.new()
	flash.name = "RicochetSpark"
	scene.add_child(flash)
	flash.global_position = point
	var particles: GPUParticles3D = source.duplicate() as GPUParticles3D
	flash.add_child(particles)
	particles.scale = Vector3.ONE*0.48
	particles.amount = 12
	particles.lifetime = 0.38
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.restart()
	var cleanup := flash.create_tween()
	cleanup.tween_interval(0.6)
	cleanup.tween_callback(flash.queue_free)

func update_ricochet(projectile: Node3D, delta: float) -> void:
	# Deliberately no lifetime. Existing orbs bounce until the scene ends;
	# the caster limits the number that may coexist, not their survival time.
	ricochet_effect_cooldown = maxf(0.0,ricochet_effect_cooldown-delta)
	var space: PhysicsDirectSpaceState3D = projectile.get_world_3d().direct_space_state
	if cached_ray == null:
		cached_ray = PhysicsRayQueryParameters3D.new()
		if owner_rid.is_valid(): cached_excludes.append(owner_rid)
		cached_ray.exclude = cached_excludes
	var scene: Node = projectile.get_tree().current_scene
	var effective_speed: float = travel_speed
	if battle_base_speed>0.0 and scene!=null:
		effective_speed = battle_base_speed*float(scene.get("battle_fireball_speed"))
	var remaining: float = maxf(0.0,effective_speed*delta)
	var at: Vector3 = projectile.global_position
	for i in range(RICOCHET_COLLISION_LIMIT):
		if remaining<=0.01: break
		cached_ray.from = at
		cached_ray.to = at+travel_direction*remaining
		var hit: Dictionary = space.intersect_ray(cached_ray)
		if hit.is_empty():
			at += travel_direction*remaining
			remaining = 0.0
			break
		var contact: Vector3 = hit["position"]
		var covered: float = at.distance_to(contact)
		at = contact-travel_direction*0.06
		var collider: Object = hit.get("collider")
		if collider is CharacterBody3D:
			var controller: Node = (collider as CharacterBody3D).get_parent()
			var injury: Node = controller.get_node_or_null("DamageSystem") if controller != null else null
			if injury != null and not injury.dead and (caster_team=="" or String(controller.get("team_id"))!=caster_team):
				var key: int = collider.get_instance_id()
				var timestamp: int = Time.get_ticks_msec()
				if timestamp-int(ricochet_last_hit_ms.get(key,-100000))>=RICOCHET_HIT_COOLDOWN_MS:
					ricochet_last_hit_ms[key] = timestamp
					injury.receive_hit(contact,RICOCHET_DAMAGE,attacker_name)
		var normal: Vector3 = hit["normal"]
		if normal.length_squared()<0.1: normal = -travel_direction
		travel_direction = travel_direction.bounce(normal.normalized()).normalized()
		if travel_direction.length_squared()<0.01: travel_direction = normal.normalized()
		at += travel_direction*0.12
		remaining = maxf(0.0,remaining-covered-0.12)
		ricochet_spark(projectile,contact)
	projectile.global_position = at

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
			base_radius = 7.0
			impact_damage = 12.0 # + 88% movement slow for five seconds
		"homing":
			base_radius = 2.7
			impact_damage = 38.0 # Aim-assisted missile that follows the victim
		"gravity":
			base_radius = 6.5
			impact_damage = 10.0 # + physical pull toward the blast
		"ricochet":
			base_radius = 0.0
			impact_damage = 0.0 # Collisions handled by persistent bouncing sphere
		"grounding":
			base_radius = 8.0
			impact_damage = 8.0 # Prevent flight for 6 seconds, force descent
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
	var affected_regions: int = 0
	# Arena spatial hash avoids testing the entire 60-fighter roster on
	# every impact. Fall back to the scene group outside arena mode.
	var query_radius: float = blast_radius
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
		if caster_team!="" and String(fighter.get("team_id"))==caster_team: continue
		if fighter.player_controlled and attacker_name=="PlayerMan": continue
		var body: CharacterBody3D = fighter.actor as CharacterBody3D
		if body == null or body.get_rid() == owner_rid: continue
		var damage: Node = fighter.get_node_or_null("DamageSystem")
		if damage == null or damage.dead: continue
		# Keep the broad-phase and per-bone radius consistent with the VFX.
		var radius_sq: float = body.global_position.distance_squared_to(position)
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
		# Every blast uses its coloured, imported VFX to actually reach
		# every hurt target, and applies the damage at visible arrival.
		if source != null:
			launch_visible_aoe_stream(impact,source,position,damage.bone_position("torso"),fighter,hit_regions,impact_damage)
		else:
			damage.receive_aoe_regions(hit_regions,impact_damage,attacker_name)
			if fighter.has_method("apply_spell_status"): fighter.apply_spell_status(spell_type,position)
		affected_regions += hit_regions.size()
	if scene != null and scene.has_method("record_aoe_event"):
		scene.record_aoe_event(affected_fighters,affected_regions)
	elif scene == null or not bool(scene.get("stress_no_deaths")):
		print("[AOE_REGIONS] fighters=",affected_fighters," body_regions=",affected_regions," radius=",blast_radius)
