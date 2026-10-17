extends Node3D
# Gameplay water volume: persistent litres per container or local ground patch.
# A cheap height-field pool, not a full Navier-Stokes solver.
const BASIN_CENTER = Vector3(5.5,0.0,8.5)
const INSIDE_WIDTH = 3.0
const INSIDE_DEPTH = 3.0
const WALL_HEIGHT = 2.1
const GROUND_CELL = 1.2
const MAX_CELLS = 256
var basin_litres: float = 0.0
var surface: MeshInstance3D
var ground_pools: Dictionary = {}
var pool_material: StandardMaterial3D

func _ready() -> void:
	pool_material = StandardMaterial3D.new()
	pool_material.albedo_color = Color(0.09,0.40,0.80,0.62)
	pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_material.roughness = 0.17
	pool_material.metallic = 0.05
	pool_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface = MeshInstance3D.new()
	surface.name = "BasinWaterSurface"
	surface.mesh = BoxMesh.new()
	surface.material_override = pool_material
	add_child(surface)
	surface.visible = false

func deposit(world_point: Vector3, litres: float = 140.0) -> void:
	if litres <= 0.0: return
	if absf(world_point.x-BASIN_CENTER.x)<INSIDE_WIDTH*0.5 and absf(world_point.z-BASIN_CENTER.z)<INSIDE_DEPTH*0.5 and world_point.y < WALL_HEIGHT + 0.5:
		var capacity: float = INSIDE_WIDTH * INSIDE_DEPTH * WALL_HEIGHT * 1000.0
		basin_litres = minf(basin_litres+litres,capacity)
		var depth: float = basin_litres/1000.0/(INSIDE_WIDTH*INSIDE_DEPTH)
		surface.visible = depth > 0.001
		(surface.mesh as BoxMesh).size = Vector3(INSIDE_WIDTH-0.10,maxf(depth,0.002),INSIDE_DEPTH-0.10)
		surface.global_position = Vector3(BASIN_CENTER.x,depth*0.5,BASIN_CENTER.z)
		print("BASIN_WATER_LITRES ",roundf(basin_litres)," DEPTH_M ",snappedf(depth,0.01))
		return
	# Outside the basin, water remains where it lands as shallow accumulating pools.
	var cell: Vector2i = Vector2i(floori(world_point.x/GROUND_CELL),floori(world_point.z/GROUND_CELL))
	if not ground_pools.has(cell):
		if ground_pools.size() >= MAX_CELLS: return
		var mesh := MeshInstance3D.new()
		mesh.name = "GroundWater"
		mesh.mesh = BoxMesh.new()
		mesh.material_override = pool_material
		add_child(mesh)
		ground_pools[cell] = {"mesh":mesh,"litres":0.0}
	var pool: Dictionary = ground_pools[cell]
	pool["litres"] = float(pool["litres"]) + litres
	var depth: float = minf(float(pool["litres"])/1000.0/(GROUND_CELL*GROUND_CELL),0.22)
	var instance: MeshInstance3D = pool["mesh"]
	(instance.mesh as BoxMesh).size = Vector3(GROUND_CELL,depth,GROUND_CELL)
	instance.global_position = Vector3((float(cell.x)+0.5)*GROUND_CELL,depth*0.5,(float(cell.y)+0.5)*GROUND_CELL)
	ground_pools[cell] = pool

func contains_water(point: Vector3) -> bool:
	var depth: float = basin_litres/1000.0/(INSIDE_WIDTH*INSIDE_DEPTH)
	return absf(point.x-BASIN_CENTER.x)<INSIDE_WIDTH*0.5 and absf(point.z-BASIN_CENTER.z)<INSIDE_DEPTH*0.5 and point.y <= depth
