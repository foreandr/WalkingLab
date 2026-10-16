extends RefCounted
# Two idle states for a Mixamo-compatible Y Bot; never touches the locomotion clips.
const FILES = {
	"Normal": "Idle.fbx",
	"ToFight": "Action Idle To Fight Idle.fbx",
	"Fight": "Idle (1).fbx",
	"ToNormal": "Fight Idle To Standing Idle.fbx"
}
var host
var available = {}
var mode = "Normal"
var phase = 0.0
var transition_length = 0.0
var desired = "Normal"

func install(owner: Node3D, player: AnimationPlayer, graph: AnimationNodeBlendTree):
	host = owner
	var library = AnimationLibrary.new()
	var target_skeleton: Skeleton3D = owner.skeleton
	var target_path = player.get_node(player.root_node).get_path_to(target_skeleton)
	for key in FILES:
		var filename = FILES[key]
		var path = "res://assets/custom_idle/" + filename
		if not ResourceLoader.exists(path):
			print("STANCE_FILE_MISSING ", filename)
			continue
		var packed = load(path)
		if not packed is PackedScene: continue
		var root = packed.instantiate()
		var players = root.find_children("*", "AnimationPlayer", true, false)
		var rigs = root.find_children("*", "Skeleton3D", true, false)
		if players.is_empty() or rigs.is_empty():
			root.free()
			continue
		var source_rig: Skeleton3D = rigs[0]
		var compatible = true
		for i in range(target_skeleton.get_bone_count()):
			if source_rig.find_bone(target_skeleton.get_bone_name(i)) < 0:
				compatible = false
				break
		if not compatible:
			push_warning("STANCE_RIG_MISMATCH " + filename)
			root.free()
			continue
		var source_player: AnimationPlayer = players[0]
		for anim_name in source_player.get_animation_list():
			if anim_name == "RESET": continue
			var clip = source_player.get_animation(anim_name).duplicate(true)
			for t in range(clip.get_track_count() - 1, -1, -1):
				var np = clip.track_get_path(t)
				if np.get_subname_count() == 0:
					clip.remove_track(t)
					continue
				var bone = String(np.get_subname(0))
				if target_skeleton.find_bone(bone) < 0:
					clip.remove_track(t)
					continue
				clip.track_set_path(t, NodePath(String(target_path) + ":" + bone))
			clip.loop_mode = Animation.LOOP_LINEAR if key in ["Normal", "Fight"] else Animation.LOOP_NONE
			library.add_animation(key, clip)
			available[key] = clip.length
			print("STANCE_LOADED ", key, " seconds=", clip.length)
			break
		root.free()
	if not available.has("Normal") or not available.has("Fight"):
		print("STANCE_DISABLED: missing compatible Normal/Fight clip")
		return
	player.add_animation_library("stance", library)
	var selector = AnimationNodeTransition.new()
	selector.xfade_time = 0.16
	for key in ["Normal", "ToFight", "Fight", "ToNormal"]:
		if not available.has(key): continue
		var node = AnimationNodeAnimation.new()
		node.animation = "stance/" + key
		graph.add_node("Stance_" + key, node)
		selector.add_input(key)
	graph.add_node("StanceState", selector)
	var index = 0
	for key in ["Normal", "ToFight", "Fight", "ToNormal"]:
		if not available.has(key): continue
		graph.connect_node("StanceState", index, "Stance_" + key)
		index += 1
	var overlay = AnimationNodeBlend2.new()
	overlay.sync = false
	graph.add_node("StanceBlend", overlay)
	graph.connect_node("StanceBlend", 0, "Posture")
	graph.connect_node("StanceBlend", 1, "StanceState")
	graph.disconnect_node("output", 0)
	graph.connect_node("output", 0, "StanceBlend")

func request(fighting: bool):
	desired = "Fight" if fighting else "Normal"
	if available.is_empty(): return
	if mode == desired: return
	var key = "ToFight" if fighting else "ToNormal"
	mode = key if available.has(key) else desired
	phase = 0.0
	transition_length = float(available.get(mode, 0.0))
	host.tree.set("parameters/StanceState/transition_request", mode)

func update(dt: float, velocity: float, crouching: bool):
	if not available.has("Normal") or not available.has("Fight"): return
	phase += dt
	if mode in ["ToFight", "ToNormal"] and phase >= maxf(transition_length - 0.08, 0.01):
		mode = desired
		host.tree.set("parameters/StanceState/transition_request", mode)
	var weight = clampf((0.85 - velocity) / 0.60, 0.0, 1.0)
	if crouching: weight = 0.0
	host.tree.set("parameters/StanceBlend/blend_amount", weight)
