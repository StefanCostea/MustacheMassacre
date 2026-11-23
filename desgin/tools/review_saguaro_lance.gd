extends SceneTree

# Run the first-wave --saguaro-lance-preview at --fixed-fps 30 on the graphical renderer.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output:=OS.get_environment("LANCE_FRAMES")
	if not output.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output)!=OK:
		push_error("Set LANCE_FRAMES to an absolute output directory")
		quit(1)
		return
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 120:
		if game.player.lance.running:break
		await physics_frame
	if not game.player.lance.running:
		push_error("Start the charged preview with -- --saguaro-lance-preview")
		game.quit_application(1)
		return
	for frame in 127:
		if frame==48:
			game.player.test_mode=true
			game.player.test_aim=game.player.position+game.player.lance.cast_heading*8+Vector3.UP
		if frame>62 and frame<89:
			game.player.test_aim+=Vector3.LEFT*.085
		await RenderingServer.frame_post_draw
		if frame in [0,9,16,23,29,32,36,43,58,78,99,115]:
			root.get_texture().get_image().save_jpg(output.path_join("%03d.jpg"%frame),.96)
	print("LANCE_PREVIEW kills=",game.kills," recovered=",not game.player.lance.running)
	game.quit_application()
