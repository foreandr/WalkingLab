extends Node3D
# Idle studio: ten stationary, continuously animated mannequins.
# Authored targets are solved with two-bone IK in the actual Y Bot skeleton.
# No walking animation, synthetic animation-track guessing, or T-pose fallback.
const TITLES = [
	"At Ease", "Wide & Proud", "Hands Behind", "Hands on Hips",
	"Arms Folded", "Boxer Guard", "One Hand Hip", "Combat Ready",
	"Military Rest", "Open Chest"
]
var specimens: Array = []
var elapsed := 0.0

func find_bone(rig: Skeleton3D, suffix: String) -> int:
	var end = suffix.to_lower()
	for i in range(rig.get_bone_count()):
		var name = String(rig.get_bone_name(i)).to_lower()
		if name.ends_with(end): return i
	return -1

func point(rig: Skeleton3D, bone: int) -> Vector3:
	return rig.get_bone_global_pose(bone).origin

func aim_joint(rig: Skeleton3D, joint: int, end: int, goal: Vector3) -> void:
	var joint_pos = point(rig,joint)
	var from = point(rig,end) - joint_pos
	var to = goal - joint_pos
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001: return
	var adjustment = Quaternion(from.normalized(),to.normalized())
	var parent = rig.get_bone_parent(joint)
	var parent_basis = Basis.IDENTITY if parent < 0 else rig.get_bone_global_pose(parent).basis
	var current_global = rig.get_bone_global_pose(joint).basis
	var wanted_global = Basis(adjustment) * current_global
	var rest_basis = rig.get_bone_rest(joint).basis
	var new_local = (parent_basis.inverse() * wanted_global).get_rotation_quaternion()
	var local_rest = rest_basis.get_rotation_quaternion()
	rig.set_bone_pose_rotation(joint,(local_rest.inverse()*new_local).normalized())

func solve_arm(rig: Skeleton3D, shoulder: int, elbow: int, hand: int, target: Vector3, elbow_pole: Vector3) -> void:
	# CCD with an explicit elbow pole to prevent arms inverting behind the torso.
	for iteration in range(9):
		aim_joint(rig,elbow,hand,target)
		aim_joint(rig,shoulder,hand,target)
	# Bias the elbow toward the anatomically appropriate side of the torso,
	# then settle the hand back onto its intended target.
	var shoulder_pos = point(rig,shoulder)
	var wrist_pos = point(rig,hand)
	var axis = (wrist_pos-shoulder_pos).normalized()
	if axis.length_squared() < 0.0001: return
	var elbow_pos = point(rig,elbow)
	var elbow_radial = (elbow_pos-shoulder_pos).slide(axis).normalized()
	var desired_radial = elbow_pole.slide(axis).normalized()
	if elbow_radial.length_squared() > 0.0001 and desired_radial.length_squared() > 0.0001:
		var sin_value = axis.dot(elbow_radial.cross(desired_radial))
		var cos_value = clampf(elbow_radial.dot(desired_radial),-1.0,1.0)
		var twist = atan2(sin_value,cos_value)
		var parent = rig.get_bone_parent(shoulder)
		var parent_basis = Basis.IDENTITY if parent < 0 else rig.get_bone_global_pose(parent).basis
		var new_global = Basis(Quaternion(axis,twist)) * rig.get_bone_global_pose(shoulder).basis
		var base = rig.get_bone_rest(shoulder).basis.get_rotation_quaternion()
		rig.set_bone_pose_rotation(shoulder,(base.inverse()*(parent_basis.inverse()*new_global).get_rotation_quaternion()).normalized())
	for iteration in range(3):
		aim_joint(rig,elbow,hand,target)
		aim_joint(rig,shoulder,hand,target)

func _ready() -> void:
	for i in range(10):
		var model: Node3D = preload("res://assets/user_mixamo.glb").instantiate()
		model.position = Vector3((float(i)-4.5)*3.3,0,17)
		model.rotation.y = PI
		add_child(model)
		var rigs = model.find_children("*","Skeleton3D",true,false)
		var players = model.find_children("*","AnimationPlayer",true,false)
		if rigs.is_empty(): continue
		var rig: Skeleton3D = rigs[0]
		# Disable any existing gait animation, including its RESET tracks.
		for animator in players: animator.stop()
		rig.reset_bone_poses()
		var left = [find_bone(rig,"LeftArm"),find_bone(rig,"LeftForeArm"),find_bone(rig,"LeftHand")]
		var right = [find_bone(rig,"RightArm"),find_bone(rig,"RightForeArm"),find_bone(rig,"RightHand")]
		var head = find_bone(rig,"Head")
		var hips = find_bone(rig,"Hips")
		if left.has(-1) or right.has(-1) or head < 0 or hips < 0:
			push_warning("IDLE_RIG_BONES_MISSING "+str(i+1))
			continue
		var l_shoulder = point(rig,left[0])
		var r_shoulder = point(rig,right[0])
		var center = (l_shoulder+r_shoulder)*0.5
		var across = (r_shoulder-l_shoulder).normalized()
		var up = (point(rig,head)-point(rig,hips)).normalized()
		var forward = across.cross(up).normalized()
		var scale_value = (r_shoulder-l_shoulder).length()
		# Identify front direction using the mesh's anatomical front:
		# target hands start near the same side as the original walk.
		var height = (point(rig,head)-point(rig,hips)).length()
		var spec = {
			"rig":rig,"left":left,"right":right,"center":center,
			"across":across,"up":up,"forward":forward,
			"width":scale_value,"height":height,"index":i
		}
		specimens.append(spec)
		for part in model.find_children("*","MeshInstance3D",true,false):
			var white := StandardMaterial3D.new()
			white.albedo_color = Color.WHITE
			white.roughness = 0.82
			part.material_override = white
		var number := Label3D.new()
		number.text = str(i+1)
		number.font_size = 85
		number.pixel_size = 0.005
		number.modulate = Color(1,0.88,0.25)
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number.position = Vector3(0,2.50,0)
		model.add_child(number)
		var name_label := Label3D.new()
		name_label.text = TITLES[i]
		name_label.font_size = 28
		name_label.pixel_size = 0.005
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.position = Vector3(0,2.12,0)
		model.add_child(name_label)
	print("IDLE_STUDIO_READY ",specimens.size()," IK-controlled stationary characters")

func target(spec: Dictionary, side: float, time: float) -> Vector3:
	var i: int = spec.index
	var w: float = spec.width
	var h: float = spec.height
	var breathing = sin(time*TAU/(2.9+float(i)*0.18)+float(i)*0.7)*0.018*h
	var shoulder = spec.center + spec.across*side*w*0.5
	var lateral = spec.across*side
	var up: Vector3 = spec.up
	var front: Vector3 = spec.forward
	var goal: Vector3
	match i:
		0: goal = shoulder + lateral*w*0.12 - up*h*0.83 + front*w*0.07
		1: goal = shoulder + lateral*w*0.45 - up*h*0.80 - front*w*0.10
		2: goal = spec.center + lateral*w*0.25 - up*h*0.70 - front*w*0.36
		3: goal = spec.center + lateral*w*0.54 - up*h*0.63 + front*w*0.26
		4: goal = spec.center - lateral*w*0.23 - up*h*0.22 + front*w*0.43
		5: goal = spec.center + lateral*w*0.20 - up*h*0.01 + front*w*0.76
		6:
			if side < 0: goal = spec.center+lateral*w*0.54-up*h*0.63+front*w*0.26
			else: goal = shoulder+lateral*w*0.1-up*h*0.82+front*w*0.10
		7: goal = spec.center + lateral*w*0.38 - up*h*0.32 + front*w*0.82
		8: goal = spec.center + lateral*w*0.18 - up*h*0.85 - front*w*0.23
		_: goal = shoulder + lateral*w*0.63 - up*h*0.73 - front*w*0.17
	return goal + up*breathing

func _process(dt: float) -> void:
	elapsed += dt
	for spec in specimens:
		var rig: Skeleton3D = spec.rig
		# Reset to rest; feet and pelvis remain perfectly planted.
		rig.reset_bone_poses()
		for side in [-1.0,1.0]:
			var arm = spec.left if side < 0.0 else spec.right
			var pole: Vector3 = spec.across*side + spec.forward*0.35
			solve_arm(rig,arm[0],arm[1],arm[2],target(spec,side,elapsed),pole)
