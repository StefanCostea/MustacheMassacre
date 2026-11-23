class_name EnemyActor
extends CharacterBody3D

var game
var kind: String = "fridge"
var health: float = 60.0
var max_health: float = 60.0
var dead: bool = false
var grace: float = 1.0
var state: String = "chase"
var timer: float = 0.0
var cooldown: float = 1.0
var navigation: NavigationAgent3D
var path_timer: float = 0.0
var pull_velocity: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
var target_point: Vector3 = Vector3.ZERO
var visual: EnemyVisual
var phase_two: bool = false
var attack_count: int = 0
var burst_left: int = 0
var hit_in_charge: bool = false
var repair_target: EnemyActor
var formation_guard := false
var is_elite := false
var repair_clock := 0.0
var weld_beam: MeshInstance3D
var flight_left := 0.0
var throw_context := {}
var pull_chain := {}
var pull_credit := 0.0
var hatch:Node3D
var throw_cast: ShapeCast3D
var shield_flash := 0.0
var movement_speed: float = 2.1
var target_position: Vector3 = Vector3.ZERO
var dummy: bool = false
var spec: EnemySpec
var death_time := 0.0
var flying := false
var flight_age := 0.0
var launch_height := 0.0
var death_length := 0.0
var crash_start := 0.0
var crash_floor := 0.0
var struck_ground := false

func setup(director, type: String, pos: Vector3, practice: bool = false) -> void:
	game=director;kind=type;position=pos;dummy=practice
	add_to_group("enemies")
	collision_layer=4;collision_mask=1|8
	spec=load("res://resources/enemies/%s.tres"%kind)
	max_health=spec.health
	health=max_health
	if dummy:health=100000;max_health=health;grace=0
	movement_speed=spec.speed
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=.60 if kind=="boss" else .34
	capsule.height=2.6 if kind=="boss" else 1.65
	shape.shape=capsule;shape.position.y=capsule.height*.5
	add_child(shape)
	build_visual()
	flying = kind == "pigeon" and visual.motion != null
	if kind=="boss":build_freezer_door()
	if kind=="repair":
		weld_beam=MeshKit.cylinder(self,Vector3.ZERO,.028,1,MeshKit.material(Color("72edce"),.4,0,1.6))
		weld_beam.hide()
	if flying:
		launch_height = pos.y
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		capsule.radius = .48
		capsule.height = 1.36
		shape.position.y = .68
		visual.motion.play_clip(&"takeoff", BadlandsEnemyMotion.TAKEOFF_TIME, 0)
	navigation=NavigationAgent3D.new();navigation.path_desired_distance=.5;navigation.target_desired_distance=.5
	navigation.radius=capsule.radius;navigation.avoidance_enabled=false
	add_child(navigation)
	path_timer=randf()*.3
	if dummy:
		MeshKit.label(self,"TARGET PRACTICE",Vector3(0,2.0,0),26,Color("d4bb8a"),.007)
	else:game.effects.ring(pos,.6,CombatEffects.DANGER,.85,.2)

func build_visual() -> void:
	visual=EnemyVisual.new()
	add_child(visual)
	visual.build(kind, "--original-enemies" in OS.get_cmdline_user_args())

func build_freezer_door() -> void:
	hatch=Node3D.new()
	visual.add_child(hatch)
	var vent:=visual.to_local(visual.motion.socket(&"Vent")) if visual.motion else Vector3(0,1.12,.64)
	hatch.position=vent+Vector3(-.32,0,.045)
	var brass:=MeshKit.material(Color("b28b4e"),.35,.62)
	var enamel:=MeshKit.material(Color("293b4b"),.33,.52)
	MeshKit.box(hatch,Vector3(.64,.38,.055),Vector3(.32,0,0),brass)
	MeshKit.box(hatch,Vector3(.60,.34,.055),Vector3(.32,0,.029),enamel)
	for i in 3:
		MeshKit.box(hatch,Vector3(.33,.025,.014),Vector3(.28,-.083+i*.08,.064),brass,.005)
	MeshKit.box(hatch,Vector3(.04,.11,.065),Vector3(.55,.014,.072),brass,.012)

func can_be_flung() -> bool:
	return not dead and not dummy and not flying and kind!="boss" and flight_left<=0

func start_fling(heading: Vector3, context:Dictionary={}) -> void:
	if not can_be_flung():return
	throw_context=context.duplicate() if not context.is_empty() else game.new_context("outlaw_collision")
	throw_context.source="outlaw_collision"
	direction=heading
	state="flung"
	flight_left=.48
	pull_velocity=Vector3.ZERO
	if not throw_cast:
		throw_cast=ShapeCast3D.new()
		var sphere:=SphereShape3D.new()
		sphere.radius=.34
		throw_cast.shape=sphere
		throw_cast.position.y=.82
		throw_cast.collision_mask=1|4|8
		throw_cast.enabled=false
		add_child(throw_cast)
		throw_cast.add_exception(self)
	if visual.motion:visual.motion.hurt()

func advance_fling(dt: float) -> void:
	var step:=direction*minf(dt,flight_left)*12.0
	throw_cast.target_position=step
	throw_cast.force_shapecast_update()
	global_position+=step*throw_cast.get_closest_collision_safe_fraction()
	flight_left=maxf(0,flight_left-dt)
	visual.position.y=.65*sin(PI*flight_left/.48)
	visual.rotation.z=.48*sin(TAU*flight_left/.48)
	if throw_cast.is_colliding():
		var victim=throw_cast.get_collider(0)
		var ctx:=throw_context
		if victim and victim.has_method("receive_hit"):victim.receive_hit(34,false,ctx)
		receive_hit(22,false,ctx)
		if victim is EnemyActor:
			game.outlaw_impact.emit(self,victim)
			if kind=="fridge" and ctx.get("freight",false):
				if victim.kind=="skillet" and not victim.dead:
					victim.state="recover"
					victim.timer=1.35
					if victim.visual.motion:victim.visual.motion.hurt()
				var point:=aim_center()
				game.effects.ring(point-Vector3.UP*.65,.3,Color("96e4e1"),.35,6.,false)
				game.effects.caption(point+Vector3.UP,"FREIGHT IMPACT",CombatEffects.GREEN,24)
				for other in game.enemies:
					if not is_instance_valid(other) or other in [self,victim] or other.dead:continue
					if point.distance_to(other.aim_center())<=2.35 and game.line_of_sight(point,other.aim_center()):
						other.receive_hit(13,false,ctx)
		game.effects.burst(aim_center(),CombatEffects.GOLD,10)
		Sound.play("hit",-4,.8)
		flight_left=0
	if flight_left<=0:
		visual.position.y=0
		visual.rotation.z=0
		if not dead:
			state="recover"
			timer=.65
			if visual.motion:visual.motion.recover()

func damaged_fridge() -> EnemyActor:
	var best:EnemyActor
	var distance:=9.0
	for other in game.enemies:
		if not is_instance_valid(other) or other.dead or other.dummy or other.kind!="fridge" or other.health>=other.max_health:continue
		var d:=position.distance_to(other.position)
		if d<distance and game.line_of_sight(aim_center(),other.aim_center()):
			best=other
			distance=d
	return best

func can_repair() -> bool:
	return is_instance_valid(repair_target) and not repair_target.dead and repair_target.health<repair_target.max_health and position.distance_to(repair_target.position)<4.5 and game.line_of_sight(aim_center(),repair_target.aim_center())

func update_weld_beam() -> void:
	if not weld_beam:return
	weld_beam.visible=state=="weld" and not dead and is_instance_valid(repair_target)
	if not weld_beam.visible:return
	var from := visual.motion.socket(&"Nozzle")
	var to := repair_target.aim_center()
	var beam := to-from
	if beam.length_squared()<.0001:
		weld_beam.hide()
		return
	weld_beam.global_position=(from+to)*.5
	weld_beam.basis=Basis(Quaternion(Vector3.UP,beam.normalized())).scaled_local(Vector3(1,beam.length(),1))

func aim_center() -> Vector3:
	return global_position + Vector3.UP * (.78 if flying else .9)

func _physics_process(delta: float) -> void:
	update_weld_beam()
	if dead:
		if death_time > 0.0:
			var death_delta: float = delta * game.hostile_time_scale
			visual.animate(death_delta, 0, "death")
			death_time -= death_delta
			var progress := (death_length + .24 - death_time) / death_length
			if flying:
				global_position.y = lerpf(crash_start,crash_floor,BadlandsEnemyMotion.descent(progress))
			if not struck_ground and progress >= float(BadlandsEnemyMotion.IMPACT_PHASE[kind]):
				struck_ground = true
				var contact := visual.motion.socket(&"Cabinet")
				contact.y = global_position.y+.03
				game.effects.fall_contact(contact,kind)
				Sound.play("hit",-13 if kind != "boss" else -5,.67 if kind in ["fridge","boss"] else 1.08)
			if death_time < .16:
				for mesh in visual.renderers:
					mesh.transparency = clampf(1.0-death_time/.16,0,1)
			if death_time <= 0.0: queue_free()
		return
	if not is_instance_valid(game.player):return
	if dummy:visual.animate(delta,0,"idle");return
	var dt: float = delta*game.hostile_time_scale
	pull_credit=maxf(0,pull_credit-dt)
	shield_flash=maxf(0,shield_flash-dt)
	if flight_left>0:
		advance_fling(dt)
		return
	if flying:
		flight_age += dt
		var height := BadlandsEnemyMotion.CRUISE_HEIGHT * BadlandsEnemyMotion.ascent(flight_age/BadlandsEnemyMotion.TAKEOFF_TIME)
		global_position.y = launch_height + height
		if flight_age < BadlandsEnemyMotion.TAKEOFF_TIME:
			visual.animate(dt,0,"takeoff")
			grace = maxf(0,grace-dt)
			return
	if kind=="chili" and visual.motion:
		var local_velocity := visual.global_basis.inverse()*velocity
		visual.motion.local_travel=Vector2(local_velocity.x,local_velocity.z)
	visual.animate(dt,Vector2(velocity.x,velocity.z).length(),state)
	if grace>0:grace-=dt;return
	if game.player.dead:return
	cooldown=maxf(0,cooldown-dt);timer-=dt;path_timer-=dt
	var offset: Vector3 = game.player.global_position-global_position;offset.y=0
	var distance:=offset.length()
	var desired:=Vector3.ZERO
	if state in ["vent","vent_open"]:
		velocity=Vector3.ZERO
		return
	if formation_guard:
		if distance<5.5 or health<=0 or game.run_time-game.bottleneck_time>11:
			formation_guard=false
		elif kind!="repair":
			velocity=Vector3.ZERO
			return
	if state=="chase":
		var goal: Vector3 = game.player.global_position
		if kind=="repair":
			repair_clock-=dt
			if repair_clock<=0:
				repair_target=damaged_fridge()
				repair_clock=.42
			if is_instance_valid(repair_target) and not repair_target.dead:goal=repair_target.position
			if can_repair() and cooldown<=0:
				state="weld";timer=.85
				if visual.motion:visual.motion.windup(timer,false)
				update_weld_beam()
				return
		if kind in ["chili","pigeon"]:
			if distance<5:goal=global_position-offset.normalized()*3
			elif distance<8:goal=global_position+offset.normalized().cross(Vector3.UP)*1.3
		if flying:
			if game.county:
				goal=game.county.clamp_point(goal)
			else:
				goal.x=clampf(goal.x,-12.7,12.7)
				goal.z=clampf(goal.z,-9.7,9.7)
			var air_direction := goal - global_position
			air_direction.y = 0
			desired = air_direction.normalized()*movement_speed
		elif path_timer<=0:
			path_timer=.28+randf()*.12
			if NavigationServer3D.map_get_iteration_id(navigation.get_navigation_map())>0:navigation.target_position=goal
		if not flying and not navigation.is_navigation_finished():
			var next:=navigation.get_next_path_position();var path_direction:=next-global_position;path_direction.y=0
			desired=path_direction.normalized()*movement_speed
		if cooldown<=0 and game.line_of_sight(global_position+Vector3.UP,game.player.global_position+Vector3.UP):
			if distance<spec.attack_range:_begin_attack(offset.normalized())
	elif state=="weld":
		if not can_repair():
			state="recover";timer=.45
		elif timer<=0:
			repair_target.health=minf(repair_target.max_health,repair_target.health+24)
			game.effects.tracer(aim_center(),repair_target.aim_center(),Color("72edce"),.085)
			game.effects.burst(repair_target.aim_center(),Color("72edce"),9)
			Sound.play("pickup",-10,1.2)
			if visual.motion:visual.motion.strike()
			state="recover";timer=.7
	elif state=="windup":
		if timer<=0:_release_attack()
	elif state=="charge":
		desired=direction*(10 if kind=="boss" else 8)
		if kind in ["fridge","skillet","boss"]:game.player.near_dodge(aim_center(),1.45 if kind=="boss" else 1.15)
		if not hit_in_charge and distance< (1.10 if kind=="boss" else .8):
			if game.player.receive_hit(spec.damage,false,{}):hit_in_charge=true
		if timer<=0 or (is_on_wall() and timer<.3):
			state="recover";timer=.9
			if visual.motion: visual.motion.recover()
	elif state=="burst":
		if timer<=0:
			var angle: float = (burst_left-2)*.07
			var muzzle := global_position + Vector3.UP * 1.05
			if visual.motion:
				visual.motion.strike(.16)
				muzzle = visual.motion.socket(&"Muzzle")
			game.spawn_projectile(muzzle,direction.rotated(Vector3.UP,angle)*spec.projectile_speed,spec.damage,"enemy")
			Sound.play("shot",-14,1.4)
			burst_left-=1;timer=.16
			if burst_left<=0:state="recover";timer=.65
	elif state=="recover":
		if timer<=0:state="chase";cooldown=1.5 if kind=="boss" and phase_two else spec.recovery_seconds
	# Gentle separation is deterministic and independent of physics pushes.
	var separation:=Vector3.ZERO
	for other in game.enemies:
		if other==self or not is_instance_valid(other) or other.dead:continue
		var d: Vector3 = global_position-other.global_position;d.y=0
		if d.length_squared()<.65 and d.length_squared()>.001:separation+=d.normalized()*(.8-d.length())*2.5
	pull_velocity=pull_velocity.limit_length(6)
	velocity=(desired+separation+pull_velocity)*game.hostile_time_scale
	velocity.y=0.0 if flying else -1.0
	move_and_slide()
	pull_velocity=pull_velocity.move_toward(Vector3.ZERO,delta*20)
	var look:=direction if state in ["windup","charge","burst"] else offset.normalized()
	if state=="weld" and is_instance_valid(repair_target):look=repair_target.position-position
	if look.length_squared()>.001:visual.rotation.y=lerp_angle(visual.rotation.y,atan2(look.x,look.z),dt*(2.2 if kind=="skillet" else 10.0))
	if flying:
		var lateral := velocity.dot(visual.global_basis.x)
		visual.rotation.z = lerpf(visual.rotation.z,clampf(-lateral*.072,-.22,.22),minf(1,dt*5))

func _begin_attack(dir: Vector3) -> void:
	direction=dir;state="windup";timer=spec.warning_seconds;hit_in_charge=false
	if visual.motion: visual.motion.windup(timer, kind == "boss" and attack_count % 2 == 1)
	target_point=game.player.global_position
	if kind=="pigeon":
		target_point+=game.player.velocity*.12;target_point.y=.04
		game.effects.ring(target_point,1.6,CombatEffects.DANGER,timer+.9)
	else:
		if kind=="boss" and attack_count%2==1:
			for i in range(9):game.effects.warning_line(global_position,global_position+direction.rotated(Vector3.UP,(i-4)*.17)*9,timer,.02)
		else:game.effects.warning_line(global_position,global_position+direction*(7 if kind=="boss" else 4.5),timer,.035)
		game.effects.ring(global_position,.65,CombatEffects.DANGER,timer)
	Sound.play("warning",-14 if kind!="boss" else -5,1.1)

func _release_attack() -> void:
	if kind=="repair":
		if visual.motion:visual.motion.strike()
		var muzzle := visual.motion.socket(&"Nozzle") if visual.motion else aim_center()
		game.spawn_projectile(muzzle,(game.player.global_position+Vector3.UP-muzzle).normalized()*7,9,"enemy")
		state="recover";timer=.75
	elif kind=="pigeon":
		if visual.motion: visual.motion.strike()
		var origin := visual.motion.socket(&"Egg") if visual.motion else global_position+Vector3.UP*1.6
		var egg=game.spawn_projectile(origin,Vector3.ZERO,20,"enemy")
		if egg:
			if flying: egg.global_basis = visual.motion.payload.global_basis.orthonormalized()
			egg.set_lob(target_point,.9)
		state="recover";timer=1.1
	elif kind=="chili":state="burst";burst_left=3;timer=0
	elif kind=="boss" and attack_count%2==1:
		if visual.motion: visual.motion.strike()
		var vent := visual.motion.socket(&"Vent") if visual.motion else global_position+Vector3.UP*1.1
		for i in range(9):game.spawn_projectile(vent,direction.rotated(Vector3.UP,(i-4)*.17)*7.5,16,"enemy")
		game.effects.burst(vent,CombatEffects.DANGER,10)
		state="recover";timer=.9 if phase_two else 1.4;attack_count+=1
		Sound.play("explosion",-5,.7)
	else:
		state="charge";timer=.55 if kind!="boss" else .75;attack_count+=1
		if visual.motion: visual.motion.strike(timer)

func receive_hit(amount: float, critical: bool = false, context: Dictionary = {}) -> void:
	if dead:return
	if context.has("budget"):
		if int(context.budget.events)>=game.config.max_chain_events:return
		context.budget.events+=1
	if kind=="skillet" and state in ["chase","windup"] and context.has("impact_from"):
		var incoming:Vector3=context.impact_from-aim_center()
		incoming.y=0
		if visual.global_basis.z.dot(incoming.normalized())>.45:
			if shield_flash<=0:
				game.effects.burst(aim_center()+visual.global_basis.z*.30,CombatEffects.GOLD,7)
				Sound.play("ricochet",-12,.75)
				game.effects.caption(aim_center()+Vector3.UP*.65,"GUARDED",CombatEffects.GOLD)
				shield_flash=.65
			return
	if state=="weld" and amount>=10:
		state="recover"
		timer=.6
	if state=="vent_open":amount*=1.5
	formation_guard=false
	health-=amount
	visual.hit()
	game.effects.number(global_position+Vector3.UP*(2.4 if kind=="boss" else 1.6),amount,critical)
	Sound.play("hit",-9,randf_range(.9,1.1))
	if dummy:
		health=max_health
		return
	if kind=="boss" and not phase_two and health<=max_health*.5:
		phase_two=true
		game.boss_enraged()
	if health<=0:
		collapse()
		game.enemy_killed(self,critical,context)
		game.effects.burst(global_position+Vector3.UP*.8,CombatEffects.GREEN if critical else CombatEffects.GOLD,12,1.3)
		Sound.play("kill",-7,randf_range(.8,1.2))

func collapse() -> void:
	if dead: return
	dead=true;collision_layer=0
	if visual.motion:
		death_length = visual.motion.die()
		death_time = death_length + .24
		if flying:
			crash_start = global_position.y
			var down := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.25,global_position+Vector3.DOWN*8,1|8,[get_rid()])
			var surface := get_world_3d().direct_space_state.intersect_ray(down)
			crash_floor = float(surface.position.y) if surface.has("position") else launch_height
	if not visual.motion:
		var tween:=create_tween()
		tween.tween_property(visual,"scale",Vector3.ZERO,.25)
		tween.tween_callback(queue_free)
