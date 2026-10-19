extends Node3D
# Engine-built subdivided PlaneMesh + matching HeightMapShape3D.
# Visual surface uses third-party authored grass/dirt textures.
# Height samples are landscape data, not hand-modelled mesh triangles.
var side: float = 30.0
var grassy: bool = false
var tile_index: int = 0
const RESOLUTION: int = 65

func _ready() -> void:
 var heights := PackedFloat32Array()
 heights.resize(RESOLUTION * RESOLUTION)
 var height_image := Image.create(RESOLUTION,RESOLUTION,false,Image.FORMAT_RF)
 var minimum: float = INF
 var maximum: float = -INF
 for z in range(RESOLUTION):
  for x in range(RESOLUTION):
   var nx: float = float(x)/float(RESOLUTION-1)*2.0-1.0
   var nz: float = float(z)/float(RESOLUTION-1)*2.0-1.0
   var y: float = terrain_height(nx,nz)
   heights[z*RESOLUTION+x] = y
   height_image.set_pixel(x,z,Color(y,0,0))
   minimum = minf(minimum,y)
   maximum = maxf(maximum,y)
 var map_texture := ImageTexture.create_from_image(height_image)
 var terrain_shader := Shader.new()
 terrain_shader.code = "shader_type spatial; render_mode cull_back, diffuse_burley; uniform sampler2D height_map : filter_nearest, repeat_disable; uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable; uniform vec4 tint_color : source_color = vec4(1.0); void vertex(){VERTEX.y = texture(height_map,UV).r;} void fragment(){ALBEDO = texture(ground_texture,UV*8.0).rgb*tint_color.rgb; ROUGHNESS=0.95;}"
 var surface_material := ShaderMaterial.new()
 surface_material.shader = terrain_shader
 surface_material.set_shader_parameter("height_map",map_texture)
 var grass_source: String = "res://assets/external_grass/Grass001_Color.jpg"
 var dirt_source: String = "res://assets/forest_ground_04_diff.jpg"
 surface_material.set_shader_parameter("ground_texture",load(grass_source) if grassy and ResourceLoader.exists(grass_source) else load(dirt_source))
 surface_material.set_shader_parameter("tint_color",Color("80bd75") if grassy and not ResourceLoader.exists(grass_source) else Color.WHITE)
 var plane := PlaneMesh.new()
 plane.size = Vector2(side,side)
 plane.subdivide_width = RESOLUTION-2
 plane.subdivide_depth = RESOLUTION-2
 var visible_ground := MeshInstance3D.new()
 visible_ground.name = "HeightmappedGround"
 visible_ground.mesh = plane
 visible_ground.material_override = surface_material
 visible_ground.custom_aabb = AABB(Vector3(-side*0.5,minimum-0.2,-side*0.5),Vector3(side,maximum-minimum+0.4,side))
 add_child(visible_ground)
 var body := StaticBody3D.new()
 body.name = "HeightmappedTerrainCollision"
 add_child(body)
 var collider := CollisionShape3D.new()
 var shape := HeightMapShape3D.new()
 shape.map_width = RESOLUTION
 shape.map_depth = RESOLUTION
 shape.map_data = heights
 collider.shape = shape
 collider.scale = Vector3(side/float(RESOLUTION-1),1.0,side/float(RESOLUTION-1))
 body.add_child(collider)
 print("[BIOME_HEIGHTMAP] tile=",tile_index," grass=",grassy," minimum_y=",snappedf(minimum,0.01)," maximum_y=",snappedf(maximum,0.01)," side=",side)

func terrain_height(nx: float, nz: float) -> float:
 var edge: float = pow(maxf(0.0,1.0-maxf(absf(nx),absf(nz))),0.65)
 var shift: float = 0.07*float(tile_index%3)
 var dx_h: float = (nx+0.35-shift)/0.38
 var dz_h: float = (nz+0.22)/0.37
 var dx_v: float = (nx-0.36+shift)/0.38
 var dz_v: float = (nz-0.30)/0.38
 var hill: float = exp(-2.0*(dx_h*dx_h+dz_h*dz_h))
 var valley: float = exp(-2.0*(dx_v*dx_v+dz_v*dz_v))
 var ripple: float = sin(nx*8.0+float(tile_index))*cos(nz*7.0)*0.08
 return (hill*1.35-valley*1.65+ripple)*side*0.18*edge
