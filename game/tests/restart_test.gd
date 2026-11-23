extends Node

var game: GameDirector

func setup(director: GameDirector) -> void:
	game=director;process_mode=Node.PROCESS_MODE_ALWAYS;run.call_deferred()

func run() -> void:
	await get_tree().physics_frame
	var index:int=Preferences.get_meta("restart_test",0)
	var p:=game.player
	var okay:=p.health==100 and p.ammo==6 and p.upgrades.is_empty() and p.q_cooldown==0 and p.e_cooldown==0 and p.frenzy_left==0 and game.noon_shots==0 and game.hostile_time_scale==1 and not get_tree().paused
	okay=okay and get_tree().get_nodes_in_group("projectiles").is_empty() and get_tree().get_nodes_in_group("vortices").is_empty() and game.live_count()==0 and get_tree().get_nodes_in_group("breakables").size()==10
	print("RESTART ",index," clean=",okay," nodes=",get_tree().get_node_count())
	if not okay:get_tree().quit(1);return
	if index==3:
		print("RESTART_TEST 3 repeated death/results/retry cycles passed")
		get_tree().quit();return
	game.start_run();p.test_mode=true;p.upgrades=["bounce","prickly"];p.ammo=1;p.arm_ricochet();p.cast_vortex()
	game.spawn_enemy("fridge",Vector3(0,0,8));game.spawn_projectile(Vector3(0,1,4),Vector3(1,0,0),12,"enemy")
	p.stache=100;p.high_noon();p.invulnerable=0;p.receive_hit(1000)
	if p.q_cooldown!=0 or p.e_cooldown!=0 or p.dash_cooldown!=0 or p.reload_elapsed>=0 or p.frenzy_left!=0 or p.empowered or p.quickdraw_ready:
		push_error("Temporary combat state survived death");get_tree().quit(1);return
	await get_tree().create_timer(1.2,true).timeout
	if game.ui.panel_kind!="results" or game.state!=GameDirector.RunState.DEAD:get_tree().quit(1);return
	Preferences.set_meta("restart_test",index+1);game.restart()
