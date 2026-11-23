extends Node

# Integration player uses the same movement, weapon, cooldown and upgrade entry
# points as a human. It never edits health, damage, enemy counts or run outcomes.
var game: GameDirector
var navigation: NavigationAgent3D
var elapsed: float = 0
var route: Array[Vector3] = [Vector3(10,0,7),Vector3(10,0,-7),Vector3(-10,0,-7),Vector3(-10,0,7)]
var corner: int = 0
var path_timer: float = 0
var finished: bool = false
var actions: Dictionary = {"shots":0,"fans":0,"slaps":0,"perfect_reloads":0,"ricochets":0,"vortices":0,"ultimates":0,"dashes":0,"upgrades":[]}
var samples: Array[float] = []
var frame_report: Array[Dictionary] = []
var stage: int = -1
var choosing: bool = false
var captured_special: bool = false
var record_run := true
var city_path := ""

func setup(director: GameDirector) -> void:
	game=director
	for branch in ["freight","fry_line"]:
		if "--route-"+branch.replace("_","-") in OS.get_cmdline_user_args():city_path=branch
	process_mode=Node.PROCESS_MODE_ALWAYS
	game.rng.seed=3711;seed(3711)
	game.player.test_mode=true
	navigation=NavigationAgent3D.new();navigation.path_desired_distance=.5;navigation.target_desired_distance=.6
	game.player.add_child(navigation)

func _process(delta: float) -> void:
	if finished:return
	if not get_tree().paused:samples.append(delta*1000)
	if game.wave!=stage:
		stage=game.wave;print("AUTOPLAY stage=",stage," time=",game.run_time," health=",game.player.health," kills=",game.kills)
		if record_run and DisplayServer.get_name()!="headless":capture("stage_%d"%stage,.8)
	if game.state==GameDirector.RunState.UPGRADE and not choosing:
		choose()
	elif game.state in [GameDirector.RunState.DEAD,GameDirector.RunState.VICTORY] and game.ui.panel_kind=="results":
		if game.state==GameDirector.RunState.VICTORY and city_path!="" and game.route.stage==0:
			game.ui.show_routes()
			game.route.enter(city_path)
			path_timer=0
		else:finish()

func _physics_process(delta: float) -> void:
	if finished or get_tree().paused:return
	elapsed+=delta
	if elapsed>(1040 if city_path!="" else 720):finish();return
	if game.state==GameDirector.RunState.ARRIVAL:
		if elapsed>1:game.start_run()
		return
	if not game.is_fighting():return
	var p:=game.player
	var candidates:Array[EnemyActor]=[]
	for e in game.enemies:
		if is_instance_valid(e) and not e.dead and not e.dummy and game.line_of_sight(p.get_muzzle(),e.global_position+Vector3.UP):candidates.append(e)
	candidates.sort_custom(func(a,b):return p.position.distance_squared_to(a.position)<p.position.distance_squared_to(b.position))
	var nearest:EnemyActor=candidates[0] if not candidates.is_empty() else null
	if nearest:
		p.test_aim=nearest.aim_center() if nearest.flying else nearest.global_position
		if p.is_coo:
			if p.coo.vent_left>.4 and p.coo.vent_left<.62:p.reload_input()
		elif p.ammo==0 and p.reload_elapsed<0:p.reload_input()
		if p.reload_elapsed>=game.config.perfect_start+.02 and not p.reload_attempted:
			p.reload_input();actions.perfect_reloads+=1
		if candidates.size()>=3 and p.arm_ricochet():actions.ricochets+=1
		if candidates.size()>=3 and p.use_field_skill():
			if p.is_coo:actions.egg_drops=actions.get("egg_drops",0)+1
			elif p.field_skill=="slap":actions.slaps+=1
			else:actions.vortices+=1
		try_special()
		if nearest.position.distance_to(p.position)<4.5 and p.ammo>=2 and p.fan_hammer():actions.fans+=1
		elif p.try_fire():actions.shots+=1
	# Travel a navigation path around the street, never teleport through cover.
	path_timer-=delta
	if p.global_position.distance_to(route[corner])<1.0:corner=(corner+1)%route.size();path_timer=0
	if path_timer<=0:navigation.target_position=route[corner];path_timer=.35
	var next:=navigation.get_next_path_position()
	var desired:=next-p.position;desired.y=0;desired=desired.normalized()
	var burning_barrel:=false
	for prop in get_tree().get_nodes_in_group("breakables"):
		if prop.kind=="barrel" and prop.fuse>=0 and prop.position.distance_to(p.position)<3.2:
			desired=(p.position-prop.position).normalized();desired.y=0;burning_barrel=true
	var right:=game.camera.global_basis.x;right.y=0;right=right.normalized()
	var back:=game.camera.global_basis.z;back.y=0;back=back.normalized()
	p.test_move=Vector2(desired.dot(right),desired.dot(back))
	var danger:=burning_barrel
	for e in candidates:
		if e.state=="charge" and e.position.distance_to(p.position)<3.2:danger=true
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if projectile.team=="enemy" and projectile.global_position.distance_to(p.position+Vector3.UP)<1.7:danger=true
	if danger and p.dash():actions.dashes+=1

func try_special() -> bool:
	if not game.player.use_special(): return false
	actions.ultimates += 1
	if record_run and not captured_special and DisplayServer.get_name() != "headless":
		captured_special = true
		capture(game.player.equipped_special,.4)
	return true

func choose() -> void:
	choosing=true
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.4,true).timeout
		if record_run:await capture("upgrade_%d"%game.wave,0)
	var key:String=game.options[0]
	var priorities := ["prickly","pinball","bounce","last_word","quickdraw"]
	if game.player.equipped_special=="saguaro_lance":
		priorities=["fling","magnet","aftershock","explosive","trigger"]
	for preferred in priorities:
		if preferred in game.options:key=preferred;break
	actions.upgrades.append(key);game.choose_upgrade(key);choosing=false

func capture(label: String, delay: float) -> void:
	if delay>0:await get_tree().create_timer(delay,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://playthrough_"+label+".png")

func finish() -> void:
	if finished:return
	finished=true
	if not record_run:
		if game.is_fighting():game.finish_run(false)
		return
	samples.sort()
	var report:={"hero":"coo" if game.player.is_coo else "espino","route":game.route.choice,"city_stage":game.route.stage,"best_play":game.best_play,"won":game.state==GameDirector.RunState.VICTORY,"seconds":game.run_time,"health":game.player.health,"kills":game.kills,"highest_chain":game.highest_chain,"actions":actions,"median_ms":samples[samples.size()/2] if samples.size()>0 else 0,"p95_ms":samples[int(samples.size()*.95)] if samples.size()>0 else 0,"renderer":RenderingServer.get_video_adapter_name(),"fixed_fps":Engine.get_frames_per_second()}
	var file:=FileAccess.open("user://autoplay.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("AUTOPLAY_REPORT ",JSON.stringify(report));print("REPORT ",OS.get_user_data_dir()+"/autoplay.json")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://autoplay_result.png")
	game.quit_application(0 if report.won else 2)
