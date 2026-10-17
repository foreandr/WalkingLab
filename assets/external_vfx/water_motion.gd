extends Node
# Gameplay water uses the external particle visual and deposits persistent liquid.
var travel_direction: Vector3 = Vector3.FORWARD
var travel_speed: float = 10.0
var owner_rid: RID
var lived: float = 0.0
const LIFETIME: float = 9.0

func _physics_process(delta: float) -> void:
	var projectile: Node3D = get_parent() as Node3D
	if projectile == null: return
	var displacement: Vector3 = travel_direction * travel_speed * delta
	var space: PhysicsDirectSpaceState3D = projectile.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(projectile.global_position,projectile.global_position+displacement)
	if owner_rid.is_valid(): ray.exclude = [owner_rid]
	var hit: Dictionary = space.intersect_ray(ray)
	if not hit.is_empty():
		var system: Node = projectile.get_tree().current_scene.get_node_or_null("WaterSystem")
		if system != null: system.deposit(hit["position"],140.0)
		projectile.queue_free()
		return
	projectile.global_position += displacement
	lived += delta
	if lived >= LIFETIME:
		var system: Node = projectile.get_tree().current_scene.get_node_or_null("WaterSystem")
		if system != null: system.deposit(projectile.global_position,140.0)
		projectile.queue_free()
