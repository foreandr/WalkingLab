extends Node3D
# Animation-only performer. Every displayed pose comes from an imported CC0 clip.
# This script does not invent procedural limb animations or substitute jogging for strafing.
var performer_index: int = 0
var source_file: String = "res://assets/source_original.glb"
var anim: AnimationPlayer
var figure: Node3D
var caption: Label3D
var program: Array = []
var current: Dictionary = {}
var step_index: int = -1
var elapsed: float = 0.0
var home: Vector3 = Vector3.ZERO
var travel: Vector3 = Vector3.ZERO
var fx_fired: bool = false
var missing_clips: Array[String] = []
var airborne: bool = false

func task(title: String, names: Array, seconds: float, velocity: Vector3 = Vector3.ZERO, height: float = 0.0, effect: String = "") -> Dictionary:
	return {"title":title, "names":names, "seconds":seconds, "velocity":velocity, "height":height, "effect":effect}

func _ready() -> void:
	home = position
	var imported: Resource = load(source_file)
	if not (imported is PackedScene):
		push_error("[SHOWCASE_ASSET_MISSING] " + source_file)
		return
	figure = (imported as PackedScene).instantiate() as Node3D
	add_child(figure)
	var players: Array[Node] = figure.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("[SHOWCASE_ANIMATOR_MISSING] " + source_file)
		return
	anim = players[0] as AnimationPlayer
	anim.playback_default_blend_time = 0.20
	# The unmodified imported GLB is the animation authority.
	program = make_program(performer_index)
	caption = Label3D.new()
	caption.text = "LOADING"
	caption.font_size = 42
	caption.pixel_size = 0.005
	caption.outline_size = 11
	caption.modulate = Color("e5ecff")
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.no_depth_test = true
	caption.position = Vector3(0, 2.55, 0)
	add_child(caption)
	_next_step()
	print("[SHOWCASE_ACTOR] index=", performer_index, " asset=", source_file, " total_clips=", anim.get_animation_list().size())

func make_program(i: int) -> Array:
	match i:
		0: return [
			task("WALK", ["Walk", "Walk_Loop"], 2.6, Vector3(0,0,-1.5)),
			task("JOG", ["Jog_Fwd", "Jog_Fwd_Loop"], 2.6, Vector3(0,0,-4.2)),
			task("SPRINT", ["Sprint", "Sprint_Loop"], 2.3, Vector3(0,0,-6.0)),
		]
		1: return [
			task("STRAFE LEFT", ["Jog_Left", "Jog_Left_Loop", "Walk_Left", "Walk_Left_Loop", "Strafe_Left"], 2.5, Vector3(-3.0,0,0)),
			task("STRAFE RIGHT", ["Jog_Right", "Jog_Right_Loop", "Walk_Right", "Walk_Right_Loop", "Strafe_Right"], 2.5, Vector3(3.0,0,0)),
			task("BACKPEDAL", ["Jog_Back", "Jog_Back_Loop", "Walk_Back", "Walk_Back_Loop", "Jog_Bwd"], 2.5, Vector3(0,0,2.0)),
		]
		2: return [
			task("JUMP", ["Jump_Start", "Jump"], 1.25, Vector3(0,0,-1.1), 1.8),
			task("DOUBLE JUMP / REPLAY", ["Jump", "Jump_Loop", "Jump_Start"], 1.85, Vector3(0,0,-1.5), 3.1),
			task("LAND", ["Jump_Land"], 1.2),
		]
		3: return [
			task("NINJA TAKEOFF", ["NinjaJump_Start"], 1.4, Vector3(0,0,-1.2), 2.2),
			task("NINJA AIRBORNE", ["NinjaJump_Idle_Loop"], 2.7, Vector3(0,0,-2.0), 3.2),
			task("NINJA LAND", ["NinjaJump_Land"], 1.3),
		]
		4: return [
			task("BACKFLIP (AUTHORED CLIP ONLY)", ["Backflip", "Back_Flip", "Flip_Back", "BackFlip"], 2.0, Vector3.ZERO, 2.3),
			task("SIDE FLIP (AUTHORED CLIP ONLY)", ["SideFlip", "Side_Flip", "Cartwheel", "Aerial"], 2.0, Vector3.ZERO, 2.3),
			task("FORWARD ROLL", ["Roll", "Roll_RM"], 1.7, Vector3(0,0,-1.5)),
		]
		5: return [
			task("FLIGHT / AIR POSE", ["NinjaJump_Idle_Loop"], 3.6, Vector3(0,0,-3.0), 4.2),
			task("AERIAL TAKEOFF", ["NinjaJump_Start"], 1.25, Vector3.ZERO, 2.3),
			task("AERIAL LAND", ["NinjaJump_Land"], 1.3),
		]
		6: return [
			task("FIRE CAST", ["Spell_Simple_Shoot", "Spell_Simple_Enter"], 1.55, Vector3.ZERO, 0.0, "fire"),
			task("SPELL READY", ["Spell_Simple_Idle", "Spell_Simple_Idle_Loop"], 1.4),
			task("RELEASE", ["Spell_Simple_Exit"], 1.05),
		]
		7: return [
			task("WATER CAST", ["Spell_Simple_Shoot", "Spell_Simple_Enter"], 1.55, Vector3.ZERO, 0.0, "water"),
			task("SPELL READY", ["Spell_Simple_Idle", "Spell_Simple_Idle_Loop"], 1.4),
			task("RELEASE", ["Spell_Simple_Exit"], 1.05),
		]
		8: return [
			task("SWORD COMBO", ["Sword_Regular_Combo", "Sword_Regular_A"], 2.4),
			task("SWORD SWING", ["Sword_Regular_B", "Sword_Regular_C"], 1.55),
			task("SWORD BLOCK", ["Sword_Block"], 1.5),
		]
		_: return [
			task("SLIDE", ["Slide_Start", "Slide_Loop"], 2.0, Vector3(0,0,-2.0)),
			task("PARKOUR CLIMB", ["ClimbUp_1m_RM", "ClimbUp_1m"], 2.0, Vector3.ZERO, 1.2),
			task("NINJA JUMP", ["NinjaJump_Start", "NinjaJump_Land"], 1.7, Vector3.ZERO, 1.6),
			task("OVERHAND THROW", ["OverhandThrow"], 1.5, Vector3.ZERO, 0.0, "fire"),
		]

func _resolve_clip(options: Array) -> String:
	if anim == null: return ""
	for requested in options:
		var key: String = String(requested)
		if anim.has_animation(key): return key
		for actual in anim.get_animation_list():
			var normalized: String = String(actual).to_lower().replace("_loop","").replace("_","").replace(" ","")
			var desired: String = key.to_lower().replace("_loop","").replace("_","").replace(" ","")
			if normalized == desired: return actual
	return ""

func _next_step() -> void:
	if anim == null or program.is_empty(): return
	step_index = (step_index + 1) % program.size()
	current = program[step_index]
	elapsed = 0.0
	fx_fired = false
	travel = Vector3.ZERO
	figure.position = Vector3.ZERO
	var clip: String = _resolve_clip(current["names"])
	if clip.is_empty():
		var unavailable: String = String(current["title"])
		if not missing_clips.has(unavailable): missing_clips.append(unavailable)
		print("[SHOWCASE_MISSING_CLIP] performer=", performer_index, " requested=", unavailable, " candidates=", current["names"], " file=", source_file)
		caption.text = "%02d  %s\nNOT IN LICENSED PACK" % [performer_index + 1, unavailable]
		var idle: String = _resolve_clip(["Idle", "Idle_Loop", "Idle_No_Loop", "A_TPose"])
		if not idle.is_empty(): anim.play(idle, 0.22)
		current["resolved"] = ""
	else:
		current["resolved"] = clip
		caption.text = "%02d  %s\n%s" % [performer_index + 1, String(current["title"]), clip]
		anim.play(clip, 0.24)
		if anim.get_animation(clip).length > 0.1:
			anim.speed_scale = 1.0
		print("[SHOWCASE_CLIP] performer=", performer_index, " title=", current["title"], " actual=", clip)
	airborne = float(current["height"]) > 0.0

func _process(delta: float) -> void:
	if anim == null or current.is_empty(): return
	elapsed += delta
	var duration: float = maxf(0.1, float(current["seconds"]))
	if elapsed >= duration:
		_next_step()
		return
	var t: float = clampf(elapsed / duration, 0.0, 1.0)
	var velocity: Vector3 = current["velocity"]
	if velocity.length_squared() > 0.01 and not String(current["resolved"]).is_empty():
		# Integrate actual travel while keeping every performer inside its own lane.
		var intended: Vector3 = home + velocity * (t * duration)
		var max_travel: float = 3.7
		position.x = home.x + clampf(intended.x-home.x, -max_travel, max_travel)
		position.z = home.z + clampf(intended.z-home.z, -max_travel, max_travel)
		if velocity.x != 0.0:
			# Strafing keeps a fixed forward heading; no turn-to-walk substitution.
			rotation.y = 0.0
		else:
			rotation.y = 0.0 if velocity.z < 0.0 else PI
	else:
		position.x = move_toward(position.x, home.x, delta*4.0)
		position.z = move_toward(position.z, home.z, delta*4.0)
	if airborne:
		var height: float = float(current["height"])
		if String(current["title"]).begins_with("DOUBLE JUMP"):
			# Two visible vertical impulses, using the imported jump motion.
			var phase: float = t*2.0
			position.y = home.y + height*(0.34 if phase < 1.0 else 0.55) + height*0.45*sin(PI*fmod(phase,1.0))
		elif String(current["title"]).begins_with("FLIGHT"):
			position.y = home.y + height * smoothstep(0.0,0.20,t) * (1.0-smoothstep(0.82,1.0,t))
		else:
			position.y = home.y + height*sin(PI*t)
	else:
		position.y = move_toward(position.y, home.y, delta*9.0)
	if not fx_fired and String(current["effect"]) != "" and elapsed > 0.35:
		fx_fired = true
		_cast_fx(String(current["effect"]))

func _cast_fx(kind: String) -> void:
	var path: String = "res://assets/external_vfx/water.tscn" if kind == "water" else "res://assets/external_vfx/fire.tscn"
	if not ResourceLoader.exists(path):
		push_warning("[SHOWCASE_VFX_MISSING] " + path)
		return
	var effect: GPUParticles3D = (load(path) as PackedScene).instantiate() as GPUParticles3D
	if effect == null: return
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position + Vector3(0, 1.4, -0.6)
	effect.one_shot = true
	effect.amount = 48
	effect.lifetime = 0.70
	effect.emitting = true
	var tween: Tween = create_tween()
	tween.tween_property(effect, "global_position", effect.global_position+Vector3(0,0,-5.5), 0.48)
	var timer: SceneTreeTimer = get_tree().create_timer(0.48)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(effect): return
		var impact: GPUParticles3D = (load(path) as PackedScene).instantiate() as GPUParticles3D
		get_tree().current_scene.add_child(impact)
		impact.global_position = effect.global_position
		impact.one_shot = true
		impact.amount = 64
		impact.lifetime = 0.55
		impact.scale = Vector3.ONE * 1.7
		impact.emitting = true
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if is_instance_valid(impact): impact.queue_free()
		)
	)
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(effect): effect.queue_free()
	)
