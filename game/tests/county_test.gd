extends Node

const Layout=preload("res://scripts/county_layout.gd")
var game:GameDirector
var county
var checks:=0
var failures:=0
var captures:=OS.get_environment("COUNTY_CAPTURES")

func setup(director:GameDirector) -> void:
	game=director
	process_mode=Node.PROCESS_MODE_ALWAYS
	review.call_deferred()

func check(ok:bool,what:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(what)

func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame

func pose_at(at:Vector3) -> void:
	game.player.position=at
	game.camera.position=at+Vector3(12,19,18)
	game.player.invulnerable=20.
	await frames(5)

func walk_to(destination:Vector3) -> bool:
	var map:=game.get_world_3d().navigation_map
	var path:=NavigationServer3D.map_get_path(map,game.player.position,destination,true)
	if path.is_empty() or path[-1].distance_to(destination)>1.2:return false
	var right:=game.camera.global_basis.x
	var back:=Vector3(game.camera.global_basis.z.x,0,game.camera.global_basis.z.z).normalized()
	game.player.invulnerable=120.
	for waypoint in path:
		var remaining:=600
		while remaining>0:
			var delta:=waypoint-game.player.position
			delta.y=0.
			if delta.length()<.33:break
			var heading:=delta.normalized()
			game.player.test_move=Vector2(heading.dot(right),heading.dot(back))
			remaining-=1
			await frames(1)
		if remaining==0:
			print("COUNTY_PATH_BLOCKED ",game.player.position," heading for ",waypoint)
			game.player.test_move=Vector2.ZERO
			return false
	game.player.test_move=Vector2.ZERO
	return true

func photo(label:String) -> void:
	if not captures.is_absolute_path() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(captures)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(captures.path_join(label+".jpg"),.90)

func trigger(action:String) -> void:
	var key:=InputEventAction.new()
	key.action=action
	key.pressed=true
	game.get_viewport().push_input(key,true)
	key.pressed=false
	game.get_viewport().push_input(key,true)

func clear_group() -> void:
	for enemy in county.group.duplicate():
		if is_instance_valid(enemy) and not enemy.dead:enemy.receive_hit(900,false,game.new_context("revolver"))

func upgrade_if_due() -> void:
	if game.state==GameDirector.RunState.UPGRADE:
		check(game.options.size()==3,"Regional work offers three choices")
		game.choose_upgrade(game.options[0])

func review() -> void:
	Preferences.settings_path="user://county-test-%d.cfg"%OS.get_process_id()
	Preferences.load_settings()
	game.player.equip_hero("espino")
	var button:Button=game.get_viewport().gui_get_focus_owner()
	check(button!=null and button.text=="EXPLORE THE COUNTY","Title screen focuses the county")
	button.pressed.emit()
	county=game.county
	check(county!=null and game.player.position.is_equal_approx(Layout.HUB),"Menu starts at Grooming Garage")
	if not county:game.quit_application(1);return
	game.player.test_mode=true
	var original:int=game.player.get_instance_id()
	await pose_at(Vector3(0,0,4.4))
	trigger("county_interact")
	check(game.ui.panel_kind=="garage" and get_tree().paused,"Walk-up garage opens the live workshop")
	game.ui.leave_loadout()
	check(game.ui.panel_kind=="" and game.is_fighting(),"Closing the workshop resumes the same county run")
	await pose_at(Layout.HUB)
	await frames(6)
	trigger("county_map")
	await frames(2)
	check(county.map_open and get_tree().paused,"Map opens with combat paused")
	var screen:=get_viewport().get_visible_rect().size
	var marker:=InputEventMouseButton.new()
	marker.button_index=MOUSE_BUTTON_LEFT
	marker.position=county.map_point(Layout.POSTS.wheel[0],county.map_rect(screen))
	marker.pressed=true
	get_viewport().push_input(marker,true)
	marker.pressed=false
	get_viewport().push_input(marker,true)
	check(county.tracked=="wheel","Clicking a map ring tracks that job")
	await photo("county-map")
	trigger("county_map")
	await frames(2)
	check(not county.map_open and not get_tree().paused,"Map closes and movement resumes")
	check(not game.arena.point_clear(Vector3(12,0,-10)) and game.arena.point_clear(Vector3(28,0,-10)),"Locked freight bridge has an open eastern ford")
	check(not game.arena.point_clear(Vector3(-6,0,-10)) and game.arena.point_clear(Vector3(-31,0,-10)),"Locked service crossing has an open western ford")
	# Walk from the garage into town under the normal camera-relative movement.
	var right:=game.camera.global_basis.x
	var back:=Vector3(game.camera.global_basis.z.x,0,game.camera.global_basis.z.z).normalized()
	game.player.test_move=Vector2(Vector3.RIGHT.dot(right),Vector3.RIGHT.dot(back))
	game.player.stache=68.
	await frames(185)
	game.player.test_move=Vector2.ZERO
	check(county.region=="grease" and game.player.position.x>12.,"Walk from the garage to Grease City")
	check(game.player.stache>=67. and game.camera.position.x>24.,"Road preserves Stache and camera follows beyond old bounds")
	var ray_target:=game.field_target(game.player.position+Vector3.RIGHT*3)
	check(ray_target.x>13.,"Field skill aims beyond legacy street bounds")
	if DisplayServer.get_name()=="headless":
		for destination in ["palace","funland","badlands","garage","grease"]:
			var reached:bool=await walk_to(Layout.PLACES[destination][0])
			check(reached and county.region==destination,"Walk the connected county to "+destination+" with both shortcuts locked")
	await pose_at(Layout.POSTS.kitchen[0])
	trigger("county_interact")
	await frames(3)
	check(county.active=="kitchen" and county.leader.variant=="cook","G at the diner starts the Fry Line")
	await photo("grease")
	var damage_test=county.group[1]
	damage_test.position=game.arena.vents[0].position+Vector3.BACK*.2
	var before:float=damage_test.health
	game.arena.switches.steam.receive_hit(10)
	check(damage_test.health<before,"Steam damages an enemy standing on a grate")
	await pose_at(Layout.HUB)
	check(county.active=="","Leaving the district releases the job")
	await pose_at(Layout.POSTS.kitchen[0]);county.interact()
	clear_group();await frames(3);upgrade_if_due()
	check(county.completed.has("kitchen"),"Returning to the diner can complete it")

	await pose_at(Layout.POSTS.wheel[0]);county.interact()
	check(county.active=="wheel" and county.leader.variant=="dodgem","Funland casts bumper cars and puppets")
	await photo("funland")
	game.arena.switches.breaker.receive_hit(5)
	check(not county.completed.has("wheel"),"Guarded breaker cannot skip the ride encounter")
	var car=county.group[0]
	var puppet=county.group[1]
	puppet.position=car.position+Vector3.BACK*.72
	car.state="charge";car.timer=.8;car.direction=Vector3.BACK;car.grace=0.
	var hp:float=puppet.health
	await frames(2)
	check(puppet.health<hp,"A charging bumper car hits a ticket puppet")
	clear_group()
	await frames(30)
	game.arena.switches.breaker.receive_hit(3)
	await frames(2);upgrade_if_due()
	check(county.tracked=="","Finishing the selected job clears its waypoint")
	check(game.arena.powered and game.arena.point_clear(Vector3(-6,0,-10)),"Breaker restarts the wheel and opens its crossing")

	await pose_at(Layout.POSTS.tower[0]);county.interact()
	await photo("badlands")
	var latch:Vector3=Layout.SWITCHES.latch[0]
	await pose_at(latch+Vector3(0,0,2.7))
	game.player.aim_from_screen(game.camera.unproject_position(latch+Vector3.UP))
	game.player.try_fire()
	check(not game.arena.gate.visible,"Revolver round opens the tower gate")
	clear_group();await frames(3);upgrade_if_due()
	await pose_at(Layout.POSTS.sheriff[0]);county.interact()
	county.leader.receive_hit(county.leader.max_health*.55)
	check(is_instance_valid(game.freezer_lane) and game.freezer_lane.position.x < -15.,"Sheriff’s freeze lane originates at the western crossing")
	clear_group();await frames(3)
	check(game.is_fighting() and county.completed.has("sheriff"),"Defeating the optional sheriff preserves free travel")

	await pose_at(Layout.POSTS.throne[0]);county.interact()
	var royal=county.leader
	royal.receive_hit(royal.max_health*.31)
	county.tick_palace(3.)
	check(county.last_stage==1,"Damaging the royal cistern telegraphs a flood")
	await photo("palace")
	county.tick_palace(1.6)
	check(game.arena.water.visible,"Flood covers the throne chamber")
	hp=royal.health
	game.arena.switches.valve.receive_hit(6)
	check(not game.arena.water.visible and royal.health<hp,"Flush valve redirects the flood back into the boss")
	clear_group();await frames(3)
	check(county.completed.has("throne"),"Palace bounty resolves")

	await pose_at(Layout.POSTS.freight[0]);county.interact()
	clear_group()
	for i in 600:
		game.player.position=game.arena.truck.position+Vector3.BACK
		county.tick_freight(.033)
		if county.escort_ambush:clear_group()
		if county.active=="":break
	check(county.completed.has("freight") and game.arena.truck.position.x<3. and county.escort_ambush,"Wax freight travels to the garage after its ambush")
	check(game.arena.point_clear(Vector3(12,0,-10)),"Freight reward opens its bridge")
	Preferences.load_settings()
	check("freight" in Preferences.county_shortcuts and "wheel" in Preferences.county_shortcuts,"Two road unlocks survive reloading settings")
	check(county.completed.size()==6 and original==game.player.get_instance_id() and game.player.upgrades.size()==3,"Six jobs share one hero and three run upgrades")
	var wax:=Preferences.wax
	county.begin("freight")
	check(county.active=="" and Preferences.wax==wax,"Completed job cannot pay twice")
	await pose_at(Layout.HUB)
	county.interact()
	check(game.state==GameDirector.RunState.VICTORY,"Garage cash-out concludes the run")
	DirAccess.remove_absolute(Preferences.settings_path)
	print("COUNTY_TEST checks=%d failures=%d"%[checks,failures])
	game.quit_application(1 if failures else 0)
