extends Node

# Staged art review with real gameplay abilities. This is not a balance run.
var game: GameDirector

func setup(director: GameDirector) -> void:
	game=director;process_mode=Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func run() -> void:
	game.start_run();game.spawn_queue.clear();game.spawn_queue.append("fridge");game.spawn_cooldown=999
	game.player.position=Vector3(0,0,2.5);game.player.test_mode=true
	game.player.test_aim=Vector3(0,0,8);game.player.invulnerable=500
	for data in [["fridge",Vector3(-3,0,5.5)],["chili",Vector3(3,0,5.5)],["pigeon",Vector3(0,0,7.5)]]:
		var enemy:=game.spawn_enemy(data[0],data[1]);enemy.health=500;enemy.max_health=500
	await get_tree().create_timer(2.0).timeout
	await capture("10_arena_combat")
	game.player.arm_ricochet();game.player.try_fire();game.player.cast_vortex()
	await get_tree().create_timer(.15).timeout
	await capture("11_arena_tumbleweed")
	game.player.stache=100;game.player.high_noon()
	await get_tree().create_timer(.4).timeout
	await capture("12_arena_high_noon")
	print("NATURAL_VISUAL_CHECK captured combat, Tumbleweed and High Noon; invulnerability/charge/enemy health staged for art review")
	game.quit_application()

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("LASTCALL_CAPTURE_DIR")
	if folder.is_empty():folder=ProjectSettings.globalize_path("res://../desgin/renders/don_espino/natural_workflow")
	DirAccess.make_dir_recursive_absolute(folder)
	get_viewport().get_texture().get_image().save_png(folder+"/"+name+".png")
