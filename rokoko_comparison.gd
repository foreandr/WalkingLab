extends Control
var keys = ["walk","run","sprint"]
var index = 0
var clock = 0.0
var rate = 1.0
var paused = false
var side = false
var rigs = []
var hud: Label
var foot_label: Label
var frame = 0
var capture = false
var clock_label = ""
var timings = [0.0,0.0,0.0]
func _ready():
	capture = "--rokoko-capture" in OS.get_cmdline_user_args()
	var row=HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation",2)
	add_child(row)
	for pane in range(2):
		var container=SubViewportContainer.new()
		container.stretch=true
		container.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(container)
		var viewport=SubViewport.new()
		viewport.size=Vector2i(640,720)
		viewport.own_world_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var world=Node3D.new();viewport.add_child(world)
		setup_world(world)
		rigs.append({"world":world,"root":null,"player":null,"skel":null,"camera":null,"driver":null,"target":null,"feet":null,"minimum":INF})
		var camera=Camera3D.new();camera.fov=43;world.add_child(camera);rigs[-1].camera=camera
	var panel=ColorRect.new();panel.color=Color(0.025,0.04,0.05,0.91);panel.size=Vector2(1280,126);add_child(panel)
	hud=Label.new();hud.position=Vector2(23,14);hud.add_theme_font_size_override("font_size",20);add_child(hud)
	var bottom=ColorRect.new();bottom.color=Color(0.025,0.04,0.05,0.91);bottom.position=Vector2(0,640);bottom.size=Vector2(1280,80);add_child(bottom)
	foot_label=Label.new();foot_label.position=Vector2(23,650);foot_label.add_theme_font_size_override("font_size",16);add_child(foot_label)
	load_clip(0)
func setup_world(world):
	var env_node=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("8d9ca5")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("ced3dc");env.ambient_light_energy=0.5
	env_node.environment=env;world.add_child(env_node)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-30,0);light.light_energy=0.8;light.shadow_enabled=true;world.add_child(light)
	var floor_mesh=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(100,100);floor_mesh.mesh=plane
	var material=StandardMaterial3D.new();material.albedo_color=Color("778181");material.roughness=1
	floor_mesh.material_override=material;world.add_child(floor_mesh)
	var grid=ImmediateMesh.new();var instance=MeshInstance3D.new();instance.mesh=grid
	var line_mat=StandardMaterial3D.new();line_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;line_mat.albedo_color=Color("a6b3b1");instance.material_override=line_mat;world.add_child(instance)
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-35,36):
		grid.surface_add_vertex(Vector3(i,0.002,-35));grid.surface_add_vertex(Vector3(i,0.002,35))
		grid.surface_add_vertex(Vector3(-35,0.002,i));grid.surface_add_vertex(Vector3(35,0.002,i))
	grid.surface_end()
func load_clip(next):
	index=next;clock=0
	for pane in range(2):
		var rig=rigs[pane]
		if rig.root:rig.root.queue_free()
		if rig.target and is_instance_valid(rig.target):rig.target.queue_free()
		rig.minimum=INF
		rig.root=load("res://assets/rokoko/"+keys[index]+("_original.glb" if pane==0 else "_mapped.glb")).instantiate()
		rig.world.add_child(rig.root)
		rig.player=rig.root.find_children("*","AnimationPlayer",true,false)[0]
		rig.skel=rig.root.find_children("*","Skeleton3D",true,false)[0]
		rig.player.callback_mode_process=2
		rig.player.play("Root",0,0)
		if pane==1:
			# Preserve the source skeleton as the animation driver. The engine retargets
			# evaluated global poses, including the source's extra spine joint.
			for mesh in rig.root.find_children("*","MeshInstance3D",true,false):mesh.visible=false
			rig.target=load("res://assets/defender_retarget.glb").instantiate()
			rig.world.add_child(rig.target)
			var target_skel=rig.target.find_children("*","Skeleton3D",true,false)[0]
			var modifier=RetargetModifier3D.new()
			modifier.profile=SkeletonProfileHumanoid.new();modifier.use_global_pose=true
			rig.skel.add_child(modifier)
			target_skel.reparent(modifier,false)
			for mesh in rig.target.find_children("*","MeshInstance3D",true,false):mesh.skeleton=mesh.get_path_to(target_skel)
			for mesh in target_skel.find_children("*","MeshInstance3D",true,false):mesh.skeleton=mesh.get_path_to(target_skel)
			rig.driver=target_skel
			rig.feet=preload("res://foot_ground.gd").new();rig.feet.setup(target_skel,target_skel)
			print("RETARGET_DRIVER ",keys[index]," source_scale=",rig.skel.global_basis.get_scale()," target_scale=",target_skel.global_basis.get_scale())
		else:
			rig.driver=rig.skel
			rig.feet=preload("res://foot_ground.gd").new();rig.feet.setup(rig.root,rig.skel)
func _process(dt):
	frame+=1
	if capture:
		var section=mini(5,frame/360)
		var wanted=section%3
		if wanted!=index:load_clip(wanted)
		side=section>=3
	if not paused:clock+=dt*rate
	for pane in range(2):
		var rig=rigs[pane]
		var duration=rig.player.get_animation("Root").length
		var time=fmod(clock,duration)
		rig.player.seek(time,true);rig.player.advance(0)
		var hip=rig.skel.to_global(rig.skel.get_bone_global_pose(rig.skel.find_bone("Hips")).origin)
		var focus=Vector3(hip.x,0.95,hip.z)
		rig.camera.position=focus+(Vector3(4.0,0.65,0.0) if side else Vector3(2.8,0.9,4.0))
		rig.camera.look_at(focus)
		if frame%15==0:
			rig.driver.force_update_all_bone_transforms()
			rig.minimum=min(rig.minimum,rig.feet.lowest(rig.feet.all_samples))
	hud.text="WALKING LAB - CURRENT  |  MILESTONE A / AUTHENTIC ROKOKO CAPTURE\nLEFT: original performer and rig       RIGHT: Godot retarget / Defender\n%s  |  %.2fs  |  %.2fx  |  %s  |  %s"%[keys[index].to_upper(),clock,rate,"SIDE" if side else "3/4","recording at 60 fps" if capture else str(Engine.get_frames_per_second())+" FPS"]
	foot_label.text="1 walk  2 treadmill run  3 running out of frame   |   Space pause   T slow   V view\nOriginal take at native timing. Cameras follow root travel. No IK or floor lift. Min mesh: %.3f / %.3fm"%[rigs[0].minimum,rigs[1].minimum]
	if capture:
		var shots=OS.get_environment("COMPARISON_SHOTS")
		if shots!="" and frame%90==45:get_viewport().get_texture().get_image().save_png(shots.path_join("rokoko-%04d.png"%frame))
		if frame>=2160:get_tree().quit()
func _unhandled_input(event):
	if capture:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode>=KEY_1 and event.keycode<=KEY_3:load_clip(event.keycode-KEY_1)
		if event.keycode==KEY_SPACE:paused=not paused
		if event.keycode==KEY_T:rate=0.25 if rate==1 else 1.0
		if event.keycode==KEY_V:side=not side

