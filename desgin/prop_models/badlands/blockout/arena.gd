class_name BadlandsArena
extends Node3D

var cover: Array[Rect2] = []
var spawn_points: Array[Vector3] = []
var foreground: Array[MeshInstance3D] = []
var rng := RandomNumberGenerator.new()
var wood: Material
var dark_wood: Material
var stone: Material
var metal: Material
var canvas: Material
var game: Node3D

func build(director: Node3D) -> void:
	game = director
	rng.seed = 20261111
	wood = MeshKit.timber(Color("785032"))
	dark_wood = MeshKit.timber(Color("35291f"))
	stone = MeshKit.material(Color("ac7950"))
	metal = MeshKit.material(Color("424b46"),0.55,0.65)
	canvas = MeshKit.material(Color("d6b67c"))
	_build_ground()
	_build_saloon()
	_build_water_tower()
	_build_boundary()
	_build_cover()
	_build_dressing()
	_build_navigation()
	for point in [Vector3(-11,0,-8),Vector3(0,0,-9),Vector3(11,0,-8),Vector3(-12,0,1),Vector3(12,0,1),Vector3(-9,0,8),Vector3(9,0,8)]:
		spawn_points.append(point)
		MeshKit.ring(self,point+Vector3.UP*0.022,0.65,0.035,MeshKit.material(Color("8c653a")))

func _build_ground() -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/environment/sand.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(120,120)
	MeshKit.instance(self,plane,Vector3.ZERO,material)
	MeshKit.collision_box(self,Vector3(0,-0.25,0),Vector3(30,0.5,24))
	for i in range(4):
		var p: Vector3 = [Vector3(-14.25,1,0),Vector3(14.25,1,0),Vector3(0,1,-11.25),Vector3(0,1,11.25)][i]
		MeshKit.collision_box(self,p,Vector3(0.5,3,23) if i<2 else Vector3(29,3,0.5))

func _build_saloon() -> void:
	var building := Node3D.new()
	building.name = "LastCallSaloon"
	building.position = Vector3(-4,0,-12.8)
	add_child(building)
	MeshKit.box(building,Vector3(9,3.5,4),Vector3(0,1.75,0),dark_wood,0.12)
	for i in range(34):
		var x := -4.4+i*0.265
		MeshKit.box(building,Vector3(0.245,3.45,0.12),Vector3(x,1.75,2.06),MeshKit.timber(Color("916645").darkened(float(i%5)*.04)),0.014)
	for y in [0.22,2.1,3.30]:MeshKit.box(building,Vector3(9.25,0.18,0.22),Vector3(0,y,2.10),wood)
	# Raised boardwalk and a shallow step at the arena edge.
	MeshKit.box(building,Vector3(10,0.30,2.4),Vector3(0,0.15,3.0),dark_wood)
	for i in range(40):MeshKit.box(building,Vector3(0.23,0.08,2.4),Vector3(-4.88+i*0.25,0.33,3),wood,0.008)
	MeshKit.box(building,Vector3(4,0.16,0.45),Vector3(0,0.08,4.35),wood)
	for x in [-4.4,4.4]:
		MeshKit.box(building,Vector3(0.22,3,0.22),Vector3(x,1.8,3.7),wood)
		MeshKit.box(building,Vector3(0.40,0.10,0.40),Vector3(x,0.5,3.7),dark_wood)
	MeshKit.box(building,Vector3(9.6,0.20,2.4),Vector3(0,3.10,3.0),dark_wood)
	for x in [-2.7,2.7]:
		MeshKit.box(building,Vector3(1.5,1.3,0.12),Vector3(x,1.9,2.15),dark_wood)
		MeshKit.box(building,Vector3(1.27,1.07,0.13),Vector3(x,1.9,2.23),MeshKit.material(Color("7eaaa2"),0.28,0.25))
		MeshKit.box(building,Vector3(1.4,0.07,0.15),Vector3(x,1.9,2.32),wood)
		MeshKit.box(building,Vector3(0.07,1.2,0.15),Vector3(x,1.9,2.32),wood)
	MeshKit.box(building,Vector3(1.8,2.5,0.14),Vector3(0,1.45,2.18),MeshKit.material(Color("211d18")))
	for sign in [-1,1]:
		var door := MeshKit.box(building,Vector3(0.75,1.20,0.12),Vector3(sign*0.41,1.43,2.32),wood)
		door.rotation.y = sign*0.18
		for j in range(6):MeshKit.box(building,Vector3(0.65,0.025,0.14),Vector3(sign*0.41,1.0+j*0.16,2.40),dark_wood,0.005)
	MeshKit.box(building,Vector3(6.8,1.08,0.24),Vector3(0,3.98,2.15),wood)
	MeshKit.box(building,Vector3(6.52,0.86,0.03),Vector3(0,3.98,2.29),MeshKit.material(Color("443526")))
	MeshKit.label(building,"LAST CALL",Vector3(0,4.02,2.34),88,Color("f2d795"),0.009)
	MeshKit.label(building,"S A L O O N",Vector3(0,3.63,2.35),27,Color("d4a45e"),0.008)
	for x in [-4,4]:_lantern(building,Vector3(x,2.45,2.45))
	for sign in [-1,1]:
		var roof := MeshKit.box(building,Vector3(9.7,0.16,2.6),Vector3(0,3.8,sign*1.1),MeshKit.material(Color("6d4540"),0.7,0.2))
		roof.rotation.x = sign*0.35
	for j in range(20):MeshKit.box(building,Vector3(0.025,0.035,4.9),Vector3(-4.6+j*0.48,4.20,0),dark_wood,0.005)
	# Sheriff notice, clearly visible as a physical prop near the boardwalk.
	MeshKit.box(building,Vector3(0.88,1.12,0.06),Vector3(-4.0,1.75,2.25),canvas)
	MeshKit.label(building,"WANTED\nDEAD SERIOUS",Vector3(-4.0,1.82,2.31),24,Color("3d2a1b"),0.007)

func _lantern(parent: Node3D, pos: Vector3) -> void:
	MeshKit.box(parent,Vector3(0.22,0.34,0.22),pos,MeshKit.material(Color("ffb650"),0.3,0,0.8))
	for y in [-0.20,0.20]:MeshKit.box(parent,Vector3(0.31,0.07,0.31),pos+Vector3(0,y,0),metal)
	for x in [-0.12,0.12]:
		for z in [-0.12,0.12]:MeshKit.beam(parent,pos+Vector3(x,-0.2,z),pos+Vector3(x,0.2,z),0.018,metal)
	MeshKit.beam(parent,pos+Vector3(0,0.25,0),pos+Vector3(0,0.4,-0.2),0.022,metal)

func _build_water_tower() -> void:
	var tower := Node3D.new()
	tower.position = Vector3(10,0,-14)
	add_child(tower)
	for x in [-1.15,1.15]:
		for z in [-1.15,1.15]:MeshKit.box(tower,Vector3(0.21,3.2,0.21),Vector3(x,1.6,z),wood)
	for z in [-1.15,1.15]:
		MeshKit.beam(tower,Vector3(-1.15,0.2,z),Vector3(1.15,2.9,z),0.07,wood)
		MeshKit.beam(tower,Vector3(1.15,0.2,z),Vector3(-1.15,2.9,z),0.07,wood)
	MeshKit.cylinder(tower,Vector3(0,4.2,0),1.6,2.1,wood)
	for i in range(24):
		var a := TAU*i/24.0
		MeshKit.beam(tower,Vector3(cos(a)*1.61,3.2,sin(a)*1.61),Vector3(cos(a)*1.61,5.2,sin(a)*1.61),0.015,dark_wood)
	for y in [3.35,4.2,5.05]:MeshKit.ring(tower,Vector3(0,y,0),1.63,0.11,metal)
	MeshKit.cylinder(tower,Vector3(0,5.42,0),1.78,0.5,metal,0.05)
	MeshKit.label(tower,"DRY GULCH",Vector3(0,4.25,1.63),38,Color("dfc59b"),0.009)
	for i in range(9):MeshKit.box(tower,Vector3(0.48,0.055,0.07),Vector3(1.7,0.4+i*0.42,0),metal,0.012)
	for z in [-0.28,0.28]:MeshKit.box(tower,Vector3(0.065,4.2,0.065),Vector3(1.7,2,z),metal,0.012)

func _build_boundary() -> void:
	for side in [-1,1]:
		for i in range(12):
			var z := -10.0+i*1.8
			var p := Vector3(side*14.3,0,z)
			MeshKit.box(self,Vector3(0.20,1.25,0.20),p+Vector3.UP*0.625,wood)
			if i%4 != 1:
				for y in [0.45,0.95]:MeshKit.box(self,Vector3(0.10,0.16,1.6),p+Vector3(0,y,0.9),wood)
	for i in range(20):
		var p := Vector3(-14+i*1.5,0,11.5)
		MeshKit.box(self,Vector3(0.14,0.62,0.14),p+Vector3.UP*.31,dark_wood)
		if i<19:MeshKit.beam(self,p+Vector3(0,0.38,0),p+Vector3(1.5,0.38,0),0.025,metal)
	# Distant silhouettes frame the playable street without blocking its camera.
	for i in range(24):
		var a := TAU*i/24.0
		var p := Vector3(cos(a)*rng.randf_range(21,34),0,sin(a)*rng.randf_range(20,29))
		var h := rng.randf_range(1.0,3.0)
		MeshKit.sphere(self,p+Vector3.UP*h*.45,Vector3(h*1.5,h*.65,h),stone)

func _build_cover() -> void:
	for bounds in [Rect2(-7,-3,3,2),Rect2(4,2,3,2),Rect2(-1.5,-0.6,3,1.2)]:
		cover.append(bounds)
		var center := Vector3(bounds.get_center().x,0.90,bounds.get_center().y)
		var size := Vector3(bounds.size.x,1.8,bounds.size.y)
		MeshKit.collision_box(self,center,size)
		if bounds.size.y<1.5:
			foreground.append(MeshKit.box(self,size,center,wood,0.10))
			foreground.append(MeshKit.box(self,Vector3(size.x-.18,.06,size.z-.18),center+Vector3.UP*.90,MeshKit.material(Color("3f6660"),.22,.2)))
			for x in [-1.0,1.0]:foreground.append(MeshKit.box(self,Vector3(.15,1.8,1.35),center+Vector3(x,0,0),metal))
		else:
			for layer in range(5):
				for col in range(5):
					var p := center+Vector3(-1.15+col*.57,layer*.35-.70,0)
					foreground.append(MeshKit.box(self,Vector3(.55,.33,size.z),p,MeshKit.material(Color("b18b5b").darkened(rng.randf_range(0,.18))),.065))
	for p in [Vector3(-10,0,-5),Vector3(10,0,-4),Vector3(-8,0,5),Vector3(8,0,6),Vector3(-2,0,-7),Vector3(3,0,8)]:
		game.create_prop("barrel",p)
	for p in [Vector3(-12,0,-7),Vector3(12,0,-6),Vector3(-12,0,6),Vector3(11,0,7)]:game.create_prop("crate",p)

func _build_dressing() -> void:
	# Small pebbles use a shared mesh and one MultiMesh draw call.
	var rock_mesh := SphereMesh.new()
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock_mesh
	mm.instance_count = 180
	for i in range(180):
		var p := Vector3(rng.randf_range(-19,19),0.03,rng.randf_range(-15,15))
		var size := rng.randf_range(.08,.30)
		mm.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled(Vector3(size*1.5,size*.5,size)),p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = stone
	add_child(mi)
	var cactus := MeshKit.material(Color("627746"))
	for p in [Vector3(-16,0,-6),Vector3(16,0,-3),Vector3(-15,0,7),Vector3(17,0,8),Vector3(6,0,-15)]:
		var h := rng.randf_range(1.5,2.5)
		MeshKit.cylinder(self,p+Vector3.UP*h*.5,.22,h,cactus)
		MeshKit.sphere(self,p+Vector3.UP*h,Vector3.ONE*.22,cactus)
		for sign in [-1,1]:
				MeshKit.beam(self,p+Vector3(0,h*.55,0),p+Vector3(sign*.55,h*.55,0),.13,cactus)
				MeshKit.cylinder(self,p+Vector3(sign*.55,h*.72,0),.13,h*.35,cactus)
	# Cart with spokes and a worn canvas load.
	var cart := Node3D.new()
	cart.position = Vector3(-11.5,0,-10)
	cart.rotation.y = -.35
	add_child(cart)
	MeshKit.box(cart,Vector3(1.5,.20,2.3),Vector3(0,.6,0),wood)
	for x in [-.8,.8]:
		var wheel := MeshKit.ring(cart,Vector3(x,.55,0),.52,.10,dark_wood)
		wheel.rotation.z = PI/2
		wheel.scale.y = 1
		for j in range(8):
			var a := TAU*j/8.0
			MeshKit.beam(cart,Vector3(x,.55,0),Vector3(x,.55+sin(a)*.45,cos(a)*.45),.025,wood)
	MeshKit.sphere(cart,Vector3(0,1.0,0),Vector3(.6,.4,.8),canvas)
	# Sheriff bell at the arrival area.
	MeshKit.box(self,Vector3(.9,.12,.6),Vector3(0,.85,7.5),wood)
	for x in [-.35,.35]:MeshKit.box(self,Vector3(.1,.8,.1),Vector3(x,.4,7.5),wood)
	MeshKit.cylinder(self,Vector3(0,1.05,7.5),.20,.26,MeshKit.material(Color("d5a84d"),.3,.7),.09)
	MeshKit.label(self,"RING THE BELL",Vector3(0,1.50,7.5),25,Color("f1d79a"),.008)

func _build_navigation() -> void:
	var nav := NavigationMesh.new()
	var vertices := PackedVector3Array()
	for z in range(21):
		for x in range(27):vertices.append(Vector3(x-13,0,z-10))
	nav.vertices = vertices
	for z in range(20):
		for x in range(26):
			var center := Vector2(x-12.5,z-9.5)
			var blocked := false
			for bounds in cover:
				if bounds.grow(.6).has_point(center):blocked=true;break
			# Static clearance around breakables keeps navigation from repeatedly
			# driving bodies into barrels. The spare clearance is harmless after
			# destruction, so this layout needs no runtime navigation rebuild.
			for prop in get_tree().get_nodes_in_group("breakables"):
				if center.distance_to(Vector2(prop.position.x,prop.position.z))<1.05:blocked=true;break
			if blocked:continue
			var i := z*27+x
			nav.add_polygon(PackedInt32Array([i,i+1,i+28,i+27]))
	var region := NavigationRegion3D.new()
	region.name = "BadlandsNavigation"
	region.navigation_mesh = nav
	add_child(region)

func point_clear(point: Vector3, radius: float = 0.5) -> bool:
	if absf(point.x)>13.1 or absf(point.z)>10.1:return false
	for bounds in cover:
		if bounds.grow(radius).has_point(Vector2(point.x,point.z)):return false
	return true

func _process(delta: float) -> void:
	if not is_instance_valid(game.player) or not is_instance_valid(game.camera):return
	var player_screen:Vector2=game.camera.unproject_position(game.player.global_position+Vector3.UP*.7)
	for mesh in foreground:
		var pos:=mesh.global_position
		var screen:Vector2=game.camera.unproject_position(pos)
		var closer:bool=pos.distance_to(game.camera.global_position)<game.player.global_position.distance_to(game.camera.global_position)
		var obscures:bool=closer and absf(screen.x-player_screen.x)<90 and absf(screen.y-player_screen.y)<95
		mesh.transparency=move_toward(mesh.transparency,.72 if obscures else 0,delta*3)
