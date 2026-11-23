class_name EspinoPlayer
extends CharacterBody3D

var game
var config: CombatConfig
var health: float = 100
var ammo: int = 6
var stache: float = 0.0
var dead: bool = false
var aim_direction: Vector3 = Vector3.FORWARD
var aim_point: Vector3 = Vector3.ZERO
var elevated_aim := false
var shoot_cooldown: float = 0.0
var reload_elapsed: float = -1.0
var reload_attempted: bool = false
var empowered: bool = false
var rounds_spent: int = 0
var invulnerable: float = 0.0
var dash_left: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction: Vector3
var q_cooldown: float = 0.0
var e_cooldown: float = 0.0
var ricochet_armed: bool = false
var frenzy_left: float = 0.0
var quickdraw_ready: bool = false
var combat_idle: float = 0.0
var shot_count: int = 0
var upgrades: Array[String] = []
var visual: Node3D
const HighNoonForm = preload("res://scripts/high_noon_form.gd")
var form: HighNoonForm
const SaguaroLance = preload("res://scripts/saguaro_lance.gd")
var lance: SaguaroLance
var field_skill := "tumbleweed"
var coo: Node3D
var is_coo := false
var fan_left := 0
var dodge_rewarded := false
var equipped_special := "high_noon"
const SpecialFlourish = preload("res://scripts/special_flourish.gd")
var flourish: SpecialFlourish
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
const EspinoFirePose = preload("res://scripts/espino_fire_pose.gd")
var fire_pose: EspinoFirePose
var action_node: AnimationNodeAnimation
var animation_names: Dictionary = {}
var muzzle: Node3D
var move_blend: Vector2 = Vector2.ZERO
var input_lock: float = 0.1
var test_move: Vector2 = Vector2.ZERO
var test_aim: Vector3 = Vector3.ZERO
var test_mode: bool = false
var knockback: Vector3 = Vector3.ZERO

func setup(director, tuning: CombatConfig) -> void:
	game=director;config=tuning;health=config.player_health
	name="DonEspino"
	equipped_special=Preferences.special
	field_skill=Preferences.field_skill
	collision_layer=2;collision_mask=1|8
	var collider:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=.33;capsule.height=1.8;collider.shape=capsule;collider.position.y=.9
	add_child(collider)
	visual=Node3D.new();visual.name="Visual";add_child(visual)
	var motion_study := "--espino-motion-study" in OS.get_cmdline_user_args()
	var natural_hero:bool=motion_study or "--natural-hero" in OS.get_cmdline_user_args()
	var path:="res://assets/characters/don_espino_natural_review/don_espino_natural.glb" if natural_hero else "res://assets/characters/don_espino/don_espino.glb"
	if motion_study:
		path = "res://assets/characters/don_espino_motion_study/don_espino_study.glb"
	if ResourceLoader.exists(path):
		var model:Node3D=load(path).instantiate();visual.add_child(model);model.scale=Vector3.ONE*.62
		var found:=model.find_children("*","AnimationPlayer",true,false)
		if not found.is_empty():animation_player=found[0];_setup_animations(motion_study)
		muzzle=model.find_child("Muzzle",true,false) as Node3D
	else:
		MeshKit.cylinder(visual,Vector3(0,1.25,0),.34,1.5,MeshKit.material(Color("67943c")))
		MeshKit.cylinder(visual,Vector3(0,2.05,0),.65,.12,MeshKit.material(Color("765030")))
		MeshKit.cylinder(visual,Vector3(0,2.28,0),.4,.5,MeshKit.material(Color("765030")))
		for sign in [-1,1]:MeshKit.sphere(visual,Vector3(sign*.22,1.62,.33),Vector3(.3,.11,.1),MeshKit.material(Color("50301e")))
	form=HighNoonForm.new();form.name="HighNoonForm";visual.add_child(form)
	form.setup(self)
	lance=SaguaroLance.new();lance.name="SaguaroLance";visual.add_child(lance);lance.setup(self)
	flourish=SpecialFlourish.new();visual.add_child(flourish);flourish.setup(self)
	equip_hero(Preferences.hero_id)

func equip_hero(id: String) -> void:
	is_coo=id=="coo"
	if is_coo and not coo:
		coo=preload("res://scripts/general_coo.gd").new()
		visual.add_child(coo)
		coo.setup(self)
	if coo:
		coo.visible=is_coo
		if not is_coo:coo.clear_flock()
	visual.get_child(0).visible=not is_coo
	if animation_tree:animation_tree.active=not is_coo
	if is_coo:
		flourish.stop()
		form.show_momentum(0)


func _setup_animations(motion_study: bool) -> void:
	for full in animation_player.get_animation_list():
		for clip in ["idle","run_forward","run_backward","strafe_left","strafe_right","shoot","reload","dash","hurt","death","cast","ultimate"]:
			if str(full).to_lower().ends_with(clip):animation_names[clip]=full
	if not animation_names.has("idle"):return
	var blend:=AnimationNodeBlendTree.new()
	var locomotion:=AnimationNodeBlendSpace2D.new()
	for data in [["idle",Vector2.ZERO],["run_forward",Vector2(0,1)],["run_backward",Vector2(0,-1)],["strafe_left",Vector2(-1,0)],["strafe_right",Vector2(1,0)]]:
		if not animation_names.has(data[0]):continue
		var node:=AnimationNodeAnimation.new();node.animation=animation_names[data[0]]
		animation_player.get_animation(node.animation).loop_mode=Animation.LOOP_LINEAR
		locomotion.add_blend_point(node,data[1],-1,data[0])
	blend.add_node("locomotion",locomotion,Vector2(0,0))
	action_node=AnimationNodeAnimation.new();action_node.animation=animation_names.idle
	blend.add_node("action_clip",action_node,Vector2(0,180))
	var shot:=AnimationNodeOneShot.new();shot.fadein_time=.04;shot.fadeout_time=.10;shot.filter_enabled=true
	# Import can strip constant tracks from idle, including the reload-only cylinder.
	var filter_clips := ["idle", "reload", "shoot"] if motion_study else ["idle"]
	for clip in filter_clips:
		if not animation_names.has(clip):continue
		var animation := animation_player.get_animation(animation_names[clip])
		for i in range(animation.get_track_count()):
			var path := animation.track_get_path(i)
			var track_name := str(path).to_lower()
			for token in ["head","torso","upper_arm","forearm","hand","finger","thumb","weapon","spine","neck","shoulder","leftarm","rightarm","stache"]:
				if token in track_name:
					shot.set_filter_path(path,true)
					break
	blend.add_node("action",shot,Vector2(250,0))
	animation_tree=AnimationTree.new();add_child(animation_tree)
	if motion_study:
		fire_pose=EspinoFirePose.new()
		fire_pose.setup(animation_tree,blend,animation_player,animation_names.shoot)
		blend.connect_node("action",0,"gun_arm")
	else:
		blend.connect_node("action",0,"locomotion")
	blend.connect_node("action",1,"action_clip")
	blend.connect_node("output",0,"action")
	animation_tree.anim_player=animation_tree.get_path_to(animation_player)
	animation_tree.tree_root=blend;animation_tree.active=true

func animate_action(clip: String) -> void:
	if is_coo:
		if clip in ["hurt","death","cast"]:coo.action(clip)
		return
	if not animation_names.has(clip):return
	if fire_pose:
		if clip=="shoot":
			fire_pose.fire(shoot_cooldown)
			return
		fire_pose.release()
	if clip=="death":
		if animation_tree:animation_tree.active=false
		animation_player.play(animation_names[clip],.08)
	elif animation_tree:
		action_node.animation=animation_names[clip]
		animation_tree.set("parameters/action/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _unhandled_input(event: InputEvent) -> void:
	if dead or input_lock>0 or game.automation:return
	if event.is_action_pressed("reload"):reload_input()
	if event.is_action_pressed("dash"):dash()
	if event.is_action_pressed("ricochet"):arm_ricochet()
	if event.is_action_pressed("tumbleweed"):use_field_skill()
	if event.is_action_pressed("fan_hammer"):fan_hammer()
	if event.is_action_pressed("ultimate"):use_special()

func _physics_process(delta: float) -> void:
	if dead:
		if is_coo:
			position.y=move_toward(position.y,0.,delta*3.)
			coo.align_gun()
		return
	input_lock=maxf(0,input_lock-delta)
	shoot_cooldown=maxf(0,shoot_cooldown-delta);invulnerable=maxf(0,invulnerable-delta)
	dash_cooldown=maxf(0,dash_cooldown-delta);q_cooldown=maxf(0,q_cooldown-delta);e_cooldown=maxf(0,e_cooldown-delta)
	frenzy_left=maxf(0,frenzy_left-delta)
	if is_coo:coo.tick(delta)
	else:
		form.advance(delta)
		flourish.advance(delta)
	combat_idle+=delta
	if combat_idle>5 and game.is_fighting() and (not game.county or game.county.in_danger()):stache=maxf(0,stache-delta*2)
	if reload_elapsed>=0:
		reload_elapsed+=delta
		if reload_elapsed>=config.reload_seconds:finish_reload(false)
	if fire_pose:fire_pose.advance(delta)
	_update_aim()
	var input:Vector2=test_move if test_mode else Input.get_vector("move_left","move_right","move_forward","move_back")
	var basis:Basis=game.camera.global_basis
	var back:=Vector3(basis.z.x,0,basis.z.z).normalized()
	var desired:Vector3=basis.x*input.x+back*input.y;desired.y=0;desired=desired.normalized()
	if dash_left>0:
		dash_left-=delta;velocity=dash_direction*config.dash_speed
	else:velocity=desired*config.movement_speed*(.28 if lance.running else 1.0)
	velocity+=knockback
	knockback=knockback.move_toward(Vector3.ZERO,delta*18)
	if form.running:
		var altitude := (.55 + .075*sin((form.age-.68)*6.2)) * form.lift
		velocity.y = clampf((altitude-global_position.y)/maxf(delta,.001),-4.5,4.5)
	elif is_coo and coo.hop_left>0:
		var altitude:float=.81*sin(PI*coo.hop_left/coo.HOP)
		velocity.y=clampf((altitude-position.y)/maxf(delta,.001),-8.,8.)
	else:velocity.y=-maxf(1.,position.y*12.) if is_coo else -1.
	move_and_slide()
	lance.advance(delta)
	var facing := lance.heading if lance.running else aim_direction
	if form.running:
		if form.age < HighNoonForm.FIRST_SPIKE: facing=form.cast_facing
		elif form.aim_hold>0 and form.shot_facing.length_squared()>.01: facing=form.shot_facing
	visual.rotation.y=atan2(facing.x,facing.z)
	visual.rotation.z=lerpf(visual.rotation.z,-desired.dot(visual.basis.x)*.14*form.lift,minf(delta*9,1))
	visual.rotation.x=lerpf(visual.rotation.x,-.10*form.lift,minf(delta*9,1))
	if animation_tree:
		var right:=Vector3(aim_direction.z,0,-aim_direction.x)
		var local_move:=Vector2(desired.dot(right),desired.dot(aim_direction))
		move_blend=move_blend.lerp(local_move,minf(1,delta*14))
		animation_tree.set("parameters/locomotion/blend_position",move_blend)
	if fan_left>0 and shoot_cooldown<=0:try_fire(true)
	if not test_mode and Input.is_action_pressed("fire") and input_lock<=0:try_fire()

func _update_aim() -> void:
	elevated_aim = false
	if test_mode:
		aim_point=test_aim
		elevated_aim = test_aim.y > 1.5
	else:
		var mouse:=get_viewport().get_mouse_position()
		aim_from_screen(mouse)
	var direction:=aim_point-global_position;direction.y=0
	if direction.length_squared()>.02:aim_direction=direction.normalized()

func aim_from_screen(mouse: Vector2) -> void:
	var displayed := get_viewport().get_camera_3d()
	var origin: Vector3 = displayed.project_ray_origin(mouse)
	var ray: Vector3 = displayed.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin+ray*100, 1|4|8)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var body=hit.get("collider")
	elevated_aim = (body is EnemyActor and body.flying) or (body is Node and body.is_in_group("county_switches"))
	if elevated_aim or ((form.running or lance.running) and hit.get("collider") is EnemyActor):
		aim_point = hit.position
	else:
		var point = Plane(Vector3.UP,0).intersects_ray(origin,ray)
		if point != null: aim_point = point

func get_muzzle() -> Vector3:
	if is_coo:return coo.nozzle.global_position
	if form and form.running and form.arm_growth>.75:return form.tip.global_position
	if is_instance_valid(muzzle):return muzzle.global_position
	return global_position+Vector3.UP*1.2+aim_direction*.65

func fan_hammer() -> bool:
	if is_coo:return coo.burst()
	if dead or form.running or lance.running or reload_elapsed>=0 or fan_left>0 or ammo<=0:return false
	fan_left=ammo
	if shoot_cooldown<=0:try_fire(true)
	return true

func try_fire(fanning := false) -> bool:
	if is_coo:return coo.fire()
	if fan_left>0 and not fanning:return false
	if dead or lance.running or shoot_cooldown>0 or reload_elapsed>=0:return false
	if form.running:
		if form.age<HighNoonForm.FIRST_SPIKE or form.arm_growth<.85:return false
	else:
		if ammo<=0:reload_input();return false
		ammo-=1;rounds_spent+=1
	shot_count+=1
	var rate:=config.hair_trigger_multiplier if "trigger" in upgrades else 1.0
	if frenzy_left>0:rate*=config.frenzy_fire_multiplier
	shoot_cooldown=config.shot_interval/rate
	if fanning:
		fan_left-=1
		shoot_cooldown=.09/rate
	var critical:=empowered or quickdraw_ready or (fanning and ammo==0 and "last_word" in upgrades)
	quickdraw_ready=false
	var hops:=3 if ricochet_armed else 0
	if "bounce" in upgrades:hops+=1
	if "pinball" in upgrades:hops+=1
	if frenzy_left>0:hops+=1
	var explosive := "explosive" in upgrades and shot_count%config.explosive_every==0
	if form.running:
		var target := aim_point
		if target.y < .15: target.y=1.0
		game.launch_thorn(target,config.shot_damage*(config.critical_multiplier if critical else 1.0),critical,hops,explosive)
	else:
		animate_action("shoot")
		var shot_direction:=aim_point-get_muzzle()
		if not elevated_aim: shot_direction.y=0
		if shot_direction.length_squared()<.01:shot_direction=aim_direction
		game.fire_player(shot_direction.normalized(),critical,hops,explosive)
	ricochet_armed=false;combat_idle=0
	Sound.play("shot",-3,randf_range(.95,1.05))
	game.shake(.055)
	return true

func reload_input() -> void:
	if is_coo:
		coo.start_vent()
		return
	if dead or form.running or lance.running or fan_left>0:return
	if reload_elapsed>=0:
		if not reload_attempted:
			reload_attempted=true
			if reload_elapsed>=config.perfect_start and reload_elapsed<=config.perfect_end:finish_reload(true)
		return
	if ammo==6:return
	reload_elapsed=0;reload_attempted=false;empowered=false
	animate_action("reload");Sound.play("reload",-3)

func finish_reload(perfect: bool) -> void:
	var reward:=rounds_spent>0
	ammo=6;reload_elapsed=-1;empowered=perfect;rounds_spent=0
	if perfect:
		if reward:add_stache(8)
		Sound.play("perfect",-1)
		game.ui.toast("PERFECT RELOAD", "Six critical rounds. Make them count.", CombatEffects.GOLD)

func dash() -> bool:
	if dead or lance.running or dash_cooldown>0:return false
	dash_direction=Vector3(velocity.x,0,velocity.z).normalized()
	if dash_direction.length_squared()<.01:dash_direction=aim_direction
	dodge_rewarded=false
	dash_left=config.dash_seconds;dash_cooldown=config.dash_cooldown;invulnerable=maxf(invulnerable,.22)
	if is_coo:coo.hop_left=coo.HOP
	quickdraw_ready="quickdraw" in upgrades
	game.effects.ring(global_position,.35,CombatEffects.GOLD,.3,1.5)
	Sound.play("dash",-4);animate_action("dash")
	return true

func near_dodge(point: Vector3, radius: float) -> void:
	if dash_left<=0 or dodge_rewarded or not game.is_fighting():return
	var chest:=global_position+Vector3.UP
	if point.distance_to(chest)>radius or not game.line_of_sight(chest,point):return
	dodge_rewarded=true
	add_stache(8)
	combat_idle=0
	if "riposte" in upgrades:quickdraw_ready=true
	game.ui.toast("CLOSE SHAVE","+8 Stache",CombatEffects.GOLD)

func use_field_skill() -> bool:
	if is_coo:return coo.field()
	if field_skill=="tumbleweed":return cast_vortex()
	if dead or lance.running or e_cooldown>0:return false
	e_cooldown=config.vortex_cooldown
	game.cast_slap(aim_point)
	animate_action("cast")
	Sound.play("vortex",-5,1.24)
	game.ui.toast("SLAPSTACHE","Send the front outlaw into the next.",CombatEffects.GOLD)
	return true

func arm_ricochet() -> bool:
	if dead or lance.running or q_cooldown>0 or ricochet_armed:return false
	q_cooldown=config.ricochet_cooldown;ricochet_armed=true
	if not is_coo:flourish.start("ricochet")
	Sound.play("ricochet",-7)
	game.ui.toast("RICOCHET RODEO", "Your next shot has three extra bounces.", CombatEffects.GOLD)
	return true

func cast_vortex() -> bool:
	if dead or lance.running or e_cooldown>0:return false
	e_cooldown=config.vortex_cooldown
	game.cast_vortex(aim_point,"magnet" in upgrades)
	flourish.start("tumbleweed")
	game.ui.toast("TUMBLEWEED VORTEX", "Draw nearby outlaws into the tumbleweed.", CombatEffects.GREEN)
	Sound.play("vortex",-3);animate_action("cast")
	return true

func use_special() -> bool:
	if is_coo:return coo.start_strike()
	if equipped_special=="high_noon":return high_noon()
	if dead or stache<100 or form.running or lance.running:return false
	prepare_special()
	dash_left=0
	lance.begin()
	Sound.play("ultimate",-2,.78)
	game.slow_left=SaguaroLance.IGNITION
	game.ui.toast("SAGUARO LANCE","Sweep the beam through the street.",CombatEffects.GREEN)
	return true

func prepare_special() -> void:
	fan_left=0
	stache=0
	combat_idle=0
	reload_elapsed=-1
	reload_attempted=false
	if fire_pose:fire_pose.release()
	flourish.stop()

func high_noon() -> bool:
	if dead or stache<100 or frenzy_left>0 or lance.running:return false
	if not game.start_high_noon():return false
	prepare_special()
	frenzy_left=config.frenzy_duration
	Sound.play("ultimate",0);animate_action("ultimate");form.begin()
	return true

func add_stache(amount: float) -> void:
	if frenzy_left<=0 and not lance.running and (not is_coo or coo.strike_age<0) and game.is_fighting():stache=minf(100,stache+amount)

func clear_temporary_state() -> void:
	if is_coo:
		coo.clear_flock()
		coo.burst_left=0
		coo.hop_left=0
	fan_left=0
	if lance.running:lance.finish()
	flourish.stop()
	if fire_pose:fire_pose.release()
	shoot_cooldown=0;reload_elapsed=-1;dash_cooldown=0;dash_left=0;invulnerable=0
	q_cooldown=0;e_cooldown=0;frenzy_left=0;ricochet_armed=false
	empowered=false;quickdraw_ready=false;knockback=Vector3.ZERO;input_lock=1.2
	if form.running:
		form.finish()
		position.y=0
		visual.rotation.x=0;visual.rotation.z=0

func receive_hit(amount: float, _critical: bool = false, _context: Dictionary = {}) -> bool:
	if dead or invulnerable>0:return false
	health=maxf(0,health-amount);invulnerable=.65;stache=maxf(0,stache-12)
	knockback=-aim_direction*2.2
	Sound.play("hurt",-1);animate_action("hurt");game.shake(.18);game.ui.damage_flash=.35
	if health<=0:
		dead=true;velocity=Vector3.ZERO;ricochet_armed=false;frenzy_left=0
		animate_action("death");game.finish_run(false)
	return true
