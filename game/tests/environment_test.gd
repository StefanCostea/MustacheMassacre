extends Node

var game: GameDirector
var checks := 0
var failures := 0

func setup(director: GameDirector) -> void:
	game = director
	review.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func review() -> void:
	await get_tree().physics_frame
	game.set_process(false)
	game.player.test_mode = true
	# Exercise the base game entry points, including the special that owns the rolling prop.
	var p := game.player
	game.cast_vortex(Vector3(3,0,5),false)
	var scene_paths := {}
	for node in game.find_children("*","Node3D",true,false):
		if not node.scene_file_path.is_empty():
			scene_paths[node.scene_file_path] = true
	for kind in BadlandsProps.MODELS:
		check(scene_paths.has(BadlandsProps.MODELS[kind].resource_path), kind+" exists in gameplay")
	var street := game.arena
	check(street.cover_surfaces.size() == 3,"two bale stacks and the water trough own visual cover")
	check(BadlandsProps.straw_material != null and BadlandsProps.straw_material.get_shader_parameter("painted") != null,"straw detail receives the imported albedo")
	for i in street.cover.size():
		var footprint := street.cover[i]
		var middle := Vector3(footprint.get_center().x,0,footprint.get_center().y)
		# Place the character just behind each prop, then beside it at the same height.
		var away := -game.camera.global_basis.z
		away.y=0
		p.global_position = middle + away.normalized()*(footprint.size.y*.46+.45)
		street._process(.4)
		var faded := true
		for part in street.cover_surfaces[i]:
			faded = faded and part.transparency > .70
		check(faded and not street.cover_surfaces[i].is_empty(),"all visible cover surfaces fade together "+str(i))
		p.global_position = middle+Vector3(3.8,0,0)
		street._process(.4)
		var restored := true
		for part in street.cover_surfaces[i]:
			restored = restored and is_zero_approx(part.transparency)
		check(restored,"cover regains full opacity "+str(i))
	var crate: BreakableProp
	var barrel: BreakableProp
	for prop in get_tree().get_nodes_in_group("breakables"):
		if prop.kind == "crate": crate=prop
		if prop.kind == "barrel": barrel=prop
	for thing in [crate,barrel]:
		var mesh: MeshInstance3D = thing.visual.find_children("*","MeshInstance3D",true,false)[0]
		var aabb: AABB = mesh.global_transform*mesh.get_aabb()
		check(absf(aabb.position.y) < .05 and absf(aabb.end.y-1.4)<.05,"breakable matches collider height")
		check(aabb.size.x < 1.0 and aabb.size.z < 1.0,"breakable has no stray spikes")
	crate.receive_hit(100)
	check(crate.spent and crate.is_queued_for_deletion() and crate.collision_layer==0,"destroyed citrus crates clear their collider")
	barrel.receive_hit(100)
	barrel._process(.20)
	check(barrel.fuse > 0 and barrel.visual.visible and absf(barrel.visual.scale.y-1)<.05,"lit fuel drum keeps its warning silhouette")
	barrel._process(.40)
	check(barrel.spent and barrel.is_queued_for_deletion(),"fuel drum explodes at end of fuse")
	print("ENVIRONMENT_TEST checks=",checks," failures=",failures)
	game.quit_application(0 if failures == 0 else 1)
