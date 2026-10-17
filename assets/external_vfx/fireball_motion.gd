extends Node
# Motion only. All fire appearance comes from the original third-party VFX.
var travel_direction: Vector3 = Vector3.FORWARD
const SPEED: float = 15.0
const LIFETIME: float = 2.5
var lived: float = 0.0

func _physics_process(delta: float) -> void:
	var projectile: Node3D = get_parent() as Node3D
	if projectile == null: return
	var displacement: Vector3 = travel_direction * SPEED * delta
	var space: PhysicsDirectSpaceState3D = projectile.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(projectile.global_position, projectile.global_position + displacement)
	var hit: Dictionary = space.intersect_ray(ray)
	if not hit.is_empty():
		projectile.queue_free()
		return
	projectile.global_position += displacement
	lived += delta
	if lived >= LIFETIME:
		projectile.queue_free()
