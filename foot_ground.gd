extends RefCounted
var skeleton: Skeleton3D
var visual: Node3D
var samples = []
var all_samples = []
var minimum = INF
var lift = 0.0
var support_groups = []
var use_full_support = false
func setup(root: Node3D, skel: Skeleton3D):
	visual = root
	skeleton = skel
	for instance in root.find_children("*","MeshInstance3D",true,false):
		if not instance.skin or not instance.mesh: continue
		var skin = instance.skin
		var binds = []
		for index in range(skin.get_bind_count()):
			var bone = skin.get_bind_bone(index)
			if bone<0: bone = skeleton.find_bone(skin.get_bind_name(index))
			binds.append({"bone":bone,"pose":skin.get_bind_pose(index)})
		for surface in range(instance.mesh.get_surface_count()):
			var arrays = instance.mesh.surface_get_arrays(surface)
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if bones==null or weights==null: continue
			var count = bones.size()/vertices.size()
			for v in range(vertices.size()):
				var foot_weight = 0.0
				var influences = []
				for k in range(count):
					var weight = weights[v*count+k]
					if weight<0.00001: continue
					var bind = binds[bones[v*count+k]]
					if bind.bone<0: continue
					var name = skeleton.get_bone_name(bind.bone).to_lower()
					if "foot" in name or "toe" in name: foot_weight += weight
					influences.append([bind.bone,bind.pose*vertices[v],weight])
				all_samples.append(influences)
				if foot_weight>0.15: samples.append(influences)
	# The native Mixamo feet are rigidly weighted to four bones. Linear height
	# extrema therefore occur on each foot's convex hull: exact support with fewer points.
	if root.scene_file_path.ends_with("user_mixamo.glb"):
		var indices = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mixamo-foot-hull.json"))
		var reduced = []
		for index in indices: reduced.append(samples[int(index)])
		samples = reduced
	print("FOOT_SURFACE_SAMPLES ",samples.size())
	if root.scene_file_path.ends_with("user_mixamo.glb") and FileAccess.file_exists("res://assets/body_ground_support.json"):
		support_groups = JSON.parse_string(FileAccess.get_file_as_string("res://assets/body_ground_support.json"))
		for group in support_groups:
			for sphere in group.bounds:
				sphere[0] = int(sphere[0])
				sphere[1] = Vector3(sphere[1][0],sphere[1][1],sphere[1][2])
			for point in group.points:
				for influence in point:
					influence[0] = int(influence[0])
					influence[1] = Vector3(influence[1][0],influence[1][1],influence[1][2])
func full_support_lowest() -> float:
	if support_groups.is_empty(): return lowest()
	var transforms = []
	var scales = []
	for bone in range(skeleton.get_bone_count()):
		var transform = skeleton.global_transform*skeleton.get_bone_global_pose(bone)
		transforms.append(transform)
		scales.append(Vector3(transform.basis.x.y,transform.basis.y.y,transform.basis.z.y).length())
	var result = INF
	for group in support_groups:
		var bound = INF
		for sphere in group.bounds:
			bound = min(bound,(transforms[sphere[0]]*sphere[1]).y-sphere[2]*scales[sphere[0]])
		if bound>=result: continue
		for point in group.points:
			var position = Vector3.ZERO
			for influence in point:
				position += (transforms[influence[0]]*influence[1])*influence[2]
			result = min(result,position.y)
	return result
func lowest(points = null) -> float:
	if points==null: points = samples
	var transforms = []
	for bone in range(skeleton.get_bone_count()): transforms.append(skeleton.global_transform*skeleton.get_bone_global_pose(bone))
	var result = INF
	for point in points:
		var position = Vector3.ZERO
		for influence in point: position += (transforms[influence[0]]*influence[1])*influence[2]
		result = min(result,position.y)
	return result
func resolve():
	# Reset each frame, then enforce the ground constraint on the final blended pose.
	visual.position.y = 0.0
	skeleton.force_update_all_bone_transforms()
	var bottom = full_support_lowest() if use_full_support else lowest()
	lift = max(0,0.006-bottom)
	visual.position.y = lift
	skeleton.force_update_all_bone_transforms()
	minimum = bottom+lift


