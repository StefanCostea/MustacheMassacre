extends SceneTree
# Capture the gameplay camera at the landmark and under local encounter lighting.
var game
var output:=OS.get_environment("COUNTY_FRAMES")

func _initialize() -> void:
	run.call_deferred()

func step(count:int) -> void:
	RenderingServer.render_loop_enabled=false
	for i in count:await physics_frame
	RenderingServer.render_loop_enabled=true

func capture(id:String) -> void:
	for i in 3:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output.path_join(id+".jpg"),.94)

func run() -> void:
	if not output.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output)!=OK:quit(1);return
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_county()
	game.player.test_mode=true
	game.player.equip_hero("espino")
	await step(200)
	await capture("garage")
	for entry:Array in [["tower",Vector3(-28,0,.2)],["kitchen",Vector3(27,0,-.4)],["wheel",Vector3(-23,0,-30.2)],["throne",Vector3(22,0,-32.1)]]:
		if game.county.active!="":game.county.abandon()
		var id:String=entry[0]
		game.player.position=game.county.Layout.POSTS[id][0]+Vector3.RIGHT
		game.player.invulnerable=20.
		await step(5)
		game.county.interact()
		game.player.position=entry[1]
		game.player.test_aim=game.county.leader.aim_center()
		game.camera.position=game.player.position+Vector3(12,19,18)
		await step(185)
		if id=="throne":
			game.county.leader.receive_hit(130)
			await step(272)
		await capture(game.county.Layout.POSTS[id][3])
	game.county.map_open=true
	await capture("map")
	game.quit_application()
