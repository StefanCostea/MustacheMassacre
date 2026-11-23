extends Node3D

const CURL = preload("res://assets/characters/high_noon/ricochet_curl.glb")
const BLOSSOM = preload("res://assets/characters/high_noon/seed_blossom.glb")

var hero
var curls: Array[Node3D] = []
var bloom: Node3D
var camera: Camera3D
var elapsed := 0.0
var mode := ""
var curl_amount := 0.0
var blossom_left := 0.0

func setup(player) -> void:
	hero = player
	for i in 2:
		var mesh: Node3D = CURL.instantiate()
		add_child(mesh)
		curls.append(mesh)
	bloom = BLOSSOM.instantiate()
	add_child(bloom)
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = .55
	for part in find_children("*","MeshInstance3D",true,false):
		part.material_override = paint
	stop()

func start(action: String) -> void:
	if hero.form.running: return
	mode = action
	elapsed = 0.0
	if mode == "tumbleweed": blossom_left = .95
	if not camera:
		camera = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		hero.game.add_child(camera)
		camera.global_transform = hero.game.camera.global_transform
		camera.size = hero.game.camera.size
		camera.make_current()
	show()

func cast_origin() -> Vector3:
	return to_global(hero.form.bone_point("free_wrist",Vector3(.29,1.0,.29)))

func advance(delta: float) -> void:
	if not visible: return
	elapsed += delta
	blossom_left = maxf(0.0,blossom_left-delta)
	curl_amount = move_toward(curl_amount,1.0 if hero.ricochet_armed else 0.0,delta*5.5)
	for i in curls.size():
		var side := -1.0 if i == 0 else 1.0
		var face: Vector3 = hero.form.bone_point("head",Vector3(0,1.43,0)) + Vector3(.07*side,.03,.36)
		var anchor: Vector3 = hero.form.bone_point("stache_root.R" if i==0 else "stache_root.L",face)
		var s := maxf(.005,curl_amount)
		var twist := Basis(Vector3.RIGHT,-.32*s+sin(elapsed*9)*.085*s)
		curls[i].transform = Transform3D(twist.scaled_local(Vector3(s*side,s,s)),anchor)
		curls[i].visible = curl_amount > .01
	bloom.visible = blossom_left > .01
	if bloom.visible:
		bloom.position = to_local(cast_origin())
		bloom.rotation.y = elapsed*5.5
		bloom.scale = Vector3.ONE * maxf(.005,smoothstep(0,.20,.95-blossom_left)*smoothstep(0,.35,blossom_left))
	if elapsed >= .70: restore_camera()
	if not camera and not bloom.visible and curl_amount <= .01: hide()

func frame_camera() -> void:
	if not is_instance_valid(camera): return
	var weight := smoothstep(0,.19,elapsed)*(1-smoothstep(.29,.70,elapsed))
	var arena: Camera3D = hero.game.camera
	var centre: Vector3 = hero.global_position + Vector3.UP*1.1
	var arena_view := arena.global_basis.z
	var low_view := Vector3(arena_view.x, arena_view.y*.55, arena_view.z).normalized()
	var distance := Vector3(12,19,18).length()
	var focus := (arena.global_position-arena_view*distance).lerp(centre,weight)
	camera.global_position = focus + arena_view.slerp(low_view,weight)*distance
	camera.look_at(focus)
	camera.near = lerpf(arena.near,distance-3.0,weight)
	camera.size = lerpf(arena.size,4.0 if mode=="ricochet" else 4.6,weight)

func restore_camera() -> void:
	if is_instance_valid(camera):
		if camera.current: hero.game.camera.make_current()
		camera.queue_free()
		camera=null

func stop() -> void:
	restore_camera()
	curl_amount=0.0;blossom_left=0.0;elapsed=0.0
	for curl in curls:curl.hide()
	if bloom:bloom.hide()
	hide()
