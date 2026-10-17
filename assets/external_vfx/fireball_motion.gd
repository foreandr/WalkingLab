extends Node
# Motion only. All fire appearance comes from the original third-party VFX.
var travel_direction: Vector3 = Vector3.FORWARD
var travel_speed: float = 3.0
var owner_rid: RID
const LIFETIME: float = 25.0
var lived: float = 0.0

func _physics_process(delta: float) -> void:
	var projectile: Node3D = get_parent() as Node3D
	if projectile == null: return
	var displacement: Vector3 = travel_direction * travel_speed * delta
	var space: PhysicsDirectSpaceState3D = projectile.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(projectile.global_position, projectile.global_position + displacement)
	if owner_rid.is_valid(): ray.exclude = [owner_rid]
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
