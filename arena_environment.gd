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
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("3279c7")
	atmosphere.sky_horizon_color = Color("b6d9f0")
	atmosphere.ground_bottom_color = Color("455d52")
	atmosphere.ground_horizon_color = Color("c1d5cd")
	atmosphere.use_debanding = true
	sky.sky_material = atmosphere
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_color = Color("9aafc7")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = biome == "flat_dirt"
	e.fog_light_color = Color("bbd4df")
	e.fog_density = 0.0018 if biome == "flat_dirt" else 0.004
	env.environment = e
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color("ffdfb6")
	sun.light_energy = 1.15
	sun.shadow_enabled = false # Battle performance: avoid dynamic skeletal shadows
	sun.directional_shadow_max_distance = 22
	add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,145,0)
	fill.light_color = Color("9ab5d3")
	fill.light_energy = 0.16
	add_child(fill)
	if biome == "flat_dirt":
		# Two neighboring 10 x 10 m terrain surfaces: west grass, east dirt.
		# Reuse existing Godot PlaneMesh as the common collision-backed surface.
		var grassland_mat := StandardMaterial3D.new()
		grassland_mat.albedo_color = Color("8abc78")
		grassland_mat.roughness = 1.0
		grassland_mat.uv1_triplanar = true
		grassland_mat.uv1_world_triplanar = true
		grassland_mat.uv1_scale = Vector3.ONE * 0.3
		var grass_texture_path := "res://assets/external_grass/Grass001_Color.jpg"
		if ResourceLoader.exists(grass_texture_path):
			grassland_mat.albedo_texture = load(grass_texture_path)
		else:
			# Visible distinction if the sourced CC0 material cannot be downloaded.
			grassland_mat.albedo_texture = load("res://assets/forest_ground_04_diff.jpg")
			grassland_mat.albedo_color = Color("75ba62")
		var surface := PlaneMesh.new()
		surface.size = Vector2(world_half_extent,world_half_extent)
		mesh_node(surface,Vector3(-world_half_extent*0.5,-0.13,0),grassland_mat)
		mesh_node(surface,Vector3(world_half_extent*0.5,-0.13,0),texture("forest_ground_04",0.18))
		# Preserve the authored Grass001 grass texture; no handmade terrain meshes.
		# Hills and true cut-in valleys require terrain assets with matching collision.
		var grass = preload("res://dirt_grass.gd").new()
		grass.half_extent = world_half_extent * 0.5
		grass.position.x = -world_half_extent * 0.5
		add_child(grass)
		# Biome map remains available for the next terrain-development phase.
		print("[LEVEL_ENVIRONMENT] flat_dirt_open_sky=true roof=false side_m=",world_half_extent*2.0)
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


