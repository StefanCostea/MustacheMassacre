class_name GameDirector
extends Node3D

enum RunState { ARRIVAL, COMBAT, TRANSITION, UPGRADE, BOSS, DEAD, VICTORY }
var state: RunState = RunState.ARRIVAL
var config: CombatConfig = preload("res://resources/combat.tres")
var arena: BadlandsArena
var player: EspinoPlayer
var camera: Camera3D
var effects: CombatEffects
var ui
var actors: Node3D
var enemies: Array[EnemyActor] = []
var boss: EnemyActor
var run_time: float = 0.0
var wax_earned := 0
var last_kill_at := -10.0
var multi_count := 0
var kills: int = 0
var highest_chain: int = 0
var best_play := ""
var playtest=preload("res://scripts/paired_playtest.gd").new()
var wave: int = 0
var spawn_queue: Array[String] = []
var spawn_cooldown: float = 0.0
var transition_timer: float = 0.0
var hostile_time_scale: float = 1.0
var slow_left: float = 0.0
var noon_shots: int = 0
var noon_timer: float = 0.0
var noon_marks: Array[int] = []
var attack_id: int = 0
var shake_amount: float = 0.0
var frame_times: Array[float] = []
var options: Array[String] = []
var rng := RandomNumberGenerator.new()
var automation: Node
var encounter: WaveSpec
var spawn_group_left: int = 0
var bottleneck: Array[EnemyActor] = []
var bottleneck_time := 0.0
var freezer_lane: Node3D
var route=preload("res://scripts/grease_route.gd").new()
var county
var paid_kill_wax := 0
signal outlaw_impact(carrier: EnemyActor, victim: EnemyActor)
signal enemy_defeated(enemy: EnemyActor)
signal wave_cleared(index: int)
signal run_finished(won: bool)

func _ready() -> void:
	if "--enemy-gallery" in OS.get_cmdline_user_args():
		process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().change_scene_to_file.call_deferred("res://scenes/badlands_enemy_review.tscn")
		return
	process_mode=Node.PROCESS_MODE_PAUSABLE
	get_tree().auto_accept_quit=false
	rng.randomize()
	route.game=self
	add_child(route)
	actors=Node3D.new();actors.name="Actors";add_child(actors)
	effects=CombatEffects.new();effects.name="Effects";add_child(effects)
	_setup_lighting()
	arena=BadlandsArena.new();arena.name="CrispyBadlands";add_child(arena);arena.build(self)
	player=EspinoPlayer.new();actors.add_child(player);player.position=Vector3(0,0,5.7);player.setup(self,config)
	_setup_camera()
	ui=load("res://scripts/hud.gd").new();add_child(ui);ui.setup(self)
	spawn_enemy("fridge",Vector3(3,0,3.0),true)
	if "--general-coo" in OS.get_cmdline_user_args():player.equip_hero("coo")
	if "--paired-ui-test" in OS.get_cmdline_user_args():
		playtest.folder="user://test-paired-ui-%d"%OS.get_process_id()
		Preferences.settings_path=playtest.folder.path_join("settings.cfg")
		Preferences.load_settings()
		playtest.open_session()
	elif "--two-run-playtest" in OS.get_cmdline_user_args():playtest.open_session()
	ui.show_arrival()
	if "--open-world" in OS.get_cmdline_user_args():start_county.call_deferred()
	if playtest.results_pending:ui.show_playtest_form()
	elif playtest.active and playtest.data.runs.size()==1:ui.show_loadout()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if "--autoplay-specials" in OS.get_cmdline_user_args():
		watch_specials()
	elif "--autoplay" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://tests/autoplay.gd"):
		automation=load("res://tests/autoplay.gd").new();add_child(automation);automation.setup(self)
	elif "--high-noon-preview" in OS.get_cmdline_user_args():
		_preview_special.call_deferred("high_noon")
	elif "--saguaro-lance-preview" in OS.get_cmdline_user_args():
		_preview_special.call_deferred("saguaro_lance")
	for preview in ["bottleneck","freezer","freight","fry-line"]:
		if "--"+preview+"-preview" in OS.get_cmdline_user_args():preview_campaign.call_deferred(preview)
	if "--capture" in OS.get_cmdline_user_args():
		_capture_after_start()
	if "--test" in OS.get_cmdline_user_args():
		var runner=load("res://tests/combat_tests.gd").new();add_child(runner);runner.setup(self)
	if "--review" in OS.get_cmdline_user_args():
		var reviewer=load("res://tests/asset_review.gd").new();add_child(reviewer);reviewer.setup(self)
	for mode in ["stress","restart-test","input-audit","mouse-test","natural-visual-check","enemy-animation-test","environment-test","high-noon-test","loadout-test","badlands-expansion-test","campaign-test","paired-ui-test","county-test"]:
		if "--"+mode in OS.get_cmdline_user_args():
			var script:String=mode.replace("-","_")
			var diagnostic=load("res://tests/"+script+".gd").new();add_child(diagnostic);diagnostic.setup(self)

func watch_specials() -> void:
	if automation or state != RunState.ARRIVAL or ui.panel_kind != "arrival": return
	player.equip_hero("espino")
	automation = load("res://scripts/specials_autoplay.gd").new()
	add_child(automation)
	automation.setup(self)

func stage_preview_group(special: String) -> Array[EnemyActor]:
	var group: Array[EnemyActor] = []
	var offsets := [Vector3(-1.25,0,3.8), Vector3(-2.95,0,3.3), Vector3(.6,0,4.75)]
	if special == "saguaro_lance":
		offsets = [Vector3(-1,0,2.9), Vector3(-1.54,0,4.35), Vector3(-1.95,0,5.65)]
	for offset: Vector3 in offsets:
		if spawn_queue.is_empty(): break
		var pos := player.position + offset
		pos.y = 0
		group.append(spawn_enemy(spawn_queue.pop_front(),pos))
	return group

func _preview_special(special: String) -> void:
	player.equip_hero("espino")
	player.equipped_special=special
	start_run()
	# Stage one charged opening, then hand the live first wave back to the player.
	player.position=Vector3(-2.8,0,4.4)
	var opening := stage_preview_group(special)
	await get_tree().create_timer(.70,false).timeout
	if player.dead:return
	for outlaw in opening:
		if valid_noon_target(outlaw):
			player.stache=100
			player.aim_direction=player.position.direction_to(outlaw.position)
			player.aim_point=outlaw.aim_center()
			player.use_special()
			break

func preview_campaign(preview:String) -> void:
	if state!=RunState.ARRIVAL:return
	start_run()
	if preview=="bottleneck":
		if player.equipped_special=="saguaro_lance" and not player.is_coo:player.upgrades.assign(["magnet","fling"])
		else:player.upgrades.assign(["prickly","bounce"])
		player.stache=100
		start_wave(3)
	elif preview=="freezer":
		start_boss()
		boss.receive_hit(boss.max_health*.5)
	else:
		state=RunState.VICTORY
		route.enter("fry_line" if preview=="fry-line" else "freight")

func _setup_lighting() -> void:
	var world:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("72634e")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c5c4bb");env.ambient_light_energy=.65
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.glow_enabled=true;env.glow_intensity=.45
	env.ssao_enabled=true;env.ssao_radius=1.0;env.ssao_intensity=1.6
	env.fog_enabled=true;env.fog_light_color=Color("a78d65");env.fog_density=.003
	world.environment=env;add_child(world)
	var sun:=DirectionalLight3D.new();sun.name="BadlandsSun";sun.rotation_degrees=Vector3(-52,-35,0)
	sun.light_color=Color("ffe2ac");sun.light_energy=1.7;sun.shadow_enabled=true;sun.directional_shadow_max_distance=50
	add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-40,145,0);fill.light_color=Color("99bfd1");fill.light_energy=.35;add_child(fill)

func _setup_camera() -> void:
	camera=Camera3D.new();camera.name="IsometricCamera";add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=22.0;camera.far=150
	camera.position=Vector3(12,19,18)+Vector3(0,0,-2.0);camera.look_at(Vector3(0,0,-2.0),Vector3.UP)
	camera.current=true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):ui.toggle_pause();get_viewport().set_input_as_handled()
	if event.is_action_pressed("start_run") and state==RunState.ARRIVAL:
		if not get_viewport().gui_get_focus_owner() is Button:
			if playtest.active:start_run()
			else:start_county()
	if county and is_fighting():
		if event.is_action_pressed("county_map"):
			county.map_open=true
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
			get_tree().paused=true
			get_viewport().set_input_as_handled()
		if event.is_action_pressed("county_interact"):
			county.interact()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if is_fighting():run_time+=delta
	frame_times.append(delta*1000)
	if frame_times.size()>18000:frame_times.pop_front()
	if is_instance_valid(player):
		var focus:=Vector3(clampf(player.position.x*.32,-3,3),0,clampf(player.position.z*.32,-1.5,2.5))
		if county:focus=Vector3(player.position.x,0,player.position.z)
		if state == RunState.ARRIVAL:
			focus = Vector3(0,0,-2.0)
		camera.size = lerpf(camera.size,22.0 if state == RunState.ARRIVAL else 17.0,minf(1,delta*2.7))
		var desired:=focus+Vector3(12,19,18)
		camera.position=camera.position.lerp(desired,minf(1,delta*4))
		camera.position+=Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1))*shake_amount*Preferences.shake_strength
	if is_instance_valid(player):
		if player.form.running:player.form.update_camera()
		elif player.lance.running:player.lance.update_camera()
		else:player.flourish.frame_camera()
	shake_amount=move_toward(shake_amount,0,delta*1.6)
	slow_left=maxf(0,slow_left-delta);hostile_time_scale=.25 if slow_left>0 else 1.0
	if noon_shots>0:
		noon_timer-=delta
		if noon_timer<=0:_noon_shot();noon_timer=.11
	for i in range(enemies.size()-1,-1,-1):
		if not is_instance_valid(enemies[i]):enemies.remove_at(i)
	if county:
		county.tick(delta)
		return
	if state in [RunState.COMBAT,RunState.BOSS]:
		spawn_cooldown-=delta
		if spawn_cooldown<=0 and not spawn_queue.is_empty() and live_count()<config.max_enemies:
			var previous:=spawn_queue.size()
			_spawn_next()
			if spawn_queue.size()<previous:
				spawn_group_left-=1
				spawn_cooldown=.32
				if spawn_group_left<=0:
					spawn_cooldown=encounter.group_interval if state==RunState.COMBAT else 1.5
					spawn_group_left=encounter.group_size if state==RunState.COMBAT else 1
			else:spawn_cooldown=.25
		if spawn_queue.is_empty() and live_count()==0:
			if route.stage>0:route.cleared()
			elif state==RunState.BOSS:finish_run(true)
			else:
				state=RunState.TRANSITION;transition_timer=2.0;award_wax(6);wave_cleared.emit(wave)
				ui.toast("STREET CLEARED", "Catch your breath, gunslinger. +25 HEALTH",CombatEffects.GOLD)
	elif state==RunState.TRANSITION:
		transition_timer-=delta
		if transition_timer<=0:
			player.health=minf(100,player.health+25)
			Sound.play("pickup",-4)
			show_upgrades()

func is_fighting() -> bool:
	return state in [RunState.COMBAT,RunState.BOSS]

func start_county() -> void:
	if state!=RunState.ARRIVAL or get_tree().paused or ui.panel_kind!="arrival" or playtest.active:return
	for actor in actors.get_children():
		if actor!=player:
			actors.remove_child(actor)
			actor.queue_free()
	enemies.clear()
	remove_child(arena)
	arena.queue_free()
	county=preload("res://scripts/county_run.gd").new()
	add_child(county)
	arena=preload("res://scripts/county_arena.gd").new()
	add_child(arena)
	arena.build(self)
	player.position=county.Layout.HUB
	player.input_lock=.25
	camera.position=player.position+Vector3(12,19,18)
	state=RunState.COMBAT
	ui.close_panel()
	county.setup(self,arena)

func start_run() -> void:
	if state!=RunState.ARRIVAL or get_tree().paused or ui.panel_kind!="arrival":return
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.dummy:enemy.queue_free()
	playtest.begin(player)
	enemies.clear();ui.close_panel();player.input_lock=.25
	Sound.play("ui",-2,.8);start_wave(1)

func start_wave(index: int) -> void:
	wave=index;state=RunState.COMBAT;spawn_queue.clear();spawn_cooldown=1.0
	encounter=load("res://resources/encounters/wave_%d.tres"%wave)
	spawn_group_left=encounter.group_size
	for i in range(encounter.count):spawn_queue.append("fridge" if wave==1 and i<6 else encounter.pattern[i%encounter.pattern.size()])
	ui.toast(encounter.title,"WAVE %02d  ·  KEEP MOVING"%wave,CombatEffects.GOLD)
	if index==3:stage_bottleneck()

func stage_bottleneck() -> void:
	bottleneck.clear()
	bottleneck_time=run_time
	# Both alleys run between permanent cover footprints. Stage on the far side
	# of the street so reinforcements never appear around the player's boots.
	var side:=1.0 if player.position.x<0 else -1.0
	var front:=Vector3(side*2.7,0,side*1.25)
	var behind:=Vector3(0,0,side)
	var formation:=[["skillet",0.,0.],["repair",1.3,-.18],["fridge",2.45,.24],["chili",3.5,.2],["chili",2.65,-.7]]
	for slot:Array in formation:
		var kind:String=slot[0]
		spawn_queue.erase(kind)
		var outlaw:=spawn_enemy(kind,front+behind*float(slot[1])+Vector3.RIGHT*float(slot[2]))
		outlaw.grace=.35
		outlaw.visual.rotation.y=atan2(-behind.x,-behind.z)
		outlaw.formation_guard=true
		bottleneck.append(outlaw)
	bottleneck[1].health=30
	bottleneck[1].cooldown=.1
	bottleneck[2].health=16
	bottleneck[3].health=11
	spawn_cooldown=10
	effects.caption(front+Vector3.UP*1.9,"THE REPAIR CREW",CombatEffects.GOLD)
	ui.toast("THE BOTTLENECK","Flank the shield. Follow the weld.",CombatEffects.GOLD)

func _spawn_next() -> void:
	var candidates:Array[Vector3]=[]
	for point in arena.spawn_points:
		if point.distance_to(player.global_position)>6:candidates.append(point)
	if candidates.is_empty():spawn_cooldown=.3;return
	var point:Vector3=candidates[rng.randi_range(0,candidates.size()-1)]
	point+=Vector3(rng.randf_range(-.35,.35),0,rng.randf_range(-.35,.35))
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and point.distance_to(enemy.global_position)<1.0:return
	if not arena.point_clear(point):return
	spawn_enemy(spawn_queue.pop_front(),point)

func spawn_enemy(kind: String, position: Vector3, dummy: bool = false) -> EnemyActor:
	var enemy:=EnemyActor.new();actors.add_child(enemy);enemy.setup(self,kind,position,dummy);enemies.append(enemy)
	return enemy

func live_count() -> int:
	var count:=0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and not enemy.dummy:count+=1
	return count

func create_prop(kind: String, pos: Vector3) -> void:
	var prop:=BreakableProp.new();actors.add_child(prop);prop.setup(self,kind,pos)

func show_upgrades() -> void:
	state=RunState.UPGRADE;options.clear()
	var pool: Array[String] = []
	for key: String in CombatConfig.UPGRADES:
		if key in player.upgrades:continue
		if key in CombatConfig.WORKSHOP and key not in Preferences.workshop:continue
		if key=="needle_powder" and "prickly" not in player.upgrades:continue
		if key in ["magnet","fling"] and (player.field_skill!="tumbleweed" or player.is_coo):continue
		pool.append(key)
	pool.shuffle()
	# Offer two different play styles, then a wildcard. All cards stay unique.
	var styles := [["prickly","bounce","last_word","pinball","riposte"],["fling","magnet","aftershock","explosive"]]
	for family: Array in styles:
		for key in pool:
			if key in family:
				options.append(key)
				break
	# Reserve the wildcard for a matching build piece when one is still available.
	var partners := {"magnet":"fling", "fling":"magnet", "prickly":"needle_powder", "last_word":"prickly", "bounce":"prickly", "pinball":"prickly"}
	for owned in player.upgrades:
		var partner: String = partners.get(owned,"")
		if partner in pool and partner not in options:
			options.append(partner)
			break
	for key in pool:
		if options.size()==3:break
		if key not in options:options.append(key)
	options.shuffle()
	ui.show_upgrades(options)
	get_tree().paused=true

func choose_upgrade(key: String) -> void:
	if state!=RunState.UPGRADE or not key in options:return
	playtest.picked(key,options)
	player.upgrades.append(key);ui.close_panel();get_tree().paused=false;player.input_lock=.25
	Sound.play("perfect",-3)
	if county:
		state=RunState.COMBAT
	elif route.reward_due:
		route.reward_due=false
		route.start_stage(2)
	elif wave==3:start_boss()
	else:start_wave(wave+1)

func start_boss() -> void:
	state=RunState.BOSS;wave=4;spawn_queue.clear();spawn_cooldown=2.0
	var spot:=Vector3(0,0,-8)
	if spot.distance_to(player.global_position)<6:spot=Vector3(0,0,8)
	boss=spawn_enemy("boss",spot);boss.grace=2.0
	ui.toast("EL FRIGORÍFICO", "THE COLDEST SHERIFF IN THE BADLANDS",CombatEffects.DANGER)
	Sound.play("ultimate",-4,.7);shake(.12)

func boss_enraged() -> void:
	if is_instance_valid(boss) and boss.health>0:
		freezer_lane=preload("res://scripts/freezer_lane.gd").new()
		actors.add_child(freezer_lane)
		freezer_lane.setup(self,boss)
	if county:return
	for kind in ["fridge","chili","pigeon","fridge","chili","fridge"]:spawn_queue.append(kind)
	spawn_cooldown=1.0

func new_context(source: String = "revolver") -> Dictionary:
	attack_id+=1
	return {"id":attack_id,"source":source,"chain":{"kills":0,"steps":[source]},"budget":{"events":0,"kills":0},"generation":0,"visited":[]}

func line_of_sight(from: Vector3, to: Vector3) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(from,to,1|8)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func fire_player(direction: Vector3, critical: bool, hops: int, explosive: bool, base_damage: float = -1, source := "revolver") -> void:
	var muzzle:=player.get_muzzle()
	var start:=player.global_position+Vector3.UP*muzzle.y
	start.y=muzzle.y
	var context:=new_context(source)
	if critical and player.empowered:context.chain.steps.append("perfect_reload")
	# Check the body-to-muzzle segment, so a barrel protruding into cover cannot shoot through it.
	var obstruction:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,muzzle,1|8))
	var from:Vector3=muzzle if obstruction.is_empty() else start
	var to:=from+direction*24
	var hit:Dictionary=obstruction if not obstruction.is_empty() else get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1|4|8))
	context.impact_from=from
	var damage:=(config.shot_damage if base_damage<0 else base_damage)*(config.critical_multiplier if critical else 1.0)
	if not hit.is_empty():to=hit.position
	effects.tracer(from,to,CombatEffects.GOLD,.035 if critical else .022)
	effects.burst(from,CombatEffects.GOLD,4,.5)
	if hit.is_empty():return
	var object=hit.collider
	if object is EnemyActor:
		context.visited.append(object.get_instance_id());object.receive_hit(damage,critical,context)
		_chain_hits(object.global_position+Vector3.UP*.9,hops,damage*ricochet_retention(),critical,context)
	elif object.has_method("receive_hit"):object.receive_hit(damage,critical,context)
	if explosive:explode(to,config.explosive_radius,config.explosive_damage,"player",context)
	else:effects.burst(to,CombatEffects.GOLD,5)

func nearest_chain_target(pos: Vector3, visited: Array, distance: float):
	var best=null;var best_distance:=distance
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.dummy or enemy.get_instance_id() in visited:continue
		var d:=enemy.global_position.distance_to(pos)
		if d<best_distance and line_of_sight(pos+Vector3.UP*.15,enemy.global_position+Vector3.UP*.9):best=enemy;best_distance=d
	return best

func ricochet_retention() -> float:
	return .95 if "pinball" in player.upgrades else .75

func _chain_hits(origin: Vector3, hops: int, amount: float, critical: bool, context: Dictionary) -> void:
	var point:=origin
	for i in range(hops):
		var enemy=nearest_chain_target(point,context.visited,5.0)
		if not is_instance_valid(enemy):break
		context.visited.append(enemy.get_instance_id())
		var next:Vector3=enemy.global_position+Vector3.UP*.9
		effects.tracer(point,next,CombatEffects.GOLD,.025)
		context.impact_from=point
		if context.has("chain") and "ricochet" not in context.chain.steps:context.chain.steps.append("ricochet")
		enemy.receive_hit(amount,critical,context);amount*=ricochet_retention();point=next
		Sound.play("ricochet",-7,1+i*.12)

func spawn_projectile(pos: Vector3, vel: Vector3, amount: float, faction: String, context: Dictionary = {}):
	var projectile:=CombatProjectile.new();actors.add_child(projectile);projectile.setup(self,pos,vel,amount,faction,context)
	return projectile

func valid_noon_target(enemy) -> bool:
	if not is_instance_valid(enemy) or enemy.dead or enemy.dummy:return false
	var point:Vector3=enemy.aim_center()
	return point.distance_to(player.global_position)<14 and not camera.is_position_behind(point) and get_viewport().get_visible_rect().has_point(camera.unproject_position(point)) and line_of_sight(player.get_muzzle(),point)

func field_target(point: Vector3) -> Vector3:
	var offset:=point-player.global_position;offset.y=0;offset=offset.limit_length(config.vortex_cast_range)
	var end:=player.global_position+offset
	var cast:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*.4,end+Vector3.UP*.4,1|8))
	if not cast.is_empty():end=cast.position-offset.normalized()*.6
	end.y=.1
	if county:return county.clamp_point(end)
	end.x=clampf(end.x,-13,13);end.z=clampf(end.z,-10,10)
	return end

func cast_slap(point: Vector3) -> void:
	var slap=preload("res://scripts/slapstache.gd").new()
	actors.add_child(slap)
	slap.setup(self,field_target(point))

func fling_outlaw(enemy: EnemyActor, context:Dictionary={}) -> void:
	var neighbour=nearest_chain_target(enemy.aim_center(),[enemy.get_instance_id()],7.0)
	var heading:=player.aim_direction
	if neighbour:heading=neighbour.global_position-enemy.global_position
	heading.y=0
	if heading.length_squared()<.001:heading=player.aim_direction
	enemy.start_fling(heading.normalized(),context)

func cast_vortex(point: Vector3, upgraded: bool) -> void:
	var end:=field_target(point)
	var vortex:=TumbleweedVortex.new();actors.add_child(vortex);vortex.setup(self,player.flourish.cast_origin(),end,upgraded)

func start_high_noon() -> bool:
	noon_marks.clear()
	var candidates:Array[EnemyActor]=[]
	for enemy in enemies:
		if valid_noon_target(enemy):candidates.append(enemy)
	candidates.sort_custom(func(a,b):return a.global_position.distance_squared_to(player.aim_point)<b.global_position.distance_squared_to(player.aim_point))
	for i in range(mini(6,candidates.size())):
		noon_marks.append(candidates[i].get_instance_id());effects.ring(candidates[i].global_position,.65,CombatEffects.GOLD,1.8)
	if noon_marks.is_empty():ui.toast("NO TARGETS", "Bring the fight into your sights.",CombatEffects.GOLD);return false
	noon_shots=6;noon_timer=EspinoPlayer.HighNoonForm.FIRST_SPIKE;slow_left=1.74;shake(.10)
	ui.toast("HIGH NOON", "THE THORNS TAKE FLIGHT.",CombatEffects.GOLD)
	return true

func _noon_shot() -> void:
	noon_shots-=1
	var chosen=null
	for id in noon_marks:
		var enemy=instance_from_id(id)
		if valid_noon_target(enemy):chosen=enemy;break
	if not is_instance_valid(chosen):
		for enemy in enemies:
			if valid_noon_target(enemy):chosen=enemy;break
	if is_instance_valid(chosen):
		launch_thorn(chosen.aim_center(),55,true,0,false,chosen)
		noon_marks.erase(chosen.get_instance_id());noon_marks.append(chosen.get_instance_id())
		Sound.play("shot",-1,.85);shake(.10)

func launch_thorn(target: Vector3, damage: float, critical: bool, hops: int, explosive: bool, mark: EnemyActor = null) -> void:
	player.form.set_spike_aim(target)
	var origin:=player.get_muzzle()
	var context:=new_context("high_noon" if mark else "thorn_arm")
	var elbow:Vector3=player.form.arm.global_position
	var near_hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(elbow,origin,1|8))
	var direction:Vector3=(target-origin).normalized()
	if not near_hit.is_empty():
		origin=elbow
		direction=(near_hit.position-elbow).normalized()
	if direction.is_zero_approx():direction=player.aim_direction
	var spike:CombatProjectile=spawn_projectile(origin,direction*30,damage,"player",context)
	spike.set_launcher_shot(critical,hops,explosive,mark if near_hit.is_empty() else null)
	effects.burst(origin,Color("f9db86"),4,.52)

func award_wax(amount: int) -> void:
	if automation or amount<=0:return
	var args:=OS.get_cmdline_user_args()
	for arg in args:
		if arg.ends_with("-preview"):return
	for mode in ["--test","--high-noon-preview","--saguaro-lance-preview","--restart-test","--stress"]:
		if mode in args:return
	Preferences.wax += amount
	if Preferences.save():
		wax_earned += amount
	else:
		Preferences.wax -= amount
		ui.toast("GARAGE SAVE UNAVAILABLE","Could not write the wax balance.",CombatEffects.DANGER)

func enemy_killed(enemy: EnemyActor, critical: bool, context: Dictionary) -> void:
	enemy_defeated.emit(enemy)
	kills+=1;player.add_stache(10);player.combat_idle=0
	if is_fighting():
		multi_count = multi_count+1 if run_time-last_kill_at <= .85 else 1
		last_kill_at = run_time
		if multi_count>=2:
			player.add_stache(5)
			effects.caption(enemy.aim_center()+Vector3.UP*.5,"%d×  +5 STACHE"%multi_count,CombatEffects.GOLD)
	if context.has("budget"):context.budget.kills+=1
	if context.has("chain"):
		context.chain.kills+=1
		var steps:Array=context.chain.steps
		var cause:String=context.get("source","")
		if cause!="" and cause not in steps:steps.append(cause)
		if context.chain.kills>highest_chain:
			highest_chain=context.chain.kills
			best_play=" → ".join(steps).replace("_"," ").to_upper()
		if context.chain.kills>=3:
			effects.caption(enemy.aim_center()+Vector3.UP*1.15,"%s   ×%d"%[" → ".join(steps).replace("_"," ").to_upper(),context.chain.kills],CombatEffects.GREEN,22)
	elif context.has("budget"):highest_chain=maxi(highest_chain,int(context.budget.kills))
	if "prickly" in player.upgrades and critical and int(context.get("generation",0))==0:
		for i in range(8):
			var a:=TAU*i/8.0
			var ctx:=context
			# Children share the event budget but generation lives in their own hit metadata.
			var child_context:Dictionary={"id":ctx.get("id",0),"source":"needle","budget":ctx.get("budget",{"events":0,"kills":0}),"generation":1,"visited":[enemy.get_instance_id()]}
			if ctx.has("chain"):child_context.chain=ctx.chain
			var needle=spawn_projectile(enemy.global_position+Vector3.UP*.8,Vector3(cos(a),0,sin(a))*12,12,"player",child_context)
			if needle:
				needle.bounces=1 if "bounce" in player.upgrades else 0
				needle.explosive="needle_powder" in player.upgrades and i%3==2
				needle.collision_exclude.append(enemy.get_rid())
	if enemy.kind=="boss" and not county:
		spawn_queue.clear()
		for other in enemies:
			if is_instance_valid(other) and other != enemy: other.collapse()
		finish_run(true)

func explode(pos: Vector3, radius: float, amount: float, team: String, context: Dictionary) -> void:
	effects.ring(pos,.4,CombatEffects.DANGER if team!="player" else CombatEffects.GOLD,.45,radius/.4-1,false)
	effects.burst(pos,CombatEffects.DANGER if team=="enemy" else CombatEffects.GOLD,18,1.7)
	Sound.play("explosion",-3,.85);shake(.12)
	if team in ["player","both"]:
		for enemy in enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(pos)<radius and line_of_sight(pos,enemy.global_position+Vector3.UP*.6):enemy.receive_hit(amount,false,context)
	if team in ["enemy","both"] and player.global_position.distance_to(pos)<radius and line_of_sight(pos,player.global_position+Vector3.UP*.6):player.receive_hit(amount,false,{})
	for prop in get_tree().get_nodes_in_group("breakables"):
		if is_instance_valid(prop) and prop.global_position.distance_to(pos)<radius:prop.receive_hit(amount)

func shake(amount: float) -> void:
	shake_amount=maxf(shake_amount,amount)

func finish_run(won: bool) -> void:
	if state in [RunState.DEAD,RunState.VICTORY]:return
	var played := is_fighting() or state in [RunState.TRANSITION, RunState.UPGRADE]
	state=RunState.VICTORY if won else RunState.DEAD
	if played:
		award_wax(kills/6-paid_kill_wax + (12 if won and route.stage==0 and not county else 0))
		paid_kill_wax=kills/6
	playtest.finish(self,won)
	run_finished.emit(won)
	noon_shots=0;slow_left=0;hostile_time_scale=1;spawn_queue.clear()
	Sound.play("victory" if won else "defeat",-1)
	player.clear_temporary_state()
	var delay := maxf(1.0, boss.death_time + .06) if won and is_instance_valid(boss) else 1.0
	if not won and player.is_coo and player.dead:delay=maxf(delay,player.coo.animator.get_animation("death").length+.1)
	await get_tree().create_timer(delay,false).timeout
	ui.show_results(won)
	get_tree().paused=true

func restart() -> void:
	if county:county.stop_audio(true)
	get_tree().paused=false
	for voice in Sound.voices:voice.stop()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:quit_application()

func quit_application(code: int = 0) -> void:
	if county:county.stop_audio(false)
	for voice in Sound.voices:voice.stop();voice.stream=null
	if Sound.music:Sound.music.stop();Sound.music.stream=null
	if DisplayServer.get_name()!="headless":await get_tree().create_timer(.12,true).timeout
	get_tree().quit(code)

func _capture_after_start() -> void:
	await get_tree().create_timer(2.0).timeout
	var image:=get_viewport().get_texture().get_image()
	image.save_png("user://arrival.png")
	print("CAPTURE ",OS.get_user_data_dir()+"/arrival.png")
