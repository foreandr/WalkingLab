extends Node3D
# All foliage geometry is imported from Kenney's CC0 Nature Kit grass.glb.
# This script only scatters and batches third-party authored grass meshes.
var half_extent: float = 250.0
var rng := RandomNumberGenerator.new()
const SOURCE: String = "res://assets/external_grass/kenney_grass.glb"
const CELL_SIZE: float = 4.0
const CHUNK_CELLS: int = 12

func _ready() -> void:
    rng.randomize()
    if not ResourceLoader.exists(SOURCE):
        push_warning("[DIRT_GRASS] Kenney grass not imported; RUN.bat installs this CC0 asset automatically.")
        return
    var scene: PackedScene = load(SOURCE) as PackedScene
    if scene == null:
        push_warning("[DIRT_GRASS] Imported authored grass scene unavailable")
        return
    var original: Node3D = scene.instantiate()
    var mesh: Mesh = _find_mesh(original)
    if mesh == null:
        original.free()
        push_warning("[DIRT_GRASS] No mesh in imported Kenney asset")
        return
    var coverage: float = rng.randf_range(0.40,0.90)
    var cells: int = int(floor(half_extent*2.0/CELL_SIZE))
    var tiles: int = int(ceil(float(cells)/float(CHUNK_CELLS)))
    var instance_total: int = 0
    for tile_x in range(tiles):
        for tile_z in range(tiles):
            var transforms: Array[Transform3D] = []
            for local_x in range(CHUNK_CELLS):
                var x: int = tile_x*CHUNK_CELLS+local_x
                if x >= cells: break
                for local_z in range(CHUNK_CELLS):
                    var z: int = tile_z*CHUNK_CELLS+local_z
                    if z >= cells: break
                    if rng.randf() > coverage: continue
                    var px: float = -half_extent+(float(x)+rng.randf())*CELL_SIZE
                    var pz: float = -half_extent+(float(z)+rng.randf())*CELL_SIZE
                    var scale_value: float = rng.randf_range(1.4,2.9)
                    var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*scale_value)
                    transforms.append(Transform3D(basis,Vector3(px,-0.03,pz)))
            if transforms.is_empty(): continue
            var batch := MultiMesh.new()
            batch.transform_format = MultiMesh.TRANSFORM_3D
            batch.mesh = mesh
            batch.instance_count = transforms.size()
            for i in range(transforms.size()):
                batch.set_instance_transform(i,transforms[i])
            var instance := MultiMeshInstance3D.new()
            instance.name = "KenneyGrass_%d_%d" % [tile_x,tile_z]
            instance.multimesh = batch
            instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            instance.visibility_range_end = 125.0
            instance.visibility_range_end_margin = 12.0
            add_child(instance)
            instance_total += transforms.size()
    original.free()
    print("[DIRT_GRASS] imported_asset=Kenney_CC0 coverage_percent=",snappedf(coverage*100.0,0.1)," grass_tufts=",instance_total)

func _find_mesh(node: Node) -> Mesh:
    if node is MeshInstance3D:
        return (node as MeshInstance3D).mesh
    for child in node.get_children():
        var found: Mesh = _find_mesh(child)
        if found != null: return found
    return null
