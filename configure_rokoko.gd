extends SceneTree
func _initialize():
	for key in ["walk","run","sprint","target"]:
		var file="res://assets/rokoko/"+key+"_mapped.glb"
		if key=="target":
			file="res://assets/defender_retarget.glb"
			DirAccess.copy_absolute(ProjectSettings.globalize_path("res://assets/character.glb"),ProjectSettings.globalize_path(file))
		else:
			configure(file,key)
	quit()
func configure(file,key):
	var c=ConfigFile.new();c.load(file+".import")
	var map=BoneMap.new();map.profile=SkeletonProfileHumanoid.new()
	var pairs={"Hips":"Hips","Spine":"Spine1","Chest":"Spine3","UpperChest":"Spine4","Neck":"Neck","Head":"Head"}
	for side in ["Left","Right"]:
		for names in [["Shoulder","Shoulder"],["UpperArm","Arm"],["LowerArm","ForeArm"],["Hand","Hand"],["UpperLeg","Thigh"],["LowerLeg","Shin"],["Foot","Foot"],["Toes","Toe"]]:pairs[side+names[0]]=side+names[1]
	for name in pairs:map.set_skeleton_bone_name(name,pairs[name])
	c.set_value("params","_subresources",{"nodes":{"PATH:Sam/Root/Skeleton3D":{"retarget/bone_map":map,"retarget/rest_fixer/apply_node_transforms":true,"retarget/rest_fixer/normalize_position_tracks":true,"retarget/rest_fixer/retarget_method":0,"retarget/rest_fixer/overwrite_axis":false,"retarget/rest_fixer/fix_silhouette/enable":false,"retarget/bone_renamer/rename_bones":true}}})
	c.save(file+".import")
