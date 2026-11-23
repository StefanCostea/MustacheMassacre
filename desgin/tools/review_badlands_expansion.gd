extends SceneTree

var directory := OS.get_environment("BADLANDS_FRAMES")

func snap(label: String) -> void:
	for i in 3:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(directory.path_join(label+".jpg"),.94)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not directory.is_absolute_path() or DirAccess.make_dir_recursive_absolute(directory)!=OK:
		push_error("Set BADLANDS_FRAMES to an absolute capture directory")
		quit(1)
		return
	var gallery=load("res://scenes/badlands_enemy_review.tscn").instantiate()
	root.add_child(gallery)
	gallery.set_process(false)
	for i in [4,5]:
		gallery.focus=i
		for stage in ["idle","windup","attack","death"]:
			gallery.step=gallery.SHOWCASE.find(stage)
			gallery._play_step()
			var motion=gallery.motions[i]
			motion.play_clip(stage,0,0)
			for j in 40:motion.animator.advance(motion.animator.get_animation(stage).length*(.95 if stage=="death" else .44)/40.)
			await snap(gallery.KINDS[i]+"_"+stage)
	gallery.queue_free()
	await process_frame
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var p=game.player
	await snap("arrival")
	game.ui.show_loadout()
	await snap("loadout")
	game.ui.leave_loadout()
	game.ui.show_garage()
	await snap("garage")
	game.ui.leave_loadout()
	game.start_run()
	game.set_process(false)
	game.ui.hide()
	p.test_mode=true
	p.global_position=Vector3(-3,0,4)
	p.test_aim=Vector3(-3,0,9)
	var camera:=Camera3D.new()
	game.add_child(camera)
	camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.5
	var face:Vector3=p.position+Vector3.UP*.97
	camera.position=face+Vector3(0,.12,3)
	camera.look_at(face)
	for i in 5:await physics_frame
	p.stache=0
	await snap("stache_empty")
	p.stache=100
	for i in 4:await physics_frame
	await snap("stache_full")
	camera.size=5.5
	var mark:=Vector3(-3.1,0,6.4)
	var fridge=game.spawn_enemy("fridge",mark)
	var medic=game.spawn_enemy("repair",mark+Vector3(2,0,-.25))
	var skillet=game.spawn_enemy("skillet",mark+Vector3(-1.58,0,.7))
	for actor in [medic,fridge,skillet]:actor.set_physics_process(false)
	camera.position=mark+Vector3(.2,2.4,6)
	camera.look_at(mark+Vector3.UP*.85)
	fridge.health=30
	medic.grace=0
	medic.cooldown=0
	medic._physics_process(.016)
	for i in 10:medic._physics_process(.025)
	await snap("weld")
	p.field_skill="slap"
	p.aim_point=skillet.position
	p.use_field_skill()
	var slap=game.actors.get_child(-1)
	slap.set_physics_process(false)
	slap._physics_process(.36)
	await snap("slap")
	game.quit_application()
