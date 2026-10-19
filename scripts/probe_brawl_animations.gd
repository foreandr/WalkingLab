extends SceneTree
# Offline rig comparison from the actual imported Godot scenes.
func _initialize() -> void:
	call_deferred("probe")

func probe() -> void:
	for pair in [
		["UAL1","res://assets/source_original.glb"],
		["UAL2","res://assets/showcase/UAL2_Standard.glb"],
		["AETHER","res://assets/showcase/aether-02.glb"]
	]:
		if not ResourceLoader.exists(pair[1]):
			print("[RIG_PROBE_MISSING] ",pair)
			continue
		var p: PackedScene = load(pair[1]) as PackedScene
		if p == null: continue
		var model: Node3D = p.instantiate() as Node3D
		root.add_child(model)
		var skels: Array[Node] = model.find_children("*","Skeleton3D",true,false)
		var players: Array[Node] = model.find_children("*","AnimationPlayer",true,false)
		if not skels.is_empty():
			var rig: Skeleton3D = skels[0] as Skeleton3D
			var names: Array[String] = []
			for bone in range(rig.get_bone_count()):
				names.append(String(rig.get_bone_name(bone)))
			print("[RIG_PROBE_SKELETON] ",pair[0]," names=",names," path=",model.get_path_to(rig))
		if not players.is_empty():
			var mixer: AnimationPlayer = players[0] as AnimationPlayer
			print("[RIG_PROBE_ANIMATOR] ",pair[0]," path=",model.get_path_to(mixer)," root_node=",mixer.root_node," library_names=",mixer.get_animation_library_list())
			for name in mixer.get_animation_list():
				var value: String = String(name)
				if value in ["Walk","Jog_Fwd","Sprint","Idle","Idle_No","NinjaJump_Start","Sword_Regular_A","Backflip","DodgeRoll"]:
					var anim: Animation = mixer.get_animation(name)
					var paths: Array[String] = []
					for t in range(mini(7,anim.get_track_count())):
						paths.append(str(anim.track_get_path(t)))
					print("[RIG_PROBE_TRACKS] ",pair[0]," clip=",name," paths=",paths)
		model.queue_free()
	quit()
