extends Node

var game: GameDirector
var passed: int = 0
var failed: int = 0
var checks: Array[Dictionary] = []

func setup(director: GameDirector) -> void:
	game=director;process_mode=Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks.append({"check":label,"passed":condition})
	if condition:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)

func frames(count: int = 2) -> void:
	for i in range(count):await get_tree().physics_frame

func clean() -> void:
	get_tree().paused=false;game.set_process(false);game.state=GameDirector.RunState.COMBAT
	game.spawn_queue.clear();game.noon_shots=0;game.slow_left=0;game.hostile_time_scale=1
	for group in ["enemies","projectiles","vortices"]:
		for node in get_tree().get_nodes_in_group(group):node.queue_free()
	game.enemies.clear();game.boss=null
	game.player.test_mode=true;game.player.test_move=Vector2.ZERO;game.player.test_aim=Vector3(0,0,8)
	game.player.position=Vector3(0,0,5);game.player.health=100;game.player.dead=false
	game.player.ammo=6;game.player.shoot_cooldown=0;game.player.reload_elapsed=-1;game.player.rounds_spent=0
	game.player.empowered=false;game.player.stache=0;game.player.frenzy_left=0;game.player.invulnerable=0
	game.player.q_cooldown=0;game.player.e_cooldown=0;game.player.ricochet_armed=false;game.player.dash_cooldown=0
	game.player.upgrades.clear();game.ui.close_panel()
	await frames(3)

func enemy(pos: Vector3, kind: String = "fridge") -> EnemyActor:
	var e:=game.spawn_enemy(kind,pos);e.set_physics_process(false);return e

func check_moving_shot(p: EspinoPlayer) -> void:
	var gun := p.muzzle.get_parent() as Node3D
	var skeleton := p.fire_pose.skeleton
	var hand := skeleton.find_bone("mixamorig_LeftHand")
	var shoulder := skeleton.find_bone("mixamorig_LeftShoulder")
	p.test_move = Vector2(1,0)
	p.test_aim = Vector3(0,0,1000)
	await frames(18)
	check(gun.global_basis.z.normalized().y < -.22,"revolver is lowered during travel")
	var fired := p.try_fire()
	check(fired and gun.global_basis.z.normalized().dot(p.aim_direction) > .999,"moving shot levels the barrel before the hitscan")
	var start := skeleton.get_bone_global_pose(hand).origin - skeleton.get_bone_global_pose(shoulder).origin
	var swing := 0.0
	var recoil := 0.0
	for i in range(15):
		await frames(1)
		var offset := skeleton.get_bone_global_pose(hand).origin - skeleton.get_bone_global_pose(shoulder).origin
		swing = maxf(swing,(skeleton.global_basis * (offset-start)).length())
		recoil = maxf(recoil,gun.global_basis.z.normalized().y)
	check(swing > .025 and recoil > .16,"free hand continues its stride through weapon recoil")
	check(p.try_fire() and gun.global_basis.z.normalized().dot(p.aim_direction) > .999,"second round restarts from level aim")
	await frames(32)
	check(gun.global_basis.z.normalized().y < -.22,"gun returns to the moving carry after firing")

func run() -> void:
	await frames(6)
	game.ui.toggle_pause();game.ui.toggle_pause()
	check(game.ui.panel_kind=="arrival" and not get_tree().paused,"pause/resume preserves the arrival start button")
	check(game.arena.spawn_points.size()==7,"seven arena spawn points")
	var nav:=game.get_world_3d().navigation_map
	var path:=NavigationServer3D.map_get_path(nav,Vector3(-8,0,-4),Vector3(-3,0,1),true)
	check(path.size()>2,"navigation routes around permanent cover")
	var cache_before:=MeshKit.meshes.size()
	for i in range(100):game.effects.tracer(Vector3(0,1,5),Vector3(float(i)*.083,1,8.37))
	check(MeshKit.meshes.size()-cache_before<=1,"arbitrary tracer lengths reuse geometry instead of growing cache")
	await clean()
	var p:=game.player
	if p.fire_pose:
		await check_moving_shot(p)
		await clean()
	check(p.animation_names.size()==12 and p.animation_tree.active,"runtime GLB exposes all clips and active animation tree")
	var origin_socket:=p.visual.find_child("GunOrigin",true,false) as Node3D
	var forward:Vector3=p.get_muzzle()-origin_socket.global_position
	forward.y=0
	check(forward.normalized().dot(p.aim_direction)>.98,"weapon sockets point along the aimed forward axis")
	print("MUZZLE_HEIGHT ",p.get_muzzle().y)
	var e:=enemy(Vector3(0,0,8));await frames()
	check(p.try_fire(),"primary shot accepted")
	check(p.ammo==5 and p.rounds_spent==1,"one primary shot spends one chamber")
	check(e.health==40,"physics ray hits aimed enemy for 20 damage")
	check(not p.try_fire() and p.ammo==5,"fire cadence rejects repeated same-frame shot")
	p.reload_input();p.reload_elapsed=.74;p.reload_input()
	check(p.ammo==6 and p.empowered and p.stache==8,"active reload grants critical cylinder and one meter reward")
	p.reload_input();check(p.stache==8 and p.reload_elapsed<0,"full-cylinder reload cannot farm Stache")
	p.shoot_cooldown=0;p.try_fire();check(e.health==8,"empowered shot deals critical damage")
	p.reload_input();p.reload_elapsed=.30;p.reload_input();p.reload_elapsed=.74;p.reload_input()
	check(not p.empowered and p.reload_elapsed>=0,"missed reload window cannot be retried within cylinder")
	await frames(40);check(p.ammo==6 and not p.empowered,"missed active reload still completes normal reload")
	await clean()
	p.arm_ricochet();check(not p.arm_ricochet() and p.q_cooldown>7,"ricochet cooldown spent once")
	p.try_fire();check(not p.ricochet_armed,"ricochet is consumed on a miss")
	var prior:=p.stache;p.stache=100
	check(not p.high_noon() and p.stache==100,"High Noon with no visible target preserves charge")
	p.stache=prior
	await clean()
	var targets:Array[EnemyActor]=[]
	for pos in [Vector3(0,0,8),Vector3(1.5,0,8),Vector3(2.5,0,6.5),Vector3(1,0,6.5)]:targets.append(enemy(pos))
	await frames();p.arm_ricochet();p.try_fire()
	var damaged:=0
	for target in targets:
		if target.health<target.max_health:damaged+=1
	check(damaged==4,"Q chains to three distinct additional live enemies")
	var ctx:=game.new_context();ctx.budget.events=32
	var before:=targets[0].health;targets[0].receive_hit(5,false,ctx)
	check(targets[0].health==before,"attack event budget rejects event 33")
	await clean()
	p.upgrades.append("prickly");p.empowered=true
	e=enemy(Vector3(0,0,8),"pigeon");await frames();p.try_fire()
	var needles:=get_tree().get_nodes_in_group("projectiles")
	check(needles.size()==8,"critical kill spawns exactly eight needles")
	if needles.size()==8:
		needles[0].context.budget.events=19
		check(needles[7].context.budget.events==19,"needle siblings share attack event budget")
		var victim:=enemy(Vector3(2,0,8),"pigeon");victim.receive_hit(100,true,needles[0].context)
		check(get_tree().get_nodes_in_group("projectiles").size()==8,"secondary needle generation cannot recursively burst")
	await clean()
	p.test_aim=Vector3(1,0,6);await frames();e=enemy(Vector3(2,0,6))
	check(p.cast_vortex() and not p.cast_vortex(),"vortex casts once and respects cooldown")
	await frames(60)
	check(e.health<e.max_health and e.pull_velocity.length()>0,"vortex damages and pulls targets in range")
	await clean()
	e=enemy(Vector3(1,0,8),"boss");game.boss=e;p.stache=100
	await frames();check(p.high_noon(),"High Noon accepts visible target")
	check(p.stache==0 and p.frenzy_left==6 and game.noon_shots==6,"ultimate spends charge and begins six-shot Frenzy")
	p.add_stache(20);check(p.stache==0,"meter cannot refill during Frenzy")
	await frames(65)
	for i in range(6):game._noon_shot()
	await frames(14)
	check(e.health==570 and game.noon_shots==0,"six precision shots recheck and repeat surviving target")
	p.test_move=Vector2.RIGHT;var pos:=p.position;await frames(10)
	check(p.position.distance_to(pos)>.4,"player remains movable during ultimate")
	var cooldown:=p.e_cooldown;var frenzy:=p.frenzy_left
	get_tree().paused=true;await frames(10)
	check(p.e_cooldown==cooldown and p.frenzy_left==frenzy,"pause freezes ability timers")
	get_tree().paused=false
	await clean()
	p.position=Vector3(13.0,0,3);p.test_aim=Vector3(20,0,3);await frames()
	p.dash();check(not p.receive_hit(30),"dash provides damage invulnerability")
	await frames(20);check(p.position.x<13.7,"dash collides with arena boundary")
	await clean()
	p.position=Vector3(-5.5,0,0);p.test_aim=Vector3(-5.5,0,-5)
	e=enemy(Vector3(-5.5,0,-5));await frames();p.try_fire()
	check(e.health==e.max_health,"permanent cover blocks revolver shot")
	await clean()
	game.wave=1;game.spawn_queue.append("chili");game.spawn_cooldown=100;game._process(.02)
	check(game.state==GameDirector.RunState.COMBAT,"living spawn queue prevents premature wave completion")
	game.spawn_queue.clear();game._process(.02)
	check(game.state==GameDirector.RunState.TRANSITION,"exhausted queue and zero living enemies completes wave")
	game.show_upgrades();check(game.options.size()==3 and get_tree().paused,"upgrade selection pauses and offers three cards")
	var offered: String=game.options[0]
	game.choose_upgrade(offered);check(offered in p.upgrades and game.wave==2 and not get_tree().paused,"upgrade commits and resumes next wave")
	game.set_process(false)
	await clean()
	var chaser:=game.spawn_enemy("fridge",Vector3(-9,0,-6));chaser.grace=0
	p.position=Vector3(-9,0,6);var origin:=chaser.position
	await frames(120)
	check(chaser.position.distance_to(origin)>1.5,"enemy navigation drives actual body movement")
	await clean()
	chaser=game.spawn_enemy("fridge",Vector3(0,0,8));chaser.grace=0
	await frames(200)
	check(p.health<100,"fridge windup and charge can damage stationary player")
	await clean()
	chaser=game.spawn_enemy("chili",Vector3(0,0,9));chaser.grace=0
	await frames(240)
	check(p.health<100,"chili burst projectiles can hit stationary player")
	await clean()
	chaser=game.spawn_enemy("pigeon",Vector3(0,0,9));chaser.grace=0
	await frames(240)
	check(p.health<100,"telegraphed pigeon egg damages its marked area")
	await clean()
	e=enemy(Vector3(0,0,8));p.upgrades.append("quickdraw");p.dash();p.dash_left=0
	await frames();p.try_fire();check(e.health==28,"Quick Draw makes first post-dash round critical")
	await clean()
	p.upgrades.append("trigger");p.try_fire()
	check(is_equal_approx(p.shoot_cooldown,.24/1.25),"Hair Trigger modifies actual firing cadence")
	await clean()
	p.upgrades.append("explosive");p.shot_count=4;e=enemy(Vector3(0,0,8));var splash:=enemy(Vector3(1,0,8))
	await frames();p.try_fire()
	check(e.health==12 and splash.health==32,"fifth explosive primary damages impact and nearby enemy")
	await clean()
	p.upgrades.append("magnet");p.test_aim=Vector3(0,0,8);await frames();p.cast_vortex()
	var vortex=get_tree().get_nodes_in_group("vortices")[0]
	check(is_equal_approx(vortex.radius,3.8) and is_equal_approx(vortex.duration,4.5),"Magnetic Tumbleweed changes radius and lifetime")
	await clean()
	var barrel:BreakableProp
	for prop in get_tree().get_nodes_in_group("breakables"):
		if prop.kind=="barrel":barrel=prop;break
	p.position=barrel.position+Vector3(1,0,0);e=enemy(barrel.position+Vector3(0,0,1))
	p.test_aim=barrel.position;await frames();p.try_fire()
	check(barrel.health==15,"aimed revolver ray hits the visible fuel barrel")
	p.shoot_cooldown=0;p.try_fire()
	check(barrel.fuse>0 and p.health==100,"barrel destruction warns before exploding")
	await frames(40)
	check(p.health==40 and e.dead,"barrel explosion damages both factions")
	await clean()
	game.start_boss();e=game.boss;e.set_physics_process(false)
	e.receive_hit(460,false,game.new_context())
	check(e.phase_two and game.spawn_queue.size()==6,"boss phase two queues one bounded escort wave")
	e.receive_hit(10,false,game.new_context());check(game.spawn_queue.size()==6,"boss escort triggers only once")
	e.receive_hit(1000,false,game.new_context())
	check(game.state==GameDirector.RunState.VICTORY,"boss death triggers victory")
	await frames(ceili((e.death_time + .15)*60))
	check(game.ui.panel_kind=="results" and get_tree().paused,"victory displays results and retry")
	get_tree().paused=false
	var result:={"passed":passed,"failed":failed,"checks":checks}
	var file:=FileAccess.open("user://combat_tests.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("COMBAT_TESTS ",JSON.stringify(result))
	print("REPORT ",OS.get_user_data_dir()+"/combat_tests.json")
	get_tree().quit(0 if failed==0 else 1)
