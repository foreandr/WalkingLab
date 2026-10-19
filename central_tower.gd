extends Node3D
# Grassland's first climbable structure: a hollow round tower with a hinged entry.
const RADIUS: float = 12.0
const HEIGHT: float = 43.0
const FLOOR_HEIGHT: float = 12.0
const FLOOR_COUNT: int = 3
const WALL_THICKNESS: float = 1.0
const SEGMENTS: int = 64
const STEP_COUNT: int = 100
var stage: int = 0
var stage_guards: Array = []
var gates: Array[Node3D] = []
var unlocked: Array[bool] = [false,false,false]
var door_pivot: Node3D
var door_open: bool = false
var door_animation: Tween
var prompt: Label3D
var previous_e: bool = false

func _ready() -> void:
	name = "CentralTower"
	position = Vector3(0.0, 0.0, -60.0)
	build_tower()
	build_floors_and_gates()
	set_process(true)
	print("[TOWER_READY] center=",global_position," height=",HEIGHT," radius=",RADIUS," steps=",STEP_COUNT," door_interact=E")

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.93
	return m

func solid_box(parent: Node3D, title: String, size: Vector3, at: Vector3, angle: float, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = title
	body.position = at
	body.rotation.y = angle
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var shape_mesh := BoxMesh.new()
	shape_mesh.size = size
	mesh.mesh = shape_mesh
	mesh.material_override = mat
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	return body

func build_tower() -> void:
	var stone := material(Color("85847e"))
	var steps_material := material(Color("ada79a"))
	var door_material := material(Color("533827"))
	var metal := material(Color("383c43"))
	# Each wall segment is real geometry and collision. Leave a wide doorway
	# at the south (+Z) side, rather than covering it with a full cylinder.
	for i in range(SEGMENTS):
		var theta: float = TAU * float(i) / float(SEGMENTS)
		if absf(wrapf(theta - PI * 0.5, -PI, PI)) < 0.19:
			continue
		var center := Vector3(RADIUS*cos(theta),HEIGHT*0.5,RADIUS*sin(theta))
		var tangent_length: float = TAU * RADIUS / float(SEGMENTS) + 0.08
		solid_box(self,"StoneWall%02d" % i,Vector3(tangent_length,HEIGHT,WALL_THICKNESS),center,-theta,stone)
	# Door hinge is at the left of the entrance when facing the tower.
	door_pivot = Node3D.new()
	door_pivot.name = "EntranceDoorHinge"
	door_pivot.position = Vector3(-2.2,0.0,RADIUS+0.15)
	add_child(door_pivot)
	var leaf := solid_box(door_pivot,"HingedWoodenDoor",Vector3(4.4,5.2,0.35),Vector3(2.2,2.6,0),0.0,door_material)
	# Door remains solid; when rotated it moves entirely out of the entrance.
	for x in [0.8,2.1,3.5]:
		var trim := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.13,5.0,0.42)
		trim.mesh = bar
		trim.position = Vector3(x-2.2,0.0,0.0)
		trim.material_override = metal
		leaf.add_child(trim)
	prompt = Label3D.new()
	prompt.text = "TOWER ENTRANCE  [E] OPEN"
	prompt.font_size = 54
	prompt.outline_size = 10
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.position = Vector3(0,7.0,RADIUS+2)
	add_child(prompt)
	# A continuous spiral of collision-backed shallow steps, open through
	# the centre. Their rise is 0.20m to keep them traversable on foot.
	for i in range(STEP_COUNT):
		var theta: float = PI*0.5 - float(i)*0.16
		var r: float = 8.8
		var center := Vector3(cos(theta)*r,0.12+float(i)*0.24,sin(theta)*r)
		solid_box(self,"Stair%03d" % i,Vector3(3.5,0.22,2.9),center,-theta,steps_material)
	# A visible landing at the top of the first section.
	var landing_y: float = float(STEP_COUNT)*0.24+0.12
	solid_box(self,"UpperLanding",Vector3(7.0,0.35,7.0),Vector3(0,landing_y,0),0,steps_material)

func _process(_dt: float) -> void:
	update_progression()
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var actor_owner: Node = scene.get("player")
	if not is_instance_valid(actor_owner):
		return
	var actor: Node3D = actor_owner.get("actor") as Node3D
	if not is_instance_valid(actor):
		return
	var door_world: Vector3 = to_global(Vector3(0,1.5,RADIUS+1.0))
	var near: bool = actor.global_position.distance_to(door_world) < 5.5
	prompt.visible = near
	if near:
		prompt.text = "TOWER ENTRANCE  [E] " + ("CLOSE" if door_open else "OPEN")
	var e_down: bool = Input.is_physical_key_pressed(KEY_E)
	if e_down and not previous_e and near:
		toggle_door()
	previous_e = e_down

func toggle_door() -> void:
	door_open = not door_open
	if door_animation != null and door_animation.is_running():
		door_animation.kill()
	door_animation = create_tween()
	door_animation.set_trans(Tween.TRANS_SINE)
	door_animation.set_ease(Tween.EASE_IN_OUT)
	door_animation.tween_property(door_pivot,"rotation:y",(-PI*0.58 if door_open else 0.0),0.75)
	print("[TOWER_DOOR] open=",door_open)

func build_floors_and_gates() -> void:
	var stone := material(Color("92918b"))
	var iron := material(Color("453c35"))
	# Floor plates are solid overhead ceilings, not traversable by jumping.
	# They fill the central room; the outer ring contains the stair flight.
	for floor_index in range(FLOOR_COUNT):
		var y: float = float(floor_index)*FLOOR_HEIGHT
		if floor_index > 0:
			var disk := StaticBody3D.new()
			disk.name = "FloorPlate%d" % (floor_index+1)
			disk.position.y = y-0.20
			add_child(disk)
			var mesh := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 6.3
			cylinder.bottom_radius = 6.3
			cylinder.height = 0.4
			mesh.mesh = cylinder
			mesh.material_override = stone
			disk.add_child(mesh)
			var collider := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = 6.3
			shape.height = 0.4
			collider.shape = shape
			disk.add_child(collider)
		# A solid partition forces passage through the locked middle gate.
		# Guard stands in front (south); stairs begin behind (north).
		solid_box(self,"Floor%dLeftPartition" % (floor_index+1),Vector3(5.0,5.0,0.8),Vector3(-5.0,y+2.5,-6.0),0.0,stone)
		solid_box(self,"Floor%dRightPartition" % (floor_index+1),Vector3(5.0,5.0,0.8),Vector3(5.0,y+2.5,-6.0),0.0,stone)
		var gate := Node3D.new()
		gate.name = "LockedGate%d" % (floor_index+1)
		gate.position = Vector3(0.0,y+2.5,-6.0)
		add_child(gate)
		solid_box(gate,"Door",Vector3(5.0,5.0,0.6),Vector3.ZERO,0.0,iron)
		gates.append(gate)
		var sign := Label3D.new()
		sign.text = "FLOOR %d - DEFEAT GUARD" % (floor_index+1)
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.font_size = 50
		sign.outline_size = 9
		sign.position = Vector3(0,y+5.6,-5.5)
		add_child(sign)
	# Close off the top of the third chamber too.
	var top := StaticBody3D.new()
	top.name = "TowerRoof"
	top.position.y = FLOOR_HEIGHT*float(FLOOR_COUNT)+0.2
	add_child(top)
	var top_mesh := MeshInstance3D.new()
	var top_cylinder := CylinderMesh.new()
	top_cylinder.top_radius = RADIUS
	top_cylinder.bottom_radius = RADIUS
	top_cylinder.height = 0.4
	top_mesh.mesh = top_cylinder
	top_mesh.material_override = stone
	top.add_child(top_mesh)
	var top_collision := CollisionShape3D.new()
	var top_shape := CylinderShape3D.new()
	top_shape.radius = RADIUS
	top_shape.height = 0.4
	top_collision.shape = top_shape
	top.add_child(top_collision)

func register_guard(fighter: Node) -> void:
	stage_guards.append(fighter)
	print("[TOWER_GUARD] floor=",stage_guards.size()," fighter=",fighter.name)

func update_progression() -> void:
	if stage >= FLOOR_COUNT or stage >= stage_guards.size():
		return
	var guard: Node = stage_guards[stage]
	if is_instance_valid(guard) and not guard.combat_dead:
		return
	var gate: Node3D = gates[stage]
	var gate_tween := create_tween()
	gate_tween.tween_property(gate,"position:y",gate.position.y+6.0,1.1)
	unlocked[stage] = true
	stage += 1
	print("[TOWER_UNLOCK] completed_floor=",stage)
	if stage < FLOOR_COUNT:
		var arena: Node = get_tree().current_scene
		if arena != null and arena.has_method("spawn_more_fighters"):
			arena.spawn_more_fighters(1,true)
