extends Node3D
# Stadium uses existing third-party CC0 bleacher geometry. No homemade visible meshes.
var radius: float = 45.0
const SEATS: String = "res://assets/stadium/bleachers.glb"

func _ready() -> void:
 var usable: bool = ResourceLoader.exists(SEATS)
 if not usable:
  push_warning("[STADIUM] Authored seating absent; RUN.bat downloads it on next launch.")
 var packed: PackedScene = load(SEATS) as PackedScene if usable else null
 var count: int = maxi(32,int(ceil(TAU*(radius+7.0)/3.7)))
 for i in range(count):
  var theta: float = TAU*float(i)/float(count)
  var direction := Vector3(sin(theta),0,cos(theta))
  var angle: float = theta
  var seat_pos: Vector3 = direction*(radius+7.0)
  if packed != null:
   var stand: Node3D = packed.instantiate()
   stand.name = "AuthoredGrandstand_%03d" % i
   stand.position = seat_pos
   stand.rotation.y = angle
   add_child(stand)
  # Invisible arena boundary. Stadium seating is external and remains visual art.
  var blocker := StaticBody3D.new()
  blocker.name = "StadiumBoundary_%03d" % i
  blocker.position = direction*(radius+0.65)+Vector3.UP*5.0
  blocker.rotation.y = angle
  var shape := CollisionShape3D.new()
  var wall := BoxShape3D.new()
  wall.size = Vector3(TAU*(radius+0.65)/float(count)+0.45,10.0,1.5)
  shape.shape = wall
  blocker.add_child(shape)
  add_child(blocker)
 print("[STADIUM] stands=",count if packed != null else 0," boundary_segments=",count," radius=",radius)
