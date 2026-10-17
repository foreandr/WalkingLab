extends Node
# Motion only. All fire appearance comes from the original third-party VFX.
var travel_direction: Vector3 = Vector3.FORWARD
var travel_speed: float = 3.0
var battle_base_speed: float = 0.0
var owner_rid: RID
const LIFETIME: float = 25.0
var lived: float = 0.0

func _physics_process(delta: float) -> void:
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
		var victim: Object = hit.get("collider")
		if victim is CharacterBody3D:
			var damage: Node = victim.get_parent().get_node_or_null("DamageSystem")
			if damage != null: damage.receive_hit(hit["position"],32.0)
		projectile.queue_free()
		return
	projectile.global_position += displacement
	lived += delta
	if lived >= LIFETIME:
		projectile.queue_free()
