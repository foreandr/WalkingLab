extends Node3D
# Ten authored standing-idle loops on the native Y Bot skeleton.
# No walking or running clips are used.
const NAMES = ["Relaxed", "Wide Stance", "Guarded", "Arms Loose", "Confident", "Alert", "Resting", "Ready", "Heavy", "Calm"]
# shoulder drop, arm forward, forearm bend, torso twist, head tilt, breathing intensity
const PROFILES = [
	[0.90, 0.05, 0.06, 0.00, 0.00, 0.020],
	[1.12, 0.02, 0.12, 0.00, 0.00, 0.025],
	[0.75, 0.38, 0.55, 0.00, 0.00, 0.030],
	[1.30, -0.05, 0.05, 0.06, 0.00, 0.020],
	[1.00, -0.18, 0.26, 0.00, -0.08, 0.028],
	[0.90, 0.12, 0.26, 0.10, 0.06, 0.035],
	[1.20, 0.00, 0.42, -0.06, 0.00, 0.018],
	[0.80, 0.28, 0.65, 0.00, 0.04, 0.040],
	[1.32, -0.14, 0.36, -0.08, -0.05, 0.025],
	[1.08, 0.02, 0.08, 0.00, 0.05, 0.014]
]
func bone_id(rig: Skeleton3D, term: String) -> int:
	for i in range(rig.get_bone_count()):
		var name = String(rig.get_bone_name(i)).to_lower()
		if name.ends_with(term.to_lower()): return i
	return -1

func animate_bone(clip: Animation, rig: Skeleton3D, target: NodePath, term: String, base: Quaternion, sway: Vector3):
	var id = bone_id(rig,term)
	if id < 0: return
	var track = clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(track,NodePath(String(target) + ":" + rig.get_bone_name(id)))
	for frame in range(5):
		var t = float(frame)*0.5
		var weight = sin(t*PI)
		var q = base * Quaternion.from_euler(sway*weight)
		clip.rotation_track_insert_key(track,t,q.normalized())

func _ready():
	for index in range(10):
		var model = preload("res://assets/user_mixamo.glb").instantiate()
		var x = (float(index)-4.5)*3.0
		model.position = Vector3(x,0,17)
		model.rotation.y = PI
		add_child(model)
		var players = model.find_children("*","AnimationPlayer",true,false)
		var rigs = model.find_children("*","Skeleton3D",true,false)
		if players.is_empty() or rigs.is_empty(): continue
		var animator: AnimationPlayer = players[0]
		var rig: Skeleton3D = rigs[0]
		var root: Node = animator.get_node(animator.root_node)
		var path = root.get_path_to(rig)
		var p = PROFILES[index]
		var idle = Animation.new()
		idle.length = 2.0
		idle.loop_mode = Animation.LOOP_LINEAR
		# Mixamo shoulders are horizontal in bind pose. Lower the arms independently
		# and put a little weight in the elbows for ten different upright stances.
		animate_bone(idle,rig,path,"LeftArm",Quaternion(Vector3(0,0,1),float(p[0])),Vector3(0,0,0.014))
		animate_bone(idle,rig,path,"RightArm",Quaternion(Vector3(0,0,1),-float(p[0])),Vector3(0,0,-0.014))
		animate_bone(idle,rig,path,"LeftForeArm",Quaternion(Vector3(0,1,0),float(p[2])),Vector3(0,0.018,0))
		animate_bone(idle,rig,path,"RightForeArm",Quaternion(Vector3(0,1,0),-float(p[2])),Vector3(0,-0.018,0))
		animate_bone(idle,rig,path,"Spine",Quaternion(Vector3(0,1,0),float(p[3])),Vector3(float(p[5]),0,0))
		animate_bone(idle,rig,path,"Spine2",Quaternion(Vector3(1,0,0),float(p[1])),Vector3(float(p[5]),0,0))
		animate_bone(idle,rig,path,"Neck",Quaternion(Vector3(0,0,1),float(p[4])),Vector3(0,0,0.01))
		var library = AnimationLibrary.new()
		library.add_animation("IdlePose",idle)
		animator.add_animation_library("preview",library)
		animator.play("preview/IdlePose")
		for part in model.find_children("*","MeshInstance3D",true,false):
			var white = StandardMaterial3D.new()
			white.albedo_color = Color.WHITE
			white.roughness = 0.82
			part.material_override = white
		var number = Label3D.new()
		number.text = str(index+1)
		number.font_size = 85
		number.pixel_size = 0.005
		number.modulate = Color(1,0.88,0.25)
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number.position = Vector3(0,2.45,0)
		model.add_child(number)
		var label = Label3D.new()
		label.text = NAMES[index]
		label.font_size = 28
		label.pixel_size = 0.005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0,2.12,0)
		model.add_child(label)
	print("STANDING_IDLE_LINEUP_READY 10 independent idle loops")
