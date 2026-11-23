extends SceneTree

var output:=OS.get_environment("GREASE_FRAMES")
var game
var cam:=Camera3D.new()

func _initialize() -> void:
	run.call_deferred()

func frame(n:int) -> void:
	RenderingServer.render_loop_enabled=false
	for i in n:await physics_frame
	RenderingServer.render_loop_enabled=true

func snap(label:String) -> void:
	for i in 3:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output.path_join(label+".jpg"),.94)

func view(pos:Vector3,at:Vector3,size:float) -> void:
	cam.current=true
	cam.position=pos
	cam.look_at(at)
	cam.size=size

func run() -> void:
	if not output.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output)!=OK:quit(1);return
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.add_child(cam)
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.player.test_mode=true
	game.player.equip_hero("coo")
	game.ui.show_loadout()
	await snap("crew")
	game.ui.leave_loadout()
	game.start_run()
	game.set_process(false)
	game.ui.hide()
	var hero=game.player
	hero.position=Vector3(-3,0,4)
	hero.test_aim=hero.position+Vector3.BACK*6
	await frame(10)
	var at:Vector3=hero.position+Vector3.UP*.82
	view(at+Vector3(1.5,.52,4.7),at,2.45)
	await snap("coo_carry")
	view(at+Vector3(-2.8,.65,-4),at,2.5)
	await snap("coo_back")
	view(at+Vector3(1.5,.52,4.7),at,2.45)
	hero.try_fire()
	await snap("coo_fire")
	hero.stache=100
	hero.use_special()
	await frame(45)
	await snap("coo_frenzy")
	var general:Vector3=hero.position+Vector3.UP
	view(general+Vector3(7,7,12),general+Vector3.BACK*3+Vector3.UP,10)
	await snap("squadron")
	hero.coo.clear_flock()
	hero.dash()
	await frame(11)
	at=hero.position+Vector3.UP*.6
	view(at+Vector3(3,.8,5),at,3.4)
	await snap("coo_hop")
	await frame(40)
	hero.coo.heat=.7
	hero.reload_input()
	await frame(20)
	at=hero.position+Vector3.UP
	view(at+Vector3(2,.55,4),at,2.7)
	await snap("coo_vent")
	hero.equip_hero("espino")
	game.start_wave(3)
	var crew=game.bottleneck[0]
	at=crew.position+Vector3(0,.8,1.5)
	view(at+Vector3(5,4,-6),at,6.5)
	await frame(25)
	await snap("bottleneck")
	for e in game.enemies:
		if is_instance_valid(e):e.queue_free()
	game.enemies.clear()
	await frame(2)
	game.start_boss()
	var sheriff=game.boss
	sheriff.position=Vector3(-3,0,6)
	hero.position=Vector3(-3,0,3)
	sheriff.visual.rotation.y=0
	sheriff.receive_hit(sheriff.max_health*.5)
	at=sheriff.position+Vector3.UP*1.1
	view(at+Vector3(5,5,9),at,8)
	await frame(12)
	await snap("freezer_warning")
	await frame(82)
	await snap("freezer_live")
	view(at+Vector3(.7,.2,4),at,2.65)
	await snap("freezer_door")
	game.state=game.RunState.VICTORY
	game.ui.show()
	game.ui.show_routes()
	await snap("route_choice")
	game.route.enter("fry_line")
	game.ui.hide()
	at=Vector3(-2,1,-8.7)
	view(at+Vector3(10,9,14),at,13)
	await snap("grease_city")
	game.camera.make_current()
	game.set_process(true)
	game.ui.show()
	await frame(45)
	await snap("fry_line")
	game.ui.hide()
	hero.equip_hero("coo")
	at=hero.position+Vector3.UP*.45
	view(at+Vector3(3,1,3.7),at,2.6)
	hero.invulnerable=0
	hero.receive_hit(1000)
	await frame(78)
	await snap("coo_death")
	game.quit_application()
