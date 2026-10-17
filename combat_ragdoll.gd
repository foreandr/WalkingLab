extends Node
# Animation drives the mesh while alive; PhysicalBone3D takes over on death.
var rig: Skeleton3D
var simulator: PhysicalBoneSimulator3D
var bodies: Array[PhysicalBone3D] = []
var active: bool = false
const PARTS = {
	"Hips": Vector2(0.19,0.28),
	"Spine": Vector2(0.17,0.29),
	"Spine1": Vector2(0.17,0.27),
	"Spine2": Vector2(0.17,0.24),
	"Head": Vector2(0.14,0.24),
	"LeftArm": Vector2(0.10,0.28),
	"LeftForeArm": Vector2(0.09,0.25),
	"RightArm": Vector2(0.10,0.28),
	"RightForeArm": Vector2(0.09,0.25),
	"LeftUpLeg": Vector2(0.13,0.38),
	"LeftLeg": Vector2(0.11,0.36),
	"RightUpLeg": Vector2(0.13,0.38),
	"RightLeg": Vector2(0.11,0.36)
}

func setup(skeleton: Skeleton3D) -> void:
	rig = skeleton
	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "CombatRagdoll"
	rig.add_child(simulator)
	simulator.active = false
	for key in PARTS:
		var index: int = -1
		for bone_index in range(rig.get_bone_count()):
			var name: String = String(rig.get_bone_name(bone_index))
			if name.to_lower().ends_with(String(key).to_lower()):
				index = bone_index
				break
		if index < 0: continue
		var body := PhysicalBone3D.new()
		body.name = "Physics_" + String(key)
		simulator.add_child(body)
		body.bone_name = rig.get_bone_name(index)
		body.transform = rig.get_bone_global_rest(index)
		body.collision_layer = 0
		body.collision_mask = 0
		body.mass = 5.0 if key in ["Hips","Spine","Spine1","Spine2"] else 1.5
		body.linear_damp = 0.7
		body.angular_damp = 1.4
		body.friction = 0.9
		body.joint_type = PhysicalBone3D.JOINT_TYPE_NONE if key == "Hips" else PhysicalBone3D.JOINT_TYPE_PIN
		var shape := CapsuleShape3D.new()
		var sizes: Vector2 = PARTS[key]
		shape.radius = sizes.x
		shape.height = maxf(sizes.y,shape.radius*2.0+0.01)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		bodies.append(body)
	simulator.physical_bones_stop_simulation()

func activate(previous_velocity: Vector3, hit_direction: Vector3 = Vector3.ZERO) -> void:
	if active or bodies.is_empty(): return
	active = true
	rig.force_update_all_bone_transforms()
	for body in bodies:
		body.collision_layer = 1
		body.collision_mask = 1
	simulator.active = true
	simulator.physical_bones_start_simulation()
	for body in bodies:
		body.linear_velocity = previous_velocity
		if hit_direction.length_squared() > 0.001:
			body.apply_central_impulse(hit_direction.normalized()*body.mass*1.4)
