extends Node
var game: GameDirector
var checks := 0
var failed := 0

func setup(director: GameDirector) -> void:
	game=director
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func check(ok: bool, what: String) -> void:
	checks+=1
	if not ok:
		failed+=1
		push_error(what)

func run() -> void:
	await frames(4)
	game.start_run()
	game.spawn_cooldown=100
	var p:=game.player
	var form:=p.form
	p.equipped_special="high_noon"
	p.test_mode=true;p.invulnerable=12;p.position=Vector3(-3.0,0,3.0);p.ammo=3
	var target:=game.spawn_enemy("boss",Vector3(-3.1,0,7.6))
	target.set_physics_process(false)
	p.test_aim=target.aim_center()
	await frames(4)
	check(p.arm_ricochet(),"ricochet activation")
	await frames(14)
	check(p.flourish.curls[0].is_visible_in_tree() and p.flourish.camera.size<game.camera.size*.6,"ricochet curls and camera push")
	check(p.cast_vortex(),"tumbleweed activation")
	await frames(14)
	check(p.flourish.bloom.is_visible_in_tree() and p.flourish.to_global(p.flourish.bloom.position).distance_to(p.flourish.cast_origin())<.14,"bloom follows casting hand")
	p.stache=100
	check(p.use_special() and p.stache==0 and not p.flourish.visible,"ultimate takes camera ownership")
	await frames(16)
	check(form.normal_face.visible and not form.moustache.visible and form.camera_weight>.9,"close-up establishes the brown moustache before it grows")
	await frames(17)
	check(form.camera_rig.current and form.camera_weight>.9 and form.camera_rig.size<4.0,"face close-up")
	check(form.released and is_instance_valid(form.dropped),"visible detached revolver")
	for held in form.held:check(not held.visible,"held revolver hidden")
	check(not p.try_fire(),"barrel cannot fire during bud formation")
	check(not form.normal_face.visible and form.face_shell.visible and form.moustache.visible,"normal face replaced by the actual morphing moustache")
	check(form.moustache.get_blend_shape_value(form.uncurl_key)>.23 and form.spread==0,"handlebar straightens before its feathers fan open")
	var shot_time:=form.age
	get_tree().paused=true
	await frames(15)
	check(is_equal_approx(form.age,shot_time) and form.camera_rig.current,"pause freezes close-up and transformation")
	get_tree().paused=false
	await frames(41)
	check(p.position.y>.42 and form.moustache.visible and form.spread>.99 and form.arm_growth>.99,"player ascends with open wings and transformed arm")
	check(form.arm.global_position.distance_to(p.get_muzzle())>.59,"thorn launches from end of transformed forearm")
	check(absf(form.moustache.get_blend_shape_value(form.upstroke_key)+form.moustache.get_blend_shape_value(form.downstroke_key)-1)<.01,"one fully winged moustache during flight")
	var start:=p.position
	p.test_move=Vector2(.6,0)
	await frames(45)
	check(p.position.distance_to(start)>.75 and p.position.y>.4,"steerable flight")
	p.test_move=Vector2.ZERO
	check(game.camera.current and not is_instance_valid(form.camera_rig),"return to arena lens")
	check(form.landed and form.dropped.global_position.y<.22,"gun rests on ground")
	check(game.noon_shots==0 and target.health<=target.max_health-330,"six damaging physical marked shots")
	var health:=target.health
	p.test_aim=target.aim_center()
	await frames(2)
	check(p.try_fire() and p.ammo==3,"manual launcher preserves revolver rounds")
	await frames(22)
	check(target.health<health,"manual spike damages enemy")
	p.position=Vector3(0,.55,2.3)
	target.position=Vector3(0,0,-2.8)
	p.test_aim=target.aim_center()
	await frames(19)
	health=target.health
	check(p.try_fire(),"launcher fires toward cover")
	await frames(24)
	check(is_equal_approx(target.health,health),"solid trough intercepts projectile")
	await frames(154)
	check(form.uncurl>.6 and form.spread<form.uncurl*.45 and form.moustache.visible,"vanes fold back into the same handlebar on descent")
	await frames(61)
	check(not form.running and not form.visible and p.position.y<.08,"lands and retracts wings")
	check(not is_instance_valid(form.dropped) and game.camera.current and not form.pose.active,"gun recall and normal rig restored")
	check(form.normal_face.visible and not form.moustache.visible and not form.face_shell.visible,"landing restores normal moustache and face")
	for held in form.held:check(held.visible,"original gun shown again")
	check(p.try_fire() and p.ammo==2,"revolver consumes ammunition again")
	p.position=Vector3(-3,0,3);target.position=Vector3(-3,0,7.6);p.stache=100
	await frames(3)
	check(p.high_noon(),"repeat activation")
	await frames(26)
	p.invulnerable=0;p.receive_hit(2000)
	check(not form.running and not form.visible and game.camera.current and not is_instance_valid(form.dropped),"death during cut restores arena and removes dropped gun")
	check(form.normal_face.visible and not form.moustache.visible and not form.face_shell.visible,"interrupted cast restores native moustache")
	print("HIGH_NOON_TEST checks=",checks," failures=",failed)
	game.quit_application(0 if failed==0 else 1)
