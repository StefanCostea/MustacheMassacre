extends SceneTree

# Run the live --high-noon-preview at --fixed-fps 30 with NOON_FRAMES set to an output directory.
# Set NOON_VIDEO=1 to capture every frame in addition to the key poses.
const KEY_TIMES := [0.0, .26, .35, .50, .64, .79, .97, 1.09, 1.27, 1.57, 2.2, 3.1, 5.78, 6.0]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := OS.get_environment("NOON_FRAMES")
	if not output.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Set NOON_FRAMES to a writable absolute directory")
		quit(1)
		return
	if "--high-noon-preview" not in OS.get_cmdline_user_args():
		push_error("Pass -- --high-noon-preview to start the charged first wave")
		quit(1)
		return
	var all_frames := OS.get_environment("NOON_VIDEO") == "1"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var hero = game.player
	for i in 120:
		if hero.form.running: break
		await physics_frame
	if not hero.form.running:
		push_error("High Noon failed to acquire a target in the first wave")
		game.quit_application(1)
		return
	var key := 0
	for frame in 195:
		if frame >= 60:
			hero.test_mode = true
			hero.test_move = Vector2(.65, -.12) if frame < 132 else Vector2.ZERO
			var enemy = game.nearest_chain_target(hero.position, [], 18.0)
			hero.test_aim = enemy.aim_center() if enemy else hero.position + Vector3(2, 1, -3)
			if frame in [72, 91, 111, 130]: hero.try_fire()
		await RenderingServer.frame_post_draw
		var is_key: bool = key < KEY_TIMES.size() and float(frame) / 30.0 >= KEY_TIMES[key]
		if all_frames or is_key:
			var still := root.get_texture().get_image()
			if all_frames: still.save_jpg(output.path_join("%04d.jpg" % frame), .94)
			if is_key:
				still.save_jpg(output.path_join("key_%02d.jpg" % key), .95)
				key += 1
	game.quit_application()
