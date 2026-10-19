extends Node3D
# Real terrain meshes with concave static collision; no decorative solid primitives.
var half_extent: float = 50.0
var seed_value: int = 1001
var grass_surface: bool = false
var randomizer := RandomNumberGenerator.new()

func _ready() -> void:
 randomizer.randomize()
 var hills: int = randomizer.randi_range(2,4)
 var mountains: int = randomizer.randi_range(1,2)
 var placements: Array[Vector2] = []
 for i in range(hills):
  _place_landform("DirtHill%d" % (i+1),false,placements)
 for i in range(mountains):
  _place_landform("DirtMountain%d" % (i+1),true,placements)
 print("[DIRT_LANDFORMS] hills=",hills," mountains=",mountains," real_collision=true")

func _place_landform(label: String, mountain: bool, positions: Array[Vector2]) -> void:
 var tier: int = randomizer.randi_range(7,10) if mountain else randomizer.randi_range(1,6)
 var radius: float = minf(half_extent*0.50,1.7+float(tier)*0.35)
 var height: float = minf(half_extent*0.40,0.35+pow(float(tier),1.35)*0.19)
 var center := Vector2.ZERO
 var best_distance: float = -1.0
 for attempt in range(40):
  var candidate := Vector2(randomizer.randf_range(-half_extent+radius,half_extent-radius),randomizer.randf_range(-half_extent+radius,half_extent-radius))
  var separation: float = candidate.length()
  for prev in positions:
   separation = minf(separation,candidate.distance_to(prev))
  if separation > best_distance:
   center = candidate
   best_distance = separation
  if separation > radius+1.0: break
 positions.append(center)
 var slices: int = 36
 var rings: int = 10
 var vertices := PackedVector3Array()
 var uv := PackedVector2Array()
 var normals := PackedVector3Array()
 var indices := PackedInt32Array()
 var phase: float = randomizer.randf_range(0.0,TAU)
 for ring in range(rings+1):
  var t: float = float(ring)/float(rings)
  for slice in range(slices+1):
   var a: float = float(slice)/float(slices)*TAU
   var shape_noise: float = 1.0+0.13*sin(a*5.0+phase)+0.09*sin(a*9.0-phase)
   var r: float = radius*t*shape_noise
   var profile: float = pow(maxf(0.0,1.0-t*t),1.4 if mountain else 1.8)
   var ridge: float = 1.0+(0.16*sin(a*7.0+phase+t*12.0)+0.12*cos(a*11.0-t*15.0))*(t if mountain else t*0.35)
   var y: float = maxf(0.0,height*profile*ridge)
   vertices.append(Vector3(cos(a)*r,y-0.08,sin(a)*r))
   uv.append(Vector2(cos(a)*r*0.15,sin(a)*r*0.15))
 for ring in range(rings):
  for slice in range(slices):
   var k: int = ring*(slices+1)+slice
   indices.append_array(PackedInt32Array([k,k+1,k+slices+1,k+1,k+slices+2,k+slices+1]))
 # Double sided collision generated from triangle faces.
 var faces := PackedVector3Array()
 for i in range(0,indices.size(),3):
  faces.append(vertices[indices[i]])
  faces.append(vertices[indices[i+1]])
  faces.append(vertices[indices[i+2]])
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(0,indices.size(),3):
  for j in range(3):
   var idx: int = indices[i+j]
   surface.set_uv(uv[idx])
   surface.add_vertex(vertices[idx])
 surface.generate_normals()
 var mesh: ArrayMesh = surface.commit()
 var body := StaticBody3D.new()
 body.name = label
 body.position = Vector3(center.x,0.0,center.y)
 add_child(body)
 var geometry := MeshInstance3D.new()
 geometry.mesh = mesh
 var dirt := StandardMaterial3D.new()
 dirt.albedo_texture = load("res://assets/forest_ground_04_diff.jpg")
 if grass_surface:
  var grass_texture_path: String = "res://assets/external_grass/Grass001_Color.jpg"
  if ResourceLoader.exists(grass_texture_path):
   dirt.albedo_texture = load(grass_texture_path)
  else:
   dirt.albedo_color = Color("5d9c52")
 dirt.uv1_scale = Vector3(0.22,0.22,0.22)
 dirt.uv1_triplanar = true
 dirt.uv1_world_triplanar = true
 dirt.cull_mode = BaseMaterial3D.CULL_DISABLED
 dirt.roughness = 1.0
 geometry.material_override = dirt
 body.add_child(geometry)
 var collision := CollisionShape3D.new()
 var concave := ConcavePolygonShape3D.new()
 concave.set_faces(faces)
 collision.shape = concave
 body.add_child(collision)
 print("[DIRT_LANDFORM] ",label," center=",body.position," radius=",snappedf(radius,0.1)," height=",snappedf(height,0.1))
