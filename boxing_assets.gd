extends RefCounted
# Loads actual Mixamo motion clips from assets/boxing. Keeps the existing Y Bot.
const MOTIONS = ["Fight_Idle", "Lead_Jab", "Cross_Punch", "Hook_Punch", "Right_Hook"]
var available = {}
func normalized_bone(name: String) -> String:
	return name.to_lower().replace("mixamorig:", "").replace("mixamorig", "").replace("_", "").replace(":", "")
func install(owner: Node3D, player: AnimationPlayer, graph: AnimationNodeBlendTree):
	var skeleton: Skeleton3D = owner.skeleton
	var target_path = player.get_node(player.root_node).get_path_to(skeleton)
	var library = AnimationLibrary.new()
	for name in MOTIONS:
		var path = "res://assets/boxing/" + name + ".glb"
		if not ResourceLoader.exists(path):
			push_warning("Optional boxing motion missing: " + path)
			continue
		var packed = load(path)
		if not packed is PackedScene: continue
		var source = packed.instantiate()
		var players = source.find_children("*", "AnimationPlayer", true, false)
		var skeletons = source.find_children("*", "Skeleton3D", true, false)
		if players.is_empty() or skeletons.is_empty():
			source.free()
			push_warning("Boxing file lacks required animation rig: " + name)
			continue
		var source_player: AnimationPlayer = players[0]
		var source_skeleton: Skeleton3D = skeletons[0]
		var bone_map = {}
		for bone in range(skeleton.get_bone_count()):
			bone_map[normalized_bone(String(skeleton.get_bone_name(bone)))] = String(skeleton.get_bone_name(bone))
		var compatible = true
		for bone in range(source_skeleton.get_bone_count()):
			if not bone_map.has(normalized_bone(String(source_skeleton.get_bone_name(bone)))):
				compatible = false
				break
		if not compatible:
			push_warning("Boxing skeleton bone names differ: " + name)
			source.free()
			continue
		var clip_names = source_player.get_animation_list()
		if clip_names.is_empty():
			source.free()
			continue
		var source_name = clip_names[0]
		for candidate in clip_names:
			if String(candidate) != "RESET":
				source_name = candidate
				break
		var clip = source_player.get_animation(source_name).duplicate(true)
		for index in range(clip.get_track_count() - 1, -1, -1):
			var track_path = clip.track_get_path(index)
			if track_path.get_subname_count() == 0:
				clip.remove_track(index)
				continue
			var bone_name = String(track_path.get_subname(0))
			var canonical = normalized_bone(bone_name)
			if not bone_map.has(canonical):
				clip.remove_track(index)
				continue
			clip.track_set_path(index, NodePath(String(target_path) + ":" + bone_map[canonical]))
		clip.loop_mode = Animation.LOOP_LINEAR if name == "Fight_Idle" else Animation.LOOP_NONE
		library.add_animation(name, clip)
		available[name] = true
		source.free()
	if library.get_animation_list().is_empty(): return
	player.add_animation_library("boxing", library)
	var choice = AnimationNodeTransition.new()
	for name in available:
		var anim = AnimationNodeAnimation.new()
		anim.animation = "boxing/" + name
		graph.add_node("Boxing_" + name, anim)
		choice.add_input(name)
		# Connect after all inputs have been allocated.
	graph.add_node("BoxingChoice", choice)
	var idx = 0
	for name in available:
		graph.connect_node("BoxingChoice", idx, "Boxing_" + name)
		idx += 1
	var overlay = AnimationNodeBlend2.new()
	overlay.sync = false
	graph.add_node("BoxingOverlay", overlay)
	graph.connect_node("BoxingOverlay", 0, "Posture")
	graph.connect_node("BoxingOverlay", 1, "BoxingChoice")
	graph.disconnect_node("output", 0)
	graph.connect_node("output", 0, "BoxingOverlay")
