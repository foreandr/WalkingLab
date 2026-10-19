extends Node3D
var biome: String = "arena"
var world_half_extent: float = 2000.0
var building_defs: Array = []
func _ready(): make_arena()

func texture(id: String, scale_value: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/"+id+"_diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/"+id+"_nor_gl.jpg")
	m.normal_scale = 0.65
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE*scale_value
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 0.9
	return m

func mesh_node(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.material_override = mat
	add_child(n)
	return n

func make_arena():
	var env = WorldEnvironment.new()
	var e = Environment.new()
	var sky = Sky.new()
	var pano = PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/sky.hdr")
	pano.energy_multiplier = 0.6
	sky.sky_material = pano
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9aafc7")
	e.ambient_light_energy = 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = biome == "grassland"
	e.fog_light_color = Color("9ba9b3")
	e.fog_density = 0.004 if biome == "grassland" else 0.004
	env.environment = e
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color("ffdfb6")
	sun.light_energy = 0.85
	sun.shadow_enabled = false # Battle performance: avoid dynamic skeletal shadows
	sun.directional_shadow_max_distance = 22
	add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,145,0)
	fill.light_color = Color("9ab5d3")
	fill.light_energy = 0.16
	add_child(fill)
	if biome == "grassland":
		# Level one uses existing sourced ground textures, without a stone ring or ruins.
		var grass_ground = PlaneMesh.new()
		grass_ground.size = Vector2(world_half_extent*2.0,world_half_extent*2.0)
		mesh_node(grass_ground,Vector3(0,-0.13,0),texture("forest_ground_04",0.18))
		make_demo_buildings()
		add_child(preload("res://central_tower.gd").new())
		print("[LEVEL_ENVIRONMENT] biome=grassland side_m=",world_half_extent*2.0," sky=true fog=true buildings=",building_defs.size()," border=false roof=false")
		return
	var ground = PlaneMesh.new()
	ground.size = Vector2(100,100) # Match the compact pursuit arena boundaries.
	mesh_node(ground,Vector3(0,-0.13,0),texture("forest_ground_04",0.35))
	var stone = texture("medieval_blocks_03",0.4)
	var platform = CylinderMesh.new()
	platform.top_radius = 47.0
	platform.bottom_radius = 47.4
	platform.height = 0.3
	platform.radial_segments = 64
	mesh_node(platform,Vector3(0,-0.16,0),stone)
	var border = TorusMesh.new()
	border.inner_radius = 46.0
	border.outer_radius = 47.0
	border.rings = 64
	border.ring_segments = 8
	mesh_node(border,Vector3.ZERO,stone)
	var pillar = load("res://assets/RuinPillar_01.glb") as PackedScene
	for i in range(12):
		var holder = Node3D.new()
		add_child(holder)
		var p = pillar.instantiate()
		holder.add_child(p)
		var bounds = AABB()
		var first = true
		for m in p.find_children("*","MeshInstance3D",true,false):
			if m.name.ends_with("100"): m.visible = false; continue
			var b = p.global_transform.affine_inverse()*m.global_transform*m.get_aabb()
			if first: bounds = b; first = false
			else: bounds = bounds.merge(b)
		var factor = (3.8 if i%3 else 2.5)/bounds.size.y
		p.scale = Vector3.ONE*factor
		p.position = Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*factor
		holder.position = Vector3(sin(i*TAU/12)*44,0,cos(i*TAU/12)*44)



func make_demo_buildings() -> void:
	for definition in building_defs:
		var root := StaticBody3D.new()
		root.name = String(definition.get("name","BUILDING"))
		root.position = definition.get("position",Vector3.ZERO)
		add_child(root)
		var extent: Vector3 = definition.get("size",Vector3(10,6,8))
		var walls := BoxMesh.new()
		walls.size = extent
		var wall_mesh := MeshInstance3D.new()
		wall_mesh.mesh = walls
		wall_mesh.position.y = extent.y*0.5
		var wall_material := StandardMaterial3D.new()
		wall_material.albedo_color = Color("ad9881")
		wall_mesh.material_override = wall_material
		root.add_child(wall_mesh)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = extent
		collider.shape = shape
		collider.position.y = extent.y*0.5
		root.add_child(collider)
		var roof_mesh := MeshInstance3D.new()
		var roof := PrismMesh.new()
		roof.size = Vector3(extent.x+1.5,3.0,extent.z+1.5)
		roof_mesh.mesh = roof
		roof_mesh.position.y = extent.y+1.0
		var roof_material := StandardMaterial3D.new()
		roof_material.albedo_color = Color("584b41")
		roof_mesh.material_override = roof_material
		root.add_child(roof_mesh)
		var label := Label3D.new()
		label.text = String(definition.get("name","BUILDING"))
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 64
		label.outline_size = 12
		label.position.y = extent.y+5.0
		root.add_child(label)
