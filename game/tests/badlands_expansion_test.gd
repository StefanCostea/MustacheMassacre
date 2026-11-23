extends "res://tests/combat_tests.gd"

func _menu_button(key: String) -> Button:
	return game.ui.host.find_child(key,true,false) as Button

func run() -> void:
	await frames(5)
	var path := Preferences.settings_path
	Preferences.settings_path="user://garage-test-%d.cfg"%OS.get_process_id()
	var legacy:=ConfigFile.new()
	legacy.set_value("audio","music",.38)
	legacy.set_value("loadout","special","saguaro_lance")
	legacy.save(Preferences.settings_path)
	Preferences.load_settings()
	var p:=game.player
	check(Preferences.special=="saguaro_lance" and Preferences.field_skill=="tumbleweed" and Preferences.wax==0 and Preferences.workshop.is_empty() and is_equal_approx(Preferences.music_volume,.38),"Legacy loadout gains an empty Garage and a default field ability")
	game.ui.show_loadout()
	_menu_button("slap").pressed.emit()
	check(p.field_skill=="slap" and Preferences.field_skill=="slap","Selecting E updates player and saved field skill")
	game.ui.leave_loadout()
	game.ui.show_garage()
	check(_menu_button("aftershock").disabled and not Preferences.buy_upgrade("aftershock"),"A new wallet cannot buy either workshop card")
	game.ui.leave_loadout()
	game.start_run()
	game.set_process(false)
	game.award_wax(24)
	game.state=GameDirector.RunState.ARRIVAL
	game.ui.show_garage()
	await frames(2)
	var purchase:=_menu_button("aftershock")
	check(not purchase.disabled,"Wax enables the workshop purchase")
	purchase.pressed.emit()
	Preferences.load_settings()
	check(Preferences.field_skill=="slap" and Preferences.special=="saguaro_lance" and Preferences.workshop==["aftershock"] and Preferences.wax==0,"Purchasing through Garage persists the card, independent loadout and balance")
	check(not Preferences.buy_upgrade("aftershock"),"A purchased family cannot be bought twice")
	game.ui.leave_loadout()
	await clean()
	var target:=enemy(Vector3(0,0,8))
	target.health=200
	target.max_health=200
	p.ammo=3
	p.upgrades.append("last_word")
	await frames(20)
	var fan:=InputEventMouseButton.new()
	fan.button_index=MOUSE_BUTTON_RIGHT
	fan.pressed=true
	p._unhandled_input(fan)
	fan.pressed=false
	p._unhandled_input(fan)
	check(p.ammo==2 and p.fan_left==2 and not p.try_fire(),"One right-click commits remaining chambers and excludes primary fire")
	p.reload_input()
	check(p.reload_elapsed<0,"Unfinished fan holds off reload")
	await frames(18)
	check(p.ammo==0 and p.fan_left==0 and is_equal_approx(target.health,128) and not p.fan_hammer(),"Three fan bullets include a final critical and grant zero ammunition")
	p.reload_input()
	p.reload_elapsed=.74
	p.reload_input()
	check(p.ammo==6 and p.empowered,"Perfect reload works after a fan")
	await clean()
	var guard:=enemy(Vector3(0,0,8),"skillet")
	guard.visual.rotation.y=PI
	await frames(4)
	p.try_fire()
	check(guard.health==guard.max_health and guard.shield_flash>0,"Skillet blocks a revolver shot fired into its shield")
	guard.visual.rotation.y=0
	p.shoot_cooldown=0
	p.try_fire()
	check(guard.health==guard.max_health-20,"A shot at the skillet's back damages it")
	guard.state="recover"
	guard.visual.rotation.y=PI
	p.shoot_cooldown=0
	p.try_fire()
	check(guard.health==guard.max_health-40,"Frontal shots punish the exposed recovery")
	await clean()
	var fridge:=enemy(Vector3(0,0,8))
	var medic:=enemy(Vector3(2,0,8),"repair")
	var full:=enemy(Vector3(1,0,8))
	fridge.health=35
	medic.grace=0
	medic.cooldown=0
	await frames(4)
	medic._physics_process(.016)
	check(medic.repair_target==fridge and medic.state=="weld" and medic.weld_beam.visible,"Repair appliance targets a wounded fridge with a visible weld")
	medic.receive_hit(20,false,{})
	medic._physics_process(.016)
	check(medic.state=="recover" and fridge.health==35 and not medic.weld_beam.visible,"Shooting the mechanic interrupts healing")
	medic.state="chase"
	medic.cooldown=0
	medic._physics_process(.016)
	medic._physics_process(.86)
	check(fridge.health==59 and full.health==full.max_health,"An uninterrupted weld restores exactly 24 to its target")
	medic.state="chase"
	medic.cooldown=0
	medic._physics_process(.016)
	medic._physics_process(.86)
	check(fridge.health==fridge.max_health and medic.damaged_fridge()==null,"Weld caps health and ignores healthy fridges")
	await clean()
	var carrier:=enemy(Vector3(0,0,7.4))
	var victim:=enemy(Vector3(2.4,0,7.4),"chili")
	p.field_skill="slap"
	p.aim_point=carrier.position
	p.upgrades.append("aftershock")
	check(p.use_field_skill() and not p.use_field_skill(),"Equipped Slapstache fires once per cooldown")
	var slap=game.actors.get_child(-1)
	slap.set_physics_process(false)
	await frames(4)
	slap._physics_process(.35)
	check(slap.struck and carrier.flight_left>0 and carrier.health==carrier.max_health-18,"Slap rises from the aimed point and sends the nearest enemy flying")
	var start:=carrier.position
	for i in 32:
		if carrier.flight_left<=0:break
		carrier.advance_fling(1./60)
	check(victim.health==victim.max_health-34 and carrier.health==carrier.max_health-40 and start.distance_to(carrier.position)>1,"Moving outlaw hits its neighbour, damaging both at contact")
	slap._physics_process(.46)
	check(not slap.struck and not slap.repeat,"Second Helping readies a second ground strike")
	slap._physics_process(.36)
	check(slap.struck,"The second strike lands")
	slap.queue_free()
	await clean()
	carrier=enemy(Vector3(0,0,7.4))
	victim=enemy(Vector3(2.4,0,7.4),"chili")
	p.field_skill="tumbleweed"
	p.upgrades.assign(["magnet","fling"])
	p.aim_point=carrier.position
	p.use_field_skill()
	var vortex:TumbleweedVortex=get_tree().get_nodes_in_group("vortices").back()
	vortex.set_physics_process(false)
	await frames(3)
	vortex._physics_process(1)
	vortex._physics_process(.1)
	check(vortex.captive==carrier and vortex.radius==game.config.magnetic_radius,"Magnetic Freight selects the fridge from a mixed crowd")
	vortex.duration=1.72
	vortex._physics_process(.04)
	check(vortex.tossed and carrier.flight_left>0,"Freight releases the actual captured body")
	for i in 32:
		if carrier.flight_left<=0:break
		carrier.advance_fling(1./60)
	check(victim.health<victim.max_health-33,"Freight causes a physical collision with a second outlaw")
	var expected:=p.stache
	p.upgrades.append("riposte")
	p.near_dodge(p.global_position+Vector3.UP,1.2)
	check(p.stache==expected,"Standing near an attack gives no dodge credit")
	p.dash()
	p.near_dodge(p.global_position+Vector3(4,1,0),1.2)
	check(p.stache==expected,"A distant dash earns no meter")
	p.near_dodge(p.global_position+Vector3.UP,1.2)
	p.near_dodge(p.global_position+Vector3.UP,1.2)
	check(p.stache==expected+8 and p.quickdraw_ready,"A close dodge awards charge and Close Shave once per dash")
	p.form.show_momentum(.85)
	check(p.form.moustache.visible and not p.form.normal_face.visible and p.form.moustache.get_blend_shape_value(p.form.momentum_key)>.70,"Existing facial hair curls visibly as the meter builds")
	p.form.show_momentum(0)
	check(p.form.normal_face.visible and not p.form.moustache.visible,"The ordinary face returns at zero charge")
	await clean()
	p.dash_left=0
	p.position=Vector3(0,0,5)
	p.upgrades.assign(["prickly","bounce","needle_powder","pinball"])
	var a:=enemy(Vector3(0,0,7))
	var b:=enemy(Vector3(2,0,7))
	b.health=24
	p.test_aim=a.position
	await frames(12)
	p.ammo=5
	p.reload_input()
	p.reload_elapsed=.74
	p.reload_input()
	p.arm_ricochet()
	p.try_fire()
	var needles:=get_tree().get_nodes_in_group("projectiles")
	var powder:=0
	var hops:=0
	for needle in needles:
		if needle.explosive:powder+=1
		hops+=needle.bounces
	check(a.health==28 and b.dead and needles.size()==8 and hops==8 and powder==2,"A perfect-reload ricochet kill bursts into eight bouncing needles, including two explosive ones")
	check(is_equal_approx(game.ricochet_retention(),.95),"Pinball retains 95 percent of damage")
	game.multi_count=0
	p.stache=0
	a.receive_hit(500)
	var c:=enemy(Vector3(4,0,8))
	c.receive_hit(500)
	check(p.stache==25,"Two quick kills award both ordinary kill gains and a multikill bonus")
	await clean()
	p.field_skill="slap"
	var openings:={}
	for i in 20:
		game.show_upgrades()
		var offer:=game.options.duplicate()
		offer.sort()
		openings[str(offer)]=true
		check(offer.size()==3 and offer[0]!=offer[1] and offer[1]!=offer[2] and "fling" not in offer and "magnet" not in offer and "needle_powder" not in offer,"Offers are legal and contain three distinct upgrades")
	check(openings.size()>4 and CombatConfig.UPGRADES.size()==12,"First picks vary across a twelve-card catalogue")
	p.field_skill="tumbleweed"
	p.upgrades.assign(["magnet"])
	game.wave=3
	game.show_upgrades()
	check("fling" in game.options and get_tree().paused and game.state==GameDirector.RunState.UPGRADE,"Final reward offers a compatible Freight combo before the sheriff")
	game.choose_upgrade("fling")
	check(game.state==GameDirector.RunState.BOSS and not get_tree().paused and p.upgrades.has("fling"),"Third reward commits before the boss spawns")
	game.kills=24
	game.finish_run(true)
	game.finish_run(true)
	Preferences.load_settings()
	check(Preferences.wax==16,"Sheriff pays twelve wax plus one per six kills exactly once")
	game.automation=Node.new()
	game.add_child(game.automation)
	game.award_wax(24)
	check(Preferences.wax==16,"Self-playing showcases do not mint currency")
	DirAccess.remove_absolute(Preferences.settings_path)
	Preferences.settings_path=path
	Preferences.load_settings()
	print("BADLANDS_EXPANSION_TEST checks=",passed+failed," failures=",failed)
	game.quit_application(1 if failed else 0)
