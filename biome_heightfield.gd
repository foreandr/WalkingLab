extends Node3D
# Engine-built subdivided PlaneMesh + matching HeightMapShape3D.
# Visual surface uses third-party authored grass/dirt textures.
# Height samples are landscape data, not hand-modelled mesh triangles.
var side: float = 30.0
var grassy: bool = false
var tile_index: int = 0
var circular_mode: bool = false
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
   var y: float = circular_height(nx,nz) if circular_mode else terrain_height(nx,nz)
   heights[z*RESOLUTION+x] = y
   height_image.set_pixel(x,z,Color(y,0,0))
   minimum = minf(minimum,y)
   maximum = maxf(maximum,y)
 var map_texture := ImageTexture.create_from_image(height_image)
 var terrain_shader := Shader.new()
 terrain_shader.code = "shader_type spatial; render_mode cull_back, diffuse_burley; uniform sampler2D height_map : filter_nearest, repeat_disable; uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable; uniform vec4 tint_color : source_color = vec4(1.0); void vertex(){VERTEX.y = texture(height_map,UV).r;} void fragment(){ALBEDO = texture(ground_texture,UV*8.0).rgb*tint_color.rgb; ROUGHNESS=0.95;}"
 if circular_mode:
  terrain_shader.code = "shader_type spatial; render_mode cull_back; uniform sampler2D height_map : filter_nearest, repeat_disable; uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable; uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable; uniform float biome_seed = 2.4; varying vec2 terrain_uv; void vertex(){terrain_uv=UV;VERTEX.y=texture(height_map,UV).r;} void fragment(){vec2 p=terrain_uv*2.0-1.0;float r=length(p);if(r>0.995) discard;float ang=atan(p.y,p.x);float warp=0.24*sin(ang*3.0+biome_seed)+0.13*sin(ang*7.0-biome_seed)+0.08*cos(r*13.0+ang*5.0);float sector=(ang+3.14159265)/(6.2831853)*8.0+warp;float grass_factor=0.5+0.5*cos(3.14159265*sector);grass_factor=smoothstep(0.24,0.76,grass_factor);vec3 grass=texture(grass_texture,terrain_uv*16.0).rgb;vec3 dirt=texture(dirt_texture,terrain_uv*16.0).rgb;ALBEDO=mix(dirt,grass,grass_factor);ROUGHNESS=0.96;}"
 var surface_material := ShaderMaterial.new()

 surface_material.shader = terrain_shader
 surface_material.set_shader_parameter("height_map",map_texture)
 if circular_mode:
  var grass_path: String = "res://assets/external_grass/Grass001_Color.jpg"
  surface_material.set_shader_parameter("grass_texture",load(grass_path) if ResourceLoader.exists(grass_path) else load("res://assets/forest_ground_04_diff.jpg"))
  surface_material.set_shader_parameter("dirt_texture",load("res://assets/forest_ground_04_diff.jpg"))
  surface_material.set_shader_parameter("biome_seed",float(tile_index)*0.7+2.4)
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

func circular_height(nx: float, nz: float) -> float:
 var r: float = Vector2(nx,nz).length()
 if r >= 1.0: return -30.0
 var angle: float = atan2(nz,nx)
 var fade: float = (1.0-smoothstep(0.83,1.0,r))
 var hill: float = 1.8*sin(nx*13.0+cos(nz*6.0)*1.7)*cos(nz*11.0)
 var valley: float = -2.4*exp(-((nx-0.34)*(nx-0.34)+(nz+0.3)*(nz+0.3))*35.0)
 var ridge: float = 1.2*cos(angle*8.0+sin(r*13.0))*sin(r*8.0)
 var centre_safe: float = smoothstep(0.08,0.24,r)
 return (hill+valley+ridge)*fade*centre_safe
