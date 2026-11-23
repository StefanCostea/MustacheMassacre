extends Node

var game: GameDirector
var checks := 0
var failures := 0

func setup(director: GameDirector) -> void:
	game = director
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func keypress(key: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = down
		get_viewport().push_input(event,true)

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event,true)

func menu_button(title: String) -> Button:
	for button in game.ui.host.find_children("*","Button",true,false):
		if button.text==title:return button
	return null

func target(pos: Vector3) -> EnemyActor:
	var enemy := game.spawn_enemy("fridge",pos)
	enemy.set_physics_process(false)
	enemy.health = 1000
	enemy.max_health = 1000
	return enemy

func run() -> void:
	var previous_path := Preferences.settings_path
	Preferences.settings_path = "user://loadout-test-%d.cfg"%OS.get_process_id()
	var legacy := ConfigFile.new()
	legacy.set_value("audio","volume",.45)
	legacy.save(Preferences.settings_path)
	Preferences.load_settings()
	var p := game.player
	p.equipped_special = Preferences.special
	check(p.equipped_special=="high_noon" and is_equal_approx(Preferences.volume,.45),"Existing audio settings gain the High Noon default")
	legacy.set_value("loadout","special","unknown")
	legacy.save(Preferences.settings_path)
	Preferences.load_settings()
	check(Preferences.special=="high_noon","Invalid saved special falls back to High Noon")
	await frames(8)
	keypress(KEY_UP)
	await frames(2)
	keypress(KEY_ENTER)
	await frames(4)
	check(game.ui.panel_kind=="loadout" and get_tree().paused,"Customize opens and pauses practice")
	var noon: Button = game.ui.host.find_child("high_noon",true,false)
	var lance: Button = game.ui.host.find_child("saguaro_lance",true,false)
	if not noon or not lance:
		push_error("Missing attack cards")
		game.quit_application(1)
		return
	check(noon.button_pressed and not lance.button_pressed,"Only the current special is equipped")
	click(lance)
	await frames(2)
	check(lance.button_pressed and not noon.button_pressed and p.equipped_special=="saguaro_lance","Click equips Saguaro Lance exclusively")
	var screenshot := OS.get_environment("LANCE_MENU_SHOT")
	if screenshot.is_absolute_path() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(screenshot,.96)
	noon.grab_focus()
	keypress(KEY_ENTER)
	await frames(2)
	check(noon.button_pressed and p.equipped_special=="high_noon" and game.wave==0,"Keyboard can re-equip High Noon without starting a wave")
	click(lance)
	keypress(KEY_ESCAPE)
	await frames(3)
	check(game.ui.panel_kind=="arrival" and not get_tree().paused,"Escape returns to the main menu")
	Preferences.special = ""
	Preferences.load_settings()
	check(Preferences.special=="saguaro_lance" and is_equal_approx(Preferences.volume,.45),"Saved special and audio survive reading settings again")
	click(menu_button("CHARACTERS & LOADOUT"))
	await frames(3)
	lance = game.ui.host.find_child("saguaro_lance",true,false)
	check(lance.button_pressed,"Reopening the menu restores the selected card")
	click(menu_button("BACK TO MAIN MENU"))
	await frames(3)
	click(menu_button("RING THE BELL"))
	check(game.is_fighting() and p.equipped_special=="saguaro_lance","Main menu launches a run with the equipped special")
	game.spawn_cooldown = 120
	p.test_mode = true
	p.position = Vector3(-3,0,2.7)
	p.ammo = 3
	var near_target := target(p.position+Vector3(0,0,3.4))
	var far_target := target(p.position+Vector3(0,0,5.4))
	var wide_target := target(p.position+Vector3(2.7,0,4.5))
	p.test_aim = near_target.aim_center()
	await frames(22)
	p.stache = 99
	keypress(KEY_F)
	check(not p.lance.running and p.stache==99,"F requires full Stache")
	p.stache = 100
	keypress(KEY_F)
	check(p.lance.running and not p.form.running and p.stache==0 and game.noon_shots==0,"F spends one meter and starts only the equipped form")
	await frames(29)
	check(p.lance.growth>0 and p.lance.fusion<1 and p.lance.camera_rig.current,"Both halves grow during the close-up")
	check(near_target.health==1000 and not p.lance.beam.visible,"The windup deals no damage")
	var age := p.lance.age
	game.ui.toggle_pause()
	await frames(12)
	check(is_equal_approx(p.lance.age,age),"Pause freezes the cast")
	game.ui.toggle_pause()
	await frames(41)
	check(p.lance.fusion>.99 and p.lance.halves[0].position.distance_to(p.lance.halves[1].position)<.01,"Both wrist barrels share a bore at ignition")
	check(p.lance.beam.visible and p.lance.beam_length>4 and p.lance.needles.visible_instance_count>5,"Spike stream is visible beyond the first target")
	check(near_target.health<1000 and far_target.health<1000 and wide_target.health==1000,"The beam pierces aligned enemies and misses off-axis enemies")
	var health_after_ignition := far_target.health
	check(not p.try_fire() and not p.dash() and not p.arm_ricochet() and not p.cast_vortex(),"Other hand actions are locked during the channel")
	await frames(34)
	check(far_target.health<health_after_ignition and game.camera.current,"The beam deals repeated damage after gameplay camera returns")
	p.test_aim = wide_target.aim_center()
	await frames(54)
	check(wide_target.health<1000 and p.lance.heading.x>.25,"Mouse aim can sweep the live beam onto another enemy")
	await frames(82)
	check(not p.lance.running and not p.lance.visible and not p.lance.pose.active and game.camera.current,"Recovery restores normal pose and camera")
	for held in p.form.held:check(held.visible,"Held revolver visible after recovery")
	check(p.try_fire() and p.ammo==2,"Revolver ammunition preserved and firing restored")
	p.position = Vector3(0,0,2.4)
	far_target.position = Vector3(0,0,-2.8)
	p.test_aim = far_target.aim_center()
	await frames(6)
	p.stache = 100
	keypress(KEY_F)
	var guarded_health := far_target.health
	await frames(110)
	check(p.lance.running and far_target.health==guarded_health and p.lance.beam_length<3,"Solid trough blocks the stream and shields enemies")
	await frames(125)
	p.position = Vector3(-3,0,2.7)
	game.create_prop("crate",p.position+Vector3(0,0,3.6))
	var crate: BreakableProp = game.actors.get_child(-1)
	far_target.position = p.position+Vector3(0,0,5.7)
	p.test_aim = far_target.aim_center()
	await frames(6)
	guarded_health = far_target.health
	p.stache = 100
	keypress(KEY_F)
	await frames(66)
	check(is_instance_valid(crate) and crate.health<25 and far_target.health==guarded_health,"The first pulse hits destructible cover and shields the enemy")
	await frames(31)
	check(not is_instance_valid(crate) and far_target.health<guarded_health,"Further pulses pierce the opening once the crate breaks")
	p.invulnerable = 0
	p.receive_hit(2000)
	check(not p.lance.running and game.camera.current and not p.lance.pose.active and not p.lance.visible,"Death clears the beam and releases the camera")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.settings_path))
	Preferences.settings_path = previous_path
	print("LOADOUT_TEST checks=",checks," failures=",failures)
	game.quit_application(0 if failures==0 else 1)
