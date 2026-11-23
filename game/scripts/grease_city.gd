extends BadlandsArena

func build(director: Node3D) -> void:
	game=director
	var asphalt:=ShaderMaterial.new()
	asphalt.shader=preload("res://assets/environment/grease_asphalt.gdshader")
	var plane:=PlaneMesh.new()
	plane.size=Vector2(100,100)
	MeshKit.instance(self,plane,Vector3.ZERO,asphalt)
	MeshKit.collision_box(self,Vector3(0,-.25,0),Vector3(30,.5,24))
	var kerb:=MeshKit.material(Color("a69c7f"))
	var stripe:=MeshKit.material(Color("c7ae70"))
	for side:float in [-1.,1.]:
		for offset in range(-12,13,3):
			MeshKit.box(self,Vector3(2.4,.03,.13),Vector3(offset,.02,side*5.2),stripe,.01)
		MeshKit.collision_box(self,Vector3(side*14.25,1,0),Vector3(.5,3,23))
		MeshKit.collision_box(self,Vector3(0,1,side*11.25),Vector3(29,3,.5))
		MeshKit.box(self,Vector3(29,.26,.55),Vector3(0,.1,side*11.25),kerb)
		MeshKit.box(self,Vector3(.55,.26,22.5),Vector3(side*14.25,.1,0),kerb)
	var diner=load("res://assets/environment/props/grease_diner.glb").instantiate()
	add_child(diner)
	diner.position=Vector3(-3,0,-12.25)
	var enamel:=MeshKit.material(Color("407f79"),.45,.23)
	var steel:=MeshKit.material(Color("66564a"),.45,.45)
	var red:=MeshKit.material(Color("8f392e"),.62,.25)
	var chrome:=MeshKit.material(Color("bfaa88"),.33,.72)
	var charcoal:=MeshKit.material(Color("292c2b"),.84,.16)
	var ember:=MeshKit.material(Color("ef873a"),.51,.3,.38)
	# A white-and-red curb and storm drains border the working drive-through.
	for z:float in [-10.83,10.83]:
		for i in range(-7,7):
			MeshKit.box(self,Vector3(1.82,.16,.32),Vector3(i*2.+1.,.085,z),red if i%2 else kerb)
		for x:float in [-9.,0.,9.]:
			MeshKit.box(self,Vector3(1.48,.04,.54),Vector3(x,.033,z-signf(z)*.66),charcoal)
			for n in 6:
				MeshKit.box(self,Vector3(.08,.055,.49),Vector3(x-.59+.235*n,.047,z-signf(z)*.66),steel)
	for x:float in [-7.,0.,7.]:
		# Drive-through arrows remain visible from either combat camera angle.
		var mark:=Vector3(x,.031,5.9)
		MeshKit.box(self,Vector3(.14,.018,1.13),mark,stripe)
		for side:float in [-1.,1.]:
			var tip:=MeshKit.box(self,Vector3(.14,.018,.46),mark+Vector3(side*.14,0,-.41),stripe)
			tip.rotation.y=side*.70
	for x:float in [-16.,11.,20.]:
		MeshKit.box(self,Vector3(6,3.8,4.5),Vector3(x,1.83,-14.7),enamel,.16)
		for offset:float in [-1.5,1.5]:
			MeshKit.cylinder(self,Vector3(x+offset,4.3,-14),.55,3.9,steel)
			MeshKit.cylinder(self,Vector3(x+offset,6.2,-14),.61,.15,red)
		MeshKit.box(self,Vector3(6.22,.20,4.67),Vector3(x,3.82,-14.7),red)
		MeshKit.box(self,Vector3(6.16,.09,4.62),Vector3(x,3.63,-14.7),chrome)
		for n in 4:
			MeshKit.box(self,Vector3(1.10,1.35,.09),Vector3(x-2.16+1.44*n,2.14,-12.43),charcoal)
			MeshKit.box(self,Vector3(1.12,.085,.12),Vector3(x-2.16+1.44*n,2.07,-12.36),chrome)
	for i in range(3):
		var x:float=[-6.,1.,6.5][i]
		var z:float=[-2.7,1.7,-3.7][i]
		var size:=Vector2(2.8,1.6)
		cover.append(Rect2(Vector2(x,z)-size*.5,size))
		var bin:=Node3D.new()
		add_child(bin)
		bin.position=Vector3(x,0,z)
		MeshKit.collision_box(bin,Vector3.UP*.85,Vector3(size.x,1.7,size.y))
		MeshKit.box(bin,Vector3(size.x,1.55,size.y),Vector3.UP*.82,enamel,.10)
		MeshKit.box(bin,Vector3(size.x+.06,.1,size.y+.05),Vector3.UP*1.64,steel)
		MeshKit.box(bin,Vector3(size.x-.20,.065,size.y-.18),Vector3.UP*1.72,charcoal)
		for n in 10:
			MeshKit.box(bin,Vector3(.059,.07,1.28),Vector3(-1.15+n*.256,1.77,0),chrome)
		for side:float in [-1.,1.]:
			MeshKit.box(bin,Vector3(2.80,.19,.08),Vector3(0,1.44,side*.80),red)
			MeshKit.box(bin,Vector3(2.26,.63,.08),Vector3(0,.86,side*.81),steel)
			for louver in 4:
				MeshKit.box(bin,Vector3(1.8,.048,.075),Vector3(0,.68+louver*.12,side*.858),charcoal)
			for dial:float in [-.91,0.,.91]:
				MeshKit.sphere(bin,Vector3(dial,1.43,side*.85),Vector3(.074,.073,.039),ember if dial==0 else charcoal)
		cover_surfaces.append(bin.find_children("*","MeshInstance3D",true,false))
	for pos in [Vector3(-9,0,4),Vector3(9,0,3),Vector3(-1,0,-6)]:game.create_prop("barrel",pos)
	for pos in [Vector3(-11,0,-6),Vector3(11,0,7)]:game.create_prop("crate",pos)
	spawn_points.assign([Vector3(-11,0,-8),Vector3(0,0,-9),Vector3(11,0,-8),Vector3(-12,0,1),Vector3(12,0,1),Vector3(-9,0,8),Vector3(9,0,8)])
	_build_navigation()
