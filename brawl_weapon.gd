extends Node
# Integrates MIT-inspired combat timing ideas from Snaiel's Combat Prototype.
# Models are original Kenney CC0 GLBs installed by RUN.bat, never generated.
const SWORD: String = "res://assets/kenney_weapons/mini-arena/weapon-sword.glb"
const AXE: String = "res://assets/kenney_weapons/survival/tool-axe.glb"
const DAGGER: String = "res://assets/kenney_weapons/weapon/knife_sharp.glb"
var pilot: Node3D
var arena: Node3D
var visual_driver: Node3D
var kind: String = "sword"
var weapon: Node3D
var hand: BoneAttachment3D
var swing_clock: float = 0.0
var swing_length: float = 0.0
var swing_cooldown: float = 0.0
var combo_number: int = 0
var struck: Dictionary = {}
var blocking: bool = false
var dodge_remaining: float = 0.0
var dodge_cooldown: float = 0.0
var decision_clock: float = 0.0
var acrobat_clock: float = 0.0
var flight_clock: float = 0.0
var flight_burst_time: float = 0.0
var total_hits: int = 0
var successful_dodges: int = 0
var last_tip: Vector3
var projectile_dodges: int = 0
var fitted: bool = false

func _ready() -> void:
	if pilot == null: return
	var main_file: String = SWORD if kind == "sword" else (AXE if kind == "axe" else DAGGER)
	if not ResourceLoader.exists(main_file):
		push_warning("[BRAWL_WEAPON_ASSET_MISSING] "+main_file+"; RUN.bat installs Kenney CC0 pack.")
		if ResourceLoader.exists(SWORD): main_file = SWORD
		else: return
	var packed: PackedScene = load(main_file) as PackedScene
	if packed == null: return
	var rig: Skeleton3D = pilot.skeleton
	if visual_driver != null and visual_driver.has_method("grip_skeleton"):
		var authored_rig: Skeleton3D = visual_driver.grip_skeleton()
		if authored_rig != null: rig = authored_rig
	var right_hand: String = ""
	for i in range(rig.get_bone_count()):
		var name: String = String(rig.get_bone_name(i))
		var lower: String = name.to_lower()
		if lower.ends_with("righthand") or lower.ends_with("hand_r") or lower.ends_with("hand.r") or lower == "handright":
			right_hand = name
			break
	if right_hand.is_empty():
		# No fake floating hand geometry. Keep the sourced weapon as a visible,
		# usable harness attachment if the imported rig names are incompatible.
		push_warning("[BRAWL_GRIP_BONE_UNKNOWN] "+pilot.name+" skeleton="+rig.name+"; fitting weapon to actor instead")
		weapon = packed.instantiate() as Node3D
		if weapon == null: return
		pilot.actor.add_child(weapon)
		weapon.position = Vector3(0.43,0.70,0.18)
	else:
		hand = BoneAttachment3D.new()
		hand.name = "WeaponRightHand"
		hand.bone_name = right_hand
		rig.add_child(hand)
		weapon = packed.instantiate() as Node3D
		if weapon == null: return
		hand.add_child(weapon)
		weapon.position = Vector3(0,0.22,0)
	# Kenney sword's GLB is 0.501 m long; 2.1x => ~1.05 m.
	weapon.scale = Vector3.ONE * (2.1 if kind == "sword" else (2.3 if kind == "axe" else 1.75))
	weapon.rotation_degrees = Vector3(180,0,0)
	last_tip = weapon.to_global(Vector3(0,-0.34,0))
	fitted = true
	decision_clock = randf_range(0.2,0.7)
	acrobat_clock = randf_range(1.4,3.5)
	flight_clock = randf_range(1.5,4.0)
	print("[BRAWL_GEAR] fighter=",pilot.name," type=",kind," source=",main_file," bone=",right_hand)

func _get_enemy() -> Node3D:
	if pilot == null or pilot.combat_dead: return null
	if not is_instance_valid(pilot.war_target) or pilot.war_target.combat_dead: return null
	if pilot.war_target.team_id == pilot.team_id: return null
	return pilot.war_target

func attack() -> void:
	if not fitted or pilot.combat_dead or swing_clock > 0.0 or swing_cooldown > 0.0 or dodge_remaining > 0.0: return
	combo_number += 1
	swing_length = 0.58 if kind == "dagger" else (0.78 if kind == "axe" else 0.68)
	swing_clock = swing_length
	swing_cooldown = swing_length + (0.06 if kind == "dagger" else 0.12)
	struck.clear()
	blocking = false
	var options: Array = []
	if kind == "sword":
		match combo_number % 4:
			0: options = ["Sword_Regular_Combo","Sword_Regular_A","Sword_Attack","PunchCombo"]
			1: options = ["Sword_Regular_A","Sword_Attack","PunchCombo"]
			2: options = ["Sword_Regular_B","Sword_Regular_A","PunchCombo"]
			_: options = ["Sword_Regular_C","Sword_Regular_Combo","PunchCombo"]
	elif kind == "axe":
		options = ["Axe_Attack","Sword_Regular_B","Sword_Regular_Combo","PunchCombo"]
	else:
		options = ["Sword_Regular_A","Sword_Regular_C","PunchCombo"]
	if visual_driver != null and visual_driver.has_method("action"):
		visual_driver.action(options,swing_length,"WEAPON "+kind.to_upper())
	else:
		pilot.start_movement_clip("Punching (1).fbx")
	print("[BRAWL_SWING] fighter=",pilot.name," combo=",combo_number," weapon=",kind)

func dodge() -> void:
	if pilot.combat_dead or dodge_cooldown > 0.0 or dodge_remaining > 0.0: return
	dodge_cooldown = 1.2
	dodge_remaining = 0.42
	successful_dodges += 1
	pilot.brawl_dodge_iframes = 0.24
	var heading: Vector3 = Vector3(-pilot.actor.global_transform.basis.z.x,0,-pilot.actor.global_transform.basis.z.z).normalized()
	var right: Vector3 = pilot.actor.global_transform.basis.x.normalized()
	var step: Vector3 = (right * (1.0 if randi()%2==0 else -1.0) - heading*0.25).normalized()
	pilot.brawl_impact_impulse += step*9.0
	if pilot.actor.is_on_floor(): pilot.actor.velocity.y = maxf(pilot.actor.velocity.y,5.0)
	if visual_driver != null and visual_driver.has_method("action"):
		var options: Array = ["DodgeRoll","Roll","Roll_RM","SideFlip","Side_Flip","Backflip","NinjaJump_Start"]
		if String(visual_driver.source_file).ends_with("aether-02.glb"):
			options = ["Backflip","DodgeRoll","Roll"]
		visual_driver.action(options,0.54,"EVASIVE ACROBATICS")
	print("[BRAWL_DODGE] fighter=",pilot.name," invulnerability_s=0.24")

func _physics_process(dt: float) -> void:
	if not fitted or pilot == null or not is_instance_valid(pilot.actor): return
	if pilot.combat_dead:
		set_physics_process(false)
		return
	var time: float = minf(dt,0.066)
	swing_cooldown = maxf(0.0,swing_cooldown-time)
	dodge_cooldown = maxf(0.0,dodge_cooldown-time)
	dodge_remaining = maxf(0.0,dodge_remaining-time)
	pilot.brawl_dodge_iframes = maxf(0.0,pilot.brawl_dodge_iframes-time)
	blocking = pilot.player_controlled and Input.is_key_pressed(KEY_B)
	var current_tip: Vector3 = weapon.to_global(Vector3(0,-0.34,0))
	if swing_clock > 0.0:
		var progress: float = 1.0-swing_clock/swing_length
		# Animation-relative active frames, not perpetual proximity damage.
		if progress >= 0.21 and progress <= 0.66:
			_sweep_weapon(last_tip,current_tip)
		swing_clock = maxf(0.0,swing_clock-time)
	last_tip = current_tip
	if pilot.player_controlled: return
	var enemy: Node3D = _get_enemy()
	if enemy == null: return
	var gap: float = pilot.actor.global_position.distance_to(enemy.actor.global_position)
	decision_clock -= time
	if decision_clock <= 0.0:
		decision_clock = randf_range(0.14,0.28)
		if gap < 3.2:
			if not enemy.combat_dead and enemy.has_node("BrawlGear") and enemy.get_node("BrawlGear").swing_clock > 0.10 and randf() < 0.25:
				dodge()
			elif swing_clock <= 0.0:
				attack()
		elif gap < 6.0 and randf() < 0.10 and swing_clock <= 0.0:
			dodge()
	acrobat_clock -= time
	if acrobat_clock <= 0.0:
		acrobat_clock = randf_range(2.0,4.4)
		if gap < 19.0 and swing_clock <= 0.0:
			if randf() < 0.40: dodge()
			elif pilot.actor.is_on_floor():
				pilot.actor.velocity.y = 8.0
				if visual_driver != null: visual_driver.action(["NinjaJump_Start","Jump_Start","Jump"],0.7,"VERTICAL JUMP")
	flight_clock -= time
	flight_burst_time = maxf(0.0,flight_burst_time-time)
	if flight_clock <= 0.0:
		flight_clock = randf_range(3.5,6.5)
		if gap > 5.5 or randf()<0.35:
			flight_burst_time = randf_range(1.1,2.2)
	pilot.brawl_flight_override = flight_burst_time > 0.0 and gap > 3.2 and pilot.spell_grounded_remaining <= 0.0
	if pilot.flight_enabled and gap < 14.0 and randf() < time*0.18 and visual_driver != null and swing_clock <= 0.0:
		visual_driver.action(["Backflip","NinjaJump_Start","DodgeRoll","Jump"],0.9,"AIRBORNE ACROBATICS")

func _sweep_weapon(old_tip: Vector3, tip: Vector3) -> void:
	# Swept sword segment checks current and prior tip, rejecting allies and
	# recording at most one damage event per victim per attack cycle.
	var base: Vector3 = weapon.global_position
	for victim in arena.mannequins:
		if not is_instance_valid(victim) or victim == pilot or victim.combat_dead or victim.team_id == pilot.team_id: continue
		_strike_candidate(victim,base,old_tip,tip)
	if is_instance_valid(arena.player) and arena.player != pilot and not arena.player.combat_dead and arena.player.team_id != pilot.team_id:
		_strike_candidate(arena.player,base,old_tip,tip)

func _strike_candidate(victim: Node3D,base: Vector3,old_tip: Vector3,tip: Vector3) -> void:
	var id: int = victim.get_instance_id()
	if struck.has(id): return
	var center: Vector3 = victim.actor.global_position + Vector3.UP * 1.15
	var closest_a: Vector3 = Geometry3D.get_closest_point_to_segment(center,base,tip)
	var closest_b: Vector3 = Geometry3D.get_closest_point_to_segment(center,old_tip,tip)
	var closest: Vector3 = closest_a if center.distance_squared_to(closest_a) < center.distance_squared_to(closest_b) else closest_b
	# Body collider radius plus sword width and frame-swept temporal margin.
	if center.distance_squared_to(closest) > 1.15: return
	struck[id] = true
	var defense: Node = victim.get_node_or_null("BrawlGear")
	if defense != null and defense.dodge_remaining > 0.10: return
	var guarded: bool = defense != null and defense.blocking
	var damage: float = (14.0 if kind == "dagger" else (27.0 if kind == "axe" else 20.0)) * (0.20 if guarded else 1.0)
	var damage_system: Node = victim.get_node_or_null("DamageSystem")
	if damage_system != null:
		damage_system.receive_hit(closest,damage,pilot.name)
	var push: Vector3 = (victim.actor.global_position-pilot.actor.global_position)
	push.y = 0.0
	if push.length_squared() > 0.001:
		victim.brawl_impact_impulse += push.normalized() * (2.5 if guarded else (9.0 if kind=="axe" else 6.0))
	if not guarded: victim.brawl_stagger_time = maxf(victim.brawl_stagger_time,0.20)
	total_hits += 1
	print("[BRAWL_WEAPON_HIT] attacker=",pilot.name," victim=",victim.name," dmg=",snappedf(damage,0.1)," blocking=",guarded," weapon=",kind)
