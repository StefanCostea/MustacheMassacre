class_name BadlandsArena
extends Node3D

var cover: Array[Rect2] = []
var spawn_points: Array[Vector3] = []
var cover_surfaces: Array[Array] = []
var rng := RandomNumberGenerator.new()
var game: Node3D

func build(director: Node3D) -> void:
	game = director
	rng.seed = 20261111
	_build_ground()
	_build_saloon()
	_build_water_tower()
	_build_boundary()
	_build_cover()
	_build_dressing()
	_build_navigation()
	for point in [Vector3(-11,0,-8),Vector3(0,0,-9),Vector3(11,0,-8),Vector3(-12,0,1),Vector3(12,0,1),Vector3(-9,0,8),Vector3(9,0,8)]:
		spawn_points.append(point)

func _build_ground() -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/environment/sand.gdshader")
	var plane := PlaneMesh.new()
	material.set_shader_parameter("road_paint", preload("res://assets/environment/gulch_road.webp"))
	material.set_shader_parameter("hardpan", preload("res://assets/environment/hardpan.webp"))
	plane.size = Vector2(120,120)
	MeshKit.instance(self,plane,Vector3.ZERO,material)
	MeshKit.collision_box(self,Vector3(0,-0.25,0),Vector3(30,0.5,24))
	for i in range(4):
		var p: Vector3 = [Vector3(-14.25,1,0),Vector3(14.25,1,0),Vector3(0,1,-11.25),Vector3(0,1,11.25)][i]
		MeshKit.collision_box(self,p,Vector3(0.5,3,23) if i<2 else Vector3(29,3,0.5))

func _build_saloon() -> void:
	var post := MeshKit.timber(Color("64513c"))
	MeshKit.box(self, Vector3(.14, 1.62, .14), Vector3(.48, .81, -9.79), post)
	BadlandsProps.place(self, "wanted", Vector3(.48, .72, -9.64), .14)
	BadlandsProps.place(self, "lantern", Vector3(.48, 1.64, -9.75), .32, Vector3.ONE * .82)
	BadlandsProps.place(self, "saloon", Vector3(-4, 0, -12.25))
	BadlandsProps.place(self, "wagon", Vector3(-10.9, 0, -9.75), -.46)
	BadlandsProps.place(self, "sacks", Vector3(-9.25, 0, -10.5), .38)
	BadlandsProps.place(self, "sacks", Vector3(.95, 0, -11.8), -1.3, Vector3.ONE * .78)

func _build_water_tower() -> void:
	BadlandsProps.place(self, "water_tower", Vector3(8.1, 0, -13.35), -.27)

func _build_boundary() -> void:
	for side in [-1, 1]:
		for i in range(11):
			if i in [2, 7]:
				continue
			BadlandsProps.place(self, "fence", Vector3(side * 14.3, 0, -10.0 + i * 2.0), side * PI/2)
	# A low hitch rail marks the near edge without hiding a fighter at the boundary.
	for i in range(14):
		BadlandsProps.place(self, "fence", Vector3(-13 + i * 2, 0, 11.5), PI, Vector3(1, .50, .78))
	# An eroded ridge to the north, low shelves along the wash to the west and east.
	# Embed the lowest strata so adjacent outcrops form one continuous skyline.
	var ridge := [
		Vector4(-20,-15,1.18,1.12), Vector4(-23,-12,.84,.49), Vector4(-18,-19,1.3,.57),
		Vector4(-11,-24,1.42,1.16), Vector4(-8,-22,1.05,.52), Vector4(-2,-25,1.52,.73),
		Vector4(7,-23,1.23,.65), Vector4(13,-24,1.34,1.33), Vector4(17,-22,.92,.72),
		Vector4(22,-16,1.31,.57), Vector4(25,-12,1.20,.9), Vector4(-23,-2,1.35,.62),
		Vector4(-24,2,.86,.35), Vector4(24,8,1.20,.50), Vector4(21,10,.62,.30),
		Vector4(-20,15,.97,.32), Vector4(8,20,1.24,.35)
	]
	for rock in ridge:
		BadlandsProps.place(self, "mesa", Vector3(rock.x, -.29, rock.y), rng.randf_range(-PI, PI), Vector3(rock.z, rock.w, rock.z*.81))

func _build_cover() -> void:
	for bounds in [Rect2(-7,-3,3,2), Rect2(4,2,3,2), Rect2(-1.5,-0.6,3,1.2)]:
		cover.append(bounds)
		var center := Vector3(bounds.get_center().x, .9, bounds.get_center().y)
		MeshKit.collision_box(self, center, Vector3(bounds.size.x, 1.8, bounds.size.y))
		var kind := "trough" if bounds.size.y < 1.5 else "hay_bales"
		var model := BadlandsProps.place(self, kind, center - Vector3.UP * .9, PI if center.x > 0 else 0.0)
		cover_surfaces.append(model.find_children("*", "MeshInstance3D", true, false))
	for p in [Vector3(-10,0,-5),Vector3(10,0,-4),Vector3(-8,0,5),Vector3(8,0,6),Vector3(-2,0,-7),Vector3(3,0,8)]:
		game.create_prop("barrel",p)
	for p in [Vector3(-12,0,-7),Vector3(12,0,-6),Vector3(-12,0,6),Vector3(11,0,7)]:
		game.create_prop("crate",p)

func _build_dressing() -> void:
	for point in [Vector3(-15.3,0,-5),Vector3(15.6,0,-2.2),Vector3(-15.7,0,7),Vector3(16.1,0,9),Vector3(3.0,0,-14.1),Vector3(-13.7,0,-13.1)]:
		BadlandsProps.place(self, "saguaro", point, rng.randf_range(-PI,PI), Vector3.ONE * rng.randf_range(.78,1.28))
	# Group desert growth at the fence feet, where the traffic gives way to scrub.
	for edge in [-1, 1]:
		for i in range(11):
			var point := Vector3(edge * rng.randf_range(13.5,17.8), -.045, -11+i*2.15+rng.randf_range(-.6,.6))
			BadlandsProps.place(self, "agave_rocks", point, rng.randf_range(-PI,PI), Vector3.ONE * rng.randf_range(.42,1.05))
	for p in [Vector3(-7.8,0,-9.9), Vector3(.8,0,-12), Vector3(8.95,0,-11.5), Vector3(-12,0,8.4), Vector3(13,0,6.8)]:
		BadlandsProps.place(self, "agave_rocks", p, rng.randf_range(-PI,PI), Vector3.ONE * .73)
	BadlandsProps.place(self, "bell", Vector3(0,0,7.5))
	# Low weathered details stay beside cover, inside its existing footprint.
	BadlandsProps.place(self, "sacks", Vector3(-6.43, 0, -2.3), -.22, Vector3.ONE * .59)
	BadlandsProps.place(self, "lantern", Vector3(8.86, 0, -11.8), -.52)
	_scatter_gravel()

func _scatter_gravel() -> void:
	# Pick a small piece from the hand-shaped rock palette. Render the whole street of gravel in one draw.
	var pebble := PrismMesh.new()
	pebble.size = Vector3(.21,.11,.16)
	pebble.left_to_right = .38
	var gravel := MultiMesh.new()
	gravel.transform_format = MultiMesh.TRANSFORM_3D
	gravel.use_colors = true
	gravel.mesh = pebble
	gravel.instance_count = 168
	var palette := [Color("9e7157"),Color("b78b63"),Color("a87956"),Color("c8996e")]
	for cluster in range(28):
		var edge := -1.0 if cluster % 2 else 1.0
		var center := Vector3(edge*rng.randf_range(12.6,16),0,rng.randf_range(-12,12))
		if cluster % 4 == 0:
			center = Vector3(rng.randf_range(-11,11),0,rng.randf_range(-9,9))
		for j in range(6):
			var size := rng.randf_range(.31,.95)
			var point := center + Vector3(rng.randfn(0,.34),.011,rng.randfn(0,.23))
			var basis := Basis.from_euler(Vector3(.11,rng.randf()*TAU,.15)).scaled(Vector3(size,.61*size,size))
			gravel.set_instance_transform(cluster*6+j,Transform3D(basis,point))
			gravel.set_instance_color(cluster*6+j,palette[rng.randi_range(0,palette.size()-1)])
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("916e54")
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = gravel
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

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
	var displayed := get_viewport().get_camera_3d()
	if not displayed:return
	var towards_camera := displayed.global_basis.z
	for i in cover.size():
		var foot := cover[i]
		var volume := AABB(Vector3(foot.position.x, 0, foot.position.y), Vector3(foot.size.x, 1.8, foot.size.y)).grow(.16)
		var obscures := false
		for height in [.35, 1.15]:
			var point: Vector3 = game.player.global_position + Vector3.UP * height
			var distance: float = maxf(0., (displayed.global_position-point).dot(towards_camera)-displayed.near)
			if volume.intersects_segment(point, point+towards_camera*distance) != null:
				obscures = true
				break
		for mesh: MeshInstance3D in cover_surfaces[i]:
			mesh.transparency = move_toward(mesh.transparency, .72 if obscures else 0., delta*3.)
