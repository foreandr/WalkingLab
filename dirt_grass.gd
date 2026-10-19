extends Node3D
# GPU-instanced crossed-blade grass. Coverage is a percentage of terrain cells,
# not a continuous green decal. No physics bodies or per-blade script nodes.
var half_extent: float = 250.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
 rng.randomize()
 var coverage: float = rng.randf_range(0.40,0.90)
 var cell_size: float = 4.0
 var cells: int = int(floor(half_extent*2.0/cell_size))
 var placements: Array[Transform3D] = []
 var blade_mesh := ArrayMesh.new()
 var vertices := PackedVector3Array()
 var normals := PackedVector3Array()
 var uv := PackedVector2Array()
 var indices := PackedInt32Array()
 # Two crossed leaf-shaped grass blades per tuft.
 for angle in [0.0,PI*0.5]:
  var dx: float = cos(angle)*0.16
  var dz: float = sin(angle)*0.16
  var k: int = vertices.size()
  vertices.append_array(PackedVector3Array([
   Vector3(-dx,0.0,-dz),Vector3(dx,0.0,dz),Vector3(0.0,0.72,0.0)
  ]))
  normals.append_array(PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]))
  uv.append_array(PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(0.5,0)]))
  indices.append_array(PackedInt32Array([k,k+1,k+2]))
 var arr := []
 arr.resize(Mesh.ARRAY_MAX)
 arr[Mesh.ARRAY_VERTEX] = vertices
 arr[Mesh.ARRAY_NORMAL] = normals
 arr[Mesh.ARRAY_TEX_UV] = uv
 arr[Mesh.ARRAY_INDEX] = indices
 blade_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
 var grass_mat := StandardMaterial3D.new()
 grass_mat.albedo_color = Color("649247")
 grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 grass_mat.roughness = 1.0
 blade_mesh.surface_set_material(0,grass_mat)
 for x in range(cells):
  for z in range(cells):
   if rng.randf() > coverage: continue
   for tuft in range(3):
    var px: float = -half_extent + (float(x)+rng.randf())*cell_size
    var pz: float = -half_extent + (float(z)+rng.randf())*cell_size
    var scale: float = rng.randf_range(0.45,1.25)
    var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3(scale,scale,scale))
    placements.append(Transform3D(basis,Vector3(px,-0.05,pz)))
 var mm := MultiMesh.new()
 mm.transform_format = MultiMesh.TRANSFORM_3D
 mm.mesh = blade_mesh
 mm.instance_count = placements.size()
 for i in range(placements.size()):
  mm.set_instance_transform(i,placements[i])
 var display := MultiMeshInstance3D.new()
 display.name = "GrassBlades"
 display.multimesh = mm
 add_child(display)
 print("[DIRT_GRASS] coverage_percent=",snappedf(coverage*100.0,0.1)," instances=",placements.size()," cells=",cells*cells)
