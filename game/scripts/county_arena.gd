extends BadlandsArena

const Layout = preload("res://scripts/county_layout.gd")
var blocked: Array[Rect2] = []
var bridges: Dictionary = {}
var nav_region := NavigationRegion3D.new()
var wheel := Node3D.new()
var cabins: Array[Node3D] = []
var powered := false
var truck:Node3D
var water:MeshInstance3D
var vents:Array[MeshInstance3D] = []
var switches := {}
var gate:Node3D
var wheel_speed:=0.
var sun:DirectionalLight3D
var tint:=Color.WHITE
var sky:Environment
var atmosphere:=Color("ccb693")
var ambient:=Color("c5c4bb")
var sunlight:=1.55
var sky_energy:=.65
var park_lights:Array[OmniLight3D]=[]
var occluders:Array[Dictionary]=[]
var metal:=MeshKit.material(Color("48585b"),.45,.65)
var brass:=MeshKit.material(Color("c7964c"),.42,.64)
var cream:=MeshKit.material(Color("ecdfba"),.68)
var red:=MeshKit.material(Color("9e363c"),.55)
var teal:=MeshKit.material(Color("287e7a"),.5,.32)

func build(director:Node3D) -> void:
	game=director
	name="MoustacheCounty"
	var plane:=PlaneMesh.new()
	plane.size=Vector2(155,140)
	var floor_paint:=ShaderMaterial.new()
	floor_paint.shader=preload("res://assets/county/ground.gdshader")
	MeshKit.instance(self,plane,Vector3.ZERO,floor_paint)
	MeshKit.collision_box(self,Vector3(0,-.25,-11),Vector3(86,.5,66))
	for x:float in [-42.5,42.5]:MeshKit.collision_box(self,Vector3(x,2,-11),Vector3(1,5,66))
	for z:float in [-43.5,21.5]:MeshKit.collision_box(self,Vector3(0,2,z),Vector3(86,5,1))
	_build_creek()
	_build_garage_and_gulch()
	_build_diner()
	_build_midway()
	_build_palace()
	_road_dressing()
	for key in Layout.POSTS:
		var post:Array=Layout.POSTS[key]
		station(post[0],post[1],Layout.PLACES[post[3]][2])
	for key in Layout.SWITCHES:_build_switch(key)
	add_child(nav_region)
	rebuild_paths()
	sun=game.get_node("BadlandsSun")
	sky=game.find_children("*","WorldEnvironment",false,false)[0].environment

func solid(pos:Vector3, size:Vector3, parent:Node3D=self) -> StaticBody3D:
	blocked.append(Rect2(Vector2(pos.x-size.x*.5,pos.z-size.z*.5),Vector2(size.x,size.z)))
	var body:=MeshKit.collision_box(parent,Vector3.ZERO,size)
	body.global_position=pos
	return body

func pin_label(parent:Node3D,title:String,at:Vector3,color:Color,scale_px:=.007) -> Label3D:
	var label:=MeshKit.label(parent,title,at,30,color,scale_px)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end=19
	label.visibility_range_end_margin=3
	return label

func station(at:Vector3,title:String,color:Color) -> void:
	MeshKit.cylinder(self,at+Vector3.UP*.13,.70,.24,metal)
	MeshKit.cylinder(self,at+Vector3.UP*.28,.57,.13,brass)
	MeshKit.beam(self,at+Vector3.UP*.3,at+Vector3.UP*1.45,.10,metal)
	MeshKit.ring(self,at+Vector3.UP*1.52,.38,.075,MeshKit.material(color,.42,.22,1.))
	pin_label(self,title,at+Vector3.UP*2.1,color)

func _build_switch(key:String) -> void:
	var info:Array=Layout.SWITCHES[key]
	var node=preload("res://scripts/county_switch.gd").new()
	add_child(node)
	node.position=info[0]
	MeshKit.box(node,Vector3(.54,1.25,.52),Vector3.UP*.63,metal)
	var handwheel:=MeshKit.ring(node,Vector3(0,1.24,.27),.42,.085,red)
	handwheel.rotation.x=PI/2
	for angle:float in [0.,PI/3,2.*PI/3]:
		var end:=Vector3(cos(angle),sin(angle),0)*.4
		MeshKit.beam(node,handwheel.position-end,handwheel.position+end,.035,brass)
	pin_label(node,info[1],Vector3.UP*1.95,Color("ffe2a5"))
	switches[key]=node

func _build_creek() -> void:
	# The ford at either end is always open. Two service crossings cut the trip.
	var river:=MeshKit.material(Color("356962"),.24,.44)
	for pair:Array in [[-25.,-8.],[-4.,10.],[14.,23.]]:
		var x:float=(pair[0]+pair[1])*.5
		var width:float=pair[1]-pair[0]
		MeshKit.box(self,Vector3(width,.05,3.4),Vector3(x,.035,-10),river)
		solid(Vector3(x,1,-10),Vector3(width,2,3.4))
		for bank:float in [-11.74,-8.26]:
			MeshKit.box(self,Vector3(width,.42,.36),Vector3(x,.18,bank),MeshKit.timber(Color("695338")))
	for key in Layout.BRIDGES:
		var x:float=Layout.BRIDGES[key]
		for i in 12:
			MeshKit.box(self,Vector3(4.02,.12,.31),Vector3(x,.056,-11.82+i*.33),MeshKit.timber(Color("98704d")))
		var barrier:=Node3D.new()
		add_child(barrier)
		barrier.position=Vector3(x,0,-10)
		MeshKit.box(barrier,Vector3(4,1.18,.25),Vector3.UP*.7,red)
		for i in 6:
			var band:=MeshKit.box(barrier,Vector3(.18,.98,.29),Vector3(-1.5+i*.59,.7,0),cream)
			band.rotation.z=-.36
		MeshKit.collision_box(barrier,Vector3.UP*1.3,Vector3(4,2.6,.5))
		pin_label(barrier,"Freight bridge" if key=="freight" else "Maintenance crossing",Vector3.UP*2.,Color.WHEAT)
		bridges[key]=barrier
		if key in Preferences.county_shortcuts:open_bridge(key,false)

func open_bridge(key:String,rebuild:=true) -> void:
	if not is_instance_valid(bridges.get(key)):return
	var barrier:Node3D=bridges[key]
	remove_child(barrier)
	barrier.queue_free()
	bridges.erase(key)
	if rebuild:rebuild_paths()

func _build_garage_and_gulch() -> void:
	landmark("barber_garage",Vector3(0,0,.2))
	station(Vector3(0,0,4.4),"Workshop",Color("c1d89c"))
	pin_label(self,"GROOMING GARAGE",Vector3(0,3.5,2.9),Color.WHEAT,.011)
	BadlandsProps.place(self,"water_tower",Vector3(-27,0,-2))
	solid(Vector3(-27,1.6,-2),Vector3(2.9,3.2,2.9))
	for p in [Vector3(-33,0,8),Vector3(-19,0,3)]:
		BadlandsProps.place(self,"hay_bales",p)
		solid(p+Vector3.UP*.8,Vector3(2.9,1.6,1.75))
	for p in [Vector3(-31,0,7),Vector3(-25,0,7),Vector3(-34,0,1)]:game.create_prop("barrel",p)
	for p in [Vector3(-35,0,12),Vector3(-37,0,-3),Vector3(-24,0,14),Vector3(-16,0,-5),Vector3(-12,0,12)]:
		BadlandsProps.place(self,"saguaro",p,PI*.37)
		BadlandsProps.place(self,"agave_rocks",p+Vector3(1.4,0,.8),PI*.2)
	for p in [Vector3(-44,-.5,4),Vector3(-40,-.5,20),Vector3(-44,-.5,-17),Vector3(-36,-.5,-46),Vector3(0,-.5,24)]:
		BadlandsProps.place(self,"mesa",p,PI*.31,Vector3(1.2,.78,1.2))
	gate=Node3D.new()
	add_child(gate)
	gate.position=Vector3(-30,0,1)
	BadlandsProps.place(gate,"fence",Vector3.ZERO,0,Vector3(1.8,1,1))
	MeshKit.collision_box(gate,Vector3.UP*.7,Vector3(3.4,1.4,.4))

func _build_diner() -> void:
	landmark("grease_diner",Vector3(29,0,-5))
	landmark("fry_plant",Vector3(36,0,-3.5),-.32)
	for x in range(16,39,3):
		MeshKit.box(self,Vector3(1.65,.02,.14),Vector3(x,.027,7),cream)
	for i in 3:
		var z:float=1.+i*2.25
		var grate:=MeshKit.box(self,Vector3(8,.09,1.0),Vector3(29,.065,z),metal)
		for j in 13:MeshKit.box(grate,Vector3(.16,.04,.85),Vector3(-3.6+j*.6,.06,0),brass)
		vents.append(grate)
	truck=AnimatableBody3D.new()
	truck.sync_to_physics=false
	truck.collision_layer=1
	truck.collision_mask=0
	add_child(truck)
	truck.position=Vector3(21,0,10.6)
	var van:Node3D=load("res://assets/county/wax_van.glb").instantiate()
	truck.add_child(van)
	var bounds:=model_bounds(van)
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=bounds.size*Vector3(.82,.95,.74)
	collider.shape=shape
	truck.add_child(collider)
	collider.global_position=bounds.get_center()
	truck.rotation.y=-PI/2
	pin_label(truck,"WAX EXPRESS",Vector3.UP*2.33,Color.WHEAT)

func _build_midway() -> void:
	var center:=Vector3(-22,5.1,-34.7)
	add_child(wheel)
	wheel.position=center
	for depth:float in [-.65,.65]:
		for side:float in [-1.,1.]:
			MeshKit.beam(self,center+Vector3(side*3.1,-5.1,depth*1.6),center+Vector3(0,0,depth),.18,teal)
		var rim:=MeshKit.ring(wheel,Vector3(0,0,depth),4.38,.14,brass)
		rim.rotation.x=PI/2
	for i in 12:
		var a:=TAU*i/12
		var end:=Vector3(sin(a),cos(a),0)*4.34
		MeshKit.beam(wheel,Vector3.ZERO,end,.074,red if i%2 else cream)
		MeshKit.sphere(wheel,end+Vector3(0,0,.71),Vector3.ONE*.115,MeshKit.material(Color("ffd58c"),.5,0,.8))
		var gondola:=Node3D.new()
		wheel.add_child(gondola)
		gondola.position=end
		MeshKit.beam(gondola,Vector3(0,0,-.47),Vector3(0,-.6,-.47),.042,metal)
		MeshKit.beam(gondola,Vector3(0,0,.47),Vector3(0,-.6,.47),.042,metal)
		MeshKit.box(gondola,Vector3(.92,.5,1.1),Vector3.DOWN*.67,teal if i%2 else red,.12)
		cabins.append(gondola)
	solid(Vector3(-22,2,-34.7),Vector3(6.4,4,2.))
	for loc in [Vector3(-32,0,-29),Vector3(-13,0,-31)]:
		landmark("ticket_kiosk",loc,.12 if loc.x<-20 else -.33)
	for i in 3:
		var x:float=-31+i*9
		MeshKit.beam(self,Vector3(x,0,-17),Vector3(x,3.1,-17),.09,metal)
		if i==2:break
		for j in 8:
			var a:=Vector3(x+j*1.125,3.1-.5*sin(PI*j/8),-17)
			var b:=Vector3(x+(j+1)*1.125,3.1-.5*sin(PI*(j+1)/8),-17)
			MeshKit.beam(self,a,b,.024,metal)
			MeshKit.sphere(self,a-Vector3.UP*.09,Vector3.ONE*.10,MeshKit.material([Color("ffc676"),Color("e67c94"),Color("7ed5cf")][j%3],.42,0,1.2))
	for x:float in [-29.,-18.]:
		MeshKit.ring(self,Vector3(x,.039,-23),2.1,.14,cream)

func _build_palace() -> void:
	landmark("grand_palace",Vector3(24,0,-37.5))
	for side:float in [-1.,1.]:
		for i in 5:
			var at:=Vector3(23+side*8.1,0,-34+i*3.5)
			MeshKit.box(self,Vector3(1.18,.28,1.18),at+Vector3.UP*.14,cream)
			MeshKit.cylinder(self,at+Vector3.UP*1.15,.42,1.9,cream,.32)
			MeshKit.cylinder(self,at+Vector3.UP*2.12,.45,.19,brass)
			MeshKit.sphere(self,at+Vector3.UP*2.42,Vector3.ONE*.30,cream)
			solid(at+Vector3.UP,Vector3(.85,2,.85))
	var flood:=ShaderMaterial.new()
	flood.shader=preload("res://assets/county/flood.gdshader")
	water=MeshKit.box(self,Vector3(13,.055,10),Vector3(23,.07,-28),flood)
	water.hide()
	for z:float in [-32.,-28.,-24.]:
		MeshKit.box(self,Vector3(13,.025,.15),Vector3(23,.03,z),brass)

func point_clear(point:Vector3,radius:float=.5) -> bool:
	var flat:=Vector2(point.x,point.z)
	if not Layout.BOUNDS.grow(-radius).has_point(flat):return false
	for foot in blocked:
		if foot.grow(radius).has_point(flat):return false
	for key in switches:
		var p:Vector3=Layout.SWITCHES[key][0]
		if Rect2(p.x-.475,p.z-.475,.95,.95).grow(radius).has_point(flat):return false
	for key in bridges:
		if Rect2(Layout.BRIDGES[key]-2,-10.3,4,.6).grow(radius).has_point(flat):return false
	if is_instance_valid(gate) and gate.visible and Rect2(-31.7,.8,3.4,.4).grow(radius).has_point(flat):return false
	return true

func rebuild_paths() -> void:
	var mesh:=NavigationMesh.new()
	var points:=PackedVector3Array()
	for z in range(-43,22):
		for x in range(-42,43):points.append(Vector3(x,0,z))
	mesh.vertices=points
	for z in 64:
		for x in 84:
			# Leave space for both the half-cell and the moving capsule at polygon edges.
			if point_clear(Vector3(x-41.5,0,z-42.5),1.08):
				var i:=z*85+x
				mesh.add_polygon(PackedInt32Array([i,i+1,i+86,i+85]))
	nav_region.navigation_mesh=mesh

func open_tower_gate() -> void:
	if not gate.visible:return
	gate.hide()
	for body in gate.find_children("*","StaticBody3D",true,false):body.set_deferred("collision_layer",0)
	rebuild_paths()

func _process(delta:float) -> void:
	if not is_instance_valid(sun):return
	_fade_occluders()
	wheel_speed=move_toward(wheel_speed,.26 if powered else 0.,delta*.18)
	wheel.rotation.z+=delta*wheel_speed
	for cabin in cabins:cabin.rotation.z=-wheel.rotation.z
	var weight:=1-exp(-delta*2.4)
	sun.light_color=sun.light_color.lerp(tint,weight)
	sun.light_energy=lerpf(sun.light_energy,sunlight,weight)
	sky.ambient_light_color=sky.ambient_light_color.lerp(ambient,weight)
	sky.ambient_light_energy=lerpf(sky.ambient_light_energy,sky_energy,weight)
	sky.fog_light_color=sky.fog_light_color.lerp(atmosphere,weight)
	sky.background_color=sky.fog_light_color.darkened(.24)
	for light in park_lights:
		light.light_energy=lerpf(light.light_energy,2. if powered else .75,weight)

func set_sky(id:String,color:Color) -> void:
	tint=color
	match id:
		"funland":
			sunlight=.53
			ambient=Color("9ca5cd")
			atmosphere=Color("80657e")
			sky_energy=.57
		"grease":
			sunlight=.9
			ambient=Color("9cbac0")
			atmosphere=Color("738c95")
			sky_energy=.52
		"palace":
			sunlight=1.15
			ambient=Color("d1c8e0")
			atmosphere=Color("adb6c6")
			sky_energy=.62
		_:
			sunlight=1.55
			ambient=Color("c5c4bb")
			atmosphere=Color("b09b77")
			sky_energy=.65

func lamp(at:Vector3,color:Color,reach:float,energy:float) -> OmniLight3D:
	var light:=OmniLight3D.new()
	light.position=at
	light.light_color=color
	light.omni_range=reach
	light.light_energy=energy
	light.distance_fade_enabled=true
	light.distance_fade_begin=23.
	add_child(light)
	return light

func _road_dressing() -> void:
	for p in [Vector3(-29,0,-11),Vector3(26,0,-11),Vector3(-2,0,10)]:
		var post:=MeshKit.timber(Color("69523d"))
		MeshKit.beam(self,p,p+Vector3.UP*2.45,.095,post)
		var board:=MeshKit.box(self,Vector3(2.72,.45,.13),p+Vector3.UP*2.07,teal)
		board.rotation.y=.45
		var txt:="WATER TOWER  /  DINER" if p.x==-2 else ("FUNLAND  ↑" if p.x<0 else "PALACE  ↑")
		var sign:=MeshKit.label(board,txt,Vector3(0,0,.085),23,Color("ffe5a8"),.006)
		sign.outline_size=2
		BadlandsProps.place(self,"agave_rocks",p+Vector3(.58,0,-.23),.3,Vector3.ONE*.52)
	for i in 12:
		var x:float=-39.+i*7.
		if i%3!=1:
			BadlandsProps.place(self,"fence",Vector3(x,0,21),.04,Vector3(1.8,.8,1))
			BadlandsProps.place(self,"fence",Vector3(x,0,-43),.04,Vector3(1.8,.8,1))
	for i in 7:
		var z:float=-39.+i*9.
		BadlandsProps.place(self,"agave_rocks",Vector3(-41,0,z),i*.7,Vector3.ONE*1.22)
		BadlandsProps.place(self,"fence",Vector3(42,0,z),PI/2,Vector3(2.,.75,1))
	for p in [Vector3(-31,2.4,-27.8),Vector3(-14,2.4,-30),Vector3(-22,3.5,-34)]:
		park_lights.append(lamp(p,Color("f59d55") if p.x<-23 else Color("ed8bad"),8,1.))
	for p in [Vector3(22,0,-4),Vector3(34,0,8)]:
		MeshKit.cylinder(self,p+Vector3.UP*1.85,.08,3.7,teal)
		MeshKit.beam(self,p+Vector3.UP*3.65,p+Vector3(.85,3.65,0),.072,metal)
		MeshKit.sphere(self,p+Vector3(.85,3.55,0),Vector3(.31,.12,.22),MeshKit.material(Color("ffc786"),.4,0,1.5))
		lamp(p+Vector3(.85,3.35,0),Color("ffd598"),7,1.3)
	for sign_x:float in [14.9,31.1]:
		lamp(Vector3(sign_x,2.8,-27),Color("b1bcff"),7,1.2)

func model_bounds(root:Node3D) -> AABB:
	var parts:=root.find_children("*","MeshInstance3D",true,false)
	var first:MeshInstance3D=parts[0]
	var box:AABB=first.global_transform*first.get_aabb()
	for part:MeshInstance3D in parts:box=box.merge(part.global_transform*part.get_aabb())
	return box

func landmark(id:String,at:Vector3,yaw:=0.) -> void:
	var path:="res://assets/environment/props/grease_diner.glb" if id=="grease_diner" else "res://assets/county/%s.glb"%id
	var root:Node3D=load(path).instantiate()
	add_child(root)
	root.position=at
	root.rotation.y=yaw
	var box:=model_bounds(root)
	solid(box.get_center(),box.size*Vector3(.86,.97,.82))
	for mesh:MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		var surface:=mesh.get_active_material(0) as StandardMaterial3D
		if not surface:continue
		var ghost:=surface.duplicate() as StandardMaterial3D
		ghost.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost.albedo_color.a=.23
		occluders.append({"mesh":mesh,"box":mesh.global_transform*mesh.get_aabb(),"ghost":ghost,"opaque":mesh.material_override})

func _fade_occluders() -> void:
	var cam:=get_viewport().get_camera_3d()
	if not cam or not is_instance_valid(game.player):return
	var chest:Vector3=game.player.position+Vector3.UP
	var line_end:=chest+cam.global_basis.z*38.
	for obstacle in occluders:
		var mesh:MeshInstance3D=obstacle.mesh
		var box:AABB=obstacle.box
		var material:Material=obstacle.ghost if box.intersects_segment(chest,line_end)!=null else obstacle.opaque
		if mesh.material_override!=material:mesh.material_override=material
