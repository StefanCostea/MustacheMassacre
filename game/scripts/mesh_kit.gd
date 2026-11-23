class_name MeshKit
extends RefCounted

static var meshes: Dictionary = {}
static var materials: Dictionary = {}

static func timber(color: Color) -> ShaderMaterial:
	var key:="timber"+str(color)
	if materials.has(key):return materials[key]
	var mat:=ShaderMaterial.new();mat.shader=load("res://assets/environment/wood.gdshader");mat.set_shader_parameter("tint",color)
	materials[key]=mat;return mat

static func material(color: Color, rough: float = 0.8, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var key := str(color)+str(rough)+str(metal)+str(glow)
	if materials.has(key):return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = false
	materials[key] = m
	return m

static func rounded_box(size: Vector3, bevel: float = 0.04) -> ArrayMesh:
	var key := "box"+str(size)+str(bevel)
	if meshes.has(key):return meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size*0.5
	var r := minf(bevel,minf(half.x,minf(half.y,half.z))*0.7)
	var inner := half-Vector3.ONE*r
	for axis in range(3):
		for side in [-1.0,1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var u := Vector3.ZERO
			u[(axis+1)%3] = 1
			var v := normal.cross(u)
			var hu: float = half[(axis+1)%3]
			var hv: float = half[(axis+2)%3]
			var us := [-hu,-hu+r,hu-r,hu]
			var vs := [-hv,-hv+r,hv-r,hv]
			for i in range(3):
				for j in range(3):
					for corner in [Vector2i(0,0),Vector2i(1,1),Vector2i(1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]:
						var a: float = us[i+corner.x]
						var b: float = vs[j+corner.y]
						var p: Vector3 = normal*half[axis]+u*a+v*b
						var q := p.clamp(-inner,inner)
						var n := (p-q).normalized()
						st.set_normal(n)
						st.set_uv(Vector2(a/(2*hu)+0.5,b/(2*hv)+0.5))
						st.add_vertex(q+n*r)
	var mesh := st.commit()
	meshes[key] = mesh
	return mesh

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, bevel: float = 0.04) -> MeshInstance3D:
	return instance(parent,rounded_box(size,bevel),pos,mat)

static func instance(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.mesh = mesh
	o.material_override = mat
	o.position = pos
	parent.add_child(o)
	return o

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	if not meshes.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 20
		mesh.rings = 10
		meshes["sphere"] = mesh
	var o := instance(parent,meshes["sphere"],pos,mat)
	o.scale = size
	return o

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var key := "cylinder"+str(radius)+str(height)+str(top)
	if not meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = radius
		mesh.top_radius = radius if top<0 else top
		mesh.height = height
		mesh.radial_segments = 16
		meshes[key] = mesh
	return instance(parent,meshes[key],pos,mat)

static func beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	# Share unit geometry: arbitrary tracer lengths must not grow the mesh cache
	# on every shot or persist as hundreds of unique resources between retries.
	var o := cylinder(parent,(a+b)*0.5,radius,1.0,mat)
	o.scale.y=a.distance_to(b)
	var d := (b-a).normalized()
	if absf(d.dot(Vector3.UP)) < 0.999:o.quaternion = Quaternion(Vector3.UP,d)
	return o

static func ring(parent: Node3D, pos: Vector3, radius: float, width: float, mat: Material) -> MeshInstance3D:
	var key := "ring"+str(radius)+str(width)
	if not meshes.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = maxf(0.01,radius-width*0.5)
		mesh.outer_radius = radius+width*0.5
		mesh.rings = 48
		mesh.ring_segments = 6
		meshes[key] = mesh
	var o := instance(parent,meshes[key],pos,mat)
	o.scale.y = 0.25
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return o

static func label(parent: Node3D, text: String, pos: Vector3, font_size: int, color: Color, pixel_size: float = 0.008) -> Label3D:
	var o := Label3D.new()
	o.text = text
	o.font = load("res://assets/fonts/WesternSerif.ttf")
	o.font_size = font_size
	o.pixel_size = pixel_size
	o.modulate = color
	o.outline_modulate = Color(0.08,0.035,0.015)
	o.outline_size = 5
	o.position = pos
	parent.add_child(o)
	return o

static func collision_box(parent: Node3D, pos: Vector3, size: Vector3, layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	return body

static func projectile_mesh(hostile: bool) -> ArrayMesh:
	var key := "bandit_slug" if hostile else "cactus_thorn"
	if meshes.has(key):
		return meshes[key]
	# Radius and longitudinal position. Forward is local -Z for look_at().
	var profile := [Vector2(.004,-.19),Vector2(.067,-.105),Vector2(.075,.047),Vector2(.058,.061),Vector2(.064,.115),Vector2(.004,.13)] if hostile else [Vector2(.001,-.22),Vector2(.026,-.045),Vector2(.037,.095),Vector2(.020,.138),Vector2(.002,.15)]
	var palette := [Color("fff3af"),Color("ff9a9a"),Color("951f40"),Color("e95573"),Color("f68b61")] if hostile else [Color("f7f8bf"),Color("b8da6b"),Color("658c44"),Color("d5af64")]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facets := 12 if hostile else 5
	for band in range(profile.size()-1):
		for face in facets:
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var radial: float = TAU*(face+corner.y)/facets
				var point: Vector2 = profile[band+corner.x]
				surface.set_color(palette[band])
				surface.add_vertex(Vector3(point.x*cos(radial),point.x*sin(radial),point.y))
	surface.generate_normals()
	var mesh := surface.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color("d3325e") if hostile else Color("6d993a")
	mat.emission_energy_multiplier = .9
	mat.roughness = .42
	mesh.surface_set_material(0,mat)
	meshes[key] = mesh
	return mesh
