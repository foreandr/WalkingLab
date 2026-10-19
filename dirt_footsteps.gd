extends Node3D
# Reusable two-foot dirt bursts; emitted at grounded running stride contacts.
# This visual has no collision or physics-body cost.
var runner: CharacterBody3D
var stride_distance: float = 0.0
var foot_side: int = 0
var previous_position: Vector3
var puffs: Array[CPUParticles3D] = []

func _ready() -> void:
 runner = get_parent() as CharacterBody3D
 previous_position = runner.global_position
 var dust_mesh := SphereMesh.new()
 dust_mesh.radius = 0.085
 dust_mesh.height = 0.17
 var dust_mat := StandardMaterial3D.new()
 dust_mat.albedo_color = Color(0.52,0.43,0.31,0.8)
 dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 dust_mesh.material = dust_mat
 for i in range(2):
  var puff := CPUParticles3D.new()
  puff.name = "DirtStepLeft" if i == 0 else "DirtStepRight"
  puff.emitting = false
  puff.one_shot = true
  puff.amount = 11
  puff.lifetime = 0.5
  puff.explosiveness = 1.0
  puff.local_coords = false
  puff.direction = Vector3(0,1,0)
  puff.spread = 65.0
  puff.initial_velocity_min = 0.7
  puff.initial_velocity_max = 1.6
  puff.gravity = Vector3(0,-3.0,0)
  puff.scale_amount_min = 0.55
  puff.scale_amount_max = 1.4
  puff.mesh = dust_mesh
  add_child(puff)
  puffs.append(puff)

func _physics_process(_dt: float) -> void:
 if not is_instance_valid(runner): return
 var movement: Vector3 = runner.global_position - previous_position
 previous_position = runner.global_position
 movement.y = 0.0
 var speed: float = Vector2(runner.velocity.x,runner.velocity.z).length()
 if not runner.is_on_floor() or speed < 2.5:
  stride_distance = 0.0
  return
 stride_distance += movement.length()
 var step_length: float = clampf(1.3-speed*0.025,0.72,1.25)
 if stride_distance < step_length: return
 stride_distance = fmod(stride_distance,step_length)
 var puff: CPUParticles3D = puffs[foot_side]
 foot_side = 1-foot_side
 var sideways: Vector3 = runner.global_transform.basis.x.normalized()*(-0.22 if foot_side == 0 else 0.22)
 puff.global_position = runner.global_position+sideways+Vector3(0,0.08,0)
 puff.restart()
 puff.emitting = true
