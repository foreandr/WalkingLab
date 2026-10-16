extends SceneTree
func _initialize(): call_deferred("run")
func run():
	for file in ["character","library"]:
		var map = BoneMap.new()
		map.profile = SkeletonProfileHumanoid.new()
		var pairs = {"Hips":"Hips","Spine":"LowerBack","Chest":"Spine","UpperChest":"Spine1","Neck":"Neck","Head":"Head"} if file=="character" else {"Root":"root","Hips":"pelvis","Spine":"spine_01","Chest":"spine_02","UpperChest":"spine_03","Neck":"neck_01","Head":"Head"}
		for side in ["Left","Right"]:
			var end = "_l" if side=="Left" else "_r"
			var original = {"Shoulder":"Shoulder","UpperArm":"Arm","LowerArm":"ForeArm","Hand":"Hand","UpperLeg":"UpLeg","LowerLeg":"Leg","Foot":"Foot","Toes":"ToeBase"}
			var source = {"Shoulder":"clavicle","UpperArm":"upperarm","LowerArm":"lowerarm","Hand":"hand","UpperLeg":"thigh","LowerLeg":"calf","Foot":"foot","Toes":"ball"}
			for name in original: pairs[side+name] = side+original[name] if file=="character" else source[name]+end
		for name in pairs: map.set_skeleton_bone_name(name,pairs[name])
		ResourceSaver.save(map,"res://assets/"+file+"_map.tres")
		var config = ConfigFile.new()
		config.load("res://assets/"+file+".glb.import")
		var path = "PATH:Defender_Ske/Skeleton3D" if file=="character" else "PATH:Armature/Skeleton3D"
		config.set_value("params","_subresources",{"nodes":{path:{"retarget/bone_map":map,"retarget/rest_fixer/apply_node_transforms":true,"retarget/rest_fixer/normalize_position_tracks":true,"retarget/rest_fixer/overwrite_axis":true,"retarget/rest_fixer/retarget_method":1,"retarget/rest_fixer/fix_silhouette/enable":file=="character","retarget/bone_renamer/rename_bones":true,"retarget/bone_renamer/unique_node/make_unique":true,"retarget/bone_renamer/unique_node/skeleton_name":"GeneralSkeleton","retarget/remove_tracks/unimportant_positions":true}}})
		config.save("res://assets/"+file+".glb.import")
	quit()
