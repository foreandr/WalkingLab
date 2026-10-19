extends Node3D
# Displays untouched authored Quaternius/AETHER animation tracks on a living fighter.
# WalkingLab's existing CharacterBody3D and damage system remain authoritative.
var pilot
var source_file: String = "res://assets/showcase/UAL2_Standard.glb"
var model: Node3D
var mixer: AnimationPlayer
var skeleton: Skeleton3D
var current_clip: String = ""
var busy_for: float = 0.0
var impact_visual_cooldown: float = 0.0
var advertised_action: String = ""
var dead_swapped: bool = false
var clip_failures: Dictionary = {}
var model_scale: float = 1.0

func _ready() -> void:
	if pilot == null: return
	var combine_quaternius: bool = source_file.ends_with("UAL2_Standard.glb")
	var candidate: String = "res://assets/source_original.glb" if combine_quaternius else source_file
	if not ResourceLoader.exists(candidate):
		candidate = "res://assets/source_original.glb"
	if not ResourceLoader.exists(candidate):
		push_warning("[BRAWL_RIG_MISSING] both "+source_file+" and UAL1 unavailable")
		return
	var packed: PackedScene = load(candidate) as PackedScene
	if packed == null: return
	model = packed.instantiate() as Node3D
	if model == null: return
	add_child(model)
	model.scale = Vector3.ONE * (0.13 if candidate.ends_with("aether-02.glb") else model_scale)
	var anims: Array[Node] = model.find_children("*","AnimationPlayer",true,false)
	if anims.is_empty():
		push_warning("[BRAWL_NO_ANIMATION_PLAYER] "+candidate)
		model.queue_free()
		model = null
		return
	mixer = anims[0] as AnimationPlayer
	mixer.playback_default_blend_time = 0.13
	var rigs: Array[Node] = model.find_children("*","Skeleton3D",true,false)
	if not rigs.is_empty(): skeleton = rigs[0] as Skeleton3D
	if combine_quaternius and ResourceLoader.exists(source_file):
		_merge_quaternius_combat(source_file)
	# Never hide BLACK's controllable Mixamo model. Replace only NPC visuals.
	var mesh_count: int = model.find_children("*","MeshInstance3D",true,false).size()
	if mesh_count == 0:
		push_warning("[BRAWL_RIG_HAS_NO_MESH] "+candidate+"; retaining original visible mannequin")
		model.queue_free()
		model = null
		mixer = null
		return
	if not pilot.player_controlled: pilot.visual.visible = false
	print("[BRAWL_RIG_LOADED] fighter=",pilot.name," path=",candidate," visible_meshes=",model.find_children("*","MeshInstance3D",true,false).size()," animations=",mixer.get_animation_list())
	play_named(["Idle","Idle_Loop","Sentinel"],true)


func _merge_quaternius_combat(source: String) -> void:
	# Confirmed using scripts/probe_brawl_animations.gd:
	# UAL1 and UAL2 have identical 61-bone rigs, AnimationPlayer.root_node,
	# and skeleton track targets Armature/Skeleton3D:<bone>.
	# Play both libraries on ONE visible rig, preserving native authored keys.
	if skeleton == null or mixer == null: return
	var source_scene: PackedScene = load(source) as PackedScene
	if source_scene == null: return
	var reference: Node3D = source_scene.instantiate() as Node3D
	if reference == null: return
	add_child(reference)
	reference.visible = false
	var peers: Array[Node] = reference.find_children("*","Skeleton3D",true,false)
	var animators: Array[Node] = reference.find_children("*","AnimationPlayer",true,false)
	var compatible: bool = not peers.is_empty() and not animators.is_empty()
	if compatible:
		var candidate_rig: Skeleton3D = peers[0] as Skeleton3D
		compatible = candidate_rig.get_bone_count() == skeleton.get_bone_count()
		if compatible:
			for index in range(skeleton.get_bone_count()):
				if String(candidate_rig.get_bone_name(index)) != String(skeleton.get_bone_name(index)):
					compatible = false
					break
	if compatible:
		var imported_animator: AnimationPlayer = animators[0] as AnimationPlayer
		var combination: AnimationLibrary = AnimationLibrary.new()
		var collected: int = 0
		for name in imported_animator.get_animation_list():
			var original: Animation = imported_animator.get_animation(name)
			if original == null: continue
			combination.add_animation(StringName(String(name)),original.duplicate(true) as Animation)
			collected += 1
		if collected > 0:
			var error_code: Error = mixer.add_animation_library("ual2",combination)
			if error_code == OK:
				print("[BRAWL_COMBINED_ANIMATIONS] actor=",pilot.name," native_locomotion=UAL1 authored_sword_and_ninja=UAL2 clips_added=",collected)
			else:
				push_warning("[BRAWL_ANIMATION_MERGE_FAILED] "+pilot.name+" code="+str(error_code))
	else:
		push_warning("[BRAWL_RIG_INCOMPATIBLE] "+source+" cannot share UAL1 skeleton")
	reference.queue_free()

func resolve(choices: Array) -> String:
	if mixer == null: return ""
	for option in choices:
		var want: String = String(option).to_lower().replace("_loop","").replace("_","").replace(" ","").replace("-","")
		for available in mixer.get_animation_list():
			var actual: String = String(available)
			var tail: String = actual.get_file().to_lower().replace("_loop","").replace("_","").replace(" ","").replace("-","")
			if tail == want: return actual
	return ""

func play_named(choices: Array, looped: bool = false) -> bool:
	if mixer == null: return false
	var chosen: String = resolve(choices)
	if chosen == "":
		var missing: String = " / ".join(choices)
		if not clip_failures.has(missing):
			clip_failures[missing] = true
			print("[BRAWL_MISSING_AUTHORED_CLIP] ",pilot.name," source=",source_file," options=",choices)
		return false
	if chosen != current_clip:
		mixer.play(chosen,0.13)
		current_clip = chosen
	elif not looped:
		mixer.stop()
		mixer.play(chosen,0.05)
	return true

func action(choices: Array, seconds: float, kind: String) -> bool:
	# Continuous spell ticks must not restart the same hit animation
	# every frame. A readable reaction should have time to finish.
	if kind == "WEAPON IMPACT":
		if impact_visual_cooldown > 0.0: return false
		impact_visual_cooldown = 0.33
	var good: bool = play_named(choices)
	if good:
		busy_for = seconds
		advertised_action = kind
		print("[BRAWL_ACTION] ",pilot.name," action=",kind," clip=",current_clip)
	return good

func _process(delta: float) -> void:
	if pilot == null or model == null or mixer == null: return
	impact_visual_cooldown = maxf(0.0,impact_visual_cooldown-delta)
	if pilot.combat_dead:
		if not dead_swapped:
			dead_swapped = true
			var death: bool = action(["Death01","Collapse","Death","Dying"],2.4,"DEATH")
			if not death:
				model.visible = false
				pilot.visual.visible = true
		return
	busy_for = maxf(0.0,busy_for-delta)
	if busy_for > 0.0: return
	var desired: Array = []
	var horiz: Vector3 = Vector3(pilot.actor.velocity.x,0,pilot.actor.velocity.z)
	var velocity: float = horiz.length()
	var height: float = pilot.actor.global_position.y
	if pilot.flight_enabled:
		desired = ["NinjaJump_Idle","Jump","Jump_Loop","Sentinel","Run"]
	elif height > 1.4 or not pilot.actor.is_on_floor():
		desired = ["Jump","Jump_Loop","NinjaJump_Idle","Run","Sentinel"]
	elif velocity <= 0.8:
		desired = ["Idle","Idle_Loop","Sentinel"]
	else:
		var right: Vector3 = pilot.actor.global_transform.basis.x
		var forward: Vector3 = -pilot.actor.global_transform.basis.z
		var sidestep: float = horiz.normalized().dot(right)
		var advance: float = horiz.normalized().dot(forward)
		if sidestep < -0.60:
			desired = ["Jog_Left","Jog_Left_Loop","Walk_Left","Jog_Fwd","Run","Walk"]
		elif sidestep > 0.60:
			desired = ["Jog_Right","Jog_Right_Loop","Walk_Right","Jog_Fwd","Run","Walk"]
		elif advance < -0.40:
			desired = ["Jog_Back","Jog_Back_Loop","Walk_Back","Walk","Run"]
		elif velocity >= 11.0:
			desired = ["Sprint","Sprint_Loop","Run","Jog_Fwd"]
		elif velocity >= 4.0:
			desired = ["Jog_Fwd","Jog_Fwd_Loop","Run","Walk"]
		else:
			desired = ["Walk","Walk_Loop","Jog_Fwd"]
	play_named(desired,true)
	# View tilt for actual powered flight; no fake bone or flip animation.
	model.rotation.x = move_toward(model.rotation.x,0.40 if pilot.flight_enabled else 0.0,delta*2.4)

func grip_skeleton() -> Skeleton3D:
	return skeleton if skeleton != null and model != null else null
