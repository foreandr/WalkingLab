extends Node
# Motion only. All fire appearance comes from the original third-party VFX.
var travel_direction: Vector3 = Vector3.FORWARD
var travel_speed: float = 3.0
var battle_base_speed: float = 0.0
var owner_rid: RID
var attacker_name: String = ""
var blast_width: float = 1.0
const LIFETIME: float = 25.0
var lived: float = 0.0
var profile_tick: int = 0

func _physics_process(delta: float) -> void:
	profile_tick += 1
	var sampled: bool = (profile_tick & 31) == 0
	var profile_start: int = Time.get_ticks_usec() if sampled else 0
	var projectile: Node3D = get_parent() as Node3D
	if projectile == null: return
	var effective_speed: float = travel_speed
	if battle_base_speed > 0.0:
		var scene: Node = projectile.get_tree().current_scene
		if scene != null: effective_speed = battle_base_speed * float(scene.get("battle_fireball_speed"))
	var displacement: Vector3 = travel_direction * effective_speed * delta
	var space: PhysicsDirectSpaceState3D = projectile.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(projectile.global_position, projectile.global_position + displacement)
	if owner_rid.is_valid(): ray.exclude = [owner_rid]
	# The spectator is not a combatant and cannot obstruct AI shots.
	var scene: Node = projectile.get_tree().current_scene
	if scene != null and scene.get("battle_fireball_speed") != null:
		var spectator: Node = scene.get_node_or_null("PlayerMan")
		if spectator != null:
			var spectator_body: CharacterBody3D = spectator.get("actor") as CharacterBody3D
			if spectator_body != null: ray.exclude.append(spectator_body.get_rid())
	var hit: Dictionary = space.intersect_ray(ray)
	if not hit.is_empty():
		explode(projectile,hit["position"])
		projectile.queue_free()
		return
	# For enlarged fireballs, the visible body of the projectile must be
	# collidable too. Query spheres along this physics step, preserving the
	# swept center ray above for narrow/high-speed shots.
	if blast_width > 1.0:
		var width_radius: float = 0.45 * blast_width
		var ball := SphereShape3D.new()
		ball.radius = width_radius
		var sphere_query := PhysicsShapeQueryParameters3D.new()
		sphere_query.shape = ball
		sphere_query.exclude = ray.exclude
		var segments: int = mini(6,maxi(1,int(ceil(displacement.length() / maxf(width_radius,0.5)))))
		for segment in range(segments):
			var probe: Vector3 = projectile.global_position + displacement * (float(segment + 1) / float(segments))
			sphere_query.transform = Transform3D(Basis.IDENTITY,probe)
			var overlaps: Array[Dictionary] = space.intersect_shape(sphere_query,1)
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
	impact.name = "FireImpact"
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
		burst.scale = source.scale * 5.0
		burst.amount = mini(4,maxi(2,int(burst.amount / 2)))
		burst.fixed_fps = 30
		burst.one_shot = true
		burst.emitting = true
		burst.restart()
	var cleanup := impact.create_tween()
	cleanup.tween_interval(0.6)
	cleanup.tween_callback(impact.queue_free)
	# The blast intersects each anatomical region independently. A large
	# fireball can hit multiple body pools on one fighter in one explosion.
	var blast_radius: float = 5.0 * blast_width
	var affected_fighters: int = 0
	var affected_regions: int = 0
	for fighter in projectile.get_tree().get_nodes_in_group("combat_fighters"):
		if not is_instance_valid(fighter): continue
		if fighter.player_controlled and scene.get("battle_fireball_speed") != null: continue
		var body: CharacterBody3D = fighter.actor as CharacterBody3D
		if body == null or body.get_rid() == owner_rid: continue
		var damage: Node = fighter.get_node_or_null("DamageSystem")
		if damage == null or damage.dead: continue
		# Broad-phase avoids most bone queries in wide battles.
		if body.global_position.distance_squared_to(position) > pow(blast_radius + 3.0,2.0): continue
		var hit_regions: Array[String] = []
		for region in damage.REGIONS:
			var bone_point: Vector3 = damage.bone_position(region)
			var region_radius: float = 0.48 if region == "torso" else (0.32 if region == "head" else 0.34)
			if bone_point.distance_squared_to(position) <= pow(blast_radius + region_radius,2.0):
				hit_regions.append(region)
		if hit_regions.is_empty(): continue
		affected_fighters += 1
		damage.receive_aoe_regions(hit_regions,32.0,attacker_name)
		affected_regions += hit_regions.size()
	print("[AOE_REGIONS] fighters=",affected_fighters," body_regions=",affected_regions," radius=",blast_radius)
