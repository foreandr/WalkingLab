extends Node3D
# Ten static previews sourced exclusively from the current rig's verified gait clips.
# Each mannequin keeps an independent AnimationPlayer at a chosen sample frame.
const POSES = [
	["PreviousWalk",0.12],["PreviousWalk",0.40],
	["NewWalk",0.12],["NewWalk",0.40],
	["EasyRun",0.17],["EasyRun",0.54],
	["Run",0.18],["Run",0.53],
	["StandardRun",0.21],["FastRun",0.43]
]
func _ready():
	for index in range(POSES.size()):
		var model = preload("res://assets/user_mixamo.glb").instantiate()
		var x = (float(index) - 4.5) * 2.6
		model.position = Vector3(x, 0, 17.0)
		model.rotation.y = PI
		add_child(model)
		var players = model.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty():
			push_warning("Idle preview lacks AnimationPlayer " + str(index + 1))
			continue
		var animation_player: AnimationPlayer = players[0]
		var clip_name: String = POSES[index][0]
		if not animation_player.has_animation(clip_name):
			push_warning("Idle preview missing " + clip_name)
			continue
		var clip: Animation = animation_player.get_animation(clip_name)
		animation_player.play(clip_name)
		animation_player.seek(clip.length * float(POSES[index][1]), true)
		animation_player.pause()
		var white = StandardMaterial3D.new()
		white.albedo_color = Color.WHITE
		white.roughness = 0.8
		for part in model.find_children("*", "MeshInstance3D", true, false):
			part.material_override = white
		var number = Label3D.new()
		number.text = str(index + 1)
		number.font_size = 90
		number.pixel_size = 0.005
		number.modulate = Color(1, 0.88, 0.27)
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number.position = Vector3(0, 2.35, 0)
		model.add_child(number)
		var marker = Label3D.new()
		marker.text = clip_name + "  " + str(roundf(float(POSES[index][1]) * 100.0)) + "%"
		marker.font_size = 27
		marker.pixel_size = 0.005
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.position = Vector3(0, 2.05, 0)
		model.add_child(marker)
	print("IDLE_LINEUP_READY 10 numbered poses")
