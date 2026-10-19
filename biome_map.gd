extends Node3D
# Battle-royale prototype: deterministic, slightly overlapping biome footprints.
# Effects combine, with gravity multipliers applied to the default gravitational pull.
const REGIONS = [
 {"name":"MEADOW","kind":"grass","p":Vector2(0,0),"r":150.0,"slow":1.0},
 {"name":"FOREST","kind":"forest","p":Vector2(220,-70),"r":145.0,"slow":0.94},
 {"name":"SAND DUNES","kind":"sand","p":Vector2(-220,-55),"r":175.0,"slow":0.77},
 {"name":"ICE FIELDS","kind":"ice","p":Vector2(80,280),"r":150.0,"slow":0.70},
 {"name":"LAVA FIELDS","kind":"lava","p":Vector2(-240,250),"r":155.0,"slow":0.88},
 {"name":"GALE","kind":"wind","p":Vector2(200,255),"r":160.0,"slow":0.91,"wind":Vector2(7.0,-3.0)},
 {"name":"BOG","kind":"slow","p":Vector2(20,-280),"r":145.0,"slow":0.40},
 {"name":"FLIGHT NULL","kind":"ground","p":Vector2(-105,-295),"r":150.0,"slow":0.91,"ground":true},
 {"name":"POND","kind":"pond","p":Vector2(250,-250),"r":85.0,"slow":0.6},
 {"name":"GRAVITY x2","kind":"gravity","p":Vector2(420,60),"r":125.0,"gravity":2.0},
 {"name":"GRAVITY x3","kind":"gravity","p":Vector2(445,250),"r":125.0,"gravity":3.0},
 {"name":"GRAVITY x4","kind":"gravity","p":Vector2(-410,90),"r":135.0,"gravity":4.0}
]
var rng := RandomNumberGenerator.new()
var clouds: Array[Node3D] = []

static func sample(pos: Vector3) -> Dictionary:
 var point := Vector2(pos.x,pos.z)
 var speed := 1.0
 var wind := Vector2.ZERO
 var grounding := false
 var gravity := 1.0
 var names: Array[String] = []
 for region in REGIONS:
  var radius: float = region["r"]
  var dist: float = point.distance_to(region["p"])
  if dist >= radius: continue
  var weight: float = clampf((radius-dist)/18.0,0.0,1.0)
  speed *= lerpf(1.0,float(region.get("slow",1.0)),weight)
  wind += region.get("wind",Vector2.ZERO)*weight
  grounding = grounding or (bool(region.get("ground",false)) and weight > 0.15)
  # Highest gravitational anomaly wins, rather than multiplying 2x * 3x.
  gravity = maxf(gravity,lerpf(1.0,float(region.get("gravity",1.0)),weight))
  names.append(region["name"])
 return {"speed":maxf(speed,0.2),"wind":wind,"grounded":grounding,"gravity":gravity,"names":names}

func _ready() -> void:
 rng.seed = 1001
 _create_clouds()
 _create_regions()
 print("[BIOME_MAP] regions=",REGIONS.size()," overlap=true gravity=2x,3x,4x clouds=",clouds.size())

func _material(color: Color, translucent: bool = false) -> StandardMaterial3D:
 var mat := StandardMaterial3D.new()
 mat.albedo_color = color
 mat.roughness = 0.9
 if translucent: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 return mat

func _mesh(parent: Node3D, shape: Mesh, position: Vector3, mat: Material) -> void:
 var obj := MeshInstance3D.new()
 obj.mesh = shape
 obj.position = position
 obj.material_override = mat
 parent.add_child(obj)

func _create_clouds() -> void:
 var white := _material(Color(0.97,0.98,1.0,0.88),true)
 for i in range(22):
  var cloud := Node3D.new()
  cloud.position = Vector3(rng.randf_range(-750,750),rng.randf_range(125,220),rng.randf_range(-750,750))
  add_child(cloud)
  for j in range(4):
   var puff := SphereMesh.new()
   puff.radius = rng.randf_range(15.0,24.0)
   puff.height = 12.0
   _mesh(cloud,puff,Vector3(float(j-2)*18.0,rng.randf_range(-3,3),rng.randf_range(-7,7)),white)
  clouds.append(cloud)
 set_process(true)

func _process(dt: float) -> void:
 for cloud in clouds:
  cloud.position.x += dt*2.0
  if cloud.position.x > 850.0: cloud.position.x = -850.0

func _create_regions() -> void:
 var colors = {
  "grass":Color("559248"),"forest":Color("326a39"),"sand":Color("d2b66f"),
  "ice":Color("afd8e8"),"lava":Color("634036"),"wind":Color("729f93"),
  "slow":Color("455f39"),"ground":Color("536b88"),"pond":Color("408eae"),
  "gravity":Color("8d6aa1")
 }
 var grass_material := _material(Color("659e48"))
 var trunk_material := _material(Color("65503d"))
 var leaves_material := _material(Color("285d36"))
 var rock_material := _material(Color("796c5e"))
 for region in REGIONS:
  var root := Node3D.new()
  root.name = String(region["name"]).replace(" ","_")
  root.position = Vector3(region["p"].x,0,region["p"].y)
  add_child(root)
  var kind: String = region["kind"]
  var disc := CylinderMesh.new()
  disc.top_radius = region["r"]
  disc.bottom_radius = region["r"]
  disc.height = 0.025
  disc.radial_segments = 48
  _mesh(root,disc,Vector3(0,-0.11,0),_material(colors[kind]))
  var sign := Label3D.new()
  sign.text = region["name"]
  sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  sign.font_size = 45
  sign.outline_size = 8
  sign.position = Vector3(0,8,0)
  root.add_child(sign)
  var count := 0
  if kind == "forest": count = 75
  elif kind == "grass" or kind == "wind" or kind == "slow": count = 65
  elif kind == "sand" or kind == "ice" or kind == "lava": count = 25
  for i in range(count):
   var angle := rng.randf_range(0,TAU)
   var radius := sqrt(rng.randf())*float(region["r"])*0.88
   var at := Vector3(cos(angle)*radius,0,sin(angle)*radius)
   if kind == "forest":
    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.32
    trunk.bottom_radius = 0.46
    trunk.height = 5.0
    _mesh(root,trunk,at+Vector3(0,2.5,0),trunk_material)
    var crown := SphereMesh.new()
    crown.radius = 3.3
    crown.height = 7.5
    _mesh(root,crown,at+Vector3(0,7,0),leaves_material)
   elif kind == "grass" or kind == "wind" or kind == "slow":
    var tuft := PrismMesh.new()
    tuft.size = Vector3(rng.randf_range(0.8,2.0),rng.randf_range(0.5,1.4),1.3)
    _mesh(root,tuft,at+Vector3(0,0.45,0),grass_material)
   else:
    var rock := SphereMesh.new()
    rock.radius = rng.randf_range(1.0,3.0)
    rock.height = rng.randf_range(0.6,1.6)
    _mesh(root,rock,at+Vector3(0,0.12,0),rock_material)
  if kind == "pond":
   var water := CylinderMesh.new()
   water.top_radius = float(region["r"])*0.75
   water.bottom_radius = water.top_radius
   water.height = 0.04
   _mesh(root,water,Vector3(0,0.06,0),_material(Color(0.17,0.54,0.76,0.76),true))
