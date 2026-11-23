extends Node

var failures := 0
var checks := 0
var game: GameDirector

func setup(director: GameDirector) -> void:
	game = director
	_run.call_deferred()

func check(result: bool, message: String) -> void:
	checks += 1
	if not result:
		failures += 1
		push_error(message)

func _run() -> void:
	await get_tree().physics_frame
	game.set_process(false)
	game.player.test_mode = true
	await _check_flight()
	var keys := {"fridge":"Door", "chili":"HandR", "pigeon":"WingL", "boss":"Louver0","skillet":"PalmR","repair":"PalmR"}
	for kind in keys:
		var actor = game.spawn_enemy(kind, game.arena.spawn_points[1])
		actor.grace = 0
		actor.set_physics_process(false)
		var motion = actor.visual.motion
		check(motion != null, "%s must spawn with an animated model" % kind)
		if not motion: continue
		var clip_names := ["idle","move","windup","attack","recover","hurt","death"]
		if kind == "boss": clip_names.append_array(["ice_windup","ice_attack","ice_recover"])
		if kind == "pigeon": clip_names.append("takeoff")
		if kind == "chili": clip_names.append_array(["strafe_left","strafe_right","backstep"])
		for name in clip_names:
			check(motion.animator.has_animation(name), "%s is missing %s" % [kind,name])
		var bone: int = motion.skeleton.find_bone(keys[kind])
		motion.play_clip("idle",0,0)
		var rest: Quaternion = motion.skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
		actor.attack_count = 1 if kind == "boss" else 0
		actor._begin_attack(Vector3.BACK)
		for frame in 45: motion.tick(actor.timer / 45.0, 0.0, "windup")
		var expected: StringName = &"ice_windup" if kind == "boss" else &"windup"
		check(motion.clip == expected, "%s windup must follow its combat state" % kind)
		actor._release_attack()
		if kind == "chili": actor._physics_process(0.001)
		var attack_name: StringName = &"ice_attack" if kind == "boss" else &"attack"
		check(motion.clip == attack_name, "%s release must play its attack" % kind)
		if kind in ["chili","pigeon","boss","repair"]:
			var shot = get_tree().get_nodes_in_group("projectiles").back()
			var socket_name: StringName = {"chili":&"Muzzle","pigeon":&"Egg","boss":&"Vent","repair":&"Nozzle"}[kind]
			check(shot.global_position.distance_to(motion.socket(socket_name)) < .015, "%s shot misses socket" % kind)
		motion.tick(.10, 0.0, actor.state)
		var posed: Quaternion = motion.skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
		check(rest.angle_to(posed) > .09, "%s attack has no articulation" % kind)
		motion.hurt()
		check(motion.clip == attack_name, "%s hit reaction interrupted an attack" % kind)
		motion.tick(1.0, 0.0, "recover")
		check(motion.clip == (&"ice_recover" if kind=="boss" else &"recover"), "%s failed to recover" % kind)
		motion.tick(.1, 1.0, "chase")
		check(motion.clip == &"move", "%s failed to walk" % kind)
		if kind == "boss":
			actor._begin_attack(Vector3.BACK)
			check(motion.clip == &"windup", "Boss did not alternate from ice to charge")
			actor._release_attack()
			check(actor.state == "charge" and motion.clip == &"attack", "Boss charge did not start")
			actor.timer = 0
			actor._physics_process(.016)
			check(actor.state == "recover" and motion.clip == &"recover", "Boss charge did not settle")
			motion.tick(.1, 1.0, "chase")
		if kind == "chili":
			var gaits := {Vector2.LEFT:&"strafe_left",Vector2.RIGHT:&"strafe_right",Vector2.DOWN:&"move",Vector2.UP:&"backstep"}
			for direction in gaits:
				motion.local_travel=direction
				motion.tick(.1,1,"chase")
				var expected_gait: StringName = gaits[direction]
				check(motion.clip==expected_gait,"Bandit did not match its direction of travel")
			motion.local_travel=Vector2.ZERO
			actor._begin_attack(Vector3.BACK)
			actor._release_attack()
			var previous_count := get_tree().get_nodes_in_group("projectiles").size()
			for round_index in 3:
				actor._physics_process(.16)
				var rounds := get_tree().get_nodes_in_group("projectiles")
				check(rounds.size() == previous_count + round_index + 1, "Bandit skipped a round")
				check(rounds.back().global_position.distance_to(motion.socket(&"Muzzle")) < .015, "Burst left the muzzle")
			check(actor.state == "recover", "Bandit did not finish the burst")
			motion.tick(.1, 1.0, "chase")
		motion.hurt()
		check(motion.clip == &"hurt", "%s missing hit reaction" % kind)
		actor.receive_hit(10000,false)
		check(actor.dead and actor.death_time > .8 and motion.clip == &"death", "%s fall was discarded on death" % kind)
		actor._physics_process(.4)
		check(not actor.is_queued_for_deletion(), "%s removed mid-fall" % kind)
		actor._physics_process(actor.death_length-.4+.03)
		check(not actor.is_queued_for_deletion(), "%s final pose was cut short" % kind)
		actor._physics_process(.24)
		check(actor.is_queued_for_deletion(), "%s corpse was retained" % kind)
	print("ENEMY_ANIMATION_TEST checks=", checks, " failures=", failures)
	game.quit_application(1 if failures else 0)

func _check_flight() -> void:
	for shot in get_tree().get_nodes_in_group("projectiles"): shot.queue_free()
	await get_tree().physics_frame
	var p := game.player
	p.global_position=Vector3(0,0,9.6)
	var bird := game.spawn_enemy("pigeon",Vector3(0,0,-2.7))
	bird.cooldown=30
	bird.grace=0
	check(bird.visual.motion.clip == &"takeoff", "Spawn skipped the takeoff pose")
	for i in 146: await get_tree().physics_frame
	bird.set_physics_process(false)
	check(bird.global_position.y>1.85 and bird.global_position.z>.6,"Flight did not clear the central trough at %s" % bird.global_position)
	check(bird.visual.motion.payload.visible,"Cruising pigeon has no egg in its talons")
	bird._begin_attack(Vector3.BACK)
	bird.visual.motion.tick(bird.timer,0,"windup")
	var origin := bird.visual.motion.socket(&"Egg")
	bird._release_attack()
	var bomb: CombatProjectile = get_tree().get_nodes_in_group("projectiles").back()
	check(bomb.lob and origin.y>1.6 and bomb.origin.distance_to(bird.visual.motion.socket(&"Egg"))<.005,"Egg was not launched from the airborne foot")
	check(bomb.origin.distance_to(origin)<.07,"Payload jumped between the held and thrown poses")
	check(not bird.visual.motion.payload.visible,"Carried egg remained visible after release")
	bomb.set_physics_process(false)
	var hp:=p.health
	for i in 65:
		if bomb.is_queued_for_deletion():break
		bomb._physics_process(1./60)
	check(bomb.is_queued_for_deletion() and p.health<hp,"Thrown egg failed to explode at its marked target")
	bird.visual.motion.tick(.7,0,"recover")
	bird.visual.motion.tick(.67,0,"recover")
	check(bird.visual.motion.payload.visible,"Pigeon did not load a fresh egg")
	var mouse:=game.camera.unproject_position(bird.aim_center())
	p.aim_from_screen(mouse)
	check(p.elevated_aim and p.aim_point.y>1.85,"Cursor cannot acquire the flying hitbox")
	p.ammo=6;p.shoot_cooldown=0;p.reload_elapsed=-1
	var health:=bird.health
	p.try_fire()
	check(bird.health<health,"Normal revolver ray missed the onscreen flier")
	if not bird.dead: bird.receive_hit(1000)
	var top:=bird.global_position.y
	bird._physics_process(bird.death_length*.41)
	check(bird.global_position.y<top and bird.global_position.y>.25,"Pigeon death skipped the descent")
	bird._physics_process(bird.death_length*.30)
	check(absf(bird.global_position.y-bird.crash_floor)<.025,"Pigeon reached its contact pose above the floor")
