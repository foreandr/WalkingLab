extends Node3D
# One and only one visible demonstration actor. Original sourced animation tracks;
# source rig is stated on screen when the action requires a different rig.
const UAL1 := "res://assets/source_original.glb"
const UAL2 := "res://assets/showcase/UAL2_Standard.glb"
const AETHER := "res://assets/showcase/aether-02.glb"
const SWORD := "res://assets/kenney_weapons/mini-arena/weapon-sword.glb"

var rigs: Dictionary = {}
var mixers: Dictionary = {}
var weapons: Dictionary = {}
var source_paths: Dictionary = {"UAL1":UAL1, "UAL2":UAL2, "AETHER":AETHER}
var sequence: Array[Dictionary] = []
var step_index: int = 0
var time_in_step: float = 0.0
var step_start: Vector3
var home: Vector3
var selected_rig: String = ""
var selected_clip: String = ""
var held_sword: bool = false
var sword_available: bool = false
var sword_pickup_complete: bool = false
var missing_count: int = 0
var paused_preview: bool = false
var stage_label: Label3D
var ground_sword: Node3D
var had_cast: bool = false
var jumped_again: bool = false
var report: String = ""

func action(label: String, rig: String, clips: Array, duration: float, velocity: Vector3 = Vector3.ZERO, height: float = 0.0, fx: String = "", special: String = "") -> Dictionary:
	return {"title":label, "rig":rig, "clips":clips, "duration":duration, "velocity":velocity, "height":height, "effect":fx, "special":special}

func build_sequence() -> void:
	sequence = [
		action("01  IDLE", "UAL1", ["Idle", "Idle_Loop"], 2.5),
		action("02  WALK", "UAL1", ["Walk", "Walk_Loop"], 3.0, Vector3(0,0,1.8)),
		action("03  JOG", "UAL1", ["Jog_Fwd", "Jog_Fwd_Loop"], 3.0, Vector3(0,0,3.4)),
		action("04  SPRINT", "UAL1", ["Sprint", "Sprint_Loop"], 3.0, Vector3(0,0,5.5)),
		action("05  STRAFE LEFT", "UAL1", ["Jog_Left","Jog_Left_Loop","Strafe_Left","Walk_Left"], 2.8, Vector3(-2.2,0,0)),
		action("06  STRAFE RIGHT", "UAL1", ["Jog_Right","Jog_Right_Loop","Strafe_Right","Walk_Right"], 2.8, Vector3(2.2,0,0)),
		action("07  BACKPEDAL", "UAL1", ["Jog_Back","Jog_Back_Loop","Walk_Back","Walk_Bwd"], 2.8, Vector3(0,0,-1.9)),
		action("08  JUMP TAKEOFF", "UAL1", ["Jump_Start"], 2.1, Vector3.ZERO, 1.3),
		action("09  AIRBORNE JUMP", "UAL1", ["Jump","Jump_Loop"], 2.3, Vector3.ZERO, 2.1),
		action("10  DOUBLE JUMP (SAME CLIP TWICE)", "UAL1", ["Jump","Jump_Loop"], 2.6, Vector3.ZERO, 3.2, "", "double"),
		action("11  LANDING", "UAL1", ["Jump_Land"], 1.8),
		action("12  NINJA TAKEOFF", "UAL2", ["NinjaJump_Start"], 2.1, Vector3.ZERO, 1.9),
		action("13  NINJA AIR", "UAL2", ["NinjaJump_Idle_Loop"], 3.1, Vector3(0,0,0.9), 2.6),
		action("14  NINJA LAND", "UAL2", ["NinjaJump_Land"], 1.8),
		action("15  FORWARD ROLL", "UAL1", ["Roll","Roll_RM"], 2.3),
		action("16  SLIDE START", "UAL2", ["Slide_Start"], 1.6, Vector3(0,0,1.1)),
		action("17  SLIDE LOOP", "UAL2", ["Slide_Loop"], 2.4, Vector3(0,0,1.9)),
		action("18  SLIDE EXIT", "UAL2", ["Slide_Exit"], 1.6),
		action("19  PARKOUR CLIMB", "UAL2", ["ClimbUp_1m_RM"], 2.4),
		action("20  BACKFLIP (SEPARATE RIG)", "AETHER", ["Backflip"], 4.0),
		action("21  SIDE FLIP (IF AVAILABLE)", "UAL2", ["SideFlip","Side_Flip","Cartwheel","Aerial"], 2.3),
		action("22  FLIGHT / AIR LOOP", "UAL2", ["NinjaJump_Idle_Loop"], 3.5, Vector3(0,0,2.0), 3.8, "", "flight"),
		action("23  SPELLCAST ENTER", "UAL1", ["Spell_Simple_Enter"], 1.9),
		action("24  SPELLCAST IDLE", "UAL1", ["Spell_Simple_Idle_Loop","Spell_Simple_Idle"], 2.0),
		action("25  FIRE CAST + IMPACT", "UAL1", ["Spell_Simple_Shoot"], 2.7, Vector3.ZERO, 0.0, "fire"),
		action("26  WATER CAST + IMPACT", "UAL1", ["Spell_Simple_Shoot"], 2.7, Vector3.ZERO, 0.0, "water"),
		action("27  SPELLCAST EXIT", "UAL1", ["Spell_Simple_Exit"], 1.8),
		action("28  GROUND SWORD PICKUP (TABLE CLIP)", "UAL1", ["PickUp_Table","Interact"], 2.9, Vector3.ZERO, 0.0, "", "pickup"),
		action("29  SWORD IDLE", "UAL1", ["Sword_Idle"], 2.4, Vector3.ZERO, 0.0, "", "sword"),
		action("30  SWORD ATTACK", "UAL1", ["Sword_Attack"], 2.4, Vector3.ZERO, 0.0, "", "sword"),
		action("31  SWORD COMBO", "UAL2", ["Sword_Regular_Combo"], 3.2, Vector3.ZERO, 0.0, "", "sword"),
		action("32  SWORD SWING A", "UAL2", ["Sword_Regular_A"], 2.5, Vector3.ZERO, 0.0, "", "sword"),
		action("33  SWORD SWING B", "UAL2", ["Sword_Regular_B"], 2.5, Vector3.ZERO, 0.0, "", "sword"),
		action("34  SWORD SWING C", "UAL2", ["Sword_Regular_C"], 2.5, Vector3.ZERO, 0.0, "", "sword"),
		action("35  SWORD BLOCK", "UAL2", ["Sword_Block"], 2.5, Vector3.ZERO, 0.0, "", "sword"),
		action("36  DROP SWORD", "UAL1", ["Idle","Idle_Loop"], 1.8, Vector3.ZERO, 0.0, "", "drop")
	]

func _ready() -> void:
	home = position
	for id in ["UAL1","UAL2","AETHER"]:
		var path: String = String(source_paths[id])
		if not ResourceLoader.exists(path):
			print("[SHOWCASE_SOURCE_MISSING] rig=",id," file=",path)
			continue
		var packed: PackedScene = load(path) as PackedScene
		if packed == null: continue
		var model: Node3D = packed.instantiate() as Node3D
		if model == null: continue
		add_child(model)
		model.visible = false
		if id == "AETHER": model.scale = Vector3.ONE*0.13
		var found: Array[Node] = model.find_children("*","AnimationPlayer",true,false)
		if found.is_empty():
			push_warning("[SHOWCASE_SOURCE_HAS_NO_CLIPS] " + path)
			model.queue_free()
			continue
		var mixer: AnimationPlayer = found[0] as AnimationPlayer
		mixer.playback_default_blend_time = 0.20
		rigs[id] = model
		mixers[id] = mixer
		print("[SHOWCASE_SOURCE] ",id," clips=",mixer.get_animation_list())
		_install_hand_sword(id,model)
	stage_label = Label3D.new()
	stage_label.font_size = 50
	stage_label.pixel_size = 0.005
	stage_label.outline_size = 12
	stage_label.modulate = Color("fff7d6")
	stage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stage_label.no_depth_test = true
	stage_label.position = Vector3(0,2.7,0)
	add_child(stage_label)
	_install_ground_sword()
	build_sequence()
	_play_step(0)

func _install_hand_sword(id: String, model: Node3D) -> void:
	var skeletons: Array[Node] = model.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty(): return
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	var chosen: String = ""
	for candidate in ["hand_r","Hand_R","RightHand","mixamorig_RightHand","right_hand","hand.R","Hand.R"]:
		if skeleton.find_bone(candidate) >= 0:
			chosen = candidate
			break
	if chosen.is_empty():
		print("[SHOWCASE_HAND_BONE_MISSING] rig=",id)
		return
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.bone_name = chosen
	attachment.name = "ShowcaseSwordHand"
	skeleton.add_child(attachment)
	var weapon: Node3D = _new_sword_model()
	if weapon == null: return
	attachment.add_child(weapon)
	weapon.position = Vector3(0.02,0.5,0.01)
	weapon.rotation_degrees = Vector3(0.0,0.0,90.0)
	weapon.visible = false
	weapons[id] = weapon
	print("[SHOWCASE_SWORD_HAND] rig=",id," bone=",chosen)

func _new_sword_model() -> Node3D:
	if not ResourceLoader.exists(SWORD): return null
	var packed: PackedScene = load(SWORD) as PackedScene
	if packed == null: return null
	var sword: Node3D = packed.instantiate() as Node3D
	return sword

func _install_ground_sword() -> void:
	ground_sword = _new_sword_model()
	sword_available = ground_sword != null
	if not sword_available:
		push_warning("[SHOWCASE_SWORD_NOT_INSTALLED] Run RUN.bat to install Kenney mini-arena original sword and texture.")
		return
	get_tree().current_scene.add_child.call_deferred(ground_sword)
	# Node enters the world on the next idle cycle; positioning is handled there.
	call_deferred("_set_ground_sword_position")

func _set_ground_sword_position() -> void:
	if not is_instance_valid(ground_sword): return
	ground_sword.global_position = home + Vector3(0.0,0.08,0.9)
	ground_sword.rotation_degrees = Vector3(0,0,90)
	ground_sword.visible = not held_sword

func _resolve(mixer: AnimationPlayer, choices: Array) -> String:
	for candidate in choices:
		var desired: String = String(candidate)
		if mixer.has_animation(desired): return desired
		for available in mixer.get_animation_list():
			var actual: String = String(available)
			if actual.to_lower().replace("_loop","").replace("_","").replace(" ","") == desired.to_lower().replace("_loop","").replace("_","").replace(" ",""):
				return actual
	return ""

func _play_step(index: int) -> void:
	if sequence.is_empty(): return
	step_index = posmod(index,sequence.size())
	time_in_step = 0.0
	had_cast = false
	jumped_again = false
	step_start = position
	var entry: Dictionary = sequence[step_index]
	var requested: String = String(entry["rig"])
	for key in rigs.keys():
		var model: Node3D = rigs[key] as Node3D
		model.visible = key == requested
	selected_rig = requested
	selected_clip = ""
	if not mixers.has(requested):
		report = "MISSING SOURCE ASSET: "+requested
	else:
		var mixer: AnimationPlayer = mixers[requested] as AnimationPlayer
		selected_clip = _resolve(mixer,entry["clips"])
		if selected_clip.is_empty():
			report = "MISSING ANIMATION: "+str(entry["clips"])
			missing_count += 1
			var idle: String = _resolve(mixer,["Idle","Idle_Loop","Sentinel","A_TPose"])
			if not idle.is_empty(): mixer.play(idle,0.15)
		else:
			report = requested + "  |  " + selected_clip
			mixer.play(selected_clip,0.20)
			mixer.speed_scale = 0.0 if paused_preview else 1.0
	_update_sword_visibility()
	if String(entry["special"]) == "drop" or step_index == 0:
		_drop_sword()
	stage_label.text = "%02d / %02d   %s\n%s" % [step_index+1,sequence.size(),String(entry["title"]),report]
	print("[SINGLE_SHOWCASE_STEP] index=",step_index+1," title=",entry["title"]," rig=",selected_rig," clip=",selected_clip," has_sword=",held_sword)

func _update_sword_visibility() -> void:
	for key in weapons.keys():
		var sword: Node3D = weapons[key] as Node3D
		sword.visible = held_sword and key == selected_rig
	if is_instance_valid(ground_sword): ground_sword.visible = not held_sword

func _take_sword() -> void:
	if not sword_available:
		stage_label.text += "\nMISSING SWORD ASSET"
		return
	if not weapons.has(selected_rig):
		stage_label.text += "\nNO RIGHT-HAND ATTACHMENT"
		return
	held_sword = true
	sword_pickup_complete = true
	_update_sword_visibility()
	print("[SHOWCASE_SWORD_PICKUP] actor=performer rig=",selected_rig)

func _drop_sword() -> void:
	if held_sword: print("[SHOWCASE_SWORD_DROP] actor=performer")
	held_sword = false
	sword_pickup_complete = false
	_update_sword_visibility()
	_set_ground_sword_position()

func next_action() -> void:
	var next: int = (step_index+1)%sequence.size()
	if String(sequence[next]["special"]) == "sword" and not held_sword:
		next = _pickup_index()
	_play_step(next)

func previous_action() -> void:
	_play_step(step_index-1)

func replay_action() -> void:
	_play_step(step_index)

func pause_action() -> void:
	paused_preview = not paused_preview
	if mixers.has(selected_rig):
		var mixer: AnimationPlayer = mixers[selected_rig] as AnimationPlayer
		mixer.speed_scale = 0.0 if paused_preview else 1.0
	print("[SHOWCASE_PAUSE] paused=",paused_preview)

func _pickup_index() -> int:
	for i in range(sequence.size()):
		if String(sequence[i]["special"]) == "pickup": return i
	return 0

func status_text() -> String:
	if sequence.is_empty(): return "no test program"
	var title: String = String(sequence[step_index]["title"])
	var duration: float = float(sequence[step_index]["duration"])
	var seconds_left: float = maxf(0.0,duration-time_in_step)
	return "%d / %d    %s\n%s    |    %.1fs left    |    SWORD %s%s" % [
		step_index+1, sequence.size(),title,report,seconds_left,
		"EQUIPPED" if held_sword else ("ON GROUND" if sword_available else "MISSING"),
		"    |    PAUSED" if paused_preview else ""
	]

func _process(delta: float) -> void:
	if paused_preview or sequence.is_empty(): return
	var dt: float = minf(delta,0.1)
	time_in_step += dt
	var entry: Dictionary = sequence[step_index]
	var duration: float = maxf(0.1,float(entry["duration"]))
	var progress: float = clampf(time_in_step/duration,0.0,1.0)
	var velocity: Vector3 = entry["velocity"]
	var desired: Vector3 = step_start + velocity * minf(time_in_step,1.2)
	desired.x = clampf(desired.x,home.x-2.4,home.x+2.4)
	desired.z = clampf(desired.z,home.z-2.4,home.z+2.4)
	if velocity.length_squared() > 0.01 and not selected_clip.is_empty():
		position.x = move_toward(position.x,desired.x,dt*maxf(2.0,velocity.length()*2.0))
		position.z = move_toward(position.z,desired.z,dt*maxf(2.0,velocity.length()*2.0))
	else:
		position.x = move_toward(position.x,home.x,dt*3.0)
		position.z = move_toward(position.z,home.z,dt*3.0)
	var height: float = float(entry["height"])
	if height > 0 and not selected_clip.is_empty():
		if String(entry["special"]) == "flight":
			position.y = home.y + height*smoothstep(0.0,0.18,progress)*(1.0-smoothstep(0.82,1.0,progress))
		elif String(entry["special"]) == "double":
			var arc1: float = 0.40*sin(PI*minf(progress*2.0,1.0))
			var arc2: float = 0.75*sin(PI*clampf((progress-0.35)/0.65,0.0,1.0))
			position.y = home.y + height*(arc1+arc2)
			if progress >= 0.40 and not jumped_again:
				jumped_again = true
				var mixer: AnimationPlayer = mixers[selected_rig] as AnimationPlayer
				mixer.play(selected_clip,0.13)
		else:
			position.y = home.y + height*sin(PI*progress)
	else:
		position.y = move_toward(position.y,home.y,dt*8.0)
	if String(entry["special"]) == "pickup" and progress >= 0.58 and not sword_pickup_complete:
		_take_sword()
	if String(entry["effect"]) != "" and not had_cast and progress > 0.32 and not selected_clip.is_empty():
		had_cast = true
		_cast_effect(String(entry["effect"]))
	if time_in_step >= duration:
		next_action()

func _cast_effect(kind: String) -> void:
	var path: String = "res://assets/external_vfx/fire.tscn" if kind == "fire" else "res://assets/external_vfx/water.tscn"
	var packed: PackedScene = load(path) as PackedScene
	if packed == null: return
	var fx: GPUParticles3D = packed.instantiate() as GPUParticles3D
	if fx == null: return
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position + Vector3(0,1.35,0.7)
	fx.one_shot = true
	fx.emitting = true
	fx.lifetime = 0.75
	fx.amount = 50
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(fx,"global_position",fx.global_position+Vector3(0,0,4.2),0.55)
	get_tree().create_timer(0.55).timeout.connect(func() -> void:
		if not is_instance_valid(fx): return
		var impact: GPUParticles3D = packed.instantiate() as GPUParticles3D
		if impact != null:
			get_tree().current_scene.add_child(impact)
			impact.global_position = fx.global_position
			impact.one_shot = true
			impact.lifetime = 0.60
			impact.scale = Vector3.ONE*1.6
			impact.emitting = true
			get_tree().create_timer(1.3).timeout.connect(func() -> void:
				if is_instance_valid(impact): impact.queue_free()
			)
	)
	get_tree().create_timer(1.7).timeout.connect(func() -> void:
		if is_instance_valid(fx): fx.queue_free()
	)
