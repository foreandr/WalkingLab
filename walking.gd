extends Node3D
@export var player_controlled = false
@export var actor_only = false
@export var autonomous_only = false
@export var stationary_only = false
@export var animation_test_mode: String = ""
@export var animation_test_speed: float = 15.0
var animation_test_phase: String = "wait"
var animation_test_clock: float = 0.0
var animation_test_landing_speed: float = 0.0
var animation_test_home: Vector3 = Vector3.ZERO
var animation_test_angle: float = 0.0
var animation_test_orbit_radius: float = 7.0
@export var ai_abilities = false
@export var ai_mode: String = ""
var idle_variants: Array[String] = []
var jab_ready := false
var jab_cooldown := 0.0
var jab_aim_remaining := 0.0
var jab_aim_target := Vector3.ZERO
var jab_strike_target: Vector3 = Vector3.ZERO
var punch_pending: bool = false
var punch_clock: float = 0.0
var punch_hand: String = "right"
var jab_left_arm := -1
var jab_left_forearm := -1
var jab_left_hand := -1
var jab_right_arm := -1
var jab_right_forearm := -1
var jab_right_hand := -1
var controlled_arm := "right"
var jab_aim_strength := 0.0
# Combat tempo: quicker arm extension / recovery, without time-scale cheats.
# Release near full extension (0.44/0.68 ~= 65%) for readable impacts.
const CAST_DURATION: float = 0.68
const CAST_RELEASE: float = 0.44
var cast_aim_point: Vector3 = Vector3.ZERO
var cast_shot_direction: Vector3 = Vector3.FORWARD
var cast_elapsed: float = -1.0
var cast_released: bool = false
var cast_arm_name: String = ""
var cast_element: String = "fire"
# Each fused cast spawns one projectile with two independent effect components.
var cast_components: Array[String] = []
const FUSION_INPUT_WINDOW_MS: int = 320
var pending_spell_slots: Array[int] = []
var pending_spell_since_ms: int = 0
var pending_spell_arm: String = ""
var fusion_feedback: String = ""
var fusion_feedback_remaining: float = 0.0
# Five fingers per hand. Shift changes which complete set 1-5 operates.
# RIGHT: Ember, Frost, Homing Missile, Gravity, Ricochet.
# LEFT: Grounding, Bloom, Tempest, Venom, Flight.
const SPELL_NAMES: Array[String] = ["Cinderburst","Permafrost","Soulseeker","Voidwell","Everbound","Earthbind","Lifeweave","Galeforce","Blight","Ascension"]
# Internal IDs intentionally stay stable; these are canonical displayed names.
const SPELL_EFFECTS: Array[String] = [
	"Explosive fire wave and lingering burns",
	"Wide ice burst; 88% movement reduction for 5 seconds",
	"A guided missile that vanishes after 4 seconds or on contact",
	"Gravity well that draws nearby opponents inward",
	"Persistent orb that ricochets off arena surfaces",
	"Grounding blast; cancels flight for 6 seconds",
	"18-metre ally-only pulse; heals all six regions and regenerates",
	"Wind burst that launches opponents away",
	"Poison explosion and damage over time",
	"Toggle magical flight; stopped by Earthbind"
]
const SPELL_IDS: Array[String] = ["fire","frost","homing","gravity","ricochet","grounding","bloom","tempest","venom","flight"]
# Lifeweave and Ascension remain standalone, non-projectile abilities.
const FUSION_PROJECTILES: Array[String] = ["fire","frost","homing","gravity","ricochet","grounding","tempest","venom"]
const FUSION_NAMES: Dictionary = {
	"fire+frost":"Thermal Rupture",
	"fire+homing":"Hellseeker",
	"fire+gravity":"Cinder Singularity",
	"fire+ricochet":"Wildfire Orbit",
	"frost+homing":"Winter's Pursuit",
	"frost+gravity":"Frozen Abyss",
	"frost+ricochet":"Glacial Rebound",
	"homing+gravity":"Event Horizon",
	"homing+ricochet":"Relentless Wisp",
	"gravity+ricochet":"Orbitbreaker",
	"grounding+tempest":"Skybreaker",
	"grounding+venom":"Withering Earth",
	"tempest+venom":"Plague Gale"
}
const SPELL_COSTS: Array[float] = [15.0,20.0,22.0,30.0,24.0,26.0,35.0,22.0,20.0,18.0]
# Faster exchanges; persistent Everbound retains the longer 7s gate.
const SPELL_COOLDOWNS: Array[float] = [1.6,5.2,3.0,6.2,7.0,5.5,9.0,4.5,5.2,3.0]
const SPELL_COLORS: Array[Color] = [Color("ff9b4f"),Color("7de8ff"),Color("f8e365"),Color("af83fa"),Color("ff5ee7"),Color("f9d474"),Color("a6f4bc"),Color("99e5e9"),Color("9cdd59"),Color("f0f0ff")]
const MAX_ACTIVE_RICOCHETS: int = 20
var spell_remaining: Array[float] = [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
var mana: float = 100.0
var infinite_mana: bool = false
var ignore_spell_cooldowns: bool = false
var stamina: float = 100.0
var sprint_exhausted: bool = false
var spell_regen_remaining: float = 0.0
var spell_regen_tick: float = 0.0
var spell_slots: Array[Label] = []
var hand_indicator: Label
var stamina_progress: ProgressBar
var mana_progress: ProgressBar
var resources_status: Label
var settings_stats: Label
var cast_last_hand: Vector3 = Vector3.ZERO
var cast_hand_velocity: Vector3 = Vector3.ZERO
var cursor_reticle: Control
var was_moving_for_idle := false
var spawn_point = Vector3(0,0,40)
var route_center = Vector3.ZERO
var route_radius = 40.0
# The anatomical damage shader colors injured limbs; healthy skin is white.
var character_tint = Color.WHITE
var manual_input = Vector2.ZERO
var manual_side_speed: float = 0.0
# Only the opt-in flight benchmark drives these controls.
var benchmark_flight_active: bool = false
var benchmark_flight_axis: Vector2 = Vector2.ZERO
var benchmark_flight_direction: Vector3 = Vector3.ZERO
var auto_war_combat: bool = false
var auto_war_cast_clock: float = 0.0
var manual_launch_lock = false
# A quick Alt tap and release followed by a held second Alt engages a dash.
var alt_press_begin_ms: int = -100000
var alt_last_short_release_ms: int = -100000
var alt_dash_held: bool = false
var flight_dash_speed: float = 0.0
const ALT_DOUBLE_TAP_WINDOW_MS: int = 380
const ALT_FIRST_TAP_MAX_MS: int = 280
const DASH_GROUND_SPEED: float = 18.0
const DASH_FLIGHT_SPEED: float = 28.0
var manual_sprint_clock = 0.0
var flight_acceleration_time: float = 0.0
var flying_clip: Dictionary = {}
var backward_flying_clip: Dictionary = {}
var selected_spell_target: CharacterBody3D = null
var lock_marker: Label3D = null
var movement_clips: Dictionary = {}
var solo_left_strafe_available: bool = false
var solo_right_strafe_available: bool = false
var ring_inventory_panel: PanelContainer = null
var demo_immortal: bool = false
var equipped_spells: Array[String] = ["fire"]
var ring_inventory_text: Label = null
# Smooth, persistent crossfade weights shared by player and motion showcase.
var strafe_left_blend: float = 0.0
var strafe_right_blend: float = 0.0
const STRAFE_VISUAL_YAW: float = 55.0
const STRAFE_FORWARD_LEAN_DEGREES: float = 34.0
const STRAFE_BLEND_RATE: float = 8.0
const STRAFE_ACTIVATE_SPEED: float = 1.25
# Black only: travel twice as far sideways while strafe clips play half as fast.
# Keep these independent so movement distance does not speed up the animation.
const STRAFE_TRAVEL_MULTIPLIER: float = 2.0
const STRAFE_PLAYBACK_MULTIPLIER: float = 0.5
# All arena combatants use the same imported rig. Share immutable retargeted
# animation curves rather than import and retarget twenty FBX files per fighter.
static var shared_flight_clips_ready: bool = false
static var shared_flying_clip: Dictionary = {}
static var shared_backward_flying_clip: Dictionary = {}
static var shared_movement_clips: Dictionary = {}
var movement_clip_name: String = ""
var combat_dead: bool = false
var combat_death_time: float = 0.0
var combat_pose_frozen: bool = false
var ragdoll: Node = null
var combat_last_velocity: Vector3 = Vector3.ZERO
var combat_initial_pitch: float = 0.0
var combat_falling: bool = false
var combat_hit_sequence: int = 0
var movement_clip_time: float = 0.0
var injury_walk_time: float = 0.0
var jump_clip_pending: bool = false
var squat_amount: float = 0.0
var squat_key_down: bool = false
var squat_hold_seconds: float = 0.0
const SQUAT_MAX_CHARGE_SECONDS: float = 2.0
# Keep the normal jump high and the fully charged jump exactly three times
# its apex height. With unchanged gravity, h = v^2 / (2g), so the
# charged launch impulse must be sqrt(3) times the normal impulse.
# Roughly 4 m normal and 12 m charged at gravity = 18 m/s^2.
const SQUAT_HOP_IMPULSE: float = 12.0
const SQUAT_MAX_HOP_IMPULSE: float = 20.784609690826528 # 12 * sqrt(3)
const AIR_JUMP_TRAVEL_MULTIPLIER: float = 1.41421356
const SQUAT_BLEND_SPEED: float = 1.8
var debug_tick: float = 0.0
var last_debug_state: String = ""
var vertical_jump_speed: float = 0.0
const SIMPLE_JUMP_IMPULSE: float = 6.0
const SIMPLE_JUMP_GRAVITY: float = 18.0

var flight_animation_time: float = 0.0
var flight_visual_pitch: float = 0.0
var flight_pose_weight: float = 0.0
var flight_idle_weight: float = 0.0
var flight_idle_time: float = 0.0
var flight_idle_active: bool = false
var flight_clip_warning_shown: bool = false
var speed_streaks: Control
var streak_clock: float = 0.0
var ai_action_clock: float = 0.0
var war_target: Node3D = null
var war_decision_timer: float = 0.0
var war_strafe_sign: float = 1.0
var war_physics_accumulator: float = 0.0
var war_lod_mode: String = "full"
# Synchronized distance-comparison mannequins retain their positions and
# fire the same spell toward the player, without pursuit/target switching.
var animation_lineup_mode: bool = false
var lineup_cast_clock: float = 0.0
# Spell-test targets: remain hittable but do not attack or hunt the player.
# Each walker orbits a local anchor so targets remain within the test range.
var spell_target_mode: String = ""
# Scripted pursuit cast: four autonomous rigs share real collision and spells.
# Player + three blue allies versus four red enemies in team mode.
var team_id: String = ""
var team_battle_ai: bool = false
var status_label: Label3D = null
var team_decision_timer: float = 0.0
var team_strafe_sign: float = 1.0
var team_mobility_timer: float = 0.0
var team_clear_shot: bool = true
var team_projectile_dodge: Vector3 = Vector3.ZERO
var pursuit_role: String = ""
var pursuit_home: Vector3 = Vector3.ZERO
var pursuit_cast_timer: float = 0.0
var pursuit_spell_cursor: int = 0
var pursuit_plan_timer: float = 0.0
var blink_cooldown_remaining: float = 0.0
const BLINK_DISTANCE: float = 9.5
const BLINK_COOLDOWN: float = 4.0
const BLINK_MANA_COST: float = 15.0
var pursuit_flight_preference: bool = false
var spell_target_anchor: Vector3 = Vector3.ZERO
var spell_walker_phase: float = 0.0
var spell_burn_remaining: float = 0.0
var spell_burn_tick: float = 0.0
var spell_frost_remaining: float = 0.0
var spell_grounded_remaining: float = 0.0
var spell_gravity_remaining: float = 0.0
var spell_gravity_origin: Vector3 = Vector3.ZERO
var spell_venom_remaining: float = 0.0
var spell_venom_tick: float = 0.0
var spell_tempest_remaining: float = 0.0
var spell_tempest_direction: Vector3 = Vector3.ZERO

var war_profile_counter: int = 0
var war_visual_accumulator: float = 0.0
var war_visual_updates: int = 0
var war_visual_skips: int = 0
var war_physics_updates: int = 0
var war_physics_skips: int = 0
var war_tactical_clock: float = 0.0
var war_flight_preference: bool = false
var war_cached_retreat: bool = false
var war_cached_dodge: Vector3 = Vector3.ZERO
var flight_enabled: bool = false
var flight_windup_remaining: float = 0.0
const FLIGHT_WINDUP_SECONDS: float = 0.35
var flight_launch_remaining: float = 0.0
var flight_clearance_time: float = 0.0
const FLIGHT_LAUNCH_DURATION: float = 0.65
const FLIGHT_LAUNCH_SPEED: float = 14.0
const FLIGHT_LAND_HEIGHT: float = 0.42
const FLIGHT_SPEED: float = 7.0
var camera_sensitivity: float = 1.0
var fireball_speed_scale: float = 1.0
var war_pose_enabled: bool = false
var options_panel: PanelContainer
# Seconds per smooth 6 -> 8 -> 10 -> 12 m/s sprint stage.
# Above 12 m/s, keep the final FastRun clip and gain 0.2 m/s per stage duration.
const ENDLESS_SPRINT_GAIN = 0.2
const SPRINT_STAGE_SECONDS = 0.7
var manual_heading = 0.0
var agent_rng := RandomNumberGenerator.new()
var agent_destination: Vector3 = Vector3.ZERO
var agent_decision_left: float = 0.0
var agent_preferred_speed: float = 0.0
var solo_landing_logged: bool = false
var camera_target: CharacterBody3D

const LABELS = ["WALK", "EASY RUN", "RUN", "STANDARD RUN", "FAST RUN", "QUICK RUN"]
const NAMES = ["PreviousWalk", "EasyRun", "Run", "StandardRun", "QuickRun", "FastRun"]
const SPEEDS = [2.295,4.0,6.0,8.0,10.0,12.0]
const STRIDES = [1.8247359725,2.0463959811,2.9254565804,3.0925173375,3.5791259432,2.8810510397]
const FILE_LABELS = ["previous walk", "Running (1).fbx", "Running.fbx", "Standard Run.fbx", "Fast Run.fbx", "Running (3).fbx"]
const BACK_NAMES = ["BackWalk", "BackRun", "BackQuickRun"]
const BACK_LABELS = ["BACKWARD WALK", "BACKWARD RUN", "QUICK BACKWARD RUN"]
const BACK_FILES = ["Walking Backwards.fbx", "Running Backward.fbx", "Run Backward.fbx"]
const BACK_SPEEDS = [1.4,4.2,7.0]
const BACK_STRIDES = [1.2861592747,1.9162409005,1.9161717009]
const LAP_RADIUS = 40.0
var actor: CharacterBody3D
var visual: Node3D
var native_idle_model: Node3D
var native_idle_playing := false
var native_idle_source_rig: Skeleton3D
var native_idle_driver: AnimationPlayer
var native_idle_bones: Array = []
var native_idle_weight := 0.0
var skeleton: Skeleton3D
var tree: AnimationTree
var camera: Camera3D
var hud: Label
var feet = preload("res://foot_ground.gd").new()
var crouch = preload("res://crouch_controller.gd").new()
var camera_focus_height = 1.05
var clock = 0.0
var speed = 0.0
var blend = 0.0
var paused = false
var slow = false
var orbit = 0.0 # Player begins facing the stationary opponent along -Z
var elevation = -0.18
var distance = 5.8
var frame = 0
var test = false
var min_sole = INF
var min_body = INF
var max_lift = 0.0
var traveled = 0.0
var seen = {}
var max_step = 0.0
var started = 0
var walk_choice = 0.0
var walk_target = 0.0
var mode_clock = 0.0
var backward = true
var back_blend = 0.0
var direction_weight = 1.0
var signed_speed = -BACK_SPEEDS[0]
var turning = false
var turn_time = 0.0
var turn_target = false
var turn_start_speed = 0.0
var turn_start_weight = 0.0
var turn_start_forward = 0.0
var turn_start_back = 0.0
var backward_distance = 0.0
var minimum_facing_alignment = 1.0
func _ready():
	var init_started_usec: int = Time.get_ticks_usec()
	var init_checkpoint_usec: int = init_started_usec
	test = "--autotest" in OS.get_cmdline_user_args()
	if "--new-walk" in OS.get_cmdline_user_args():
		walk_target = 1.0
		walk_choice = 1.0
		backward = false
		direction_weight = 0.0
		signed_speed = SPEEDS[0]
	started = Time.get_ticks_msec()
	if ai_mode != "" or ai_abilities:
		agent_rng.randomize()
		agent_rng.seed = agent_rng.randi() ^ hash(name)
		agent_preferred_speed = (2.0 if ai_mode == "walk" else (10.0 if ai_mode == "sprint" else 7.5)) * agent_rng.randf_range(0.85,1.15)
		choose_agent_destination()
		# Stagger squad casts so all seven NPCs do not allocate spell VFX
		# on the same physics tick.
		if team_battle_ai: pursuit_cast_timer = agent_rng.randf_range(0.12,0.72)
	if not actor_only:
		add_child(preload("res://arena_environment.gd").new())
		var floor_body = StaticBody3D.new()
		add_child(floor_body)
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(1400,0.2,1400)
		shape.shape = box
		shape.position.y = -0.1
		floor_body.add_child(shape)
	actor = CharacterBody3D.new()
	add_child(actor)
	add_to_group("combat_fighters")
	if ai_mode != "" or ai_abilities: add_to_group("walking_agents")
	actor.position = spawn_point
	actor.rotation.y = -PI/2
	actor.floor_snap_length = 0.12
	actor.safe_margin = 0.003
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	actor.add_child(collision)
	var model_begin_usec: int = Time.get_ticks_usec()
	visual = preload("res://assets/user_mixamo.glb").instantiate()
	actor.add_child(visual)
	if autonomous_only: print("[FIGHTER_INIT_PHASE] fighter=",name," phase=model_attach ms=",snappedf(float(Time.get_ticks_usec()-model_begin_usec)/1000.0,0.01))
	visual.rotation.y = PI
	skeleton = visual.find_children("*","Skeleton3D",true,false)[0]
	# PhysicalBoneSimulator disabled until rest transforms and joint axes
	# are calibrated to this imported rig. Avoid stretching the live mesh.
	ragdoll = null
	var damage_system = preload("res://combat_damage.gd").new()
	damage_system.name = "DamageSystem"
	add_child(damage_system)
	damage_system.setup(actor,skeleton)
	var player: AnimationPlayer = visual.find_children("*","AnimationPlayer",true,false)[0]
	if player.has_animation("Sprint"): player.get_animation_library("").remove_animation("Sprint")
	var backwards_begin_usec: int = Time.get_ticks_usec()
	install_backwards(player)
	solo_left_strafe_available = install_solo_left_strafe(player)
	solo_right_strafe_available = install_solo_strafe(player,"Right")
	if autonomous_only: print("[FIGHTER_INIT_PHASE] fighter=",name," phase=backwards ms=",snappedf(float(Time.get_ticks_usec()-backwards_begin_usec)/1000.0,0.01))
	if player_controlled: print("MIXAMO_CLIPS ",player.get_animation_list())
	var white = StandardMaterial3D.new()
	white.albedo_color = character_tint
	white.roughness = 0.8
	for part in visual.find_children("*","MeshInstance3D",true,false): part.material_override = white
	# The damage shader must be installed after the default material,
	# otherwise the default material masks every injury color.
	damage_system.apply_damage_material()
	var space = AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = float(NAMES.size()-1)
	space.sync = true
	for i in range(NAMES.size()):
		var clip_name = NAMES[i]
		if not player.has_animation(clip_name): clip_name += "_Loop"
		assert(player.has_animation(clip_name),"Missing animation: "+clip_name)
		player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
		var clip = AnimationNodeAnimation.new()
		clip.animation = clip_name
		if i==0:
			var walk_graph = AnimationNodeBlendTree.new()
			walk_graph.add_node("Previous",clip)
			var new_walk = AnimationNodeAnimation.new()
			new_walk.animation = "NewWalk"
			player.get_animation("NewWalk").loop_mode = Animation.LOOP_LINEAR
			walk_graph.add_node("New",new_walk)
			var choice = AnimationNodeBlend2.new()
			choice.sync = true
			walk_graph.add_node("Choice",choice)
			walk_graph.connect_node("Choice",0,"Previous")
			walk_graph.connect_node("Choice",1,"New")
			walk_graph.connect_node("output",0,"Choice")
			space.add_blend_point(walk_graph,0.0,-1,"Walk")
		else: space.add_blend_point(clip,float(i),-1,NAMES[i])
	var back_space = AnimationNodeBlendSpace1D.new()
	back_space.min_space = 0.0
	back_space.max_space = 2.0
	back_space.sync = true
	for i in range(3):
		var clip = AnimationNodeAnimation.new()
		clip.animation = "back/"+BACK_NAMES[i]
		back_space.add_blend_point(clip,float(i),-1,BACK_NAMES[i])
	var graph = AnimationNodeBlendTree.new()
	graph.add_node("Gaits",space)
	graph.add_node("BackGaits",back_space)
	var direction_blend = AnimationNodeBlend2.new()
	direction_blend.sync = true
	graph.add_node("Direction",direction_blend)
	graph.connect_node("Direction",0,"Gaits")
	graph.connect_node("Direction",1,"BackGaits")
	if solo_left_strafe_available:
		var solo_strafe := AnimationNodeAnimation.new()
		solo_strafe.animation = "strafe/Left"
		graph.add_node("SoloLeftClip",solo_strafe)
		var solo_blend := AnimationNodeBlend2.new()
		solo_blend.sync = true # Keep both gait clocks advancing across a transition.
		graph.add_node("SoloLeftBlend",solo_blend)
		graph.connect_node("SoloLeftBlend",0,"Direction")
		graph.connect_node("SoloLeftBlend",1,"SoloLeftClip")
	if solo_right_strafe_available:
		var right_clip := AnimationNodeAnimation.new()
		right_clip.animation = "strafe/Right"
		graph.add_node("SoloRightClip",right_clip)
		var right_blend := AnimationNodeBlend2.new()
		right_blend.sync = true
		graph.add_node("SoloRightBlend",right_blend)
		graph.connect_node("SoloRightBlend",0,"SoloLeftBlend" if solo_left_strafe_available else "Direction")
		graph.connect_node("SoloRightBlend",1,"SoloRightClip")
	graph.add_node("Cadence",AnimationNodeTimeScale.new())
	graph.connect_node("Cadence",0,"SoloRightBlend" if solo_right_strafe_available else ("SoloLeftBlend" if solo_left_strafe_available else "Direction"))
	var crouch_begin_usec: int = Time.get_ticks_usec()
	crouch.setup(self,player,graph)
	if autonomous_only: print("[FIGHTER_INIT_PHASE] fighter=",name," phase=crouch ms=",snappedf(float(Time.get_ticks_usec()-crouch_begin_usec)/1000.0,0.01))
	
	var idle_begin_usec: int = Time.get_ticks_usec()
	if player_controlled or stationary_only or ai_abilities: choose_random_idle()
	if autonomous_only: print("[FIGHTER_INIT_PHASE] fighter=",name," phase=idle ms=",snappedf(float(Time.get_ticks_usec()-idle_begin_usec)/1000.0,0.01))
	if player_controlled: print("CROUCH_CLIPS ",player.get_animation_list())
	tree = AnimationTree.new()
	visual.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.tree_root = graph
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	if player_controlled or ai_abilities:
		for bone_i in range(skeleton.get_bone_count()):
			var bone_label = normalized_idle_bone(String(skeleton.get_bone_name(bone_i)))
			if bone_label == "leftarm": jab_left_arm = bone_i
			if bone_label == "leftforearm": jab_left_forearm = bone_i
			if bone_label == "lefthand": jab_left_hand = bone_i
			if bone_label == "rightarm": jab_right_arm = bone_i
			if bone_label == "rightforearm": jab_right_forearm = bone_i
			if bone_label == "righthand": jab_right_hand = bone_i

		if player_controlled: print("JAB_IK_BONES arm=",jab_left_arm," forearm=",jab_left_forearm," hand=",jab_left_hand)
	var flight_begin_usec: int = Time.get_ticks_usec()
	if player_controlled or ai_abilities or ai_mode == "fly" or (name == "DemoNPC" and ai_mode == "sprint") or animation_test_mode != "" or stationary_only: load_flight_clips()
	if autonomous_only: print("[FIGHTER_INIT_PHASE] fighter=",name," phase=flight_clips ms=",snappedf(float(Time.get_ticks_usec()-flight_begin_usec)/1000.0,0.01))
	var feet_begin_usec: int = Time.get_ticks_usec()
	feet.setup(visual,skeleton)
	if autonomous_only: print("[FIGHTER_INIT_PHASE] fighter=",name," phase=feet ms=",snappedf(float(Time.get_ticks_usec()-feet_begin_usec)/1000.0,0.01))
	camera = Camera3D.new()
	camera.fov = 52 if player_controlled else 46
	add_child(camera)
	camera.current = not autonomous_only
	var canvas = CanvasLayer.new()
	add_child(canvas)
	canvas.visible = not autonomous_only
	hud = Label.new()
	hud.position = Vector2(14,48)
	hud.visible = not player_controlled
	hud.add_theme_font_size_override("font_size",16)
	canvas.add_child(hud)
	if player_controlled:
		# Fixed screen-center reticle. All elements ignore mouse input.
		var reticle := Control.new()
		reticle.set_anchors_preset(Control.PRESET_TOP_LEFT)
		cursor_reticle = reticle
		reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(reticle)
		for segment in [
			Rect2(-2.0,-17.0,4.0,12.0),
			Rect2(-2.0,5.0,4.0,12.0),
			Rect2(-17.0,-2.0,12.0,4.0),
			Rect2(5.0,-2.0,12.0,4.0)
		]:
			var outline := ColorRect.new()
			outline.color = Color(0.02,0.025,0.03,0.9)
			outline.position = segment.position-Vector2(1,1)
			outline.size = segment.size+Vector2(2,2)
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			reticle.add_child(outline)
			var stroke := ColorRect.new()
			stroke.color = Color(1.0,0.93,0.20,1.0)
			stroke.position = segment.position
			stroke.size = segment.size
			stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
			reticle.add_child(stroke)
		var dot := ColorRect.new()
		dot.color = Color.WHITE
		dot.position = Vector2(-2,-2)
		dot.size = Vector2(4,4)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reticle.add_child(dot)
		install_options_menu(canvas)
		install_ring_inventory(canvas)
		install_resource_hud(canvas)
		install_speed_streaks(canvas)
	if player_controlled:
		backward = false
		direction_weight = 0.0
		signed_speed = 0.0
		actor.rotation.y = orbit
		manual_heading = orbit
		distance = 5.0 # Start slightly closer to BLACK; mouse wheel can still adjust zoom.
	update_camera()
	if autonomous_only: print("[FIGHTER_INIT_TOTAL] fighter=",name," duration_ms=",snappedf(float(Time.get_ticks_usec()-init_started_usec)/1000.0,0.01))
	# War fighters are advanced by the arena's physics scheduler. Their
	# Node3D idle _process only checks screenshot/testing hooks; disable
	# sixty redundant callbacks in normal combat without touching physics.
	if autonomous_only and not test: set_process(false)
	if not player_controlled and "--crouch-demo" in OS.get_cmdline_user_args(): crouch.start_showcase()
func install_options_menu(canvas: CanvasLayer) -> void:
	var cog := Button.new()
	cog.text = "⚙  Settings"
	cog.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cog.position = Vector2(-190,16)
	cog.size = Vector2(174,40)
	canvas.add_child(cog)
	options_panel = PanelContainer.new()
	options_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	options_panel.position = Vector2(-352,66)
	options_panel.custom_minimum_size = Vector2(335,230)
	options_panel.visible = false
	camera.far = 450.0
	canvas.add_child(options_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(326,470)
	options_panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",9)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size",19)
	column.add_child(heading)
	add_setting_slider(column,"Camera sensitivity",0.3,2.5,1.0,0.1,"camera")
	add_setting_slider(column,"Camera field of view",40.0,90.0,camera.fov,1.0,"fov")
	add_setting_slider(column,"View distance (m)",35.0,550.0,450.0,5.0,"view_distance")

	add_setting_slider(column,"Fireball speed",0.25,100.0,1.0,0.25,"fireball")
	add_setting_slider(column,"Fireball width",0.25,100.0,1.0,0.25,"fireball_size")
	var spawn_button := Button.new()
	spawn_button.text = "Spawn +10 fighters (0)"
	column.add_child(spawn_button)
	spawn_button.pressed.connect(func():
		var arena: Node = get_tree().current_scene
		if arena != null and arena.has_method("spawn_more_fighters"):
			arena.spawn_more_fighters()
	)
	var pose_toggle := CheckButton.new()
	pose_toggle.text = "Ground foot correction - everyone (ON/OFF)"
	pose_toggle.button_pressed = false
	column.add_child(pose_toggle)
	pose_toggle.toggled.connect(func(enabled: bool):
		war_pose_enabled = enabled
		if not enabled and not flight_enabled:
			visual.position.y = 0.0
		var arena: Node = get_tree().current_scene
		if arena != null:
			var roster = arena.get("mannequins")
			if roster is Array:
				for fighter in roster:
					if is_instance_valid(fighter):
						fighter.war_pose_enabled = enabled
						if not enabled and not fighter.flight_enabled:
							fighter.visual.rotation.x = 0.0
							fighter.visual.position.y = 0.0
		print("[PERF_POSE_TOGGLE] ground_feet_enabled=",enabled," player_and_ai=true flight_pose_enabled=true")
	)
	var mana_toggle := CheckButton.new()
	mana_toggle.text = "Infinite mana"
	mana_toggle.button_pressed = infinite_mana
	column.add_child(mana_toggle)
	mana_toggle.toggled.connect(func(enabled: bool):
		infinite_mana = enabled
		if enabled: mana = 100.0
		update_resource_hud()
	)
	var cooldown_toggle := CheckButton.new()
	cooldown_toggle.text = "Disable spell cooldowns"
	cooldown_toggle.button_pressed = ignore_spell_cooldowns
	column.add_child(cooldown_toggle)
	cooldown_toggle.toggled.connect(func(enabled: bool):
		ignore_spell_cooldowns = enabled
		if enabled:
			for i in range(spell_remaining.size()): spell_remaining[i] = 0.0
		update_resource_hud()
	)
	var demo_toggle := CheckButton.new()
	demo_toggle.text = "Motion demo NPC (debug)"
	demo_toggle.button_pressed = false
	column.add_child(demo_toggle)
	demo_toggle.toggled.connect(func(enabled: bool):
		var arena: Node = get_tree().current_scene
		if arena != null and arena.has_method("set_demo_npc_enabled"): arena.set_demo_npc_enabled(enabled)
	)
	var stats_toggle := Button.new()
	stats_toggle.text = "Stats for geeks  ▾"
	column.add_child(stats_toggle)
	settings_stats = Label.new()
	settings_stats.visible = false
	settings_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_stats.custom_minimum_size.x = 305.0
	column.add_child(settings_stats)
	stats_toggle.pressed.connect(func(): settings_stats.visible = not settings_stats.visible)
	var controls_heading := Button.new()
	controls_heading.text = "Controls  ▾"
	column.add_child(controls_heading)
	var controls_details := Label.new()
	controls_details.text = "WASD: Move / Strafe\nAlt+W: Sprint; double-tap and hold Alt: Dash\nB + W: Blink forward; B + S: Blink backward\nCtrl: Walk / descend during flight\nSpace: Charged jump / rise during flight\nMiddle-mouse drag: Rotate camera; wheel: Zoom\nShift: Switch active hand and spell fingers\nStart: Right 1 Cinderburst; other ring slots empty\nI: Inventory | V: Flight | G: Immortality\nLeft click: Punch with selected hand\nF: Lock target | C: Crouch | Tab (hold): War / damage\n0: More combatants | F11: Fullscreen"
	controls_details.visible = false
	column.add_child(controls_details)
	controls_heading.pressed.connect(func(): controls_details.visible = not controls_details.visible)
	var spellbook_heading := Button.new()
	spellbook_heading.text = "Spellbook  ▾"
	column.add_child(spellbook_heading)
	var spellbook := Label.new()
	spellbook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spellbook.text = ""
	for i in range(SPELL_NAMES.size()):
		spellbook.text += "%s %d. %s — %s\n" % ["LEFT" if i>=5 else "RIGHT",(i%5)+1,SPELL_NAMES[i],SPELL_EFFECTS[i]]
	spellbook.visible = false
	column.add_child(spellbook)
	spellbook_heading.pressed.connect(func(): spellbook.visible = not spellbook.visible)
	cog.pressed.connect(func(): options_panel.visible = not options_panel.visible)

func install_resource_hud(canvas: CanvasLayer) -> void:
	# Anatomical damage is visible directly on the white body; show stamina and mana only.
	# All controls ignore mouse input so aiming and punching work through them.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(16,-167)
	panel.custom_minimum_size = Vector2(280,144)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.88
	canvas.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",5)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)
	var name_text := Label.new()
	name_text.text = "YOU"
	name_text.add_theme_font_size_override("font_size",15)
	name_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_text)
	for bar_data in [["STAMINA",Color("d8a35e")],["MANA",Color("4b8eee")]]:
		var bar_label := Label.new()
		bar_label.text = String(bar_data[0])
		bar_label.add_theme_font_size_override("font_size",12)
		bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(bar_label)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(267,14)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = bar_data[1]
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill",fill)
		stack.add_child(bar)
		match String(bar_data[0]):
			"STAMINA": stamina_progress = bar
			"MANA": mana_progress = bar
	resources_status = Label.new()
	resources_status.add_theme_font_size_override("font_size",12)
	resources_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(resources_status)
	var slots := HBoxContainer.new()
	slots.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	slots.position = Vector2(312,-69)
	slots.add_theme_constant_override("separation",8)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(slots)
	hand_indicator = Label.new()
	hand_indicator.text = "RIGHT HAND  |  FIVE FINGERS"
	hand_indicator.position = Vector2(315,-99)
	hand_indicator.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hand_indicator.add_theme_font_size_override("font_size",13)
	hand_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hand_indicator)
	for i in range(5):
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(98,51)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slots.add_child(box)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size",14)
		box.add_child(label)
		spell_slots.append(label)
	update_resource_hud()

func update_resource_hud() -> void:
	if not player_controlled or stamina_progress == null: return
	stamina_progress.value = stamina
	mana_progress.value = mana
	resources_status.text = "STA %d   |   MANA %s" % [ceili(stamina),"∞" if infinite_mana else str(ceili(mana))]
	var hand_offset: int = 5 if controlled_arm == "left" else 0
	if hand_indicator != null:
		hand_indicator.text = ("LEFT HAND" if controlled_arm == "left" else "RIGHT HAND")+" | 1-5 (SHIFT) | I INVENTORY | V FLIGHT | G IMMORTAL"
		if fusion_feedback_remaining>0.0:
			hand_indicator.text = fusion_feedback
		elif cast_elapsed>=0.0 and cast_components.size()>1:
			hand_indicator.text = "FUSION: "+fusion_name(cast_components)
	for i in range(5):
		var slot: int = hand_offset+i
		var remaining: float = 0.0 if ignore_spell_cooldowns else spell_remaining[slot]
		var label: Label = spell_slots[i]
		if not SPELL_IDS[slot] in equipped_spells:
			label.text = "%d  Empty" % (i+1)
			label.tooltip_text = "No ring equipped"
			label.add_theme_color_override("font_color",Color("888d98"))
			continue
		var mana_needed: bool = not infinite_mana and mana<SPELL_COSTS[slot] and not (SPELL_IDS[slot]=="flight" and (flight_enabled or flight_windup_remaining>0.0))
		var description: String = "OFF" if SPELL_IDS[slot]=="flight" and (flight_enabled or flight_windup_remaining>0.0) else ("%.1fs" % remaining if remaining>0.05 else ("%d MP" % int(SPELL_COSTS[slot])))
		label.text = "%d  %s\n%s" % [i+1,SPELL_NAMES[slot],description]
		label.tooltip_text = SPELL_EFFECTS[slot]
		label.add_theme_color_override("font_color",Color("888d98") if remaining>0.05 or mana_needed else SPELL_COLORS[slot])
	if options_panel != null and options_panel.visible and settings_stats != null and settings_stats.visible:
		var arena: Node = get_tree().current_scene
		var overlay_text: String = "Performance not ready"
		var fighter_count: int = 0
		var demo_enabled: bool = false
		if arena != null:
			var perf: Label = arena.get("performance_label") as Label
			if perf != null: overlay_text = perf.text
			var roster: Array = arena.get("mannequins")
			fighter_count = roster.size()
			demo_enabled = is_instance_valid(arena.get("ai"))
		settings_stats.text = overlay_text+"\nPhysics 30 Hz | Fighters: "+str(fighter_count)+"\nDemo NPC: "+str(demo_enabled)+"\nFlight: "+str(flight_enabled)+"\nSpeed: %.1f m/s" % actor.velocity.length()

func add_setting_slider(parent: VBoxContainer, title: String, low: float, high: float, initial: float, increment: float, setting: String) -> void:
	var label := Label.new()
	label.text = title + ": " + str(initial)
	parent.add_child(label)
	var control := HSlider.new()
	control.min_value = low
	control.max_value = high
	control.step = increment
	control.value = initial
	control.custom_minimum_size = Vector2(265,18)
	parent.add_child(control)
	control.value_changed.connect(func(value: float):
		label.text = title + ": " + str(snappedf(value,increment))
		match setting:
			"camera": camera_sensitivity = value
			"fov": camera.fov = value
			"view_distance":
				camera.far = value
				print("[VIEW_DISTANCE] far_m=",value)

			"fireball_size":
				var arena: Node = get_tree().current_scene
				if arena != null and arena.has_method("set_fireball_width"):
					arena.set_fireball_width(value)
			"fireball":
				fireball_speed_scale = value
				if get_tree().current_scene.get("battle_fireball_speed") != null:
					get_tree().current_scene.set("battle_fireball_speed",value)
	)

func install_speed_streaks(canvas: CanvasLayer) -> void:
	speed_streaks = Control.new()
	speed_streaks.name = "SpeedStreaks"
	speed_streaks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_streaks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(speed_streaks)
	speed_streaks.draw.connect(draw_speed_streaks)

func update_speed_streaks(dt: float) -> void:
	if speed_streaks == null: return
	streak_clock += dt
	speed_streaks.queue_redraw()

func draw_speed_streaks() -> void:
	if speed_streaks == null: return
	var move_speed: float = Vector2(actor.velocity.x,actor.velocity.z).length() if not flight_enabled else actor.velocity.length()
	var intensity: float = clampf((move_speed-6.0)/14.0,0.0,1.0)
	if move_speed < 6.0: return
	var region: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = region*0.5
	var count: int = clampi(1+int(floor(move_speed-6.0)),1,15)
	for i in range(count):
		var angle: float = float(i)*2.39996323
		var cycle: float = fposmod(float(i)*0.6180339+streak_clock*(0.2+intensity*2.2),1.0)
		var radius: float = lerpf(0.40,0.94,cycle)
		var offset := Vector2(cos(angle),sin(angle))
		var edge: Vector2 = center+offset*radius*region.y
		var length: float = (32.0+190.0*intensity)*(0.6+cycle)
		speed_streaks.draw_line(edge-offset*length,edge,Color(0.93,0.96,1.0,0.40+intensity*0.52),1.7+intensity*1.6,true)

func smooth_gait(t: float) -> float:
	return t*t*t*(t*(t*6.0-15.0)+10.0)
func install_solo_left_strafe(player: AnimationPlayer) -> bool:
	return install_solo_strafe(player,"Left")

func install_solo_strafe(player: AnimationPlayer, direction: String) -> bool:
	if not player_controlled and not (name == "DemoNPC" and ai_mode == "sprint"): return false
	# Prefer the newly supplied single left-strafe run clip.
	# The run(1) attachment is not automatically in the Windows project.
	# Select an imported clip that actually exists, and log the selection.
	var path: String = ""
	for candidate_path in (["res://assets/locomotion/Left Strafe run(1).fbx", "res://assets/locomotion/Left Strafe run.fbx", "res://assets/locomotion/Left Strafe.fbx", "res://assets/locomotion/left strafe.fbx", "res://assets/locomotion/Left Strafe Walking.fbx"] if direction == "Left" else ["res://assets/locomotion/Right Strafe run.fbx","res://assets/locomotion/Right Strafe.fbx","res://assets/locomotion/right strafe.fbx","res://assets/locomotion/Right Strafe Walking.fbx"]):
		if ResourceLoader.exists(candidate_path):
			path = candidate_path
			break
	if path.is_empty():
		# Use an actual mirrored strafe when the local pack has only LEFT.
		# Do not silently substitute the forward walking or running clips.
		if direction == "Right" and player.has_animation("strafe/Left"):
			var source_left: Animation = player.get_animation("strafe/Left")
			var mirrored: Animation = source_left.duplicate(true) as Animation
			var dest_root: NodePath = player.get_node(player.root_node).get_path_to(skeleton)
			for track_i in range(mirrored.get_track_count()):
				if mirrored.track_get_type(track_i) != Animation.TYPE_ROTATION_3D: continue
				var bone_path: NodePath = mirrored.track_get_path(track_i)
				if bone_path.get_subname_count() == 0: continue
				var original: String = String(bone_path.get_subname(bone_path.get_subname_count()-1))
				var partner: String = original
				if original.contains("Left"): partner = original.replace("Left","Right")
				elif original.contains("Right"): partner = original.replace("Right","Left")
				if skeleton.find_bone(partner) >= 0:
					mirrored.track_set_path(track_i,NodePath(String(dest_root)+":"+partner))
				for key_i in range(mirrored.track_get_key_count(track_i)):
					var q: Quaternion = mirrored.track_get_key_value(track_i,key_i)
					mirrored.track_set_key_value(track_i,key_i,Quaternion(q.x,-q.y,-q.z,q.w).normalized())
			player.get_animation_library("strafe").add_animation("Right",mirrored)
			print("[STRAFE_IMPORT] right_mirrored_from_left=true")
			return true
		push_error("[STRAFE_IMPORT] NO "+direction.to_upper()+" STRAFE CLIP FOUND; check Downloads/RUN.bat")
		return false
	print("[SOLO_LEFT_STRAFE] selected=",path)
	var packed = load(path)
	if not packed is PackedScene: return false
	var source: Node = packed.instantiate()
	var players: Array[Node] = source.find_children("*","AnimationPlayer",true,false)
	var rigs: Array[Node] = source.find_children("*","Skeleton3D",true,false)
	if players.is_empty() or rigs.is_empty():
		source.free()
		return false
	var source_player: AnimationPlayer = players[0] as AnimationPlayer
	var source_rig: Skeleton3D = rigs[0] as Skeleton3D
	var chosen: Animation = null
	for animation_name in source_player.get_animation_list():
		if animation_name == "RESET": continue
		var candidate: Animation = source_player.get_animation(animation_name)
		if chosen == null or candidate.get_track_count() > chosen.get_track_count():
			chosen = candidate
	if chosen == null:
		source.free()
		return false
	var dest_root: NodePath = player.get_node(player.root_node).get_path_to(skeleton)
	var clip := Animation.new()
	clip.length = chosen.length
	clip.loop_mode = Animation.LOOP_LINEAR
	var mapped: int = 0
	for t in range(chosen.get_track_count()):
		if chosen.track_get_type(t) != Animation.TYPE_ROTATION_3D: continue
		var subpath: NodePath = chosen.track_get_path(t)
		if subpath.get_subname_count() == 0: continue
		var normalized: String = normalized_idle_bone(String(subpath.get_subname(subpath.get_subname_count()-1)))
		if normalized == "hips": continue
		var source_index: int = -1
		var dest_index: int = -1
		for bi in range(source_rig.get_bone_count()):
			if normalized_idle_bone(String(source_rig.get_bone_name(bi))) == normalized:
				source_index = bi
				break
		for bi in range(skeleton.get_bone_count()):
			if normalized_idle_bone(String(skeleton.get_bone_name(bi))) == normalized:
				dest_index = bi
				break
		if source_index < 0 or dest_index < 0: continue
		# The imported Mixamo clips and Y Bot use corresponding local joint
		# frames. Conjugating these poses by a rest quaternion caused the
		# crossed/twisted limbs seen in the prior test. Copy local rotations
		# directly; the physical body owns world heading and root position.
		var track_id: int = clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track_id,NodePath(String(dest_root)+":"+skeleton.get_bone_name(dest_index)))
		for k in range(chosen.track_get_key_count(t)):
			var rotation: Quaternion = chosen.track_get_key_value(t,k)
			clip.rotation_track_insert_key(track_id,chosen.track_get_key_time(t,k),rotation.normalized())
		mapped += 1
	source.free()
	if mapped < 12:
		print("[SOLO_LEFT_STRAFE] rejected tracks=",mapped)
		return false
	var library := AnimationLibrary.new()
	library.add_animation(direction,clip)
	if player.has_animation_library("strafe"):
		player.get_animation_library("strafe").add_animation(direction,clip)
	else:
		player.add_animation_library("strafe",library)
	print("[SOLO_LEFT_STRAFE] ready tracks=",mapped," file=",path," hips_ignored=true local_rotation=true")
	return true

func install_ring_inventory(canvas: CanvasLayer) -> void:
	ring_inventory_panel = PanelContainer.new()
	ring_inventory_panel.name = "RingInventory"
	ring_inventory_panel.visible = false
	ring_inventory_panel.custom_minimum_size = Vector2(450.0,450.0)
	canvas.add_child(ring_inventory_panel)
	ring_inventory_panel.position = (get_viewport().get_visible_rect().size-Vector2(450,450))*0.5
	get_viewport().size_changed.connect(func(): ring_inventory_panel.position = (get_viewport().get_visible_rect().size-ring_inventory_panel.size)*0.5)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	ring_inventory_panel.add_child(column)
	var heading := Label.new()
	heading.text = "INVENTORY  |  RINGS     [I to close]"
	heading.add_theme_font_size_override("font_size",22)
	column.add_child(heading)
	var instructions := Label.new()
	instructions.text = "Equipped spells - five fingers on each hand"
	column.add_child(instructions)
	ring_inventory_text = Label.new()
	ring_inventory_text.add_theme_font_size_override("font_size",17)
	column.add_child(ring_inventory_text)
	refresh_ring_inventory()

func refresh_ring_inventory() -> void:
	if ring_inventory_text == null: return
	var result: String = ""
	for i in range(SPELL_NAMES.size()):
		if i == 5: result += "\nLEFT HAND\n"
		elif i == 0: result += "RIGHT HAND\n"
		result += "  %d.  %s\n" % [i % 5 + 1,SPELL_NAMES[i] if SPELL_IDS[i] in equipped_spells else "Empty"]
	result += "\nV: Flight movement   |   G: Immortality"
	ring_inventory_text.text = result

func install_backwards(player: AnimationPlayer):
	install_motion_library(player,"res://assets/backward_motions.glb","back",BACK_NAMES,BACK_NAMES)
func install_motion_library(player: AnimationPlayer, resource_path: String, library_name: String, clip_names: Array, loops: Array):
	var source = load(resource_path).instantiate()
	var source_player: AnimationPlayer = source.find_children("*","AnimationPlayer",true,false)[0]
	var source_skeleton: Skeleton3D = source.find_children("*","Skeleton3D",true,false)[0]
	assert(source_skeleton.get_bone_count()==skeleton.get_bone_count(),"Backward rig differs")
	for index in range(skeleton.get_bone_count()):
		var name = skeleton.get_bone_name(index)
		assert(source_skeleton.find_bone(name)>=0,"Missing backward bone: "+name)
	var library = AnimationLibrary.new()
	var target_path = player.get_node(player.root_node).get_path_to(skeleton)
	for name in clip_names:
		var source_name = name if source_player.has_animation(name) else name+"_Loop"
		assert(source_player.has_animation(source_name),"Missing backward clip: "+name)
		var clip = source_player.get_animation(source_name).duplicate(true)
		for index in range(clip.get_track_count()-1,-1,-1):
			var path = clip.track_get_path(index)
			if path.get_subname_count()==0:
				clip.remove_track(index)
				continue
			var bone = String(path.get_subname(0))
			assert(skeleton.find_bone(bone)>=0,"Unknown backward animation bone: "+bone)
			clip.track_set_path(index,NodePath(String(target_path)+":"+bone))
		clip.loop_mode = Animation.LOOP_LINEAR if name in loops else Animation.LOOP_NONE
		library.add_animation(name,clip)
	player.add_animation_library(library_name,library)
	source.free()
func schedule(at: float, sequence: Array) -> Dictionary:
	var segment = int(at/10.0)%sequence.size()
	var a = sequence[segment]
	var b = sequence[(segment+1)%sequence.size()]
	var weight = smooth_gait(clamp((fmod(at,10.0)-6.0)/4.0,0.0,1.0))
	return {"a":a,"b":b,"weight":weight,"blend":lerp(float(a),float(b),weight)}
func band_value(values: Array, at: float) -> float:
	var low = int(floor(at))
	return lerp(float(values[low]),float(values[mini(low+1,values.size()-1)]),at-low)
func begin_direction_change(target_backward: bool):
	turning = true
	turn_time = 0.0
	turn_target = target_backward
	turn_start_speed = signed_speed
	turn_start_weight = direction_weight
	turn_start_forward = blend
	turn_start_back = back_blend
func update_war_fighter(dt: float) -> void:
	# Sample only 1/16 fighter updates to keep profiling overhead modest.
	war_profile_counter += 1
	var sampled: bool = (war_profile_counter & 15) == 0
	var profile_start: int = Time.get_ticks_usec() if sampled else 0
	var profile_physics: int = 0
	var profile_animation: int = 0
	var profile_phase: int = profile_start
	# The arena assembles one living roster per physics tick, avoiding
	# dozens of repeated full-roster scans and array allocations.
	var opponents: Array = get_tree().current_scene.active_war_fighters
	if opponents.size() <= 1:
		actor.velocity = Vector3.ZERO
		tree.advance(dt)
		return
	war_decision_timer -= dt
	if sampled:
		get_tree().current_scene.record_performance_sample("war_roster",Time.get_ticks_usec()-profile_phase)
		profile_phase = Time.get_ticks_usec()
	if war_target == null or not is_instance_valid(war_target) or war_target.combat_dead or war_decision_timer <= 0.0:
		war_decision_timer = agent_rng.randf_range(0.9,2.0)
		war_flight_preference = agent_rng.randf() < 0.65
		war_strafe_sign = -1.0 if agent_rng.randf() < 0.5 else 1.0
		var best_score: float = INF
		# Search local spatial cells first; only scan all fighters when isolated.
		var candidates: Array = get_tree().current_scene.war_nearby_fighters(actor.global_position,2)
		if candidates.size() <= 1: candidates = opponents
		for other in candidates:
			if other == self: continue
			var gap: float = actor.global_position.distance_to(other.actor.global_position)
			var score: float = gap + agent_rng.randf_range(-8.0,8.0)
			if score < best_score:
				best_score = score
				war_target = other
	if war_target == null or not is_instance_valid(war_target): return
	if sampled:
		get_tree().current_scene.record_performance_sample("war_target_selection",Time.get_ticks_usec()-profile_phase)
		profile_phase = Time.get_ticks_usec()
	var target_body: CharacterBody3D = war_target.actor
	var offset: Vector3 = target_body.global_position - actor.global_position
	var flat: Vector3 = Vector3(offset.x,0.0,offset.z)
	var distance: float = flat.length()
	var forward: Vector3 = flat.normalized() if distance > 0.01 else Vector3.FORWARD
	var tangent: Vector3 = Vector3(-forward.z,0,forward.x)
	var retreating: bool = war_cached_retreat
	var desired: Vector3 = tangent*war_strafe_sign*0.6
	if distance > 19.0 and not retreating: desired += forward*1.3
	elif distance < 10.0 or retreating: desired -= forward*1.5
	# Recompute expensive threat sensing only 8 times a second.
	war_tactical_clock -= dt
	if war_tactical_clock <= 0.0:
		war_tactical_clock = 0.125
		var nearby_threats: int = 0
		for other in get_tree().current_scene.war_nearby_fighters(actor.global_position,2):
			if other == self: continue
			if other.actor.global_position.distance_squared_to(actor.global_position) < 169.0:
				nearby_threats += 1
		war_cached_retreat = nearby_threats >= 3
		war_cached_dodge = Vector3.ZERO
		for fire in get_tree().current_scene.war_nearby_projectiles(actor.global_position,2):
			if not is_instance_valid(fire): continue
			var mover: Node = fire.get_node_or_null("Motion")
			if mover == null: continue
			var approach: Vector3 = actor.global_position - fire.global_position
			var travel: Vector3 = mover.travel_direction
			var in_front: float = approach.dot(travel)
			if in_front > 0.0 and in_front < 13.0:
				var miss: Vector3 = approach-travel*in_front
				if miss.length_squared() < 9.0:
					war_cached_dodge += tangent*war_strafe_sign*3.5
	desired += war_cached_dodge
	if sampled:
		get_tree().current_scene.record_performance_sample("war_steering",Time.get_ticks_usec()-profile_phase)
		profile_phase = Time.get_ticks_usec()
	# Only Fighter01 may fly in the ten-fighter war; all others stay grounded.
	var may_fly: bool = autonomous_only and name.begins_with("Fighter") and int(name.trim_prefix("Fighter")) % 10 == 1
	var must_fly: bool = may_fly and (distance > 22.0 or target_body.global_position.y > 3.0 or (war_flight_preference and distance > 10.0))
	if not may_fly: flight_enabled = false
	if must_fly: flight_enabled = true
	elif distance < 15.0 and actor.global_position.y < 2.8: flight_enabled = false
	actor.floor_snap_length = 0.0 if flight_enabled else 0.12
	var wish: Vector3 = desired.normalized()
	if flight_enabled:
		var destination_height: float = clampf(target_body.global_position.y+(8.0 if war_flight_preference else 4.0),4.0,48.0)
		wish.y = clampf((destination_height-actor.global_position.y)/6.0,-0.8,0.8)
		wish = wish.normalized()
		actor.velocity = actor.velocity.move_toward(wish*6.5,dt*16.0)
	else:
		actor.velocity.x = move_toward(actor.velocity.x,wish.x*4.0,dt*12.5)
		actor.velocity.z = move_toward(actor.velocity.z,wish.z*4.0,dt*12.5)
		actor.velocity.y -= SIMPLE_JUMP_GRAVITY*dt
	if sampled:
		get_tree().current_scene.record_performance_sample("war_velocity_setup",Time.get_ticks_usec()-profile_phase)
		profile_phase = Time.get_ticks_usec()
	var physics_start: int = Time.get_ticks_usec() if sampled else 0
	actor.move_and_slide()
	if sampled: profile_physics = Time.get_ticks_usec()-physics_start
	if sampled: profile_phase = Time.get_ticks_usec()
	if distance > 0.1: actor.rotation.y = atan2(-flat.x,-flat.z)
	speed = Vector2(actor.velocity.x,actor.velocity.z).length()
	blend = speed_band(SPEEDS,speed)
	if sampled:
		get_tree().current_scene.record_performance_sample("war_blend_setup",Time.get_ticks_usec()-profile_phase)
		profile_phase = Time.get_ticks_usec()
	# Schedule animation independently from movement and collision updates.
	# Casting and nearby fighters retain 60 Hz bone/IK motion. Fighters far
	# from the player use 30 Hz in combat, or 15 Hz when not engaged.
	var spectator: Node = get_tree().current_scene.get("player")
	var near_player: bool = spectator != null and is_instance_valid(spectator) and actor.global_position.distance_squared_to(spectator.actor.global_position) < 324.0
	var in_combat: bool = cast_elapsed >= 0.0 or (war_target != null and is_instance_valid(war_target) and actor.global_position.distance_squared_to(war_target.actor.global_position) < 400.0)
	var visual_rate: float = 30.0 if near_player or flight_enabled else 8.0
	war_visual_accumulator += dt
	var advance_visual: bool = war_visual_accumulator + 0.00001 >= 1.0 / visual_rate
	var animation_start: int = Time.get_ticks_usec() if sampled else 0
	if advance_visual:
		# AnimationTree parameters are only consumed by tree.advance().
		# Avoid three property writes on physics ticks with skipped visuals.
		tree.set("parameters/Gaits/blend_position",blend)
		tree.set("parameters/Direction/blend_amount",0.0)
		tree.set("parameters/Cadence/scale",maxf(0.2,speed/3.0))
		tree.advance(war_visual_accumulator)
		war_visual_accumulator = 0.0
		war_visual_updates += 1
	else:
		war_visual_skips += 1
	if sampled: profile_animation = Time.get_ticks_usec()-animation_start
	if sampled: profile_phase = Time.get_ticks_usec()
	if advance_visual and flight_enabled:
		# Flight poses remain active independently of the expensive ground-foot correction.
		# The airborne rig must visually pitch with its velocity, not keep
		# its standing orientation while flying.
		var planar_speed: float = Vector2(actor.velocity.x,actor.velocity.z).length()
		var target_pitch: float = clampf(atan2(planar_speed,maxf(-6.0,actor.velocity.y)),0.10,2.8)
		visual.rotation.x = move_toward(visual.rotation.x,target_pitch,dt*5.0)
		visual.position.y = 0.95*absf(sin(visual.rotation.x))
		apply_flight_pose(dt)
	elif advance_visual:
		visual.rotation.x = move_toward(visual.rotation.x,0.0,dt*8.0)
		if war_pose_enabled:
			visual.position.y = 0.0
			if actor.is_on_floor(): feet.resolve(true)
	if sampled:
		get_tree().current_scene.record_performance_sample("war_pose_and_feet",Time.get_ticks_usec()-profile_phase)
		profile_phase = Time.get_ticks_usec()
	ai_action_clock += dt
	if ai_action_clock >= 0.95 and distance < 70.0:
		ai_action_clock = 0.0
		if cast_elapsed < 0.0:
			controlled_arm = "left" if controlled_arm == "right" else "right"
			cast_fireball()
	# War fighters use this cast IK path rather than the player movement path.
	# Without an initialized weight their cast arm stays motionless.
	jab_aim_strength = 1.0
	if advance_visual: adjust_jab_arm()
	update_cast_motion(dt)
	if sampled:
		get_tree().current_scene.record_performance_sample("war_cast_and_ik",Time.get_ticks_usec()-profile_phase)
		var arena: Node = get_tree().current_scene
		if arena != null and arena.has_method("record_performance_sample"):
			arena.record_performance_sample("war_ai_total",Time.get_ticks_usec()-profile_start)
			arena.record_performance_sample("war_collision",profile_physics)
			arena.record_performance_sample("war_animation_tree",profile_animation)

func update_hunter_mannequin(dt: float) -> void:
	# Pursue the player with the same speed budget, flight pose, and fire cast.
	var target_node: Node3D = get_tree().current_scene.get_node_or_null("PlayerMan") as Node3D
	if target_node == null: return
	var target_body: CharacterBody3D = target_node.get("actor") as CharacterBody3D
	if target_body == null: return
	var target_flying: bool = bool(target_node.get("flight_enabled"))
	var offset: Vector3 = target_body.global_position - actor.global_position
	var horizontal: Vector3 = Vector3(offset.x,0.0,offset.z)
	var distance: float = horizontal.length()
	var player_speed: float = target_body.velocity.length()
	var desired_speed: float = clampf(player_speed+2.0,6.0,40.0)
	var direction: Vector3 = Vector3.ZERO
	if distance > 17.0: direction = horizontal.normalized()
	elif distance < 11.0: direction = -horizontal.normalized()
	elif distance > 0.01: direction = Vector3(-horizontal.z,0.0,horizontal.x).normalized()*0.45
	# Use flight as a pursuit tool even when the player is on foot.
	# Hysteresis avoids toggling flight on and off near a single threshold.
	var must_fly: bool = target_flying or target_body.global_position.y > 2.5
	var takeoff_for_chase: bool = distance > 30.0 and desired_speed > SPEEDS[2]
	if not flight_enabled:
		flight_enabled = must_fly or takeoff_for_chase
	elif not must_fly and distance < 18.0:
		flight_enabled = false
	actor.floor_snap_length = 0.0 if flight_enabled else 0.12
	if flight_enabled:
		# Climb to cruising altitude when chasing a grounded player.
		var cruise_height: float = target_body.global_position.y + (0.7 if distance < 21.0 else 4.0)
		var vertical_error: float = cruise_height-actor.global_position.y
		direction.y = clampf(vertical_error/4.0,-1.0,1.0)
		if direction.length_squared() > 0.001: direction = direction.normalized()
		var flight_chase_speed: float = maxf(desired_speed,FLIGHT_SPEED+5.0)
		actor.velocity = actor.velocity.move_toward(direction*flight_chase_speed,dt*32.0)
	else:
		actor.velocity.x = move_toward(actor.velocity.x,direction.x*desired_speed,dt*24.0)
		actor.velocity.z = move_toward(actor.velocity.z,direction.z*desired_speed,dt*24.0)
		actor.velocity.y -= SIMPLE_JUMP_GRAVITY*dt
	actor.move_and_slide()
	if horizontal.length_squared() > 0.05:
		actor.rotation.y = atan2(-horizontal.x,-horizontal.z)
	if flight_enabled:
		var h: float = Vector2(actor.velocity.x,actor.velocity.z).length()
		flight_visual_pitch = move_toward(flight_visual_pitch,clampf(atan2(h,actor.velocity.y),0.08,PI-0.08),dt*5.0)
		visual.rotation.x = flight_visual_pitch
		visual.position.y = 0.95*sin(flight_visual_pitch)
	else:
		flight_visual_pitch = move_toward(flight_visual_pitch,0.0,dt*8.0)
		visual.rotation.x = flight_visual_pitch
		visual.position.y = 0.0
	jab_aim_strength = 1.0
	speed = Vector2(actor.velocity.x,actor.velocity.z).length()
	blend = speed_band(SPEEDS,speed)
	tree.set("parameters/Gaits/blend_position",blend)
	tree.set("parameters/Direction/blend_amount",0.0)
	tree.set("parameters/Cadence/scale",maxf(0.2,speed/2.9))
	tree.advance(dt)
	if flight_enabled:
		apply_flight_pose(dt)
	else:
		feet.use_full_support = false
		if actor.is_on_floor(): feet.resolve(true)
	ai_action_clock += dt
	if ai_action_clock >= 1.75 and cast_elapsed < 0.0 and distance <= 26.0:
		ai_action_clock = 0.0
		controlled_arm = "left" if controlled_arm == "right" else "right"
		cast_fireball()
	adjust_jab_arm()
	update_cast_motion(dt)

func update_fire_mannequin(dt: float) -> void:
	# Keep the test mannequin planted and aim each cast at the player.
	tree.set("parameters/StandingMove/blend_amount",0.0)
	jab_aim_strength = 1.0
	var target_node: Node3D = get_tree().current_scene.get_node_or_null("PlayerMan") as Node3D
	if target_node != null:
		var target_actor: Node3D = target_node.get("actor") as Node3D
		if target_actor != null:
			var delta: Vector3 = target_actor.global_position - actor.global_position
			actor.rotation.y = atan2(-delta.x,-delta.z)
	tree.advance(dt)
	actor.velocity = Vector3.ZERO
	actor.move_and_slide()
	feet.use_full_support = false
	feet.resolve(true)
	ai_action_clock += dt
	if ai_action_clock >= 1.7:
		ai_action_clock = 0.0
		controlled_arm = "left" if controlled_arm == "right" else "right"
		cast_fireball()
	adjust_jab_arm()
	update_cast_motion(dt)

func update_animation_test(dt: float) -> void:
	tree.advance(dt)
	animation_test_clock += dt
	var jumping: bool = animation_test_mode == "jump"
	var target_height: float = 4.0 if jumping else (8.0 if animation_test_speed < 18.0 else 10.0)
	if animation_test_phase == "wait":
		flight_enabled = false
		actor.velocity = Vector3.ZERO
		actor.move_and_slide()
		feet.use_full_support = false
		feet.resolve(true)
		if animation_test_clock >= 1.0:
			animation_test_home = actor.position
			animation_test_angle = 0.0
			animation_test_clock = 0.0
			animation_test_phase = "up"
			start_movement_clip("Jumping Up.fbx")
			actor.velocity.y = 7.0 if jumping else animation_test_speed
			flight_enabled = not jumping
			flight_animation_time = 0.0
	elif animation_test_phase == "up":
		actor.velocity = Vector3.UP * (7.0 if jumping else animation_test_speed)
		if jumping:
			actor.velocity.y = maxf(0.0,7.0-animation_test_clock*18.0)
		actor.move_and_slide()
		if (jumping and actor.velocity.y <= 0.01) or (not jumping and actor.position.y >= target_height):
			animation_test_phase = "down" if jumping else "orbit"
			animation_test_clock = 0.0
	elif animation_test_phase == "orbit":
		# Fly one full circle around the launch marker, then return to land there.
		# The orbit is traversed at the configured linear speed.
		var previous_angle: float = animation_test_angle
		animation_test_angle = minf(TAU,animation_test_angle + animation_test_speed * dt / animation_test_orbit_radius)
		var orbit_target := animation_test_home + Vector3(cos(animation_test_angle)-1.0,0.0,sin(animation_test_angle)) * animation_test_orbit_radius + Vector3.UP * target_height
		var orbit_delta: Vector3 = orbit_target - actor.position
		actor.velocity = orbit_delta / maxf(dt,0.0001)
		actor.move_and_slide()
		if actor.velocity.length_squared() > 0.01:
			actor.rotation.y = atan2(-actor.velocity.x,-actor.velocity.z)
		if animation_test_angle >= TAU:
			animation_test_phase = "down"
			animation_test_clock = 0.0
	elif animation_test_phase == "down":
		actor.velocity = Vector3.DOWN * (7.0 if jumping else animation_test_speed)
		# Begin recovering to feet-first well before touchdown.
		if not jumping and flight_enabled:
			var floor_cast: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*0.12,actor.global_position+Vector3.DOWN*1.6)
			floor_cast.exclude = [actor.get_rid()]
			var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(floor_cast)
			if not hit.is_empty() and Vector3(hit["normal"]).y > 0.72:
				flight_enabled = false
		actor.move_and_slide()
		if actor.is_on_floor() or actor.position.y <= 0.02:
			actor.position.y = maxf(actor.position.y,0.0)
			animation_test_landing_speed = 7.0 if jumping else animation_test_speed
			animation_test_phase = "land"
			animation_test_clock = 0.0
			flight_enabled = false
			actor.velocity = Vector3.ZERO
			movement_clip_name = ""
	elif animation_test_phase == "land":
		flight_enabled = false
		actor.velocity = Vector3.ZERO
		actor.move_and_slide()
		if animation_test_clock > 0.4:
			animation_test_phase = "wait"
			animation_test_clock = 0.0
	if animation_test_phase == "up" or animation_test_phase == "orbit" or animation_test_phase == "down":
		visual.position.y = 0.0
		if not jumping and flight_enabled:
			apply_flight_pose(dt)
			# Pitch the visual rig into the actual 3D velocity (head-first).
			# The collider stays upright; yaw follows horizontal velocity.
			var v: Vector3 = actor.velocity
			var horizontal_speed: float = Vector2(v.x,v.z).length()
			if horizontal_speed > 0.01:
				actor.rotation.y = atan2(-v.x,-v.z)
			if v.length_squared() > 0.01:
				var aim_pitch: float = clampf(atan2(horizontal_speed,v.y),0.08,PI-0.08)
				if animation_test_phase == "down" and actor.position.y <= 7.0:
					aim_pitch = 0.0
				flight_visual_pitch = move_toward(flight_visual_pitch,aim_pitch,dt*(20.0 if animation_test_phase == "down" and actor.position.y <= 7.0 else 7.0))
			visual.rotation.x = flight_visual_pitch
			visual.position.y = 0.95*sin(flight_visual_pitch)
	else:
		flight_visual_pitch = move_toward(flight_visual_pitch,0.0,dt*9.0)
		visual.rotation.x = flight_visual_pitch
		feet.use_full_support = false
		feet.resolve(true)
	apply_movement_clip(dt)

func combat_react(region: String, amount: float, remaining: float) -> void:
	if combat_dead: return
	combat_hit_sequence += 1
	var clip: String = "Reaction.fbx" if combat_hit_sequence % 2 == 0 else "Reaction (1).fbx"
	if region == "head":
		clip = ("Light Hit To Head.fbx" if combat_hit_sequence % 2 == 0 else "Light Hit To Head (1).fbx") if amount < 25.0 else ("Medium Hit To Head.fbx" if combat_hit_sequence % 2 == 0 else "Medium Hit To Head (1).fbx")
	elif region == "torso":
		# General body reactions and kidney-hit variants alternate.
		var body_clips: Array[String] = ["Reaction.fbx","Reaction (1).fbx","Big Kidney Hit.fbx","Big Kidney Hit (1).fbx"]
		clip = body_clips[combat_hit_sequence % body_clips.size()]
	start_movement_clip(clip)

func combat_die(region: String) -> void:
	combat_dead = true
	combat_death_time = 0.0
	combat_pose_frozen = false
	combat_last_velocity = actor.velocity
	combat_initial_pitch = visual.rotation.x
	punch_pending = false
	flight_enabled = false
	flight_windup_remaining = 0.0
	var clips: Array[String] = ["Dying.fbx","Dying (1).fbx","Dying (2).fbx","Dying (3).fbx"]
	start_movement_clip(clips[randi_range(0,clips.size()-1)]) # Every death ends in a genuine falling pose.

func update_combat_fall(dt: float) -> void:
	combat_death_time += dt
	if not combat_pose_frozen:
		tree.advance(dt)
	actor.velocity.x = move_toward(actor.velocity.x,0.0,dt*8.0)
	actor.velocity.z = move_toward(actor.velocity.z,0.0,dt*8.0)
	if not actor.is_on_floor():
		actor.velocity.y -= SIMPLE_JUMP_GRAVITY*dt
	else:
		actor.velocity.y = -0.1
	actor.move_and_slide()
	if not combat_pose_frozen:
		apply_movement_clip(dt)
		var finished: bool = movement_clip_name == "" or not movement_clips.has(movement_clip_name)
		if not finished:
			var selected_clip: Dictionary = movement_clips[movement_clip_name]
			finished = movement_clip_time >= float(selected_clip["length"])-0.004
		if finished:
			combat_pose_frozen = true
			tree.active = false
	# The physics capsule remains upright, but the visible rig lies prone.
	# Once settled, compute floor clearance from animated bones rather
	# than raising the entire body by a guessed constant.
	visual.rotation.x = lerpf(combat_initial_pitch,0.0,smoothstep(0.0,0.95,combat_death_time))
	if combat_death_time >= 0.95:
		# The capsule's upright center is not a corpse floor-contact point.
		# Adjust the visual rig until its lowest animated joint sits at floor height.
		skeleton.force_update_all_bone_transforms()
		var lowest: float = INF
		for bone_index in range(skeleton.get_bone_count()):
			var bone_world: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(bone_index).origin
			lowest = minf(lowest,bone_world.y)
		if lowest < INF:
			var floor_height: float = maxf(0.0,actor.global_position.y)
			var correction: float = floor_height+0.04-lowest
			visual.position.y += clampf(correction,-dt*2.5,dt*2.5)
		# Do not let a death pose retain the previous aerial-flight pitch.
		visual.rotation.z = 0.0

func update_sky_target(dt: float) -> void:
	tree.advance(dt)
	if actor.position.y < 20.0:
		flight_enabled = true
		actor.velocity = Vector3.UP*9.0
		actor.move_and_slide()
		apply_flight_pose(dt)
	else:
		actor.position.y = 20.0
		actor.velocity = Vector3.ZERO
		flight_enabled = true
		apply_flight_pose(dt)
	apply_movement_clip(dt)

# Called once per arena physics tick by the central scheduler.
func update_animation_lineup(dt: float) -> void:
	var arena: Node = get_tree().current_scene
	if arena == null: return
	var target: Node = arena.get("player")
	if not is_instance_valid(target): return
	var target_actor: CharacterBody3D = target.actor
	var offset: Vector3 = target_actor.global_position-actor.global_position
	if offset.length_squared() > 0.0001:
		actor.rotation.y = atan2(-offset.x,-offset.z)
	actor.velocity = Vector3.ZERO
	speed = 0.0
	signed_speed = 0.0
	blend = 0.0
	back_blend = 0.0
	direction_weight = 0.0
	# A zero-velocity mannequin must use the standing idle blend, not
	# the locomotion tree's minimum-speed walk cycle.
	tree.set("parameters/StandingMove/blend_amount",0.0)
	tree.set("parameters/Gaits/blend_position",0.0)
	tree.set("parameters/BackGaits/blend_position",0.0)
	tree.set("parameters/Direction/blend_amount",0.0)
	tree.set("parameters/Cadence/scale",0.0)
	# All rigs still advance their idle/cast animations in lockstep.
	tree.advance(dt)
	lineup_cast_clock += dt
	if lineup_cast_clock >= 2.5:
		lineup_cast_clock = fmod(lineup_cast_clock,2.5)
		if cast_elapsed < 0.0:
			controlled_arm = "right"
			cast_fireball()
			if cast_elapsed >= 0.0:
				cast_aim_point = target_actor.global_position + Vector3.UP*1.1
	jab_aim_strength = 1.0
	adjust_jab_arm()
	update_cast_motion(dt)

func apply_spell_status(effect_id: String, center: Vector3) -> void:
	match effect_id:
		"fire":
			spell_burn_remaining = maxf(spell_burn_remaining,3.5)
			spell_burn_tick = 0.0
		"frost":
			spell_frost_remaining = maxf(spell_frost_remaining,5.0)
		"grounding":
			spell_grounded_remaining = maxf(spell_grounded_remaining,6.0)
			flight_enabled = false
			flight_windup_remaining = 0.0
			flight_launch_remaining = 0.0
			flight_acceleration_time = 0.0
		"gravity":
			spell_gravity_remaining = maxf(spell_gravity_remaining,2.6)
			spell_gravity_origin = center
		"venom":
			spell_venom_remaining = maxf(spell_venom_remaining,7.0)
			spell_venom_tick = 0.0
		"tempest":
			spell_tempest_remaining = maxf(spell_tempest_remaining,0.75)
			spell_tempest_direction = actor.global_position-center
			spell_tempest_direction.y = 0.0
			if spell_tempest_direction.length_squared()>0.01:
				spell_tempest_direction = spell_tempest_direction.normalized()
			else:
				spell_tempest_direction = Vector3.FORWARD

func apply_spell_statuses(effect_ids: Array[String], center: Vector3) -> void:
	# Deferred impact tweens outlive the shot; victims own status dispatch.
	for effect_id in effect_ids:
		apply_spell_status(effect_id,center)

func status_description() -> String:
	if combat_dead: return ""
	var active: PackedStringArray = []
	if spell_frost_remaining>0.0: active.append("PERMAFROST %.1fs" % spell_frost_remaining)
	if spell_grounded_remaining>0.0: active.append("EARTHBOUND %.1fs" % spell_grounded_remaining)
	if spell_burn_remaining>0.0: active.append("BURNING %.1fs" % spell_burn_remaining)
	if spell_venom_remaining>0.0: active.append("BLIGHT %.1fs" % spell_venom_remaining)
	if spell_gravity_remaining>0.0: active.append("VOID PULL %.1fs" % spell_gravity_remaining)
	if spell_tempest_remaining>0.0: active.append("KNOCKBACK")
	if spell_regen_remaining>0.0: active.append("LIFEWEAVE %.1fs" % spell_regen_remaining)
	return "  |  ".join(active)

func team_is_enemy(other: Node) -> bool:
	return other != null and is_instance_valid(other) and other != self and not other.combat_dead and team_id != "" and String(other.get("team_id")) != "" and String(other.get("team_id")) != team_id

func heal_from_bloom(amount: float) -> void:
	var damage: Node = get_node_or_null("DamageSystem")
	if damage == null or damage.dead: return
	for region in damage.REGIONS:
		damage.hp[region] = minf(100.0,float(damage.hp[region])+amount)
		damage.region_regen_delays[region] = 0.0
	damage.update_damage_colors()
	spell_regen_remaining = maxf(spell_regen_remaining,5.0)
	spell_regen_tick = 0.0
	if player_controlled: update_resource_hud()

func cast_bloom_pulse() -> void:
	# Friendly-only area healing: 18 metres, all six body regions, plus HoT.
	var arena: Node = get_tree().current_scene
	if arena == null: return
	var center: Vector3 = actor.global_position+Vector3.UP*1.0
	for recipient in get_tree().get_nodes_in_group("combat_fighters"):
		if not is_instance_valid(recipient) or recipient.combat_dead: continue
		if team_id!="" and String(recipient.get("team_id"))!=team_id: continue
		if recipient.actor.global_position.distance_to(actor.global_position)>18.0: continue
		recipient.heal_from_bloom(32.0)
	# The imported particle texture and motion create a spreading green ring.
	var bloom := Node3D.new()
	bloom.name = "BloomHealingWave"
	arena.add_child(bloom)
	bloom.global_position = center
	var particles: GPUParticles3D = arena.fireball_scene.instantiate()
	bloom.add_child(particles)
	particles.local_coords = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.85
	particles.amount = 180
	particles.fixed_fps = 30
	var material: ParticleProcessMaterial = particles.process_material.duplicate(true) as ParticleProcessMaterial
	if material != null:
		var gradient := Gradient.new()
		gradient.set_color(0,Color("6df4a0"))
		gradient.set_color(1,Color(0.20,0.95,0.58,0.0))
		var ramp := GradientTexture1D.new()
		ramp.gradient = gradient
		material.color_ramp = ramp
		material.gravity = Vector3.ZERO
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		material.emission_sphere_radius = 0.20
		material.spread = 180.0
		material.initial_velocity_min = 18.0/0.80
		material.initial_velocity_max = 18.0/0.65
		particles.process_material = material
	particles.emitting = true
	particles.restart()
	var cleanup := bloom.create_tween()
	cleanup.tween_interval(1.4)
	cleanup.tween_callback(bloom.queue_free)

func update_spell_test_target(dt: float) -> void:
	# Spell effects stay active even on completely passive mannequins.
	if spell_burn_remaining > 0.0:
		spell_burn_remaining = maxf(0.0,spell_burn_remaining-dt)
		spell_burn_tick += dt
		if spell_burn_tick >= 0.65:
			spell_burn_tick = 0.0
			var hurt: Node = get_node_or_null("DamageSystem")
			if hurt != null and not hurt.dead:
				hurt.receive_region_hit("torso",actor.global_position+Vector3.UP,4.5,"BURN",false)
	if spell_venom_remaining > 0.0:
		spell_venom_remaining = maxf(0.0,spell_venom_remaining-dt)
		spell_venom_tick += dt
		if spell_venom_tick >= 0.8:
			spell_venom_tick = 0.0
			var poison_hurt: Node = get_node_or_null("DamageSystem")
			if poison_hurt != null and not poison_hurt.dead:
				poison_hurt.receive_region_hit("torso",actor.global_position+Vector3.UP,5.0,"VENOM",false)
	spell_frost_remaining = maxf(0.0,spell_frost_remaining-dt)
	spell_gravity_remaining = maxf(0.0,spell_gravity_remaining-dt)
	spell_tempest_remaining = maxf(0.0,spell_tempest_remaining-dt)
	if spell_tempest_remaining > 0.0:
		actor.velocity = spell_tempest_direction * (21.0*spell_tempest_remaining/0.75)
		actor.velocity.y = -0.3
		actor.move_and_slide()
		tree.advance(dt)
		return
	if spell_gravity_remaining > 0.0:
		var toward: Vector3 = spell_gravity_origin-actor.global_position
		toward.y = 0.0
		actor.velocity = toward.normalized()*minf(13.0,toward.length()*3.0) if toward.length_squared()>0.2 else Vector3.ZERO
		actor.velocity.y = -0.3
		actor.move_and_slide()
		tree.advance(dt)
		return
	# Static mannequins idle in place; moving mannequins walk predictable
	# small routes without casting or turning into combat AI.
	if spell_target_mode == "stationary":
		# Restore the range after being pulled by gravity.
		var back: Vector3 = spell_target_anchor-actor.global_position
		back.y = 0.0
		if back.length_squared()>0.04:
			actor.velocity = back.normalized()*minf(4.5,back.length()*2.0)
			actor.velocity.y = -0.3
			actor.move_and_slide()
		actor.velocity = Vector3.ZERO
		tree.set("parameters/StandingMove/blend_amount",0.0)
		tree.set("parameters/Cadence/scale",0.0)
		tree.advance(dt)
		return
	clock += dt
	var cycle: float = clock*0.48+spell_walker_phase
	var waypoint: Vector3 = spell_target_anchor+Vector3(sin(cycle)*3.2,0.0,cos(cycle)*2.2)
	var to_waypoint: Vector3 = waypoint-actor.global_position
	to_waypoint.y = 0.0
	var desired: Vector3 = to_waypoint.normalized()*minf(2.7,to_waypoint.length()*1.7) if to_waypoint.length_squared()>0.01 else Vector3.ZERO
	if spell_frost_remaining > 0.0: desired *= 0.22
	actor.velocity.x = move_toward(actor.velocity.x,desired.x,dt*8.0)
	actor.velocity.z = move_toward(actor.velocity.z,desired.z,dt*8.0)
	actor.velocity.y = -0.3
	actor.move_and_slide()
	var walker_speed: float = Vector2(actor.velocity.x,actor.velocity.z).length()
	if walker_speed > 0.15:
		actor.rotation.y = rotate_toward(actor.rotation.y,atan2(-actor.velocity.x,-actor.velocity.z),dt*4.0)
	tree.set("parameters/Gaits/blend_position",speed_band(SPEEDS,walker_speed))
	tree.set("parameters/Direction/blend_amount",0.0)
	tree.set("parameters/StandingMove/blend_amount",smooth_gait(clampf(walker_speed/0.7,0.0,1.0)))
	tree.set("parameters/Cadence/scale",maxf(0.15,walker_speed/STRIDES[0]))
	tree.advance(dt)

func cast_blink(direction_sign: float) -> bool:
	# W casts a forward blink; S casts a backward blink. Travel checks the
	# real CharacterBody capsule against physical walls and nearby fighters.
	if blink_cooldown_remaining>0.0 or combat_dead: return false
	if not infinite_mana and mana<BLINK_MANA_COST: return false
	var forward: Vector3 = -actor.global_basis.z
	forward.y = 0.0
	if forward.length_squared()<0.01: return false
	var blink_direction: Vector3 = forward.normalized()*signf(direction_sign)
	var start: Vector3 = actor.global_position
	var max_distance: float = BLINK_DISTANCE
	# Stay inside the visible 100 m arena; no teleporting through its wall.
	var edge: float = 46.0
	if blink_direction.x>0.001: max_distance = minf(max_distance,(edge-start.x)/blink_direction.x)
	if blink_direction.x< -0.001: max_distance = minf(max_distance,(-edge-start.x)/blink_direction.x)
	if blink_direction.z>0.001: max_distance = minf(max_distance,(edge-start.z)/blink_direction.z)
	if blink_direction.z< -0.001: max_distance = minf(max_distance,(-edge-start.z)/blink_direction.z)
	if max_distance<1.0: return false
	var distance_available: float = max_distance
	for test_step in range(8):
		if not actor.test_move(actor.global_transform,blink_direction*distance_available): break
		distance_available *= 0.65
	if distance_available<1.0 or actor.test_move(actor.global_transform,blink_direction*distance_available): return false
	if not infinite_mana: mana -= BLINK_MANA_COST
	blink_cooldown_remaining = BLINK_COOLDOWN
	actor.global_position += blink_direction*distance_available
	actor.velocity = blink_direction*11.0
	# Reuse the external spell-particle asset for the two teleport endpoints.
	var arena: Node = get_tree().current_scene
	if arena != null and arena.get("fireball_scene") != null:
		for location in [start,actor.global_position]:
			var flash := Node3D.new()
			flash.name = "BlinkFlash"
			arena.add_child(flash)
			flash.global_position = location+Vector3.UP
			var sparkle: GPUParticles3D = arena.fireball_scene.instantiate()
			flash.add_child(sparkle)
			var material: ParticleProcessMaterial = sparkle.process_material.duplicate(true) as ParticleProcessMaterial
			if material!=null:
				material.color_ramp = null
				material.color = Color("9fbcff")
				sparkle.process_material = material
			sparkle.scale = Vector3.ONE*0.65
			sparkle.amount = 25
			sparkle.lifetime = 0.5
			sparkle.one_shot = true
			sparkle.emitting = true
			sparkle.restart()
			var cleanup := arena.create_tween()
			cleanup.tween_interval(0.75)
			cleanup.tween_callback(flash.queue_free)
	print("[BLINK] ",name," direction=",("W_FORWARD" if direction_sign>0.0 else "S_BACK")," distance=",snappedf(distance_available,0.1))
	return true

func update_pursuit_agent(dt: float) -> void:
	# Pursuit sandbox: one frightened escapee versus three ability-constrained
	# hunters. All use real move_and_slide and the imported animation rig.
	clock += dt
	blink_cooldown_remaining = maxf(0.0,blink_cooldown_remaining-dt)
	var arena: Node = get_tree().current_scene
	if arena == null: return
	var is_escapee: bool = pursuit_role == "escapee"
	var escapee: Node = arena.get_node_or_null("Fighter01")
	var delta_to_target: Vector3 = Vector3.ZERO
	var target_distance: float = 9999.0
	if not is_escapee and is_instance_valid(escapee) and not escapee.combat_dead:
		war_target = escapee
		delta_to_target = escapee.actor.global_position-actor.global_position
		target_distance = delta_to_target.length()
	var desired: Vector3 = Vector3.ZERO
	if is_escapee:
		var nearest_distance: float = 9999.0
		var avoidance: Vector3 = Vector3.ZERO
		for other in arena.mannequins:
			if not is_instance_valid(other) or other == self or other.combat_dead: continue
			if other.pursuit_role == "": continue
			var offset: Vector3 = actor.global_position-other.actor.global_position
			offset.y = 0.0
			var separation: float = offset.length()
			if separation>0.001:
				nearest_distance = minf(nearest_distance,separation)
				avoidance += offset/(separation*maxf(separation,3.0))
		# Black is also a threat if the player approaches the fleeing NPC.
		var player_threat: Node = arena.get("player")
		if is_instance_valid(player_threat) and not player_threat.combat_dead:
			var player_offset: Vector3 = actor.global_position-player_threat.actor.global_position
			player_offset.y = 0.0
			var player_separation: float = player_offset.length()
			if player_separation>0.001:
				nearest_distance = minf(nearest_distance,player_separation)
				avoidance += player_offset/(player_separation*maxf(player_separation,3.0))
		var nearest_away: Vector3 = avoidance.normalized() if avoidance.length_squared()>0.00001 else Vector3.FORWARD
		var bend: Vector3 = Vector3(-nearest_away.z,0.0,nearest_away.x)
		desired = (nearest_away*1.15+bend*(0.40+0.23*sin(clock*0.58))).normalized()
		# Alternate running and flight, taking off when badly pressured.
		pursuit_flight_preference = sin(clock*0.43)>0.25 or nearest_distance<11.0
	else:
		if target_distance < 9998.0:
			desired = Vector3(delta_to_target.x,0.0,delta_to_target.z).normalized()
		pursuit_flight_preference = pursuit_role != "no_flight" and target_distance < 70.0 and is_instance_valid(escapee) and (escapee.flight_enabled or escapee.actor.global_position.y>3.0)
	# Anticipate the smaller walls and stay in the real arena.
	var position: Vector3 = actor.global_position
	var edge: float = 40.0
	var correction := Vector3.ZERO
	if absf(position.x)>edge: correction.x = -signf(position.x)*(absf(position.x)-edge)/6.0
	if absf(position.z)>edge: correction.z = -signf(position.z)*(absf(position.z)-edge)/6.0
	if correction.length_squared()>0.001:
		var wall_strength: float = clampf(correction.length()*3.0,0.0,4.0)
		desired = (desired+correction.normalized()*wall_strength).normalized()
	if is_escapee:
		flight_enabled = pursuit_flight_preference and (position.y>0.6 or sin(clock*0.43)>0.55 or position.distance_to(pursuit_home)<30.0)
	elif pursuit_role=="no_flight":
		flight_enabled = false
	else:
		flight_enabled = pursuit_flight_preference
	actor.floor_snap_length = 0.0 if flight_enabled else 0.12
	# Apply ongoing spell damage and physics impulses in this same simulation.
	if spell_burn_remaining>0.0:
		spell_burn_remaining = maxf(0.0,spell_burn_remaining-dt)
		spell_burn_tick += dt
		if spell_burn_tick>=0.65:
			spell_burn_tick = 0.0
			var burn_damage: Node = get_node_or_null("DamageSystem")
			if burn_damage!=null and not burn_damage.dead:
				burn_damage.receive_region_hit("torso",actor.global_position+Vector3.UP,4.5,"BURN",false)
	if spell_venom_remaining>0.0:
		spell_venom_remaining = maxf(0.0,spell_venom_remaining-dt)
		spell_venom_tick += dt
		if spell_venom_tick>=0.8:
			spell_venom_tick=0.0
			var venom_damage: Node = get_node_or_null("DamageSystem")
			if venom_damage!=null and not venom_damage.dead:
				venom_damage.receive_region_hit("torso",actor.global_position+Vector3.UP,5.0,"VENOM",false)
	spell_frost_remaining = maxf(0.0,spell_frost_remaining-dt)
	spell_gravity_remaining = maxf(0.0,spell_gravity_remaining-dt)
	spell_tempest_remaining = maxf(0.0,spell_tempest_remaining-dt)
	var travel_speed: float = 11.4 if is_escapee else (12.7 if pursuit_role=="hunter" else (10.8 if pursuit_role=="no_flight" else (4.7 if pursuit_role=="no_sprint" else 12.2)))
	if flight_enabled:
		travel_speed = 15.2 if is_escapee else (17.0 if pursuit_role=="hunter" else (8.0 if pursuit_role=="no_sprint" else 14.5))
	if spell_frost_remaining>0.0: travel_speed *= 0.24
	if spell_tempest_remaining>0.0:
		desired = spell_tempest_direction
		travel_speed = 22.0*spell_tempest_remaining/0.75
	elif spell_gravity_remaining>0.0:
		desired = spell_gravity_origin-position
		desired.y = 0.0
		desired = desired.normalized()
		travel_speed = 13.0
	var wish_velocity: Vector3 = desired*travel_speed
	if flight_enabled:
		var destination_altitude: float = clampf((13.0+sin(clock*0.8)*2.0) if is_escapee else (escapee.actor.global_position.y+1.8 if is_instance_valid(escapee) else 10.0),5.0,28.0)
		wish_velocity.y = clampf((destination_altitude-position.y)*2.7,-12.0,12.0)
		actor.velocity = actor.velocity.move_toward(wish_velocity,dt*30.0)
	else:
		actor.velocity.x = move_toward(actor.velocity.x,wish_velocity.x,dt*27.0)
		actor.velocity.z = move_toward(actor.velocity.z,wish_velocity.z,dt*27.0)
		actor.velocity.y -= SIMPLE_JUMP_GRAVITY*dt
	actor.move_and_slide()
	if desired.length_squared()>0.01:
		actor.rotation.y = rotate_toward(actor.rotation.y,atan2(-desired.x,-desired.z),dt*7.0)
	if pursuit_role=="blink_hunter" and not combat_dead and is_instance_valid(escapee) and not escapee.combat_dead and blink_cooldown_remaining<=0.0:
		# Equivalent of the actor casting with W to close, or S to escape
		# dangerously close opponents and reposition its next spell.
		if target_distance>14.0 and target_distance<55.0:
			cast_blink(1.0)
		elif target_distance<6.5:
			cast_blink(-1.0)
	speed = Vector2(actor.velocity.x,actor.velocity.z).length()
	blend = speed_band(SPEEDS,speed)
	tree.set("parameters/Gaits/blend_position",blend)
	tree.set("parameters/Direction/blend_amount",0.0)
	tree.set("parameters/Cadence/scale",maxf(0.25,speed/3.5))
	tree.advance(dt)
	if flight_enabled:
		var planar_speed: float = Vector2(actor.velocity.x,actor.velocity.z).length()
		var tilt: float = clampf(atan2(planar_speed,maxf(-5.0,actor.velocity.y)),0.12,2.7)
		visual.rotation.x = move_toward(visual.rotation.x,tilt,dt*4.0)
		visual.position.y = 0.95*absf(sin(visual.rotation.x))
		apply_flight_pose(dt)
	else:
		visual.rotation.x = move_toward(visual.rotation.x,0.0,dt*6.0)
		visual.position.y = 0.0
	# Hunters pick spells from BOTH hands (other than flight), then throw
	# real palm-origin projectiles at the escaping target.
	if not is_escapee and is_instance_valid(escapee) and not escapee.combat_dead:
		pursuit_cast_timer -= dt
		if pursuit_cast_timer<=0.0 and target_distance<65.0 and cast_elapsed<0.0:
			var choices: Array[String] = ["fire","frost","homing","gravity","ricochet","grounding","tempest","venom"]
			var chosen: String = choices[(pursuit_spell_cursor+int(name.right(1)))%choices.size()]
			pursuit_spell_cursor += 1
			controlled_arm = "left" if chosen in ["grounding","tempest","venom"] else "right"
			var partner: String = "venom" if controlled_arm=="left" else ("homing" if chosen!="homing" else "fire")
			if pursuit_spell_cursor%3!=0 or not cast_spell_pair(chosen,partner):
				cast_spell(chosen)
			pursuit_cast_timer = 1.65 if pursuit_role=="hunter" else (2.3 if pursuit_role=="no_flight" else (3.3 if pursuit_role=="no_sprint" else 1.85))
	jab_aim_strength = 1.0
	adjust_jab_arm()
	update_cast_motion(dt)

func tick_live_spell_effects(dt: float) -> void:
	spell_grounded_remaining = maxf(0.0,spell_grounded_remaining-dt)
	spell_frost_remaining = maxf(0.0,spell_frost_remaining-dt)
	spell_gravity_remaining = maxf(0.0,spell_gravity_remaining-dt)
	spell_tempest_remaining = maxf(0.0,spell_tempest_remaining-dt)
	if spell_grounded_remaining>0.0:
		flight_enabled = false
		flight_windup_remaining = 0.0
	if spell_burn_remaining>0.0:
		spell_burn_remaining = maxf(0.0,spell_burn_remaining-dt)
		spell_burn_tick += dt
		if spell_burn_tick>=0.7:
			spell_burn_tick = 0.0
			var injury: Node = get_node_or_null("DamageSystem")
			if injury!=null and not injury.dead: injury.receive_region_hit("torso",actor.global_position+Vector3.UP,4.0,"BURN",false)
	if spell_venom_remaining>0.0:
		spell_venom_remaining = maxf(0.0,spell_venom_remaining-dt)
		spell_venom_tick += dt
		if spell_venom_tick>=0.85:
			spell_venom_tick = 0.0
			var injury: Node = get_node_or_null("DamageSystem")
			if injury!=null and not injury.dead: injury.receive_region_hit("torso",actor.global_position+Vector3.UP,4.0,"VENOM",false)
	if spell_regen_remaining>0.0:
		spell_regen_remaining = maxf(0.0,spell_regen_remaining-dt)
		spell_regen_tick += dt
		if spell_regen_tick>=0.5:
			spell_regen_tick = 0.0
			var damage: Node = get_node_or_null("DamageSystem")
			if damage!=null and not damage.dead:
				for region in damage.REGIONS:
					damage.hp[region] = minf(100.0,float(damage.hp[region])+2.5)
				damage.update_damage_colors()

func update_team_battle_agent(dt: float) -> void:
	# Full roster is shared by the arena scheduler; decisions use enemies only.
	# Navigation, targeting, flight, statuses and casts remain autonomous.
	var arena: Node = get_tree().current_scene
	if arena==null or combat_dead: return
	clock += dt
	blink_cooldown_remaining = maxf(0.0,blink_cooldown_remaining-dt)
	for i in range(spell_remaining.size()):
		spell_remaining[i] = maxf(0.0,spell_remaining[i]-dt)
	mana = minf(100.0,mana+18.0*dt)
	tick_live_spell_effects(dt)
	team_decision_timer -= dt
	var previous_target: Node = war_target
	if team_decision_timer<=0.0 or not team_is_enemy(war_target):
		team_decision_timer = agent_rng.randf_range(0.26,0.43)
		team_strafe_sign = -1.0 if agent_rng.randf()<0.5 else 1.0
		var best_score: float = INF
		war_target = null
		var fighters: Array = arena.active_war_fighters.duplicate()
		fighters.append(arena.player)
		for candidate in fighters:
			if not team_is_enemy(candidate): continue
			var enemy_damage: Node = candidate.get_node_or_null("DamageSystem")
			if enemy_damage==null or enemy_damage.dead: continue
			var dist: float = actor.global_position.distance_to(candidate.actor.global_position)
			var vulnerability: float = (100.0-float(enemy_damage.hp["torso"]))*0.10
			var score: float = dist-vulnerability+agent_rng.randf_range(-3.0,3.0)
			if candidate==previous_target: score-=4.0
			if score<best_score:
				best_score = score
				war_target = candidate
	var target_valid: bool = team_is_enemy(war_target)
	var offset: Vector3 = war_target.actor.global_position-actor.global_position if target_valid else Vector3.ZERO
	var planar: Vector3 = Vector3(offset.x,0.0,offset.z)
	var distance_m: float = planar.length()
	var forward: Vector3 = planar.normalized() if distance_m>0.01 else Vector3.FORWARD
	var flank: Vector3 = Vector3(-forward.z,0.0,forward.x)
	# Use an actual physics ray to distinguish a clear shot from an opponent
	# concealed by a wall, pillar, or another body.
	if target_valid and team_decision_timer>0.3:
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.2,war_target.actor.global_position+Vector3.UP*1.1)
		var sight_excludes: Array[RID] = [actor.get_rid()]
		# Teammates do not block our spells. Ignore their colliders when
		# deciding whether the intended enemy is exposed.
		for ally in arena.active_war_fighters:
			if is_instance_valid(ally) and ally != self and ally.team_id==team_id:
				sight_excludes.append(ally.actor.get_rid())
		if is_instance_valid(arena.player) and arena.player!=self and arena.player.team_id==team_id:
			sight_excludes.append(arena.player.actor.get_rid())
		ray.exclude = sight_excludes
		var obstacle: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray)
		team_clear_shot = obstacle.is_empty() or obstacle.get("collider")==war_target.actor
	var injury: Node = get_node_or_null("DamageSystem")
	var critical: bool = injury != null and (float(injury.hp["torso"])<42.0 or float(injury.hp["head"])<46.0)
	var desired: Vector3 = flank*team_strafe_sign*0.5
	if target_valid:
		if distance_m>21.0: desired += forward*1.3
		elif distance_m<10.0 or critical: desired -= forward*1.5
		else: desired += forward*0.2
		if not team_clear_shot: desired += flank*team_strafe_sign*1.9
	# Avoid incoming hostile spell paths without expensive full trajectory tests.
	team_projectile_dodge = team_projectile_dodge.move_toward(Vector3.ZERO,dt*7.0)
	if team_decision_timer>0.30:
		for shot in arena.war_nearby_projectiles(actor.global_position,1):
			if not is_instance_valid(shot): continue
			var motion: Node = shot.get_node_or_null("Motion")
			if motion == null or motion.caster_team==team_id: continue
			var inbound: Vector3 = actor.global_position-shot.global_position
			var ahead: float = inbound.dot(motion.travel_direction)
			if ahead<0.0 or ahead>14.0: continue
			var lateral_miss: Vector3 = inbound-motion.travel_direction*ahead
			if lateral_miss.length_squared()<11.0:
				team_projectile_dodge = flank*team_strafe_sign*2.3
	desired += team_projectile_dodge
	var edge_push := Vector3.ZERO
	var at: Vector3 = actor.global_position
	if absf(at.x)>39.0: edge_push.x = -signf(at.x)*2.0
	if absf(at.z)>39.0: edge_push.z = -signf(at.z)*2.0
	desired = (desired+edge_push).normalized()
	# Flight is a tactical route to airborne opponents and safe escapes.
	team_mobility_timer -= dt
	if team_mobility_timer<=0.0:
		team_mobility_timer = agent_rng.randf_range(0.85,1.65)
		var want_flight: bool = target_valid and spell_grounded_remaining<=0.0 and (war_target.flight_enabled or offset.y>3.5 or (critical and agent_rng.randf()<0.40))
		if want_flight and not flight_enabled:
			var flight_slot: int = SPELL_IDS.find("flight")
			if spell_is_ready(flight_slot):
				spend_spell(flight_slot)
				flight_enabled = true
		elif not want_flight:
			flight_enabled = false
	if spell_grounded_remaining>0.0: flight_enabled = false
	actor.floor_snap_length = 0.0 if flight_enabled else 0.12
	var movement_speed: float = 17.2 if not critical else 14.4
	if flight_enabled: movement_speed = 21.0
	if spell_frost_remaining>0.0: movement_speed *= 0.12
	if spell_gravity_remaining>0.0:
		desired = (spell_gravity_origin-at).normalized()
		movement_speed = 13.0
	if spell_tempest_remaining>0.0:
		desired = spell_tempest_direction
		movement_speed = 20.0
	var target_velocity: Vector3 = desired*movement_speed
	if flight_enabled:
		var height_goal: float = clampf((war_target.actor.global_position.y+2.0) if target_valid else 8.0,4.0,28.0)
		target_velocity.y = clampf((height_goal-at.y)*2.0,-9.0,10.0)
		actor.velocity = actor.velocity.move_toward(target_velocity,dt*44.0)
	else:
		actor.velocity.x = move_toward(actor.velocity.x,target_velocity.x,dt*41.0)
		actor.velocity.z = move_toward(actor.velocity.z,target_velocity.z,dt*41.0)
		actor.velocity.y -= SIMPLE_JUMP_GRAVITY*dt
	actor.move_and_slide()
	if desired.length_squared()>0.01:
		actor.rotation.y = rotate_toward(actor.rotation.y,atan2(-desired.x,-desired.z),dt*8.2)
	# Any teammate can blink to flank or escape, not only an assigned class.
	if target_valid and blink_cooldown_remaining<=0.0:
		if distance_m>22.0 and distance_m<43.0 and agent_rng.randf()<dt*1.5: cast_blink(1.0)
		elif distance_m<5.0 and critical: cast_blink(-1.0)
	speed = Vector2(actor.velocity.x,actor.velocity.z).length()
	blend = speed_band(SPEEDS,speed)
	tree.set("parameters/Gaits/blend_position",blend)
	tree.set("parameters/Direction/blend_amount",0.0)
	tree.set("parameters/Cadence/scale",maxf(0.2,speed/3.2))
	tree.advance(dt)
	if flight_enabled:
		var pitch: float = clampf(atan2(speed,maxf(-4.0,actor.velocity.y)),0.10,2.6)
		visual.rotation.x = move_toward(visual.rotation.x,pitch,dt*5.0)
		visual.position.y = 0.95*absf(sin(visual.rotation.x))
		apply_flight_pose(dt)
	else:
		visual.rotation.x = move_toward(visual.rotation.x,0.0,dt*7.0)
		visual.position.y = 0.0
	pursuit_cast_timer -= dt
	if pursuit_cast_timer<=0.0 and cast_elapsed<0.0:
		var chosen: String = ""
		# Heal wounded allies together. Squad spacing determines efficiency.
		var hurt_allies: int = 0
		for ally in arena.active_war_fighters:
			if not is_instance_valid(ally) or ally.combat_dead or ally.team_id!=team_id: continue
			if ally.actor.global_position.distance_to(at)>18.0: continue
			var ally_hp: Node = ally.get_node_or_null("DamageSystem")
			if ally_hp!=null and (float(ally_hp.hp["torso"])<75.0 or float(ally_hp.hp["head"])<75.0): hurt_allies+=1
		if arena.player.team_id==team_id and not arena.player.combat_dead and arena.player.actor.global_position.distance_to(at)<18.0:
			var player_hp: Node = arena.player.get_node_or_null("DamageSystem")
			if player_hp!=null and (float(player_hp.hp["torso"])<75.0 or float(player_hp.hp["head"])<75.0): hurt_allies+=1
		if hurt_allies>=2 or critical:
			if spell_is_ready(SPELL_IDS.find("bloom")): chosen = "bloom"
		if chosen=="" and target_valid and team_clear_shot and distance_m<67.0:
			# Prioritize counters, then fall back to ANY available attack.
			# The old single random pick silently wasted most attack windows
			# whenever the selected spell was on cooldown.
			var preferences: Array[String] = []
			if war_target.flight_enabled and war_target.spell_grounded_remaining<0.25: preferences.append("grounding")
			if war_target.spell_frost_remaining<0.25 and distance_m<38.0: preferences.append("frost")
			if distance_m<12.0: preferences.append("tempest")
			if distance_m>20.0: preferences.append("homing")
			var attacks: Array[String] = ["fire","homing","venom","gravity","frost","grounding","tempest","ricochet"]
			var seed_index: int = agent_rng.randi_range(0,attacks.size()-1)
			for i in range(attacks.size()):
				preferences.append(attacks[(seed_index+i)%attacks.size()])
			for candidate_spell in preferences:
				if spell_is_ready(SPELL_IDS.find(candidate_spell)):
					chosen = candidate_spell
					break
		if chosen!="":
			var spell_slot: int = SPELL_IDS.find(chosen)
			if spell_is_ready(spell_slot):
				controlled_arm = "left" if spell_slot>=5 else "right"
				var fused: bool = false
				if target_valid and FUSION_PROJECTILES.has(chosen) and agent_rng.randf()<0.45:
					var combo: Array[String] = [chosen]
					var candidates: Array[String] = []
					if spell_slot<5:
						if distance_m>12.0: candidates.append("homing")
						if war_target.spell_frost_remaining<0.25: candidates.append("frost")
						if distance_m<32.0: candidates.append("gravity")
						candidates.append_array(["fire","ricochet"])
					else:
						if war_target.flight_enabled: candidates.append("grounding")
						candidates.append_array(["tempest","venom"])
					for candidate in candidates:
						if combo.has(candidate): continue
						var proposed: Array[String] = combo.duplicate()
						proposed.append(candidate)
						if spell_combo_is_ready(proposed) and agent_rng.randf()<0.75: combo = proposed
					if combo.size()>1: fused = begin_projectile_cast(combo)
				if not fused: cast_spell(chosen)
		# Fire the next shot promptly when there is something ready to cast.
		# When every attack is on cooldown, check again instead of waiting a
		# full second on an already-rejected spell.
		pursuit_cast_timer = agent_rng.randf_range(0.34,0.59) if chosen!="" else 0.22
	jab_aim_strength = 1.0
	adjust_jab_arm()
	update_cast_motion(dt)

func war_simulation_tick(dt: float) -> void:
	if team_battle_ai:
		update_team_battle_agent(dt)
		return
	if pursuit_role != "":
		update_pursuit_agent(dt)
		return
	if spell_target_mode != "":
		update_spell_test_target(dt)
		return
	if animation_lineup_mode:
		update_animation_lineup(dt)
		return
	var full_physics: bool = false
	var arena: Node = get_tree().current_scene
	if arena != null:
		var spectator: Node = arena.get("player")
		if spectator != null and is_instance_valid(spectator):
			full_physics = actor.global_position.distance_squared_to(spectator.actor.global_position) < 324.0
	if war_target != null and is_instance_valid(war_target) and not war_target.combat_dead:
		# Preserve full-rate close-quarters collision; remote duels beyond 7m
		# are simulated at 15Hz, with accumulated dt preserving travel speed.
		if actor.global_position.distance_squared_to(war_target.actor.global_position) < 49.0:
			full_physics = true
	# Distant fireball casts are advanced by their own projectile physics callbacks.
	# A cast alone need not force the entire remote fighter into the 30 Hz tier.
	if full_physics:
		war_lod_mode = "full"
		var accumulated: float = dt + war_physics_accumulator
		war_physics_accumulator = 0.0
		war_physics_updates += 1
		update_war_fighter(accumulated)
	else:
		war_lod_mode = "reduced"
		war_physics_accumulator += dt
		# Remote actors move at 10 Hz; elapsed time accumulates to preserve
		# world speed and timers. Near-player and melee collision remain at 30 Hz.
		if war_physics_accumulator + 0.00001 < 1.0/10.0:
			war_physics_skips += 1
			return
		var accumulated: float = war_physics_accumulator
		war_physics_accumulator = 0.0
		war_physics_updates += 1
		update_war_fighter(accumulated)

func _physics_process(dt):
	if player_controlled and auto_war_combat and not combat_dead:
		auto_war_cast_clock -= dt
		if auto_war_cast_clock <= 0.0:
			auto_war_cast_clock = 2.5
			var arena: Node = get_tree().current_scene
			var closest: Node3D = null
			var distance_best: float = 1600.0
			if arena != null:
				for opponent in arena.active_war_fighters:
					if not is_instance_valid(opponent) or opponent.combat_dead: continue
					var distance_sq: float = actor.global_position.distance_squared_to(opponent.actor.global_position)
					if distance_sq < distance_best:
						distance_best = distance_sq
						closest = opponent
			if closest != null and cast_elapsed < 0.0:
				var changed_target: bool = war_target != closest
				war_target = closest
				# Reuse the AI aim/cast mechanic without enabling AI locomotion:
				# the player still owns movement, camera, flight and manual input.
				ai_abilities = true
				cast_spell("fire")
				ai_abilities = false
				if cast_elapsed >= 0.0 and arena != null:
					arena.record_player_auto_attack(closest.name)
					if changed_target: arena.record_player_auto_target_change(closest.name)
	if paused: return
	if player_controlled:
		flush_pending_spell()
		fusion_feedback_remaining = maxf(0.0,fusion_feedback_remaining-dt)
		tick_live_spell_effects(dt)
		blink_cooldown_remaining = maxf(0.0,blink_cooldown_remaining-dt)
		for i in range(spell_remaining.size()):
			spell_remaining[i] = maxf(0.0,spell_remaining[i]-dt)
		mana = 100.0 if infinite_mana else minf(100.0,mana+7.0*dt)
		var spending_stamina: bool = (alt_dash_held or Input.is_action_pressed("sprint")) and manual_input.length_squared()>0.02 and not sprint_exhausted
		stamina = clampf(stamina-(24.0 if alt_dash_held else 11.0)*dt if spending_stamina else stamina+18.0*dt,0.0,100.0)
		if stamina <= 0.0:
			sprint_exhausted = true
			alt_dash_held = false
		elif stamina >= 25.0:
			sprint_exhausted = false
		update_resource_hud()
	if combat_dead:
		update_combat_fall(dt)
		if player_controlled: update_camera()
		return
	if animation_test_mode == "sky_target":
		update_sky_target(dt)
		return
	if animation_test_mode == "war":
		if player_controlled: update_camera()
		# Arena owns updates of all war fighters. A fallback remains for isolated tests.
		if get_tree().current_scene.has_method("tick_war_fighters"): return
		war_simulation_tick(dt)
		return
	if animation_test_mode == "hunter":
		update_hunter_mannequin(dt)
		return
	if animation_test_mode == "fire":
		update_fire_mannequin(dt)
		return
	if animation_test_mode != "":
		update_animation_test(dt)
		return
	if stationary_only:
		tree.advance(dt)
		feet.use_full_support = false
		feet.resolve(true)
		apply_movement_clip(dt)
		return
	var step = dt*(0.35 if slow else 1.0)
	if player_controlled:
		# Jump and flight windup use imported Jumping Up motion, not mesh scaling.
		squat_amount = 0.0
		if squat_key_down and not flight_enabled:
			squat_hold_seconds = minf(squat_hold_seconds+step,SQUAT_MAX_CHARGE_SECONDS)
		if flight_windup_remaining > 0.0:
			flight_windup_remaining = maxf(0.0,flight_windup_remaining-step)
			if flight_windup_remaining <= 0.0:
				flight_enabled = true
				flight_launch_remaining = FLIGHT_LAUNCH_DURATION
				flight_clearance_time = 1.0
				squat_amount = 0.0
				start_movement_clip("Jumping Up.fbx")
				debug_player("FLIGHT_TAKEOFF","windup complete")
	clock += step
	# Solo showcase: physical launch, controlled flight and gravity landing.
	# This never touches the human-controlled forward sprint system.
	var solo_showcase: bool = name == "DemoNPC" and ai_mode == "sprint" and not player_controlled
	var solo_flight_time: float = fmod(clock,48.0) if solo_showcase else 0.0
	if solo_showcase:
		var should_fly: bool = solo_flight_time >= 32.0 and solo_flight_time < 42.0
		if should_fly and not flight_enabled:
			flight_enabled = true
			vertical_jump_speed = 0.0
			flight_launch_remaining = FLIGHT_LAUNCH_DURATION
			print("[SOLO_FLIGHT] takeoff t=",snappedf(clock,0.1))
		elif not should_fly and flight_enabled:
			flight_enabled = false
			flight_launch_remaining = 0.0
			vertical_jump_speed = 0.0
			print("[SOLO_FLIGHT] descent t=",snappedf(clock,0.1)," altitude=",snappedf(actor.position.y,0.1))
	jab_cooldown = maxf(0.0,jab_cooldown-step)
	jab_aim_remaining = maxf(0.0,jab_aim_remaining-step)
	jab_aim_strength = move_toward(jab_aim_strength,1.0 if (player_controlled or ai_abilities) else 0.0,step*8.0)
	if player_controlled: update_cursor_aim()
	if ai_abilities: update_ai_abilities(step)
	if ai_mode != "" or ai_abilities: update_agent_navigation(step)
	if ai_mode == "fly" and not flight_enabled:
		flight_enabled = true
		flight_launch_remaining = FLIGHT_LAUNCH_DURATION
		
		flight_clearance_time = 1.0
	var active = {}
	var old_blend = blend
	var old_back_blend = back_blend
	var was_turning = turning
	if player_controlled:
		manual_input = benchmark_flight_axis if benchmark_flight_active else Input.get_vector("move_left","move_right","move_back","move_forward")
		if manual_input.length()>0.01:
			# Face the camera's forward direction, not the lateral travel.
			manual_heading = orbit
		if not (Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_ALT)): manual_launch_lock = false
		if Input.is_action_just_pressed("sprint") and crouch.active():
			manual_launch_lock = true
			crouch.sprint()
	var crouch_driving = crouch.update(step)
	if player_controlled:
		var building_sprint = not crouch_driving and not crouch.active() and not manual_launch_lock and not sprint_exhausted and (Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_ALT)) and not Input.is_action_pressed("walk") and manual_input.y>0.1
		if not building_sprint:
			manual_sprint_clock = 0.0
		else:
			# Alt+W passes through run stages rapidly; a held second Alt tap
			# jumps directly into the final fast sprint, without a timed delay.
			manual_sprint_clock += step
			if alt_dash_held:
				manual_sprint_clock = maxf(manual_sprint_clock,SPRINT_STAGE_SECONDS*3.0)
	if ai_mode in ["walk","sprint","fly"]:
		signed_speed = move_toward(signed_speed,agent_preferred_speed,step*5.0)
		blend = speed_band(SPEEDS,absf(signed_speed))
		backward = false
		direction_weight = 0.0
	elif crouch_driving:
		signed_speed = crouch.forward_speed
	elif player_controlled:
		# Input axes remain separate: pure A/D never drives the forward gait.
		var target_speed: float = absf(manual_target_speed())
		var move_accel: float = step*(8.0 if manual_input.length()<0.01 else (105.0 if alt_dash_held and manual_input.y>0.1 else 20.0))
		signed_speed = move_toward(signed_speed,target_speed*manual_input.y,move_accel)
		# Double sideways travel without lengthening the acceleration ramp.
		# Forward/backward velocities and sprint progression are unchanged.
		var lateral_rate: float = 22.0 if manual_input.x*manual_side_speed <= 0.0 else 16.0
		var lateral_target: float = target_speed*manual_input.x*STRAFE_TRAVEL_MULTIPLIER
		manual_side_speed = move_toward(manual_side_speed,lateral_target,step*lateral_rate*STRAFE_TRAVEL_MULTIPLIER)
		backward = signed_speed < -0.01
		direction_weight = move_toward(direction_weight,1.0 if backward else 0.0,step*4.0)
		blend = speed_band(SPEEDS,absf(signed_speed))
		back_blend = speed_band(BACK_SPEEDS,absf(signed_speed))
	elif turning:
		turn_time += step
		var weight = smooth_gait(clamp(turn_time/4.0,0.0,1.0))
		blend = lerp(turn_start_forward,0.0,weight)
		back_blend = lerp(turn_start_back,0.0,weight)
		direction_weight = lerp(turn_start_weight,1.0 if turn_target else 0.0,weight)
		signed_speed = lerp(turn_start_speed,-BACK_SPEEDS[0] if turn_target else SPEEDS[0],weight)
		if turn_time>=4.0:
			turning = false
			backward = turn_target
			mode_clock = 0.0
	else:
		mode_clock += step
		if backward:
			active = schedule(mode_clock,[0,1,2,1])
			back_blend = active.blend
			blend = 0.0
			direction_weight = 1.0
			signed_speed = -band_value(BACK_SPEEDS,back_blend)
			seen[BACK_LABELS[active.a]] = true
		else:
			active = schedule(mode_clock,[0,1,2,3,4,5,4,3,2,1])
			blend = active.blend
			back_blend = 0.0
			direction_weight = 0.0
			signed_speed = band_value(SPEEDS,blend)
			seen[LABELS[active.a]] = true
		if mode_clock>=(40.0 if backward else 100.0): begin_direction_change(not backward)
	max_step = max(max_step,max(abs(blend-old_blend),abs(back_blend-old_back_blend)))
	var side_speed = crouch.lateral_speed if crouch_driving else (manual_side_speed if player_controlled else 0.0)
	# Solo CPU demonstration: alternate ordinary forward travel with
	# backward and lateral movement, using the existing collision and gait tree.
	var solo_direction_phase: int = -1
	if name == "DemoNPC" and ai_mode == "sprint":
		# Six 8-second ground phases: walk, run, sprint, backward,
		# left strafe, right strafe; flight overrides from 32s to 42s.
		var cycle_phase: float = fmod(clock,48.0)
		solo_direction_phase = 5 if cycle_phase >= 24.0 and cycle_phase < 28.0 else (4 if cycle_phase >= 28.0 and cycle_phase < 32.0 else -1)
		if cycle_phase >= 16.0 and cycle_phase < 24.0:
			solo_direction_phase = 2
		if solo_direction_phase == -1:
			backward = false
			signed_speed = 2.5 if cycle_phase < 8.0 else (6.0 if cycle_phase < 12.0 else (0.0 if cycle_phase >= 42.0 else 11.0))
			blend = speed_band(SPEEDS,signed_speed)
			direction_weight = 0.0
		if cycle_phase >= 12.0 and cycle_phase < 12.1 and actor.is_on_floor():
			vertical_jump_speed = 6.0
			print("[MOTION_DEMO] jump")
		if solo_direction_phase == 2 or solo_direction_phase == 3:
			backward = true
			signed_speed = -minf(agent_preferred_speed,BACK_SPEEDS[2])
			blend = 0.0
			back_blend = speed_band(BACK_SPEEDS,absf(signed_speed))
			direction_weight = 1.0
		elif solo_direction_phase == 4 or solo_direction_phase == 5:
			# Lateral velocity uses the existing actor.move_and_slide path.
			side_speed = 2.0*(1.0 if solo_direction_phase == 4 else -1.0)
			signed_speed = 0.0
			blend = speed_band(SPEEDS,absf(side_speed))
			back_blend = 0.0
			direction_weight = 0.0
		else:
			backward = false
			direction_weight = 0.0
	speed = Vector2(side_speed,signed_speed).length()
	walk_choice = move_toward(walk_choice,walk_target,step/4.0)
	var forward_strides = STRIDES.duplicate()
	forward_strides[0] = lerp(STRIDES[0],1.646443612,walk_choice)
	var stride = lerp(band_value(forward_strides,blend),band_value(BACK_STRIDES,back_blend),direction_weight)
	tree.set("parameters/Gaits/Walk/Choice/blend_amount",walk_choice)
	tree.set("parameters/Gaits/blend_position",blend)
	tree.set("parameters/BackGaits/blend_position",back_blend)
	tree.set("parameters/Direction/blend_amount",direction_weight)
	# Pure A/D is strafing. Diagonals retain a proportional forward/backward gait.
	# The speed envelope fades the strafe out while slowing into standing idle.
	var strafe_weight: float = 0.0
	if not flight_enabled:
		strafe_weight = absf(side_speed)/maxf(speed,0.001)
		strafe_weight *= smoothstep(0.10,STRAFE_ACTIVATE_SPEED,speed)
	var target_left: float = strafe_weight if side_speed < -0.01 and solo_left_strafe_available else 0.0
	var target_right: float = strafe_weight if side_speed > 0.01 and solo_right_strafe_available else 0.0
	var strafe_lerp: float = 1.0-exp(-STRAFE_BLEND_RATE*step)
	strafe_left_blend = lerpf(strafe_left_blend,target_left,strafe_lerp)
	strafe_right_blend = lerpf(strafe_right_blend,target_right,strafe_lerp)
	if solo_left_strafe_available:
		tree.set("parameters/SoloLeftBlend/blend_amount",strafe_left_blend)
	if solo_right_strafe_available:
		tree.set("parameters/SoloRightBlend/blend_amount",strafe_right_blend)
	# The rig rotates more strongly INTO the strafe, but the collider and
	# camera-relative travel remain facing forward. The same blend smoothly
	# restores the normal facing on release and on left/right reversals.
	if player_controlled:
		var visible_strafe: float = strafe_right_blend-strafe_left_blend
		visual.rotation.y = PI-deg_to_rad(STRAFE_VISUAL_YAW)*visible_strafe
	# Use pre-boost lateral speed as the animation's speed reference. Then
	# halve the strafe playback independently of the doubled travel distance.
	# The original run cadence stays untouched whenever strafing is inactive.
	var active_strafe: float = maxf(strafe_left_blend,strafe_right_blend)
	var cadence: float = lerpf(speed/stride,speed/2.0,active_strafe)
	if player_controlled and not crouch_driving:
		var original_speed: float = Vector2(side_speed/STRAFE_TRAVEL_MULTIPLIER,signed_speed).length()
		var original_cadence: float = lerpf(original_speed/stride,original_speed/2.0,active_strafe)
		cadence = original_cadence*lerpf(1.0,STRAFE_PLAYBACK_MULTIPLIER,active_strafe)
	tree.set("parameters/Cadence/scale",1.0 if flight_enabled else cadence)
	if player_controlled: tree.set("parameters/StandingMove/blend_amount",smooth_gait(clamp(speed/0.85,0.0,1.0)))
	if player_controlled:
		var moving_now = speed > 0.12 or crouch.active()
		if was_moving_for_idle and not moving_now: choose_random_idle()
		was_moving_for_idle = moving_now
	tree.advance(step)
	if player_controlled and not flight_enabled:
		visual.position.y = 0.0
		visual.scale.y = 1.0
	if player_controlled or ai_abilities or ai_mode == "fly" or solo_showcase:
		apply_flight_pose(step)
	if player_controlled:
		apply_injured_walk(step)
		apply_movement_clip(step)
		update_punch_contact(step)
	if player_controlled:
		debug_tick += step
		if debug_tick >= 0.25:
			debug_tick = 0.0
			var state: String = "FLIGHT" if flight_enabled else ("JUMP" if not actor.is_on_floor() else ("MOVE" if speed>0.1 else "IDLE"))
			if state != last_debug_state:
				debug_player("STATE_CHANGE",last_debug_state+" -> "+state)
				last_debug_state = state
			debug_player("TELEMETRY","state="+state+" input="+str(manual_input)+" velocity="+str(actor.velocity)+" grounded="+str(actor.is_on_floor())+" squat="+str(snappedf(squat_amount,0.01))+" key="+str(squat_key_down)+" visual_y="+str(snappedf(visual.position.y,0.01))+" visual_scale_y="+str(snappedf(visual.scale.y,0.01))+" animation=pelvis_only"+" animation_cadence="+str(snappedf(cadence,0.01))+" strafe_weight="+str(snappedf(strafe_weight,0.01))+" strafe_left_blend="+str(snappedf(strafe_left_blend,0.01))+" strafe_right_blend="+str(snappedf(strafe_right_blend,0.01))+" visual_yaw="+str(snappedf(rad_to_deg(wrapf(visual.rotation.y-PI,-PI,PI)),0.1))+" strafe_side_mps="+str(snappedf(side_speed,0.01))+" strafe_left_ready="+str(solo_left_strafe_available)+" strafe_right_ready="+str(solo_right_strafe_available)+" flight_idle="+str(snappedf(flight_idle_weight,0.01))+" cam_yaw="+str(snappedf(orbit,0.01))+" cam_pitch="+str(snappedf(elevation,0.01)))
	# Calibration only: pitch the visible character down, never the collider.
	if name == "DemoNPC" and ai_mode == "sprint" and not flight_enabled:
		visual.rotation.x = deg_to_rad(-8.0)
	if player_controlled or ai_abilities:
		adjust_jab_arm()
		update_cast_motion(step)
	feet.use_full_support = (crouch_driving or crouch.active()) and not ((player_controlled or ai_abilities or ai_mode == "fly") and (flight_enabled or not actor.is_on_floor()))
	if not flight_enabled and actor.is_on_floor():
		if war_pose_enabled: feet.resolve(true)
	else:
		visual.position.y = 0.0
	crouch.update_capsule(step)
	if test and frame%60==0: min_body = min(min_body,feet.lowest(feet.all_samples))
	min_sole = min(min_sole,feet.minimum)
	max_lift = max(max_lift,feet.lift)
	var radial = Vector3(actor.position.x-route_center.x,0,actor.position.z-route_center.z)
	var angle = atan2(radial.x,radial.z)
	var tangent = Vector3(cos(angle),0,-sin(angle))
	var movement_sign = -1.0 if signed_speed<0.0 else 1.0
	# The body keeps facing the same tangent while its travel reverses.
	var facing = tangent*max(speed,0.1)-radial.normalized()*(radial.length()-route_radius)*2.0*movement_sign
	if player_controlled:
		if flight_enabled:
			actor.rotation.y = rotate_toward(actor.rotation.y,orbit,step*7.0)
		elif crouch_driving and crouch.state in ["crouched","settle"]:
			actor.rotation.y = rotate_toward(actor.rotation.y,orbit,step*5.0)
		elif not crouch_driving or crouch.state in ["brake","recover","standing"]:
			actor.rotation.y = rotate_toward(actor.rotation.y,manual_heading,step*5.0)
	elif ai_mode != "" or ai_abilities:
		# Keep facing the selected direction while moving sideways/backwards.
		# Preserve normal agent steering during forward-running phases.
		var showcase_facing: float = manual_heading
		if name == "DemoNPC" and ai_mode == "sprint" and solo_direction_phase >= 2 and solo_direction_phase <= 5:
			showcase_facing = deg_to_rad(55.0) if solo_direction_phase == 5 else deg_to_rad(-55.0) # Stronger sideways presentation, not forward walking.
		actor.rotation.y = rotate_toward(actor.rotation.y,showcase_facing,step*(2.3 if ai_mode == "walk" else 4.4))
	elif crouch_driving and crouch.state in ["crouched","settle"] and speed>0.01:
		var travel_direction = -tangent*speed-radial.normalized()*(radial.length()-route_radius)*2.0
		var local_yaw = atan2(-side_speed,signed_speed)
		var target_yaw = atan2(-travel_direction.x,-travel_direction.z)-local_yaw
		actor.rotation.y = rotate_toward(actor.rotation.y,target_yaw,step*1.8)
	elif not crouch_driving or crouch.state in ["brake","recover","standing"]:
		actor.rotation.y = rotate_toward(actor.rotation.y,atan2(-facing.x,-facing.z),step*(1.2 if crouch_driving else 2.8))
	actor.velocity = (-actor.global_basis.z*signed_speed+actor.global_basis.x*side_speed)*(0.35 if slow else 1.0)
	# Diagnostic: keep world travel exactly LEFT despite the 30-degree
	# facing adjustment. Otherwise the rotation changes the movement path.
	if name == "DemoNPC" and ai_mode == "sprint" and (solo_direction_phase == 5 or solo_direction_phase == 4):
		actor.velocity.x = side_speed*(0.35 if slow else 1.0)
		actor.velocity.z = 0.0
	var injury_system: Node = get_node_or_null("DamageSystem")
	if injury_system != null and not flight_enabled and (float(injury_system.hp["left_leg"]) <= 20.0 or float(injury_system.hp["right_leg"]) <= 20.0):
		actor.velocity.x = clampf(actor.velocity.x,-SPEEDS[0],SPEEDS[0])
		actor.velocity.z = clampf(actor.velocity.z,-SPEEDS[0],SPEEDS[0])
	if player_controlled and not flight_enabled and not actor.is_on_floor():
		actor.velocity.x *= AIR_JUMP_TRAVEL_MULTIPLIER
		actor.velocity.z *= AIR_JUMP_TRAVEL_MULTIPLIER
	if player_controlled or ai_abilities or ai_mode == "fly" or solo_showcase: actor.floor_snap_length = 0.0 if flight_enabled else 0.12
	if player_controlled or ai_abilities or ai_mode == "fly" or solo_showcase:
		if flight_enabled:
			if solo_showcase:
				# Real collision remains active; rise and then hold altitude.
				var target_altitude: float = 13.0 + sin((solo_flight_time-34.0)*0.75)*2.0
				actor.velocity.y = clampf((target_altitude-actor.position.y)*2.0,-6.0,12.0)
			elif ai_abilities or ai_mode == "fly":
				actor.velocity.y = (1.0 if ai_mode == "fly" and actor.position.y < 5.0 else sin(clock*0.9)*0.6)*FLIGHT_SPEED
			else:
				# W moves in the camera's three-dimensional aim direction.
				var forward_flight := Vector3(-sin(orbit)*cos(elevation),sin(elevation),-cos(orbit)*cos(elevation))
				var right_flight := Vector3(cos(orbit),0.0,-sin(orbit))
				var flight_direction: Vector3 = benchmark_flight_direction if benchmark_flight_active else forward_flight * manual_input.y + right_flight * manual_input.x
				if flight_direction.length_squared() > 1.0: flight_direction = flight_direction.normalized()
				if player_controlled:
					if flight_direction.length_squared() > 0.001:
						flight_acceleration_time += step*(2.0 if Input.is_action_pressed("sprint") and not sprint_exhausted else 1.0)
					else:
						flight_acceleration_time = 0.0
				# A held double-Alt gives a short, powerful flight dash. Once
				# released, smoothly fall back to ordinary flight acceleration.
				var flight_boost: float = FLIGHT_SPEED * (pow(1.15,minf(flight_acceleration_time,45.0)/2.0)-1.0)
				flight_dash_speed = move_toward(flight_dash_speed,DASH_FLIGHT_SPEED if alt_dash_held and flight_direction.length_squared()>0.001 else 0.0,step*(100.0 if alt_dash_held else 25.0))
				actor.velocity = flight_direction * maxf(maxf(absf(signed_speed),FLIGHT_SPEED+flight_boost),flight_dash_speed)
				actor.velocity.y += (float(Input.is_key_pressed(KEY_SPACE))-float(Input.is_key_pressed(KEY_CTRL)))*FLIGHT_SPEED
			if flight_launch_remaining > 0.0:
				var launch_progress: float = 1.0-flight_launch_remaining/FLIGHT_LAUNCH_DURATION
				var launch_weight: float = 1.0-smoothstep(0.35,1.0,launch_progress)
				actor.velocity.y = maxf(actor.velocity.y,FLIGHT_LAUNCH_SPEED*launch_weight)
				flight_launch_remaining = maxf(0.0,flight_launch_remaining-step)
		else:
			vertical_jump_speed -= SIMPLE_JUMP_GRAVITY * step
			actor.velocity.y = vertical_jump_speed
	else:
		actor.velocity.y = -0.3
	var flight_impact_speed: float = -actor.velocity.y if player_controlled and flight_enabled and actor.velocity.y < 0.0 else 0.0
	# Frost reduces flight movement too, not only ground running.
	if player_controlled and spell_frost_remaining>0.0 and flight_enabled:
		actor.velocity *= 0.12
	# Lower travel speed only; physics gravity and jump impulses remain normal.
	if player_controlled:
		if not flight_enabled: flight_dash_speed = 0.0
		actor.velocity.x *= 0.5
		actor.velocity.z *= 0.5
		if flight_enabled and actor.velocity.y > 0.0: actor.velocity.y *= 0.5
	actor.move_and_slide()
	if solo_showcase and not flight_enabled and actor.is_on_floor() and actor.position.y <= 0.1 and solo_flight_time >= 42.0:
		if not solo_landing_logged:
			print("[SOLO_FLIGHT] landed t=",snappedf(clock,0.1))
			solo_landing_logged = true
	elif solo_flight_time < 32.0:
		solo_landing_logged = false
	if player_controlled and not flight_enabled and actor.is_on_floor():
		vertical_jump_speed = 0.0
		if movement_clip_name == "Jumping Up.fbx":
			movement_clip_name = ""
	if flight_clearance_time > 0.0: flight_clearance_time = maxf(0.0,flight_clearance_time-step)
	if player_controlled and flight_enabled and flight_launch_remaining <= 0.0 and actor.velocity.y <= 0.0:
		# Only land while approaching the floor, never on launch or ascent.
		var floor_cast: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*0.12,actor.global_position+Vector3.DOWN*FLIGHT_LAND_HEIGHT)
		floor_cast.exclude = [actor.get_rid()]
		var floor_hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(floor_cast)
		if not floor_hit.is_empty() and Vector3(floor_hit["normal"]).y > 0.72 and flight_clearance_time <= 0.0:
			flight_enabled = false
			flight_launch_remaining = 0.0
			actor.floor_snap_length = 0.12
			if player_controlled:
				movement_clip_name = ""
				print("FLIGHT_AUTO_LANDED speed=",flight_impact_speed)
	if player_controlled or ai_abilities or ai_mode == "fly" or solo_showcase:
		update_flight_orientation(step)

	# This arena has a flat floor at zero, including at wall contacts.
	if actor.position.y<0.0:
		actor.position.y = 0.0
		actor.velocity.y = 0.0
	if backward and not turning and not crouch_driving:
		backward_distance += speed*step
		minimum_facing_alignment = min(minimum_facing_alignment,(-actor.global_basis.z).dot(tangent))
	traveled += speed*step
	# Off-screen CPUs do not need to update private cameras or hidden HUDs.
	if autonomous_only: return
	update_camera()
	if player_controlled: update_speed_streaks(step)
	if player_controlled:
		var player_state = crouch.state.to_upper() if crouch.active() else ("IDLE" if speed<0.05 else ("BACKWARD" if backward else ("SPRINTING" if speed>8.0 else "RUNNING")))
		hud.text = "YOU | %s | %.1f m/s | SPRINT %.1fs | TARGET %.1f m/s" % ["FLYING" if flight_enabled else player_state,actor.velocity.length() if flight_enabled else Vector2(actor.velocity.x,actor.velocity.z).length(),manual_sprint_clock,manual_target_speed()]
	elif crouch_driving:
		hud.text = crouch.status()
	elif was_turning or turning:
		hud.text = "MALE Y BOT  |  CHANGING DIRECTION\n%.2f m/s   |   easing through a stop\nB changes direction   |   AI automatically demonstrates both\nW compares the two walks" % speed
	elif ai_mode != "":
		# Dedicated autonomous locomotion does not populate schedule()'s
		# a/b/weight keys. Never use the demo HUD in these modes.
		hud.text = "%s  |  %.1f m/s  |  %s" % [name,absf(signed_speed),"FLYING" if flight_enabled else ai_mode.to_upper()]
	else:
		var names = BACK_LABELS if backward else LABELS
		var files = BACK_FILES if backward else FILE_LABELS
		if active.has("a") and active.has("b") and active.has("weight"):
			hud.text = "MALE Y BOT  |  %s -> %s\n%.2f m/s   |   %s   |   blend %.0f%%\nFile: %s\nB changes direction   |   W compares walks" % [names[active["a"]],names[active["b"]],speed,"BACKWARD" if backward else "FORWARD",active["weight"]*100,files[active["a"]] if backward or active["a"]!=0 or walk_choice<0.5 else "Walking.fbx"]
		else:
			hud.text = "%s  |  %.1f m/s" % [name,absf(signed_speed)]
func update_camera():
	var subject: CharacterBody3D = camera_target if is_instance_valid(camera_target) else actor
	if subject==null or camera==null: return
	# CrouchController extends RefCounted, NOT Node. Do not type it as Node:
	# doing so prevents walking.gd from compiling and leaves the arena empty.
	var subject_controller = crouch
	if subject!=actor and is_instance_valid(subject.get_parent()):
		var parent_controller: Node = subject.get_parent()
		var target_crouch = parent_controller.get("crouch")
		if target_crouch!=null: subject_controller = target_crouch
	var focus_target: float = subject_controller.capsule.height*0.58 if subject_controller.capsule!=null else 1.05
	camera_focus_height = lerpf(camera_focus_height,focus_target,0.18)
	var focus: Vector3 = subject.global_position+Vector3.UP*camera_focus_height
	if player_controlled and combat_dead and subject==actor and skeleton!=null:
		# Follow the actual animated body (not only its upright physics capsule).
		# It may still be airborne, pitching forward, or lying prone after death.
		skeleton.force_update_all_bone_transforms()
		var torso_index: int = -1
		for bone_name in ["Spine2","Spine1","Spine","mixamorig:Spine2","mixamorig:Spine1","mixamorig:Spine","Hips","mixamorig:Hips"]:
			torso_index = skeleton.find_bone(bone_name)
			if torso_index>=0: break
		if torso_index>=0:
			var torso_center: Vector3 = skeleton.global_transform*skeleton.get_bone_global_pose(torso_index).origin
			if torso_center.distance_to(subject.global_position)<3.5:
				focus = torso_center
	# World-space follow is mandatory when grounding pulls a flying fighter
	# down. Avoid root-local offsets and never smooth the actor's world Y.
	camera.global_position = focus+Vector3(sin(orbit)*cos(elevation),-sin(elevation),cos(orbit)*cos(elevation))*distance
	camera.look_at(focus,Vector3.UP)
func _process(_dt):
	frame += 1
	var shots = OS.get_environment("WALK_SHOTS")
	if shots!="" and frame in [180,540,780,1140,1380,1740,1980,2340,2580,2940]:
		get_viewport().get_texture().get_image().save_png(shots+"/mixamo-%04d.png"%frame)
	if test and clock>=(10.0 if "--new-walk" in OS.get_cmdline_user_args() else 149.0):
		print("BACKWARD_TEST gaits=",seen," traveled=",traveled," min_sole=",min_sole," min_body=",min_body," backward_distance=",backward_distance," facing_alignment=",minimum_facing_alignment," max_lift=",max_lift," max_blend_step=",max_step," wall_seconds=",(Time.get_ticks_msec()-started)/1000.0)
		get_tree().quit(0 if max_lift<0.15 and min_sole>=0.0059 and min_body>=0.0 else 1)
func manual_target_speed() -> float:
	if manual_input.length()<0.01: return 0.0
	var desired_speed: float = 0.0
	var injury: Node = get_node_or_null("DamageSystem")
	if injury != null and (float(injury.hp["left_leg"]) <= 20.0 or float(injury.hp["right_leg"]) <= 20.0):
		desired_speed = -BACK_SPEEDS[0] if manual_input.y < -0.1 else SPEEDS[0]
	else:
		var sprinting: bool = (Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_ALT)) and not manual_launch_lock and not sprint_exhausted
		if manual_input.y< -0.1: desired_speed = -BACK_SPEEDS[2] if sprinting else -BACK_SPEEDS[1]
		elif Input.is_action_pressed("walk"): desired_speed = SPEEDS[0]
		elif not sprinting or manual_input.y<=0.1: desired_speed = SPEEDS[2]
		elif alt_dash_held and not flight_enabled: desired_speed = DASH_GROUND_SPEED
		else:
			var progress: float = manual_sprint_clock / SPRINT_STAGE_SECONDS
			if progress>=3.0: desired_speed = SPEEDS[5]+(progress-3.0)*ENDLESS_SPRINT_GAIN
			else:
				var stage: int = mini(int(progress),2)
				desired_speed = lerp(float(SPEEDS[2+stage]),float(SPEEDS[3+stage]),smooth_gait(progress-stage))
	# Frost truly slows Black's movement, not only the autonomous fighters.
	return desired_speed*(0.12 if spell_frost_remaining>0.0 else 1.0)
func speed_band(values: Array, value: float) -> float:
	for index in range(values.size()-1):
		if value<=values[index+1]: return clamp(float(index)+(value-values[index])/(values[index+1]-values[index]),0.0,float(values.size()-1))
	return float(values.size()-1)
func normalized_idle_bone(name: String) -> String:
	var simplified = name.to_lower().replace(":", "").replace("_", "").replace(" ", "")
	simplified = simplified.replace("mixamorig", "")
	while simplified.length() > 0 and simplified.unicode_at(0) >= 48 and simplified.unicode_at(0) <= 57:
		simplified = simplified.substr(1)
	return simplified

func make_standing_idle(player: AnimationPlayer):
	# Import as many of the user's authored FBX idle motions as match the Y Bot.
	# These all run on the ORIGINAL Y Bot mesh in the standing blend-tree slot.
	var source_template: Animation = player.get_animation("NewWalk")
	var destination_paths := {}
	for t in range(source_template.get_track_count()):
		if source_template.track_get_type(t) != Animation.TYPE_ROTATION_3D: continue
		var target_path = source_template.track_get_path(t)
		if target_path.get_subname_count() == 0: continue
		var n = normalized_idle_bone(String(target_path.get_subname(target_path.get_subname_count()-1)))
		destination_paths[n] = target_path
	var library = AnimationLibrary.new()
	idle_variants.clear()
	var wanted = ["Idle (3).fbx", "Breathing Idle.fbx", "Idle (2).fbx", "Offensive Idle.fbx", "Neutral Idle.fbx"]
	for filename in wanted:
		var path = "res://assets/custom_idle/" + filename
		if not ResourceLoader.exists(path): continue
		var packed = load(path)
		if not packed is PackedScene: continue
		var root = packed.instantiate()
		var animators = root.find_children("*","AnimationPlayer",true,false)
		var rigs = root.find_children("*","Skeleton3D",true,false)
		if animators.is_empty() or rigs.is_empty():
			root.free()
			continue
		var src_rig: Skeleton3D = rigs[0]
		var src_bones := {}
		for i in range(src_rig.get_bone_count()):
			src_bones[normalized_idle_bone(String(src_rig.get_bone_name(i)))] = i
		var dest_bones := {}
		for i in range(skeleton.get_bone_count()):
			dest_bones[normalized_idle_bone(String(skeleton.get_bone_name(i)))] = i
		var best = -1
		var motion: Animation = null
		for animator in animators:
			for name in animator.get_animation_list():
				if name == "RESET": continue
				var candidate: Animation = animator.get_animation(name)
				var score := 0
				for t in range(candidate.get_track_count()):
					if candidate.track_get_type(t) != Animation.TYPE_ROTATION_3D or candidate.track_get_key_count(t) < 2: continue
					var first: Quaternion = candidate.track_get_key_value(t,0)
					var mid: Quaternion = candidate.track_get_key_value(t,int(candidate.track_get_key_count(t)/2))
					if absf(first.dot(mid)) < 0.99999: score += 1
				if score > best:
					best = score
					motion = candidate
		if motion != null and best > 0:
			var idle = Animation.new()
			idle.length = motion.length
			idle.loop_mode = Animation.LOOP_LINEAR
			var tracks := 0
			for t in range(motion.get_track_count()):
				if motion.track_get_type(t) != Animation.TYPE_ROTATION_3D: continue
				var sp = motion.track_get_path(t)
				if sp.get_subname_count() == 0: continue
				var n = normalized_idle_bone(String(sp.get_subname(sp.get_subname_count()-1)))
				if not destination_paths.has(n) or not src_bones.has(n) or not dest_bones.has(n): continue
				var src_index: int = src_bones[n]
				var dst_index: int = dest_bones[n]
				var src_rest = src_rig.get_bone_rest(src_index).basis.get_rotation_quaternion()
				var dst_rest = skeleton.get_bone_rest(dst_index).basis.get_rotation_quaternion()
				var correction: Quaternion = (dst_rest.inverse() * src_rest).normalized()
				var out = idle.add_track(Animation.TYPE_ROTATION_3D)
				idle.track_set_path(out,destination_paths[n])
				# The imported Mixamo Hips rotation uses the source character's root
				# orientation. Applying it on the Y Bot turns the entire body sideways.
				# Lock only the target root to its own known-upright standing orientation;
				# all other joints retain their imported idle motion.
				if n == "hips":
					var upright: Quaternion = Quaternion.IDENTITY
					for template_track in range(source_template.get_track_count()):
						if source_template.track_get_type(template_track) == Animation.TYPE_ROTATION_3D and source_template.track_get_path(template_track) == destination_paths[n]:
							upright = source_template.rotation_track_interpolate(template_track, source_template.length * 0.48)
							break
					idle.rotation_track_insert_key(out,0.0,upright)
					idle.rotation_track_insert_key(out,idle.length,upright)
				elif filename == "Neutral Idle.fbx" and (n.begins_with("spine") or n == "neck" or n == "head"):
					# Keep the imported idle upright on the destination skeleton.
					# Use the proven upright Y Bot torso/head orientation only for
					# these joints; keep its arms and other motion as imported.
					var neutral: Quaternion = Quaternion.IDENTITY
					for template_track in range(source_template.get_track_count()):
						if source_template.track_get_type(template_track) == Animation.TYPE_ROTATION_3D and source_template.track_get_path(template_track) == destination_paths[n]:
							neutral = source_template.rotation_track_interpolate(template_track, source_template.length * 0.48)
							break
					idle.rotation_track_insert_key(out,0.0,neutral)
					idle.rotation_track_insert_key(out,idle.length,neutral)
				else:
					for k in range(motion.track_get_key_count(t)):
						var rot: Quaternion = motion.track_get_key_value(t,k)
						idle.rotation_track_insert_key(out,motion.track_get_key_time(t,k),(correction*rot*correction.inverse()).normalized())
				tracks += 1
			if tracks >= 12:
				var id = "Idle3" if filename == "Idle (3).fbx" else ("BreathingIdle" if filename == "Breathing Idle.fbx" else ("Idle1" if filename == "Idle (2).fbx" else ("Idle2" if filename == "Offensive Idle.fbx" else "Idle0")))
				library.add_animation(id,idle)
				idle_variants.append("manual/"+id)
				if player_controlled: print("IDLE_REGISTERED ",filename," name=",id," tracks=",tracks," length=",idle.length)
			else:
				if player_controlled: print("IDLE_REJECTED ",filename," mapped_tracks=",tracks)
		root.free()
	if idle_variants.is_empty():
		push_warning("No compatible idle FBX installed; put Idle (3).fbx in Downloads and rerun RUN.bat.")
		var fallback = Animation.new()
		fallback.length = 1.0
		fallback.loop_mode = Animation.LOOP_LINEAR
		var at = source_template.length * 0.48
		for t in range(source_template.get_track_count()):
			if source_template.track_get_key_count(t) == 0: continue
			var kind = source_template.track_get_type(t)
			if kind not in [Animation.TYPE_ROTATION_3D,Animation.TYPE_POSITION_3D,Animation.TYPE_SCALE_3D]: continue
			var value
			match kind:
				Animation.TYPE_ROTATION_3D: value = source_template.rotation_track_interpolate(t,at)
				Animation.TYPE_POSITION_3D: value = source_template.position_track_interpolate(t,at)
				Animation.TYPE_SCALE_3D: value = source_template.scale_track_interpolate(t,at)
			var out = fallback.add_track(kind)
			fallback.track_set_path(out,source_template.track_get_path(t))
			fallback.track_insert_key(out,0.0,value)
			fallback.track_insert_key(out,1.0,value)
		library.add_animation("Fallback",fallback)
		idle_variants.append("manual/Fallback")
	player.add_animation_library("manual",library)

func install_left_jab(player: AnimationPlayer, graph: AnimationNodeBlendTree) -> void:
	# One imported, upper-body-only Mixamo punch. Preserve the original rig,
	# locomotion, feet, hip orientation, and random standing idle selection.
	var path = "res://assets/custom_idle/Punching.fbx"
	if not ResourceLoader.exists(path):
		push_warning("LEFT_JAB_MISSING: place Punching.fbx in Downloads and run RUN.bat")
		return
	var packed = load(path)
	if not packed is PackedScene: return
	var root = packed.instantiate()
	var animators = root.find_children("*","AnimationPlayer",true,false)
	var rigs = root.find_children("*","Skeleton3D",true,false)
	if animators.is_empty() or rigs.is_empty():
		root.free()
		push_warning("LEFT_JAB_FBX_NO_SKELETON")
		return
	var source_rig: Skeleton3D = rigs[0]
	var source_bones := {}
	for i in range(source_rig.get_bone_count()):
		source_bones[normalized_idle_bone(String(source_rig.get_bone_name(i)))] = i
	var dest_bones := {}
	for i in range(skeleton.get_bone_count()):
		dest_bones[normalized_idle_bone(String(skeleton.get_bone_name(i)))] = i
	var valid_paths := {}
	var reference: Animation = player.get_animation("NewWalk")
	for i in range(reference.get_track_count()):
		if reference.track_get_type(i) != Animation.TYPE_ROTATION_3D: continue
		var p = reference.track_get_path(i)
		if p.get_subname_count() == 0: continue
		var n = normalized_idle_bone(String(p.get_subname(p.get_subname_count()-1)))
		valid_paths[n] = p
	var chosen: Animation = null
	var best := 0
	for animator in animators:
		for name in animator.get_animation_list():
			if name == "RESET": continue
			var candidate: Animation = animator.get_animation(name)
			var moving := 0
			for i in range(candidate.get_track_count()):
				if candidate.track_get_type(i) != Animation.TYPE_ROTATION_3D or candidate.track_get_key_count(i) < 2: continue
				var first: Quaternion = candidate.track_get_key_value(i,0)
				var mid: Quaternion = candidate.track_get_key_value(i,int(candidate.track_get_key_count(i)/2))
				if absf(first.dot(mid)) < 0.99999: moving += 1
			if moving > best:
				best = moving
				chosen = candidate
	if chosen == null:
		root.free()
		push_warning("LEFT_JAB_NO_ANIMATED_TAKE")
		return
	var clip = Animation.new()
	clip.length = chosen.length
	clip.loop_mode = Animation.LOOP_NONE
	var tracks := 0
	for i in range(chosen.get_track_count()):
		if chosen.track_get_type(i) != Animation.TYPE_ROTATION_3D: continue
		var p = chosen.track_get_path(i)
		if p.get_subname_count() == 0: continue
		var n = normalized_idle_bone(String(p.get_subname(p.get_subname_count()-1)))
		# Leave legs, pelvis and translation strictly on the locomotion controller.
		if n == "hips" or n.contains("leg") or n.contains("foot") or n.contains("toe"): continue
		# The left arm is NOT animated by the punch clip. Its pose is
		# exclusively guided by the mouse-directed two-joint IK.
		if n.begins_with("left") and (n.contains("arm") or n.contains("hand") or n.contains("shoulder") or n.contains("finger") or n.contains("thumb")): continue
		if not valid_paths.has(n) or not source_bones.has(n) or not dest_bones.has(n): continue
		var from_index: int = source_bones[n]
		var to_index: int = dest_bones[n]
		var from_rest: Quaternion = source_rig.get_bone_rest(from_index).basis.get_rotation_quaternion()
		var to_rest: Quaternion = skeleton.get_bone_rest(to_index).basis.get_rotation_quaternion()
		var correction = (to_rest.inverse()*from_rest).normalized()
		var track = clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,valid_paths[n])
		for k in range(chosen.track_get_key_count(i)):
			var q: Quaternion = chosen.track_get_key_value(i,k)
			clip.rotation_track_insert_key(track,chosen.track_get_key_time(i,k),(correction*q*correction.inverse()).normalized())
		tracks += 1
	root.free()
	if tracks < 6:
		push_warning("LEFT_JAB_TOO_FEW_TRACKS " + str(tracks))
		return
	var lib := AnimationLibrary.new()
	lib.add_animation("LeftJab",clip)
	player.add_animation_library("combat",lib)
	var jab_node := AnimationNodeAnimation.new()
	jab_node.animation = "combat/LeftJab"
	graph.add_node("JabClip",jab_node)
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.09
	shot.fadeout_time = 0.16
	# OneShot normally blends its overlay against the whole skeleton's rest
	# pose. Filter it to ONLY the jab's authored upper-body tracks. Everything
	# else, including hips, legs and feet, stays on the Posture base input.
	shot.filter_enabled = true
	for track_index in range(clip.get_track_count()):
		shot.set_filter_path(clip.track_get_path(track_index), true)
	graph.add_node("JabOneShot",shot)
	# Rewire from the leaf toward the graph output. Godot 4 disallows
	# connecting a node as a source while that node is already the output root.
	graph.disconnect_node("output",0)
	graph.connect_node("JabOneShot",0,"Posture")
	graph.connect_node("JabOneShot",1,"JabClip")
	graph.connect_node("output",0,"JabOneShot")
	jab_ready = true
	if player_controlled: print("LEFT_JAB_READY duration=",clip.length," upper_body_tracks=",tracks)

func update_cursor_aim() -> void:
	if camera == null or actor == null: return
	if selected_spell_target != null:
		if not is_instance_valid(selected_spell_target):
			clear_spell_lock()
		else:
			var target_center: Vector3 = selected_spell_target.global_position+Vector3.UP*1.1
			var viewport_size: Vector2 = get_viewport().get_visible_rect().size
			if camera.is_position_behind(target_center):
				clear_spell_lock()
			else:
				var screen: Vector2 = camera.unproject_position(target_center)
				if screen.x < 0.0 or screen.y < 0.0 or screen.x > viewport_size.x or screen.y > viewport_size.y:
					clear_spell_lock()
	var cursor = get_viewport().get_mouse_position()
	var bounds = get_viewport().get_visible_rect().size
	cursor = Vector2(clampf(cursor.x,0.0,bounds.x),clampf(cursor.y,0.0,bounds.y))
	if cursor_reticle != null: cursor_reticle.position = cursor
	var origin: Vector3 = camera.project_ray_origin(cursor)
	var direction: Vector3 = camera.project_ray_normal(cursor)
	jab_aim_target = origin + direction * 20.0

func rotate_arm_joint_toward(bone: int, hand: int, goal: Vector3, weight: float) -> void:
	# Cyclic coordinate descent: turn this joint so the CURRENT hand position
	# points toward the target. All vectors are skeleton-local coordinates.
	skeleton.force_update_all_bone_transforms()
	var pivot: Vector3 = skeleton.get_bone_global_pose(bone).origin
	var tip: Vector3 = skeleton.get_bone_global_pose(hand).origin
	var present: Vector3 = tip - pivot
	var intended: Vector3 = goal - pivot
	if present.length_squared() < 0.00001 or intended.length_squared() < 0.00001: return
	var angle = present.angle_to(intended)
	if angle < 0.001: return
	var axis = present.cross(intended)
	if axis.length_squared() < 0.000001: return
	# Rotate only a bounded amount per solve to preserve the jab silhouette.
	var global_delta = Quaternion(axis.normalized(),minf(angle,0.65)*weight)
	var parent = skeleton.get_bone_parent(bone)
	var parent_orientation = Quaternion.IDENTITY if parent < 0 else skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var local_delta = parent_orientation.inverse()*global_delta*parent_orientation
	var old_rotation = skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone,(local_delta*old_rotation).normalized())

func adjust_jab_arm() -> void:
	# Preserve the supplied authored punch instead of fighting it with IK.
	if movement_clip_name in ["Punching (1).fbx","Punching(2).fbx"]: return
	# Fist-directed two-bone IK, layered over the original Mixamo jab.
	# The actor, pelvis, torso and both legs remain completely untouched.
	var aiming_arm: String = cast_arm_name if cast_elapsed >= 0.0 else controlled_arm
	var arm = jab_right_arm if aiming_arm == "right" else jab_left_arm
	var forearm = jab_right_forearm if aiming_arm == "right" else jab_left_forearm
	var hand = jab_right_hand if aiming_arm == "right" else jab_left_hand
	if arm < 0 or forearm < 0 or hand < 0: return
	if jab_aim_strength < 0.001 or (cast_elapsed < 0.0 and jab_aim_remaining <= 0.0): return
	skeleton.force_update_all_bone_transforms()
	var shoulder: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(arm).origin
	var elbow: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(forearm).origin
	var wrist: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hand).origin
	var reach = shoulder.distance_to(elbow) + elbow.distance_to(wrist)
	if reach < 0.1: return
	# The cursor defines the shared arm + spell target. The hand reaches
	# along the direction from shoulder to that cursor's world-space ray.
	# The same forward aim vector is used for projectile release.
	var aim_world: Vector3 = cast_aim_point if cast_elapsed >= 0.0 else jab_strike_target
	var shot: Vector3 = (aim_world - shoulder).normalized()
	var local_shot: Vector3 = actor.global_basis.inverse() * shot
	local_shot.z = minf(local_shot.z,-0.12)
	shot = (actor.global_basis * local_shot.normalized()).normalized()
	# A single eased thrust and recovery per click, with a stable target.
	var jab_extension: float = 0.38
	if cast_elapsed < 0.0:
		var elapsed: float = clampf(0.45-jab_aim_remaining,0.0,0.45)
		var strike: float = smoothstep(0.0,0.16,elapsed) * (1.0-smoothstep(0.21,0.43,elapsed))
		jab_extension = lerpf(0.35,0.88,strike)
	var goal_world_position: Vector3 = shoulder + shot * reach * jab_extension
	var goal_actor: Vector3 = actor.global_transform.affine_inverse() * goal_world_position
	# No drawback: start at the ordinary aiming pose and extend directly
	# toward the cursor over a long smooth stroke. Release at full extension.
	if cast_elapsed >= 0.0:
		var phase: float = clampf(cast_elapsed / CAST_DURATION,0.0,1.0)
		var extension: float = 0.0
		if phase < 0.69:
			extension = 0.60 * smoothstep(0.0,0.69,phase)
		elif phase < 0.79:
			extension = 0.60
		else:
			extension = 0.60 * (1.0-smoothstep(0.79,1.0,phase))
		goal_actor += actor.global_basis.inverse() * shot * (extension * reach)
	# Only disallow a hand target behind the character; crossing the chest
	# in front is intentional to preserve full lateral aiming.
	goal_actor.z = minf(goal_actor.z,-0.30)
	var goal_world: Vector3 = actor.global_transform * goal_actor
	var goal_local: Vector3 = skeleton.global_transform.affine_inverse() * goal_world
	# The selected arm follows an XY target on a depth-locked plane.
	var influence = jab_aim_strength
	if influence < 0.002: return
	# Solve the upper arm first. The elbow is kept outside the torso, not
	# merely the wrist: a wrist-only target can still fold through the ribs.
	var base_arm: Quaternion = skeleton.get_bone_pose_rotation(arm)
	var base_forearm: Quaternion = skeleton.get_bone_pose_rotation(forearm)
	var ik_iterations: int = 3
	if animation_test_mode == "war":
		var arena: Node = get_tree().current_scene
		if arena != null:
			var spectator: Node = arena.get("player")
			if spectator != null and is_instance_valid(spectator):
				if actor.global_position.distance_squared_to(spectator.actor.global_position) >= 324.0:
					ik_iterations = 1
	for iteration in range(ik_iterations):
		rotate_arm_joint_toward(arm,hand,goal_local,influence)
		rotate_arm_joint_toward(forearm,hand,goal_local,influence)
		skeleton.force_update_all_bone_transforms()
		var elbow_world: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(forearm).origin
		var hand_world: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hand).origin
		var elbow_actor: Vector3 = actor.global_transform.affine_inverse() * elbow_world
		var hand_actor: Vector3 = actor.global_transform.affine_inverse() * hand_world
		# No same-side restriction: the right hand can aim left and vice versa.
		# Reject only joints that swing substantially behind the character.
		# Small front-of-chest overlap is allowed to avoid a frozen aim arc.
		var elbow_clear: bool = elbow_actor.z <= 0.14
		var hand_clear: bool = hand_actor.z <= -0.10
		if elbow_clear and hand_clear:
			base_arm = skeleton.get_bone_pose_rotation(arm)
			base_forearm = skeleton.get_bone_pose_rotation(forearm)
			continue
		# Reject unsafe CCD rotation, keeping the last collision-free pose.
		skeleton.set_bone_pose_rotation(arm,base_arm)
		skeleton.set_bone_pose_rotation(forearm,base_forearm)
		skeleton.force_update_all_bone_transforms()
		break
	# Keep Godot bone transforms synchronized for foot solver and skinning.
	skeleton.force_update_all_bone_transforms()

func load_flight_clips() -> void:
	if shared_flight_clips_ready:
		flying_clip = shared_flying_clip
		backward_flying_clip = shared_backward_flying_clip
		movement_clips = shared_movement_clips.duplicate()
		return
	var import_start_usec: int = Time.get_ticks_usec()

	for filename in ["Flying (1).fbx","Jumping Up.fbx","Sitting Idle.fbx","Punching (1).fbx","Punching(2).fbx","Reaction.fbx","Reaction (1).fbx","Medium Hit To Head.fbx","Medium Hit To Head (1).fbx","Light Hit To Head.fbx","Light Hit To Head (1).fbx","Big Kidney Hit.fbx","Big Kidney Hit (1).fbx","Dying.fbx","Dying (1).fbx","Dying (2).fbx","Dying (3).fbx","Stunned.fbx","Injured Walk (1).fbx","Injured Walk.fbx"]:
		var resource_path: String = "res://assets/custom_idle/" + filename
		if not ResourceLoader.exists(resource_path):
			if player_controlled: debug_player("ASSET_MISSING",filename+" path="+resource_path)
			continue
		var packed = load(resource_path)
		if not packed is PackedScene: continue
		var root = packed.instantiate()
		var rigs = root.find_children("*","Skeleton3D",true,false)
		var animators = root.find_children("*","AnimationPlayer",true,false)
		if rigs.is_empty() or animators.is_empty():
			root.free()
			continue
		var source_rig: Skeleton3D = rigs[0]
		var selected: Animation = null
		for animation_player in animators:
			for animation_name in animation_player.get_animation_list():
				if animation_name == "RESET": continue
				var candidate: Animation = animation_player.get_animation(animation_name)
				if selected == null or candidate.get_track_count() > selected.get_track_count():
					selected = candidate
		if selected != null:
			var curves: Array = []
			for t in range(selected.get_track_count()):
				if selected.track_get_type(t) != Animation.TYPE_ROTATION_3D: continue
				var track_path: NodePath = selected.track_get_path(t)
				if track_path.get_subname_count() == 0: continue
				var bone_label: String = normalized_idle_bone(String(track_path.get_subname(track_path.get_subname_count()-1)))


				if bone_label == "hips": continue
				var src_index: int = -1
				var dst_index: int = -1
				for bi in range(source_rig.get_bone_count()):
					if normalized_idle_bone(String(source_rig.get_bone_name(bi))) == bone_label: src_index = bi
				for bi in range(skeleton.get_bone_count()):
					if normalized_idle_bone(String(skeleton.get_bone_name(bi))) == bone_label: dst_index = bi
				if src_index < 0 or dst_index < 0: continue
				var source_rest: Quaternion = source_rig.get_bone_rest(src_index).basis.get_rotation_quaternion()
				var target_rest: Quaternion = skeleton.get_bone_rest(dst_index).basis.get_rotation_quaternion()
				var correction: Quaternion = (target_rest.inverse()*source_rest).normalized()
				var keys: Array = []
				for k in range(selected.track_get_key_count(t)):
					keys.append({"time":selected.track_get_key_time(t,k),"rot":(correction*selected.track_get_key_value(t,k)*correction.inverse()).normalized()})
				if not keys.is_empty(): curves.append({"bone":dst_index,"keys":keys})
			if not curves.is_empty():
				if filename == "Flying (1).fbx":
					flying_clip = {"file":filename,"length":maxf(selected.length,0.001),"curves":curves}
				elif filename == "Sitting Idle.fbx":
					backward_flying_clip = {"file":filename,"length":maxf(selected.length,0.001),"curves":curves}
				else:
					movement_clips[filename] = {"file":filename,"length":maxf(selected.length,0.001),"curves":curves}
				if player_controlled: debug_player("ANIMATION_LOADED",filename+" tracks="+str(curves.size())+" seconds="+str(selected.length))
		root.free()
	shared_flying_clip = flying_clip
	shared_backward_flying_clip = backward_flying_clip
	shared_movement_clips = movement_clips.duplicate()
	shared_flight_clips_ready = true
	print("[ANIMATION_CACHE_BUILD] duration_ms=%.2f imported_clips=%d" % [float(Time.get_ticks_usec()-import_start_usec)/1000.0,movement_clips.size()+int(not flying_clip.is_empty())+int(not backward_flying_clip.is_empty())])
	if flying_clip.is_empty():
		push_warning("FLIGHT_ANIMATION_MISSING: res://assets/custom_idle/Flying (1).fbx not imported or no matching bones. Flight hover will use fallback pose.")
	else:
		if player_controlled: print("FLIGHT_ANIMATION_LOADED ",name," tracks=",flying_clip["curves"].size())

func sample_flight_curve(keys: Array, time: float) -> Quaternion:
	if keys.size() == 1 or time <= float(keys[0]["time"]): return keys[0]["rot"]
	for n in range(1,keys.size()):
		if time <= float(keys[n]["time"]):
			var before: Dictionary = keys[n-1]
			var after: Dictionary = keys[n]
			var fraction: float = clampf((time-float(before["time"]))/maxf(float(after["time"])-float(before["time"]),0.0001),0.0,1.0)
			var q1: Quaternion = before["rot"]
			var q2: Quaternion = after["rot"]
			return q1.slerp(q2,fraction)
	return keys[keys.size()-1]["rot"]

func update_flight_orientation(dt: float) -> void:
	# Head-first along camera aiming direction; physical collider remains upright.
	var target_pitch: float = 0.0
	if player_controlled and not flight_enabled:
		# The rig faces back-to-front (PI around Y); the prior negative X pitch
		# made the strafe lean backwards. Positive X leans the chest FORWARD.
		var strafe_pose: float = maxf(strafe_left_blend,strafe_right_blend)
		target_pitch = deg_to_rad(STRAFE_FORWARD_LEAN_DEGREES)*strafe_pose
	if flight_enabled:
		target_pitch = deg_to_rad(20.0)
		# Hover leans forward by 20 degrees; steering keeps head-first alignment.
		var steering: bool = manual_input.length() > 0.08 or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_CTRL) if player_controlled else actor.velocity.length() > 0.7
		if steering:
			target_pitch = clampf(PI*0.5-elevation,0.08,PI-0.08)
		# Backward flight uses the sitting pose and reclines toward the tail,
		# rather than pitching head-first as if travelling forward.
		if player_controlled and manual_input.y < -0.1:
			target_pitch = deg_to_rad(-65.0)
	flight_visual_pitch = move_toward(flight_visual_pitch,target_pitch,dt*(3.5 if flight_enabled else 8.0))
	visual.rotation.x = flight_visual_pitch
	# Rig pivot is at the feet. Raise the visible mesh as it pitches so
	# the head and chest do not cut through the ground at low altitude.
	visual.position.y = 0.95 * absf(sin(flight_visual_pitch)) if flight_enabled else 0.0

func debug_player(event_type: String, details: String) -> void:
	if not player_controlled: return
	print("[PLAYER_DEBUG] t=",snappedf(clock,0.01)," ",event_type," | ",details)

func start_movement_clip(clip_name: String) -> void:
	if not movement_clips.has(clip_name): 
		if player_controlled: debug_player("ASSET_MISSING",clip_name)
		return
	movement_clip_name = clip_name
	movement_clip_time = 0.0
	if player_controlled: debug_player("MOVEMENT_CLIP",clip_name)

func is_upper_body_bone(bone: int) -> bool:
	var part: String = normalized_idle_bone(String(skeleton.get_bone_name(bone)))
	return part.begins_with("spine") or part.begins_with("neck") or part.begins_with("head") or part.begins_with("leftshoulder") or part.begins_with("rightshoulder") or part.begins_with("leftarm") or part.begins_with("rightarm") or part.begins_with("leftforearm") or part.begins_with("rightforearm") or part.begins_with("lefthand") or part.begins_with("righthand") or part.begins_with("leftthumb") or part.begins_with("rightthumb") or part.begins_with("leftindex") or part.begins_with("rightindex") or part.begins_with("leftmiddle") or part.begins_with("rightmiddle") or part.begins_with("leftring") or part.begins_with("rightring") or part.begins_with("leftpinky") or part.begins_with("rightpinky")

func apply_movement_clip(dt: float) -> void:
	if movement_clip_name == "" or not movement_clips.has(movement_clip_name): return
	var clip: Dictionary = movement_clips[movement_clip_name]
	var length: float = float(clip["length"])
	if combat_dead:
		movement_clip_time = minf(movement_clip_time+dt,maxf(0.0,length-0.002))
		for entry in clip["curves"]:
			var pose: Quaternion = sample_flight_curve(entry["keys"],movement_clip_time)
			skeleton.set_bone_pose_rotation(entry["bone"],pose)
		skeleton.force_update_all_bone_transforms()
		return
	movement_clip_time += dt
	var end_blend: float = clampf((length-movement_clip_time)/0.20,0.0,1.0)
	var start_blend: float = clampf(movement_clip_time/0.12,0.0,1.0)
	var weight: float = minf(start_blend,end_blend)
	if movement_clip_time >= length:
		movement_clip_name = ""
		return
	for entry in clip["curves"]:
		var bone: int = entry["bone"]
		if movement_clip_name in ["Punching (1).fbx","Punching(2).fbx"] and not is_upper_body_bone(bone): continue
		var base_pose: Quaternion = skeleton.get_bone_pose_rotation(bone)
		var target_pose: Quaternion = sample_flight_curve(entry["keys"],movement_clip_time)
		skeleton.set_bone_pose_rotation(bone,base_pose.slerp(target_pose,weight))
	skeleton.force_update_all_bone_transforms()

func apply_injured_walk(dt: float) -> void:
	if flight_enabled or combat_dead: return
	var injury: Node = get_node_or_null("DamageSystem")
	if injury == null: return
	var right_broken: bool = float(injury.hp["right_leg"]) <= 0.0
	var left_broken: bool = float(injury.hp["left_leg"]) <= 0.0
	if not right_broken and not left_broken:
		injury_walk_time = 0.0
		return
	# One gait drives both legs; mirror the corresponding bones for the opposite injury.
	var filename: String = "Injured Walk.fbx"
	var mirror_gait: bool = left_broken and not right_broken
	if not movement_clips.has(filename): return
	if absf(signed_speed) < 0.1: return
	var clip: Dictionary = movement_clips[filename]
	var length: float = float(clip["length"])
	injury_walk_time = fmod(injury_walk_time+dt*maxf(0.25,absf(signed_speed)/SPEEDS[0]),length)
	for entry in clip["curves"]:
		var bone: int = entry["bone"]
		if is_upper_body_bone(bone): continue
		var pose: Quaternion = sample_flight_curve(entry["keys"],injury_walk_time)
		if mirror_gait:
			var label: String = normalized_idle_bone(String(skeleton.get_bone_name(bone)))
			var flipped: String = ""
			if label.begins_with("left"): flipped = "right"+label.substr(4)
			elif label.begins_with("right"): flipped = "left"+label.substr(5)
			if flipped != "":
				for index in range(skeleton.get_bone_count()):
					if normalized_idle_bone(String(skeleton.get_bone_name(index))) == flipped:
						bone = index
						break
			pose = Quaternion(pose.x,-pose.y,-pose.z,pose.w).normalized()
		skeleton.set_bone_pose_rotation(bone,pose)
	skeleton.force_update_all_bone_transforms()

func apply_flight_pose(dt: float) -> void:
	if not flight_enabled: return
	var moving: bool = (manual_input.length() > 0.08 or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_CTRL)) if player_controlled else actor.velocity.length() > 0.7
	flight_idle_weight = move_toward(flight_idle_weight,0.0 if moving else 1.0,dt*4.0)
	flight_animation_time += dt*0.65
	flight_idle_time += dt
	var source: Dictionary = backward_flying_clip if player_controlled and manual_input.y < -0.1 and not backward_flying_clip.is_empty() else flying_clip
	if source.is_empty(): return
	var moment: float = fmod(flight_animation_time,float(source["length"]))
	for entry in source["curves"]:
		var bone: int = entry["bone"]
		if cast_elapsed >= 0.0:
			var bone_name: String = normalized_idle_bone(String(skeleton.get_bone_name(bone)))
			if bone_name.begins_with(cast_arm_name) and (bone_name.contains("arm") or bone_name.contains("hand") or bone_name.contains("shoulder")): continue
		var pose: Quaternion = sample_flight_curve(entry["keys"],moment)

		skeleton.set_bone_pose_rotation(bone,pose)
	skeleton.force_update_all_bone_transforms()

func throw_left_jab() -> void:
	if jab_cooldown > 0.0 or crouch.active(): return
	var arm_health: Node = get_node_or_null("DamageSystem")
	if arm_health != null and float(arm_health.hp["right_arm" if controlled_arm == "right" else "left_arm"]) <= 0.0: return
	jab_cooldown = 0.55
	jab_aim_remaining = 0.45
	punch_clock = 0.0
	punch_pending = true
	punch_hand = controlled_arm
	jab_strike_target = get_cursor_world_target()
	# User testing established these imported clips have opposite hands.
	var clip: String = "Punching(2).fbx" if punch_hand == "left" else "Punching (1).fbx"
	start_movement_clip(clip)
	if player_controlled: print("PUNCH ",punch_hand," ",clip)

func update_punch_contact(dt: float) -> void:
	if not punch_pending: return
	punch_clock += dt
	# Impact only at the end of extension, not during the windup.
	if punch_clock < 0.36: return
	punch_pending = false
	var hand_index: int = jab_left_hand if punch_hand == "left" else jab_right_hand
	if hand_index < 0: return
	skeleton.force_update_all_bone_transforms()
	var fist: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index).origin
	for candidate in get_tree().get_nodes_in_group("combat_fighters"):
		if candidate == self: continue
		if team_id!="" and String(candidate.get("team_id"))==team_id: continue
		var damage: Node = candidate.get_node_or_null("DamageSystem")
		if damage == null or damage.dead: continue
		var nearest: String = ""
		var nearest_distance: float = 0.65
		for region in damage.REGIONS:
			var point: Vector3 = damage.bone_position(region)
			var distance_to_hit: float = point.distance_to(fist)
			if distance_to_hit < nearest_distance:
				nearest_distance = distance_to_hit
				nearest = region
		if nearest != "":
			damage.receive_hit(damage.bone_position(nearest),18.0,name)
			break

func get_cursor_world_target() -> Vector3:
	var cursor: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(cursor)
	var ray_direction: Vector3 = camera.project_ray_normal(cursor)
	# Fixed aiming distance produces a stable direction regardless of
	# arbitrary floor intersections, including aiming above the horizon.
	var aim_ray := PhysicsRayQueryParameters3D.create(ray_origin,ray_origin + ray_direction * 150.0)
	aim_ray.exclude = [actor.get_rid()]
	var aim_hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(aim_ray)
	if not aim_hit.is_empty():
		return aim_hit["position"]
	return ray_origin + ray_direction * 150.0

func ai_target_position() -> Vector3:
	var opponent: Node3D = war_target if animation_test_mode == "war" or auto_war_combat else get_tree().current_scene.get_node_or_null("PlayerMan") as Node3D
	if opponent != null:
		var opponent_body: Node3D = opponent.get("actor") as Node3D
		if opponent_body != null:
			var aiming_point: Vector3 = opponent_body.global_position+Vector3.UP*1.2
			if team_battle_ai and opponent_body is CharacterBody3D:
				var lead_time: float = clampf(actor.global_position.distance_to(aiming_point)/34.0,0.0,0.65)
				aiming_point += (opponent_body as CharacterBody3D).velocity*lead_time*0.75
			return aiming_point
	return actor.global_position - actor.global_basis.z*15.0

func choose_agent_destination() -> void:
	# Each AI owns a private wandering target and decision clock; no shared circle.
	var radius: float = agent_rng.randf_range(7.0,32.0)
	var angle: float = agent_rng.randf_range(-PI,PI)
	agent_destination = Vector3(cos(angle)*radius,0.0,sin(angle)*radius)
	agent_decision_left = agent_rng.randf_range(3.5,9.0)
	agent_preferred_speed = (2.3 if ai_mode == "walk" else (11.0 if ai_mode == "sprint" else (8.5 if ai_mode == "fly" else 4.5))) * agent_rng.randf_range(0.82,1.17)
	# Solo showcase covers walk, jog, run and sprint using existing gait blends.
	if name == "DemoNPC" and ai_mode == "sprint":
		agent_preferred_speed = agent_rng.randf_range(1.5,12.0)
		print("[SOLO_GROUND_SPEED] target_mps=",snappedf(agent_preferred_speed,0.1))

func update_agent_navigation(dt: float) -> void:
	agent_decision_left -= dt
	var flat_delta: Vector3 = agent_destination-actor.global_position
	flat_delta.y = 0.0
	if flat_delta.length() < 2.6 or agent_decision_left <= 0.0:
		choose_agent_destination()
		flat_delta = agent_destination-actor.global_position
		flat_delta.y = 0.0
	var avoid: Vector3 = Vector3.ZERO
	# At most 9 local bodies. Avoid neighbours rather than bunching behind them.
	for other in get_tree().get_nodes_in_group("walking_agents"):
		if other == self or not other is Node3D: continue
		var other_body: CharacterBody3D = other.get("actor") as CharacterBody3D
		if other_body == null: continue
		var away: Vector3 = actor.global_position-other_body.global_position
		away.y = 0.0
		var distance_sq: float = away.length_squared()
		if distance_sq > 0.001 and distance_sq < 12.25:
			avoid += away.normalized()*(1.0-sqrt(distance_sq)/3.5)*3.0
	var course: Vector3 = (flat_delta.normalized()+avoid).normalized()
	if course.length_squared() > 0.01:
		manual_heading = atan2(-course.x,-course.z)

func update_ai_abilities(dt: float) -> void:
	ai_action_clock += dt
	if ai_action_clock >= 4.0:
		ai_action_clock = 0.0
		controlled_arm = "left" if controlled_arm == "right" else "right"
		if randi() % 3 == 0: flight_enabled = not flight_enabled
		cast_spell("fire")

func cast_fireball() -> void:
	cast_spell("fire")

func heal_from_spell(amount: float) -> void:
	var damage: Node = get_node_or_null("DamageSystem")
	if damage != null and not damage.dead:
		for region in ["head","torso"]:
			damage.hp[region] = minf(100.0,float(damage.hp[region])+amount)
		damage.update_damage_colors()
	mana = minf(100.0,mana+amount*0.6)
	update_resource_hud()

func selected_target_aim_point() -> Vector3:
	if selected_spell_target != null and is_instance_valid(selected_spell_target) and camera != null:
		var target_position: Vector3 = selected_spell_target.global_position + Vector3.UP*1.1
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		if not camera.is_position_behind(target_position):
			var screen: Vector2 = camera.unproject_position(target_position)
			if screen.x >= 0.0 and screen.y >= 0.0 and screen.x <= viewport_size.x and screen.y <= viewport_size.y:
				return target_position
	return get_cursor_world_target()

func clear_spell_lock() -> void:
	selected_spell_target = null
	if is_instance_valid(lock_marker):
		lock_marker.queue_free()
	lock_marker = null
	if player_controlled: debug_player("TARGET_UNLOCKED","cursor aim")

func select_hovered_target() -> void:
	if camera == null: return
	var pointer: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(pointer)
	var direction: Vector3 = camera.project_ray_normal(pointer)
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin,origin+direction*500.0)
	ray.exclude = [actor.get_rid()]
	var result: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray)
	var hovered: CharacterBody3D = null
	if not result.is_empty():
		var hit: Object = result.get("collider")
		if hit is CharacterBody3D and hit != actor:
			hovered = hit as CharacterBody3D
	# F toggles the current lock off, or switches to the hovered target.
	if hovered == null or hovered == selected_spell_target:
		clear_spell_lock()
		return
	clear_spell_lock()
	selected_spell_target = hovered
	lock_marker = Label3D.new()
	lock_marker.name = "SpellLockMarker"
	lock_marker.text = "◆ LOCKED ◆"
	lock_marker.font_size = 54
	lock_marker.pixel_size = 0.006
	lock_marker.modulate = Color("ffdd55")
	lock_marker.outline_size = 12
	lock_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lock_marker.no_depth_test = true
	lock_marker.position = Vector3.UP*2.75
	selected_spell_target.add_child(lock_marker)
	if player_controlled: debug_player("TARGET_LOCKED",selected_spell_target.name)

func acquire_homing_target() -> CharacterBody3D:
	# Explicit lock wins, but the missile never requires the user to lock.
	if is_instance_valid(selected_spell_target):
		var locked_owner: Node = selected_spell_target.get_parent()
		var locked_damage: Node = locked_owner.get_node_or_null("DamageSystem") if locked_owner != null else null
		if locked_damage != null and not locked_damage.dead and selected_spell_target != actor and (team_id=="" or String(locked_owner.get("team_id"))!=team_id):
			return selected_spell_target
	if not player_controlled:
		if is_instance_valid(war_target) and not war_target.combat_dead:
			return war_target.actor as CharacterBody3D
		return null
	if camera == null: return null
	var pointer: Vector2 = get_viewport().get_mouse_position()
	var sight: Vector3 = camera.project_ray_normal(pointer)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var max_cursor_offset: float = minf(viewport_size.x,viewport_size.y)*0.55
	var best: CharacterBody3D = null
	var best_score: float = INF
	for opponent in get_tree().get_nodes_in_group("combat_fighters"):
		if opponent == self or not is_instance_valid(opponent) or opponent.combat_dead: continue
		if team_id!="" and String(opponent.get("team_id"))==team_id: continue
		var victim_body: CharacterBody3D = opponent.get("actor") as CharacterBody3D
		if victim_body == null: continue
		var victim_position: Vector3 = victim_body.global_position+Vector3.UP*1.0
		var to_victim: Vector3 = victim_position-camera.global_position
		var range_m: float = to_victim.length()
		if range_m<0.5 or range_m>110.0 or sight.dot(to_victim/range_m)<0.35: continue
		if camera.is_position_behind(victim_position): continue
		var pixels: float = camera.unproject_position(victim_position).distance_to(pointer)
		if pixels>max_cursor_offset: continue
		var score: float = pixels + range_m*1.5
		if score<best_score:
			best_score = score
			best = victim_body
	return best

func spell_is_ready(slot: int) -> bool:
	return slot>=0 and slot<SPELL_IDS.size() and (ignore_spell_cooldowns or spell_remaining[slot]<=0.0) and (infinite_mana or mana>=SPELL_COSTS[slot])

func spend_spell(slot: int) -> void:
	if not infinite_mana: mana = maxf(0.0,mana-SPELL_COSTS[slot])
	if not ignore_spell_cooldowns: spell_remaining[slot] = SPELL_COOLDOWNS[slot]
	update_resource_hud()

func toggle_flight_spell() -> void:
	# Grounding prevents flight recast for the full debuff duration.
	if spell_grounded_remaining>0.0: return
	# Left-hand pinky: flight toggles off freely, even mid-cooldown.
	if flight_enabled or flight_windup_remaining>0.0:
		flight_enabled = false
		flight_windup_remaining = 0.0
		flight_launch_remaining = 0.0
		update_resource_hud()
		debug_player("FLIGHT_SPELL","off")
		return
	var slot: int = SPELL_IDS.find("flight")
	if not spell_is_ready(slot) or crouch.active(): return
	var damage: Node = get_node_or_null("DamageSystem")
	if damage != null and float(damage.hp["left_arm"])<=0.0: return
	spend_spell(slot)
	if actor.is_on_floor():
		flight_windup_remaining = FLIGHT_WINDUP_SECONDS
		flight_acceleration_time = 0.0
		vertical_jump_speed = 0.0
		flight_animation_time = 0.0
		flight_pose_weight = 0.0
		start_movement_clip("Jumping Up.fbx")
		debug_player("FLIGHT_SPELL","windup")
	else:
		flight_enabled = true
		flight_launch_remaining = FLIGHT_LAUNCH_DURATION
		flight_clearance_time = 1.0
		debug_player("FLIGHT_SPELL","air_launch")

func fusion_name(elements: Array[String]) -> String:
	if elements.is_empty(): return ""
	if elements.size()==1: return SPELL_NAMES[SPELL_IDS.find(elements[0])]
	if elements.size()==2:
		var a: int = mini(SPELL_IDS.find(elements[0]),SPELL_IDS.find(elements[1]))
		var b: int = maxi(SPELL_IDS.find(elements[0]),SPELL_IDS.find(elements[1]))
		return String(FUSION_NAMES.get(SPELL_IDS[a]+"+"+SPELL_IDS[b],SPELL_NAMES[a]+" + "+SPELL_NAMES[b]))
	return "Convergence (%d)" % elements.size()

func spell_combo_is_ready(elements: Array[String]) -> bool:
	if elements.is_empty() or cast_elapsed>=0.0 or crouch.active() or combat_dead: return false
	var total: float = 0.0
	var seen: Dictionary = {}
	for element in elements:
		var slot: int = SPELL_IDS.find(element)
		if slot<0 or seen.has(slot) or not FUSION_PROJECTILES.has(element): return false
		if not spell_is_ready(slot): return false
		seen[slot] = true
		total += SPELL_COSTS[slot]
	if not infinite_mana and mana<total: return false
	if seen.has(SPELL_IDS.find("ricochet")) and get_tree().get_nodes_in_group("persistent_ricochets").size()>=MAX_ACTIVE_RICOCHETS: return false
	return true

func spell_pair_is_ready(first_slot: int, second_slot: int) -> bool:
	if first_slot<0 or second_slot<0 or first_slot>=SPELL_IDS.size() or second_slot>=SPELL_IDS.size(): return false
	var pair: Array[String] = [SPELL_IDS[first_slot],SPELL_IDS[second_slot]]
	return spell_combo_is_ready(pair)

func begin_projectile_cast(elements: Array[String]) -> bool:
	if not spell_combo_is_ready(elements): return false
	if not ResourceLoader.exists("res://assets/external_vfx/fire.tscn"): return false
	var ordered: Array[String] = elements.duplicate()
	ordered.sort_custom(func(a: String,b: String) -> bool: return SPELL_IDS.find(a)<SPELL_IDS.find(b))
	var first_slot: int = SPELL_IDS.find(ordered[0])
	var first_arm: String = "left" if first_slot>=5 else "right"
	var arm_health: Node = get_node_or_null("DamageSystem")
	if arm_health!=null and float(arm_health.hp["right_arm" if first_arm=="right" else "left_arm"])<=0.0: return false
	var hand_id: int = jab_right_hand if first_arm=="right" else jab_left_hand
	if hand_id<0: return false
	var total_mana: float = 0.0
	for element in ordered:
		var slot: int = SPELL_IDS.find(element)
		total_mana += SPELL_COSTS[slot]
		if not ignore_spell_cooldowns: spell_remaining[slot] = SPELL_COOLDOWNS[slot]
	if not infinite_mana: mana = maxf(0.0,mana-total_mana)
	cast_element = ordered[0]
	cast_components = ordered
	cast_arm_name = first_arm
	cast_aim_point = ai_target_position() if ai_abilities else selected_target_aim_point()
	skeleton.force_update_all_bone_transforms()
	cast_last_hand = skeleton.global_transform*skeleton.get_bone_global_pose(hand_id).origin
	cast_hand_velocity = Vector3.ZERO
	cast_elapsed = 0.0
	cast_released = false
	update_resource_hud()
	if ordered.size()>1 and player_controlled: print("SPELL_FUSION ",fusion_name(ordered)," components=",ordered," mana=",total_mana)
	return true

func cast_spell_pair(first: String, second: String) -> bool:
	var pair: Array[String] = [first,second]
	return begin_projectile_cast(pair)

func cast_spell(element: String) -> void:
	var slot: int = SPELL_IDS.find(element)
	if slot<0: return
	if player_controlled:
		if (slot<5 and controlled_arm!="right") or (slot>=5 and controlled_arm!="left"): return
		if element=="flight":
			toggle_flight_spell()
			return
	if element=="bloom":
		if cast_elapsed>=0.0 or crouch.active() or combat_dead or not spell_is_ready(slot): return
		var arm_health: Node = get_node_or_null("DamageSystem")
		if arm_health!=null and float(arm_health.hp["left_arm"])<=0.0: return
		spend_spell(slot)
		cast_bloom_pulse()
		return
	var standalone: Array[String] = [element]
	begin_projectile_cast(standalone)

func flush_pending_spell(force: bool = false) -> void:
	if pending_spell_slots.is_empty(): return
	if not force and Time.get_ticks_msec()-pending_spell_since_ms<FUSION_INPUT_WINDOW_MS: return
	var slots: Array[int] = pending_spell_slots.duplicate()
	pending_spell_slots.clear()
	pending_spell_arm = ""
	var combo: Array[String] = []
	for slot in slots: combo.append(SPELL_IDS[slot])
	# Never silently change a requested combination into a different spell.
	if combo.is_empty(): return
	var required_mana: float = 0.0
	for slot in slots: required_mana += SPELL_COSTS[slot]
	if not infinite_mana and mana<required_mana:
		fusion_feedback = "FUSION FAILED: %d mana needed (%d available)" % [ceili(required_mana),ceili(mana)]
		fusion_feedback_remaining = 2.0
		update_resource_hud()
		if player_controlled: print(fusion_feedback," requested=",combo)
		return
	if not begin_projectile_cast(combo):
		fusion_feedback = "FUSION UNAVAILABLE: spell cooldown, casting, or ricochet limit"
		fusion_feedback_remaining = 2.0
		update_resource_hud()
		if player_controlled: print(fusion_feedback," requested=",combo)

func receive_spell_key(slot: int) -> void:
	if slot<0 or slot>=SPELL_IDS.size(): return
	if not SPELL_IDS[slot] in equipped_spells: return
	if not FUSION_PROJECTILES.has(SPELL_IDS[slot]):
		flush_pending_spell(true)
		if slot==SPELL_IDS.find("bloom") and controlled_arm!="left":
			var old_arm: String = controlled_arm
			controlled_arm = "left"
			cast_spell(SPELL_IDS[slot])
			controlled_arm = old_arm
		else:
			cast_spell(SPELL_IDS[slot])
		return
	var now_ms: int = Time.get_ticks_msec()
	if not pending_spell_slots.is_empty() and now_ms-pending_spell_since_ms>FUSION_INPUT_WINDOW_MS:
		flush_pending_spell(true)
	if pending_spell_slots.is_empty():
		pending_spell_since_ms = now_ms
		pending_spell_arm = controlled_arm
	if not pending_spell_slots.has(slot):
		pending_spell_slots.append(slot)
		pending_spell_slots.sort()

func update_cast_motion(dt: float) -> void:
	if cast_elapsed < 0.0: return
	var hand_id: int = jab_right_hand if cast_arm_name == "right" else jab_left_hand
	if hand_id < 0:
		cast_elapsed = -1.0
		return
	skeleton.force_update_all_bone_transforms()
	var hand_now: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hand_id).origin
	if dt > 0.00001:
		var instantaneous: Vector3 = (hand_now - cast_last_hand) / dt
		cast_hand_velocity = cast_hand_velocity.lerp(instantaneous,0.65)
	cast_last_hand = hand_now
	cast_elapsed += dt
	if not cast_released and cast_elapsed >= CAST_RELEASE:
		cast_released = true
		if player_controlled and not auto_war_combat: cast_aim_point = selected_target_aim_point()
		release_fireball(hand_now)
	if cast_elapsed >= CAST_DURATION:
		cast_elapsed = -1.0
		cast_arm_name = ""

func release_fireball(hand_world: Vector3) -> void:
	var arm_id: int = jab_right_arm if cast_arm_name == "right" else jab_left_arm
	if arm_id < 0: return
	# Aim at the SAME world target captured at cast start. This direction
	# is measured from the palm so the projectile actually hits the cursor.
	var components: Array[String] = cast_components.duplicate()
	if components.is_empty(): components.append(cast_element)
	var has_homing: bool = components.has("homing")
	var has_ricochet: bool = components.has("ricochet")
	var homing_pick: CharacterBody3D = acquire_homing_target() if has_homing else null
	var raw_direction: Vector3 = (cast_aim_point-hand_world).normalized()
	if is_instance_valid(homing_pick):
		# Start toward the target immediately. A shot initially aimed at the
		# ground should not strike the floor before guidance has time to turn.
		var initial_intercept: Vector3 = homing_pick.global_position+Vector3.UP*1.05+homing_pick.velocity*0.20
		if initial_intercept.distance_squared_to(hand_world)>0.01:
			raw_direction = (initial_intercept-hand_world).normalized()
	# Preserve the original precise palm/cursor aim for other spells.
	var travel: Vector3 = raw_direction
	# Quicker projectiles make moving-target spells feel immediate. The
	# homing missile still expires after four seconds and cannot turn through
	# structures; ordinary spells preserve cursor-precise palm release.
	var launch_speed: float = maxf(29.0,cast_hand_velocity.dot(travel))
	var projectile := Node3D.new()
	projectile.name = (fusion_name(components) if components.size()>1 else cast_element.capitalize())+"Projectile"
	projectile.add_to_group("battle_fireballs")
	if has_ricochet: projectile.add_to_group("persistent_ricochets")
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = hand_world + travel * 0.20
	# Use external particles for both spell types; never hand-draw VFX.
	var arena: Node = get_tree().current_scene
	var effect: GPUParticles3D = arena.fireball_scene.instantiate() if arena != null and arena.get("fireball_scene") != null else load("res://assets/external_vfx/fire.tscn").instantiate()
	projectile.add_child(effect)
	var spell_index: int = SPELL_IDS.find(cast_element)
	var spell_color: Color = SPELL_COLORS[spell_index] if spell_index >= 0 else Color("ff9b4f")
	if components.size()>1:
		spell_color = Color.BLACK
		for component in components: spell_color += SPELL_COLORS[SPELL_IDS.find(component)]/float(components.size())
	if (spell_index > 0 or components.size()>1) and effect.process_material is ParticleProcessMaterial:
		# The imported fire particle asset has a red/orange color ramp;
		# multiplying it by cyan/green would make the new spells appear dark.
		# Replace only the ramp; keep the externally sourced motion and texture.
		var colored_particles: ParticleProcessMaterial = effect.process_material.duplicate(true) as ParticleProcessMaterial
		var tint_gradient := Gradient.new()
		tint_gradient.set_color(0,spell_color)
		tint_gradient.set_color(1,Color(spell_color.r,spell_color.g,spell_color.b,0.0))
		var tint_ramp := GradientTexture1D.new()
		tint_ramp.gradient = tint_gradient
		colored_particles.color = Color.WHITE
		colored_particles.color_ramp = tint_ramp
		effect.process_material = colored_particles
	if player_controlled and not has_ricochet:
		var glow := OmniLight3D.new()
		glow.light_color = spell_color
		glow.light_energy = 1.25
		glow.omni_range = 3.0
		projectile.add_child(glow)
	# Three times the size at the hand and during travel.
	if arena != null and arena.has_method("configure_fireball_particles"):
		arena.configure_fireball_particles(effect,float(arena.get("battle_fireball_size")))
	else:
		effect.scale = Vector3.ONE * 3.0
	effect.amount = mini(effect.amount,10 if has_ricochet else 6)
	if has_ricochet: effect.lifetime = 0.40
	if has_homing and not has_ricochet:
		# Particle positions stay relative to the travelling projectile so
		# the entire imported effect grows thinner as the parent shrinks.
		# World-space particles would otherwise leave a full-sized trail behind.
		effect.local_coords = true
		effect.lifetime = 0.35
	effect.fixed_fps = 30
	effect.emitting = true
	effect.restart()
	# Fuse the actual imported spell VFX motions, not just their colour.
	# A single physics projectile owns small, independent particle layers;
	# every constituent keeps its own motion, with NO extra physics bodies.
	if components.size()>1:
		# Scale visual cost with the number of component motions.
		# Keep the full combination physically authoritative even in large battles.
		var per_layer_particles: int = 4 if components.size()<=2 else (3 if components.size()<=4 else 2)
		effect.amount = mini(effect.amount,per_layer_particles)
		for component in components:
			var layer: GPUParticles3D = effect.duplicate() as GPUParticles3D
			layer.name = component.capitalize()+"FusionMotion"
			projectile.add_child(layer)
			var layer_mat: ParticleProcessMaterial = layer.process_material.duplicate(true) as ParticleProcessMaterial
			if layer_mat!=null:
				var color: Color = SPELL_COLORS[SPELL_IDS.find(component)]
				var ramp := Gradient.new()
				ramp.set_color(0,color)
				ramp.set_color(1,Color(color.r,color.g,color.b,0.0))
				var texture := GradientTexture1D.new()
				texture.gradient = ramp
				layer_mat.color_ramp = texture
				layer_mat.color = Color.WHITE
				match component:
					"fire":
						layer_mat.direction = Vector3(0.0,1.0,0.0)
						layer_mat.spread = 55.0
					"frost":
						layer_mat.direction = Vector3(0.0,0.0,-1.0)
						layer_mat.spread = 15.0
						layer_mat.gravity = Vector3.ZERO
					"homing":
						layer_mat.direction = Vector3(0.0,0.0,1.0)
						layer_mat.spread = 12.0
					"gravity":
						layer_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
						layer_mat.emission_sphere_radius = 0.7
						layer_mat.direction = Vector3(0.0,-1.0,0.0)
						layer_mat.spread = 165.0
					"ricochet":
						layer_mat.spread = 180.0
					"grounding":
						layer_mat.direction = Vector3(0.0,-1.0,0.0)
						layer_mat.spread = 30.0
					"tempest":
						layer_mat.direction = Vector3(1.0,0.0,0.0)
						layer_mat.spread = 130.0
					"venom":
						layer_mat.direction = Vector3(0.0,1.0,0.0)
						layer_mat.spread = 85.0
				layer.process_material = layer_mat
			layer.amount = per_layer_particles
			layer.fixed_fps = 30
			layer.emitting = true
			layer.restart()
	var script_path: String = "res://assets/external_vfx/" + "fireball_motion.gd"
	var mover = load(script_path).new()
	mover.name = "Motion"
	mover.travel_direction = travel
	mover.travel_speed = launch_speed * fireball_speed_scale
	if animation_test_mode == "war":
		mover.battle_base_speed = mover.travel_speed
		mover.travel_speed *= float(get_tree().current_scene.get("battle_fireball_speed"))
	mover.owner_rid = actor.get_rid()
	mover.attacker_name = name
	mover.caster_team = team_id
	mover.spell_type = "ricochet" if has_ricochet else ("homing" if has_homing else cast_element)
	mover.spell_components = components.duplicate()
	mover.spell_color = spell_color
	if has_homing:
		mover.homing_target = homing_pick
		mover.travel_speed = maxf(mover.travel_speed,37.0)
		if animation_test_mode=="war": mover.battle_base_speed = maxf(mover.battle_base_speed,37.0)
	if has_ricochet:
		mover.travel_speed = maxf(mover.travel_speed,29.0)
		if animation_test_mode=="war": mover.battle_base_speed = maxf(mover.battle_base_speed,29.0)
	mover.blast_width = float(arena.get("battle_fireball_size")) if arena != null else 1.0
	projectile.add_child(mover)
	if player_controlled: print("SPELL_RELEASE ",fusion_name(components) if components.size()==2 else cast_element," arm=",cast_arm_name," speed_mps=",snappedf(launch_speed,0.1))

func choose_random_idle():
	# Historical name retained for existing callers. Idle (3).fbx preferred for everyone; never swap.
	if idle_variants.is_empty() or crouch.standing_idle_node == null: return
	var chosen: String = idle_variants[0]
	if String(crouch.standing_idle_node.animation) == chosen: return
	crouch.standing_idle_node.animation = chosen
	if player_controlled: print("IDLE_FIXED ",name," ",chosen)

func _unhandled_input(event):
	if autonomous_only: return
	if player_controlled:
		if event is InputEventKey and event.keycode == KEY_SPACE:
			if not event.pressed and squat_key_down and not flight_enabled and actor.is_on_floor():
				vertical_jump_speed = lerpf(SQUAT_HOP_IMPULSE,SQUAT_MAX_HOP_IMPULSE,clampf(squat_hold_seconds/SQUAT_MAX_CHARGE_SECONDS,0.0,1.0))
				start_movement_clip("Jumping Up.fbx")
				debug_player("SQUAT_HOP","hold="+str(snappedf(squat_hold_seconds,0.01))+" impulse="+str(vertical_jump_speed))
			squat_key_down = event.pressed
			if event.pressed and not event.echo: squat_hold_seconds = 0.0
			if not event.echo: debug_player("SQUAT_KEY","pressed="+str(event.pressed))
		if event is InputEventKey and event.keycode == KEY_ALT and not event.echo:
			var event_ms: int = Time.get_ticks_msec()
			if event.pressed:
				alt_press_begin_ms = event_ms
				alt_dash_held = (event_ms-alt_last_short_release_ms <= ALT_DOUBLE_TAP_WINDOW_MS) and not sprint_exhausted
				alt_last_short_release_ms = -100000
				if alt_dash_held:
					debug_player("ALT_DASH","second_alt_held=true mode="+("FLIGHT" if flight_enabled else "GROUND"))
			else:
				if not alt_dash_held and event_ms-alt_press_begin_ms <= ALT_FIRST_TAP_MAX_MS:
					alt_last_short_release_ms = event_ms
				else:
					alt_last_short_release_ms = -100000
				alt_dash_held = false
		if event is InputEventKey and event.pressed and not event.echo:
			debug_player("KEY_DOWN",OS.get_keycode_string(event.keycode)+" grounded="+str(actor.is_on_floor())+" flying="+str(flight_enabled)+" crouch="+str(crouch.active()))
			if event.keycode==KEY_SPACE and not flight_enabled and (not actor.is_on_floor() or crouch.active()):
				debug_player("JUMP_REJECTED","grounded="+str(actor.is_on_floor())+" crouch="+str(crouch.active()))
			if event.keycode==KEY_C:
				crouch.toggle()
				debug_player("CROUCH","toggle")
			if event.keycode==KEY_B:
				if Input.is_physical_key_pressed(KEY_W): cast_blink(1.0)
				elif Input.is_physical_key_pressed(KEY_S): cast_blink(-1.0)

			if event.keycode == KEY_I and ring_inventory_panel != null:
				ring_inventory_panel.visible = not ring_inventory_panel.visible
				if ring_inventory_panel.visible: refresh_ring_inventory()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_G:
				demo_immortal = not demo_immortal
				var arena: Node = get_tree().current_scene
				if arena.get("player_label") != null:
					arena.player_label.text = "BLACK / %s [G]" % ("IMMORTAL" if demo_immortal else "MORTAL")
				print("[PLAYER_IMMORTAL] enabled=",demo_immortal)
			if event.keycode == KEY_V:
				toggle_flight_spell()
			if event.keycode==KEY_ESCAPE:
				if ring_inventory_panel != null: ring_inventory_panel.visible = false
				if options_panel != null: options_panel.visible = false
			if event.keycode>=KEY_1 and event.keycode<=KEY_5:
				var spell_index: int = (5 if controlled_arm=="left" else 0)+(event.keycode-KEY_1)
				receive_spell_key(spell_index)
			# Fixed fusion keys: 6=Earthbind, 7=Lifeweave, 8=Galeforce,
			# 9=Blight. Right-hand 1-5 + 6/8/9 can chord all 8.
			if event.keycode>=KEY_6 and event.keycode<=KEY_9:
				receive_spell_key(5+event.keycode-KEY_6)
			if event.keycode==KEY_F: select_hovered_target()
			if event.keycode==KEY_SHIFT:
				flush_pending_spell(true)
				if cast_elapsed < 0.0:
					controlled_arm = "left" if controlled_arm == "right" else "right"
					update_resource_hud()
				print("CONTROLLED_ARM ",controlled_arm)
			if event.keycode==KEY_F11: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		# Releasing a key does NOT immediately fire: give the remaining
		# fingers the full chord window even if the first key was tapped.
		if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			orbit = wrapf(orbit-event.relative.x*0.004*camera_sensitivity,-PI,PI)
			elevation = clampf(elevation-event.relative.y*0.004*camera_sensitivity,-1.20,1.20)
		if event is InputEventMouseButton and event.pressed:
			debug_player("MOUSE_DOWN","button="+str(event.button_index))
			if event.button_index == MOUSE_BUTTON_LEFT: throw_left_jab()
			if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance = max(3.0,distance-0.4)
			if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance = min(22.0,distance+0.4)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_P: paused = not paused
		if event.keycode==KEY_T: slow = not slow
		if event.keycode==KEY_W: walk_target = 1.0-walk_target
		if event.keycode==KEY_B:
			if crouch.active(): crouch.toggle_direction()
			else: begin_direction_change(not (turn_target if turning else backward))
		if event.keycode==KEY_C: crouch.toggle()
		if event.keycode==KEY_SHIFT: crouch.sprint()
		if event.keycode==KEY_V: crouch.start_showcase()
		if event.keycode==KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		orbit -= event.relative.x*0.006
		elevation = clamp(elevation-event.relative.y*0.004,-0.8,0.15)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance = max(2.5,distance-0.4)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance = min(18.0,distance+0.4)
	update_camera()









