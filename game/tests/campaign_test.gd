extends "res://tests/combat_tests.gd"

func run() -> void:
	await frames(5)
	var rosters:=[["fridge","chili","fridge","skillet","chili","fridge"],["fridge","chili","repair","fridge","pigeon","skillet","chili","fridge"],["fridge","skillet","pigeon","chili","repair","fridge","pigeon","chili","skillet"]]
	for index in rosters.size():
		var wave:WaveSpec=load("res://resources/encounters/wave_%d.tres"%(index+1))
		check(wave.pattern==PackedStringArray(rosters[index]),"Wave %d loads its complete authored roster"%(index+1))
	var p:=game.player
	var settings:=Preferences.settings_path
	Preferences.settings_path="user://campaign-check-%d.cfg"%OS.get_process_id()
	Preferences.load_settings()
	game.ui.show_loadout()
	var pilot:Button=game.ui.host.find_child("pilot_coo",true,false)
	pilot.pressed.emit()
	await frames(2)
	Preferences.load_settings()
	check(p.is_coo and p.coo.is_visible_in_tree() and not p.visual.get_child(0).visible and Preferences.hero_id=="coo","Crew selector equips the independent pigeon model and persists the choice")
	game.ui.leave_loadout()
	await clean()
	var coo=p.coo
	var target:=enemy(Vector3(0,0,8))
	target.health=500
	p.test_aim=target.position
	await frames(4)
	var start_count:=p.shot_count
	var first_cadence:=0.0
	var fast_cadence:=1.0
	for i in 270:
		if p.try_fire():
			if first_cadence==0:first_cadence=p.shoot_cooldown
			fast_cadence=minf(fast_cadence,p.shoot_cooldown)
		if coo.vent_left>0:break
		await frames(1)
	check(p.shot_count-start_count>=18 and fast_cadence<first_cadence*.65 and target.health<450,"Sustained rotary fire accelerates and damages a target from its muzzle")
	check(coo.vent_left>0 and not p.try_fire(),"Reaching full heat locks the rotary gun")
	while coo.vent_left>.63:await frames(1)
	p.reload_input()
	check(coo.heat==0 and coo.timed_vent and coo.vent_left==0,"Timed vent cools the weapon and primes a critical round")
	p.dash()
	await frames(10)
	check(p.position.y>.25 and p.invulnerable>0,"Coo's short hop actually leaves the ground")
	await frames(45)
	check(p.position.y<.08,"Coo lands on the arena floor")
	p.position=Vector3(0,0,5)
	p.test_aim=target.position
	await frames(5)
	var health:=target.health
	check(p.use_field_skill() and not p.use_field_skill(),"Egg Drop casts once per field cooldown")
	await frames(60)
	check(target.health<health and p.health==100,"Friendly egg hits enemies without damaging its pilot")
	p.stache=100
	check(p.use_special() and not p.use_special() and coo.flock.size()==3 and p.stache==0,"Full Stache summons exactly three wingmen")
	await frames(44)
	check(coo.whiskers.spread>.8 and coo.pods[0].visible and coo.next_drop>=1,"Whisker barrels grow from the rig while the squadron drops eggs")
	await frames(160)
	check(coo.next_drop==6 and coo.flock.is_empty() and not coo.pods[0].visible,"Six designated eggs and their carriers finish cleanly")
	p.equip_hero("espino")
	await clean()
	p.position=Vector3(1,0,5)
	game.start_wave(3)
	var formation:=game.bottleneck
	check(formation.size()==5 and formation[0].kind=="skillet" and formation[1].kind=="repair" and formation[2].health<formation[2].max_health and game.spawn_queue.size()+5==game.encounter.count,"Third wave opens with a shield, welder and wounded fridge from its own spawn budget")
	for outlaw in formation:outlaw.set_physics_process(false)
	var mechanic:=formation[1]
	var fridge:=formation[2]
	mechanic.grace=0
	mechanic.cooldown=0
	mechanic._physics_process(.02)
	check(mechanic.state=="weld" and mechanic.repair_target==fridge,"The arranged crew establishes a real repair link")
	p.position=mechanic.position+Vector3.RIGHT*2.3
	p.test_aim=mechanic.position
	p.upgrades.assign(["prickly","bounce"])
	p.ammo=4
	p.reload_input()
	p.reload_elapsed=.74
	p.reload_input()
	p.arm_ricochet()
	await frames(6)
	p.try_fire()
	await frames(18)
	check(mechanic.dead and game.highest_chain>=3,"Flanking the weld with a perfect-reload ricochet produces at least three linked kills")
	check(game.best_play.contains("RICOCHET") and game.best_play.contains("PERFECT RELOAD"),"The results attribute the chain to the player's actual build")
	print("PRECISION_PAYOFF kills=",game.highest_chain," cause=",game.best_play)
	await clean()
	game.start_wave(3)
	game.highest_chain=0
	var collisions:Array=[]
	game.outlaw_impact.connect(func(carrier,victim):collisions.append([carrier.kind,victim.kind]))
	var lane_fridge:EnemyActor=game.bottleneck[2]
	p.position=lane_fridge.position+Vector3.RIGHT*4.1
	p.test_aim=lane_fridge.position
	p.field_skill="tumbleweed"
	p.equipped_special="saguaro_lance"
	p.upgrades.assign(["magnet","fling"])
	await frames(8)
	p.use_field_skill()
	var vortex:TumbleweedVortex=get_tree().get_nodes_in_group("vortices").back()
	while is_instance_valid(vortex) and vortex.duration>2.58:await frames(1)
	p.stache=100
	var alive:=game.live_count()
	check(p.use_special(),"Saguaro Lance charges while the Freight vortex gathers the repair crew")
	var tossed:=false
	for i in 215:
		if is_instance_valid(vortex) and vortex.tossed:tossed=true
		for outlaw in game.bottleneck:
			if is_instance_valid(outlaw) and not outlaw.dead:
				p.test_aim=outlaw.aim_center()
		await frames(1)
	check(tossed,"The crowd-control build physically throws an outlaw in the real bottleneck")
	check(not collisions.is_empty() and collisions[0][0]=="fridge","The thrown fridge contacts a second outlaw in the formation")
	check(game.live_count()<alive and game.highest_chain>=3 and game.best_play.contains("FREIGHT") and game.best_play.contains("OUTLAW COLLISION"),"The Freight collision and its follow-ups earn a multikill in the live formation")
	print("FREIGHT_PAYOFF kills=",game.highest_chain," cause=",game.best_play," beam_kills=",p.lance.direct_kills," contacts=",collisions)
	while p.lance.running:await frames(1)
	await clean()
	p.position=Vector3(0,0,4)
	var guard:=enemy(Vector3(0,0,8))
	guard.health=40
	p.test_aim=guard.aim_center()
	p.field_skill="tumbleweed"
	p.equipped_special="saguaro_lance"
	await frames(6)
	p.use_field_skill()
	var waited:=0
	while guard.pull_chain.is_empty() and waited<120:
		await frames(1)
		waited+=1
	p.stache=100
	p.use_special()
	await frames(180)
	check(p.lance.direct_kills==1 and "tumbleweed" in p.lance.cast_chain.steps and "saguaro_lance" in p.lance.cast_chain.steps,"Saguaro Lance finishes a pulled survivor and records both abilities in one chain")
	await clean()
	game.start_boss()
	var boss:=game.boss
	boss.set_physics_process(false)
	p.position=Vector3(0,0,5)
	boss.receive_hit(boss.max_health*.51,false,game.new_context())
	var ice=game.freezer_lane
	ice.set_physics_process(false)
	check(boss.state=="vent" and ice.marks.visible and not ice.sheet.visible,"Half health interrupts the sheriff and clearly warns the selected lane")
	var hp:=p.health
	ice._physics_process(.9)
	check(p.health==hp and not ice.fired,"The striped warning gives time to reposition")
	p.position.z=2
	ice._physics_process(.60)
	check(ice.sheet.visible and boss.hatch.rotation.y< -1.8 and p.health==hp,"The freezer door bursts open and players outside the marked lane escape")
	p.position.z=5
	ice._physics_process(.01)
	check(p.health==hp-15,"The live sheet damages a grounded player in its stripe")
	ice._physics_process(2.5)
	var before:=boss.health
	boss.receive_hit(20)
	check(boss.state=="vent_open" and boss.health==before-30,"The cooling boss is vulnerable to a timed punish")
	ice._physics_process(2.2)
	check(boss.state=="recover" and boss.hatch.rotation.y==0,"Door and attack state recover after the opening")
	p.upgrades.assign(["bounce"])
	game.kills=24
	game.finish_run(true)
	await frames(68)
	game.ui.show_routes()
	check(game.ui.panel_kind=="routes","Victory opens an actual branch choice")
	game.route.enter("unknown")
	check(game.route.stage==0,"An invalid route cannot start a continuation")
	var branch:="freight" if "--route-freight" in OS.get_cmdline_user_args() else "fry_line"
	game.route.enter(branch)
	check(game.route.stage==1 and game.wave==5 and p.upgrades==["bounce"] and game.arena.get_script().resource_path.ends_with("grease_city.gd"),"Route builds the second location and carries the chosen character and upgrades")
	await frames(5)
	var nav:=game.get_world_3d().navigation_map
	check(NavigationServer3D.map_get_path(nav,Vector3(-10,0,6),Vector3(10,0,-6),true).size()>2,"Grease City navigation routes around its new counter layout")
	var wallet:=Preferences.wax
	if branch=="freight":
		game.route.cleared()
		check(Preferences.wax==wallet+12 and game.route.stage==2 and not game.route.reward_due,"Safe freight pays its bounty before the exit fight")
	else:
		check(is_instance_valid(game.route.elite) and game.route.elite.is_elite and game.route.elite.max_health==190,"Fry line contains the armored elite")
		game.route.oil_cooldown=0
		game.route._physics_process(.03)
		check(game.route.oil_warning>0,"Elite gives an aimed hot-grease warning")
		game.route.cleared()
		check(game.route.reward_due and game.state==GameDirector.RunState.UPGRADE,"Elite completion offers an extra draft")
		game.choose_upgrade(game.options[0])
		check(game.route.stage==2 and p.upgrades.size()==2 and game.spawn_queue.size()>0,"The bonus upgrade is usable in an exit encounter")
	game.kills=36
	game.finish_run(true)
	check(Preferences.wax==wallet+(12 if branch=="freight" else 0)+2,"The city pays only newly earned kill wax and does not repeat the sheriff bounty")
	await test_feedback()
	DirAccess.remove_absolute(Preferences.settings_path)
	Preferences.settings_path=settings
	Preferences.load_settings()
	print("CAMPAIGN_TEST checks=",passed+failed," failures=",failed," branch=",branch)
	game.quit_application(1 if failed else 0)

func test_feedback() -> void:
	var survey=preload("res://scripts/paired_playtest.gd").new()
	survey.folder="user://campaign-survey-%d"%OS.get_process_id()
	survey.open_session()
	game.player.equip_hero("espino")
	survey.begin(game.player)
	survey.picked("bounce",["bounce","prickly","magnet"])
	survey.finish(game,true)
	check(not survey.answer("","try Coo"),"Survey requires a player-supplied observation")
	check(survey.answer("the bouncing rounds","try Coo"),"First report accepts the player's own explanation and second-run intention")
	var continued=preload("res://scripts/paired_playtest.gd").new()
	continued.folder=survey.folder
	continued.open_session()
	game.player.equip_hero("coo")
	continued.begin(game.player)
	continued.picked("explosive",["explosive","pinball","riposte"])
	continued.finish(game,false)
	check(continued.answer("the fifth round","yes"),"A second run can finish after a process restart")
	var saved=JSON.parse_string(FileAccess.get_file_as_string(survey.folder.path_join(str(continued.data.id)+".json")))
	check(saved.runs.size()==2 and saved.runs[0].next_intent=="try Coo" and saved.runs[1].hero=="coo" and saved.runs[1].picks[0].selected=="explosive","The paired record independently preserves intended build and actual second-run picks")
