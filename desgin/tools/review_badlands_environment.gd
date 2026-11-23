extends SceneTree
## Capture the same four views and a staged encounter with the normal arena, AI and camera.
## Set BADLANDS_ART_DIR to an absolute output directory; BADLANDS_FRAMES optionally saves the encounter as frames.

func _initialize():
	capture.call_deferred()

func save_view(path: String):
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func capture():
	var dest := OS.get_environment("BADLANDS_ART_DIR")
	if dest.is_empty():
		push_error("Set BADLANDS_ART_DIR to the capture directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(dest)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 6:
		await physics_frame
	await save_view(dest+"/arrival.png")
	game.start_run()
	game.spawn_queue.clear()
	game.set_process(false)
	game.player.test_mode = true
	game.ui.hide()
	var cam = game.camera
	var angles = [
		["gameplay",Vector3(0,0,1.82),Vector3(12,19,18),17.0],
		["wide",Vector3(0,.1,-2),Vector3(13,22,26),26.0],
		["saloon",Vector3(-4,1.7,-11.5),Vector3(5,4,12),8.7],
		["street",Vector3(3,.7,2),Vector3(7,8,11),9.5],
	]
	for a in angles:
		cam.size=a[3]
		cam.position=a[1]+a[2]
		cam.look_at(a[1])
		await save_view(dest+"/"+a[0]+".png")

	var frames := OS.get_environment("BADLANDS_FRAMES")
	if frames:
		DirAccess.make_dir_recursive_absolute(frames)
	var p = game.player
	p.position=Vector3(1.4,0,4.7)
	var chili=game.spawn_enemy("chili",Vector3(-3,0,1.9))
	var bird=game.spawn_enemy("pigeon",Vector3(4.1,0,.05))
	game.spawn_enemy("fridge", Vector3(-2.6,0,6.3))
	cam.position=Vector3(12,19,18)+Vector3(0,0,1.6)
	cam.look_at(Vector3(0,0,1.6))
	cam.size=17.0
	game.ui.show()
	game.ui.toast_timer=0
	game.set_process(true)
	for i in 210:
		var target = Vector3(3,0,8) if i < 56 else Vector3(-3,0,1.9)
		if i > 90 and is_instance_valid(bird) and not bird.dead:
			target = bird.aim_center()
		elif i > 56 and is_instance_valid(chili) and not chili.dead:
			target = chili.global_position
		p.test_aim=target
		p.test_move = Vector2(-.48,.35) if i > 55 and i < 112 else Vector2.ZERO
		if i==58:
			p.cast_vortex()
		if i%9==0:
			p.try_fire()
			if p.ammo==0:
				p.reload_input()
		if p.reload_elapsed>.70 and not p.reload_attempted:
			p.reload_input()
		await RenderingServer.frame_post_draw
		if i==77 or (i==139):
			root.get_texture().get_image().save_png(dest+("/combat.png" if i==77 else "/combat_late.png"))
		if frames:
			root.get_texture().get_image().save_jpg(frames+"/%04d.jpg"%i,.93)
	game.quit_application()
