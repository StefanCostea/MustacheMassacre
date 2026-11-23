extends Node3D

const MODEL := preload("res://assets/characters/general_coo/general_coo.glb")
const WINGMAN := preload("res://assets/enemies/animated/pigeon_bomber.glb")
const HOT := Color("ff9e4d")
const HOP := .39
const VENT := 1.35
const GLIDE := 2.5
var hero: EspinoPlayer
var rig: Skeleton3D
var animator: AnimationPlayer
var hand_index := -1
var fallen_grip:=Transform3D.IDENTITY
var gun:=Node3D.new()
var rotor:=Node3D.new()
var nozzle:=Marker3D.new()
var heat := 0.0
var spin := 0.0
var rest := 2.0
var vent_left := 0.0
var timed_vent := false
var burst_left := 0
var hop_left := 0.0
var strike_age := -1.0
var next_drop := 0
var flock: Array[Node3D] = []
var strike_start := Vector3.ZERO
var strike_heading := Vector3.BACK
var strike_chain := {}
var whiskers=preload("res://scripts/coo_whiskers.gd").new()
var pods: Array[Node3D]=[]

func setup(owner_hero: EspinoPlayer) -> void:
	hero=owner_hero
	var body=MODEL.instantiate()
	add_child(body)
	rig=body.find_children("*","Skeleton3D",true,false)[0]
	animator=body.find_children("*","AnimationPlayer",true,false)[0]
	hand_index=rig.find_bone("PalmR")
	for clip in ["idle","move","backstep","strafe_left","strafe_right"]:
		animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	add_child(gun)
	var brass:=MeshKit.material(Color("ce9851"),.35,.60)
	var metal:=MeshKit.material(Color("374b50"),.37,.68)
	var paint:=MeshKit.material(Color("805339"),.7,.3)
	MeshKit.box(gun,Vector3(.23,.27,.36),Vector3(0,-.015,.06),paint,.06)
	MeshKit.box(gun,Vector3(.09,.15,.12),Vector3(0,.12,-.05),metal,.025)
	var saddle:=MeshKit.ring(gun,Vector3(0,.11,-.045),.124,.042,paint)
	saddle.scale.y=.8
	for side:float in [-1.,1.]:
		MeshKit.sphere(gun,Vector3(side*.113,.095,-.038),Vector3(.021,.025,.024),brass)
	gun.add_child(rotor)
	rotor.position.z=.22
	for i in 6:
		var angle:=TAU*i/6
		var radial:=Vector3(cos(angle)*.082,sin(angle)*.082,0)
		MeshKit.beam(rotor,radial,radial+Vector3.BACK*.41,.039,metal)
		MeshKit.beam(rotor,radial+Vector3.BACK*.37,radial+Vector3.BACK*.42,.042,brass)
		MeshKit.beam(rotor,radial+Vector3.BACK*.421,radial+Vector3.BACK*.424,.025,MeshKit.material(Color("251f19")))
	for z in [.22,.49]:
		MeshKit.beam(gun,Vector3.BACK*z,Vector3.BACK*(z+.05),.13,brass)
	gun.add_child(nozzle)
	nozzle.position.z=.65
	rig.add_child(whiskers)
	for side in ["R","L"]:
		var pod:=Node3D.new()
		add_child(pod)
		for i in 3:
			var angle:=TAU*i/3.
			var offset:=Vector3(cos(angle)*.054,sin(angle)*.054,0)
			MeshKit.beam(pod,offset,offset+Vector3.BACK*.38,.035,metal)
			MeshKit.beam(pod,offset+Vector3.BACK*.33,offset+Vector3.BACK*.385,.041,brass)
			MeshKit.beam(pod,offset+Vector3.BACK*.386,offset+Vector3.BACK*.389,.028,MeshKit.material(Color("251f19")))
		pods.append(pod)
		pod.hide()
	action("idle")

func update_whiskers() -> void:
	var spread:float=0.0 if strike_age<0 else smoothstep(0,.45,strike_age)*(1.-smoothstep(GLIDE-.38,GLIDE,strike_age))
	whiskers.spread=spread
	for i in pods.size():
		var pod:=pods[i]
		pod.visible=spread>.005
		if not pod.visible:continue
		var bone:=rig.find_bone("WhiskerTipR" if i==0 else "WhiskerTipL")
		pod.global_position=rig.to_global(rig.get_bone_global_pose(bone).origin)
		pod.global_basis=Basis.looking_at(hero.aim_direction,Vector3.UP,true)*Basis(Vector3.BACK,strike_age*27.*(-1. if i==0 else 1.))
		pod.scale*=maxf(.001,spread)

func action(clip: String) -> void:
	if clip=="death":fallen_grip=(rig.global_transform*rig.get_bone_global_pose(hand_index)).affine_inverse()*gun.global_transform
	if animator.current_animation!=clip:animator.play(clip,.06)

func tick(dt: float) -> void:
	rest+=dt
	vent_left=maxf(0,vent_left-dt)
	if vent_left>0:
		heat=move_toward(heat,0,dt/VENT)
	elif rest>.18:
		heat=move_toward(heat,0,dt*.25)
	spin=move_toward(spin,1. if rest<.23 else 0.,dt*(1.35 if rest<.23 else 1.8))
	hop_left=maxf(0,hop_left-dt)
	rotor.rotate_z(dt*(3.+spin*33.))
	if strike_age>=0:advance_strike(dt)
	update_whiskers()
	if burst_left>0 and hero.shoot_cooldown<=0:
		if not fire():burst_left=0
		else:burst_left-=1
	var motion:=Vector3(hero.velocity.x,0,hero.velocity.z)
	var pose:="idle"
	if hop_left>0:pose="hop"
	elif vent_left>0:pose="vent"
	elif rest<.13:pose="fire"
	elif motion.length()>.4:
		var local:=hero.visual.global_basis.inverse()*motion
		if absf(local.x)>absf(local.z)*1.25:pose="strafe_right" if local.x>0 else "strafe_left"
		else:pose="backstep" if local.z<0 else "move"
	if animator.current_animation!="hurt" and animator.current_animation!="cast":action(pose)
	position.y=0
	align_gun()

func align_gun() -> void:
	if hero.dead:
		gun.global_transform=rig.global_transform*rig.get_bone_global_pose(hand_index)*fallen_grip
		return
	var palm:=rig.to_global(rig.get_bone_global_pose(hand_index).origin)
	gun.global_position=palm+hero.visual.global_basis*Vector3(0,-.075,.055)-hero.aim_direction*.047*sin(PI*clampf(rest/.10,0.,1.))
	var aim:=hero.aim_direction
	if hero.elevated_aim:aim=gun.global_position.direction_to(hero.aim_point)
	if aim.length_squared()<.001:aim=Vector3.BACK
	var kick:=.095*sin(PI*clampf(rest/.10,0.,1.))
	var carry:=kick if rest<.18 else lerpf(0.,-.38,smoothstep(.18,.35,rest)) if vent_left==0 else .5
	var barrel:=(aim+Vector3.UP*carry).normalized()
	gun.global_basis=Basis.looking_at(barrel,Vector3.UP,true)

func fire() -> bool:
	if hero.dead or vent_left>0 or hero.shoot_cooldown>0:return false
	rest=0
	align_gun()
	var critical:=hero.quickdraw_ready or timed_vent or (heat>.78 and "last_word" in hero.upgrades)
	hero.quickdraw_ready=false
	timed_vent=false
	hero.shot_count+=1
	var direction:=hero.aim_point-nozzle.global_position
	if not hero.elevated_aim:direction.y=0
	if direction.length_squared()<.001:direction=hero.aim_direction
	var hops:=(3 if hero.ricochet_armed else 0)+int("bounce" in hero.upgrades)+int("pinball" in hero.upgrades)
	var blast:bool="explosive" in hero.upgrades and hero.shot_count%hero.config.explosive_every==0
	hero.game.fire_player(direction.normalized(),critical,hops,blast,10.0,"rotary")
	if whiskers.spread>.75 and hero.shot_count%3==0:
		for pod in pods:
			var tracer=hero.game.spawn_projectile(pod.global_position+hero.aim_direction*.33,direction.normalized()*24,7.,"player",hero.game.new_context("whisker_rotary"))
			tracer.remaining=.72
	hero.ricochet_armed=false
	hero.combat_idle=0
	hero.shoot_cooldown=lerpf(.18,.066,spin)/(1.25 if "trigger" in hero.upgrades else 1.)
	heat=minf(1.,heat+.052)
	Sound.play("shot",-11,1.28+spin*.18)
	hero.game.shake(.023)
	if heat>=.999:start_vent()
	return true

func burst() -> bool:
	if burst_left>0 or not fire():return false
	burst_left=2
	return true

func start_vent() -> void:
	if vent_left>0:
		if vent_left>.38 and vent_left<.68:
			vent_left=0
			heat=0
			timed_vent=true
			hero.add_stache(5)
			Sound.play("perfect",-6)
		return
	if heat<.07:return
	vent_left=VENT
	burst_left=0
	action("vent")
	Sound.play("reload",-6,.83)

func egg(point: Vector3, origin: Vector3, damage: float, context: Dictionary) -> void:
	var target:Vector3=hero.game.field_target(point)
	var bomb=hero.game.spawn_projectile(origin,Vector3.ZERO,damage,"player",context)
	bomb.set_lob(target,.68)
	hero.game.effects.ring(target,.85,CombatEffects.GOLD,.67,.8,false)

func field() -> bool:
	if hero.dead or hero.e_cooldown>0:return false
	hero.e_cooldown=hero.config.vortex_cooldown
	action("cast")
	var context:Dictionary=hero.game.new_context("egg_drop")
	egg(hero.aim_point,global_position+Vector3.UP*1.48,35,context)
	if "aftershock" in hero.upgrades:
		egg(hero.aim_point+hero.visual.global_basis.x*1.5,global_position+Vector3.UP*2.6,28,context)
	return true

func start_strike() -> bool:
	if hero.dead or hero.stache<100 or strike_age>=0:return false
	hero.stache=0
	strike_age=0
	next_drop=0
	strike_start=hero.game.field_target(hero.aim_point)
	strike_heading=hero.aim_direction
	strike_chain=hero.game.new_context("coo_bombing")
	for i in 3:
		var bird:Node3D=WINGMAN.instantiate()
		hero.game.actors.add_child(bird)
		bird.scale=Vector3.ONE*.64
		bird.rotation.y=atan2(strike_heading.x,strike_heading.z)
		var flight:AnimationPlayer=bird.find_children("*","AnimationPlayer",true,false)[0]
		flight.play("move")
		flock.append(bird)
	advance_strike(0)
	hero.game.ui.toast("CARPET COO-BOMBING","Sweep your aim to designate egg drops.",CombatEffects.GOLD)
	Sound.play("ultimate",-5,.88)
	return true

func advance_strike(dt: float) -> void:
	strike_age+=dt
	var right:=Vector3(strike_heading.z,0,-strike_heading.x)
	for i in flock.size():
		flock[i].global_position=strike_start+strike_heading*(strike_age*7.5-8.-abs(i-1)*1.3)+right*(i-1)*1.45+Vector3.UP*(3.4+.14*sin(strike_age*6+i))
	if next_drop<6 and strike_age>=.48+.25*next_drop:
		var bird:=flock[next_drop%3]
		egg(hero.aim_point+right*(next_drop%3-1)*.85,bird.global_position,35,strike_chain)
		next_drop+=1
	if strike_age>=GLIDE:clear_flock()

func clear_flock() -> void:
	for bird in flock:
		if is_instance_valid(bird):bird.queue_free()
	flock.clear()
	strike_age=-1
	update_whiskers()
