extends Node3D

const HALF := preload("res://assets/characters/saguaro_lance/lance_half.glb")
const Pose := preload("res://scripts/saguaro_pose.gd")
const SpecialCamera := preload("res://scripts/special_camera.gd")
const IGNITION := 1.02
const CUT_END := 1.66
const BEAM_END := 3.12
const DURATION := 3.75
const REACH := 16.5
const TICK := .16
const DAMAGE := 23.0
const NEEDLES := 88

var hero
var pose: SkeletonModifier3D
var camera_rig: SpecialCamera
var camera_weight := 0.0
var running := false
var age := 0.0
var brace := 0.0
var growth := 0.0
var fusion := 0.0
var gun_stowed := false
var heading := Vector3.BACK
var pitch := 0.0
var cast_heading := Vector3.BACK
var next_tick := IGNITION
var right_wrist: Vector3
var left_wrist: Vector3
var muzzle: Vector3
var cast_chain := {}
var direct_kills := 0
var beam_length := 0.0
var halves: Array[Node3D] = []
var cuffs: Array[MeshInstance3D] = []
var beam: Node3D
var sap: MeshInstance3D
var needles: MultiMesh
var bud: MeshInstance3D
var hit_box := BoxShape3D.new()
var hit_query := PhysicsShapeQueryParameters3D.new()

func setup(player) -> void:
	hero = player
	if hero.form.rig:
		pose = Pose.new()
		pose.bind(hero.form.rig,self)
		hero.form.rig.add_child(pose)
	var wax := ShaderMaterial.new()
	wax.shader = preload("res://assets/characters/high_noon/succulent.gdshader")
	for i in 2:
		var half: Node3D = HALF.instantiate()
		add_child(half)
		for part in half.find_children("*","MeshInstance3D",true,false):
			part.material_override = wax
		halves.append(half)
		cuffs.append(MeshKit.sphere(self,Vector3.ZERO,Vector3.ONE,MeshKit.material(Color("719651"),.55)))
	bud = MeshKit.sphere(self,Vector3.ZERO,Vector3.ONE,MeshKit.material(Color("f6db78"),.3,0,1.5))
	beam = Node3D.new()
	add_child(beam)
	sap = MeshKit.cylinder(beam,Vector3.ZERO,1,1,MeshKit.material(Color("e6c878"),.45,0,1.25))
	sap.rotation.x = PI/2
	needles = MultiMesh.new()
	needles.transform_format = MultiMesh.TRANSFORM_3D
	needles.mesh = MeshKit.projectile_mesh(false)
	needles.instance_count = NEEDLES
	var stream := MultiMeshInstance3D.new()
	stream.multimesh = needles
	stream.custom_aabb = AABB(Vector3(-1,-1,-1),Vector3(2,2,REACH+2))
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(stream)
	hit_query.shape = hit_box
	hit_query.collision_mask = 4
	hide()

func begin() -> void:
	direct_kills=0
	cast_chain=hero.game.new_context("saguaro_lance").chain
	running=true
	age=0
	next_tick=IGNITION
	heading=hero.aim_direction
	cast_heading=heading
	pitch=target_pitch()
	beam.hide()
	show()
	if pose:pose.active=true
	camera_rig=SpecialCamera.new()
	hero.game.add_child(camera_rig)
	sample_wrists()
	update_camera()
	camera_rig.make_current()

func target_pitch() -> float:
	var target:Vector3=hero.aim_point
	if target.y < .2:target.y = hero.global_position.y+1.0
	var offset:Vector3=target-(hero.global_position+Vector3.UP*(1.0 if hero.form.natural else 1.25))
	return clampf(atan2(offset.y,maxf(.01,Vector2(offset.x,offset.z).length())),-.27,.65)

func advance(delta: float) -> void:
	if not running:return
	age+=delta
	if age>=DURATION:
		finish()
		return
	var unwind:=1.0-smoothstep(BEAM_END,DURATION,age)
	brace=smoothstep(.05,.53,age)*unwind
	growth=smoothstep(.22,.86,age)*unwind
	fusion=smoothstep(.42,.92,age)*unwind
	var stow:=age>.23 and age<DURATION-.12
	if stow!=gun_stowed:
		gun_stowed=stow
		for prop in hero.form.held:prop.visible=not stow
	if age>=CUT_END and age<BEAM_END:
		var yaw:=rotate_toward(atan2(heading.x,heading.z),atan2(hero.aim_direction.x,hero.aim_direction.z),delta*2.25)
		heading=Vector3(sin(yaw),0,cos(yaw))
		pitch=move_toward(pitch,target_pitch(),delta*1.6)
	hero.visual.rotation.y=atan2(heading.x,heading.z)
	follow_arms()
	var firing:=age>=IGNITION and age<BEAM_END
	beam.visible=firing
	if firing:
		trace_beam(age>=next_tick)
		if age>=next_tick:
			if next_tick==IGNITION:
				Sound.play("explosion",-6,.82)
				hero.game.shake(.18)
			next_tick+=TICK

func sample_wrists() -> void:
	right_wrist=hero.form.bone_point("wrist",Vector3(-.22,.96,.36))
	left_wrist=hero.form.bone_point("free_wrist",Vector3(.22,.96,.36))
	follow_arms()

func follow_arms() -> void:
	var centre:=(left_wrist+right_wrist)*.5
	var axis:=Vector3(0,sin(pitch),cos(pitch))
	var recoil:=.055*(.5+.5*cos((age-IGNITION)*TAU/TICK)) if age>=IGNITION and age<BEAM_END else 0.0
	var root:=centre+axis*(.035-recoil)
	for i in 2:
		var side:float=-1 if i==0 else 1
		var wrist:=right_wrist if i==0 else left_wrist
		var socket:=wrist.lerp(root,fusion)
		var spread_angle:=side*(1.0-fusion)*.43
		var size:=maxf(.001,growth)
		var frame:=Basis(Vector3.UP,spread_angle)*Basis(Vector3.RIGHT,-pitch)
		halves[i].transform=Transform3D(frame.scaled_local(Vector3(side*size,size,size)),socket)
		var junction:=socket+axis*.12
		var length:=wrist.distance_to(junction)
		var cuff_frame:=Basis.looking_at((junction-wrist).normalized(),Vector3.UP,true) if length>.001 else Basis.IDENTITY
		cuffs[i].transform=Transform3D(cuff_frame.scaled_local(Vector3(.11*size,.105*size,maxf(.001,.5*length+.05*size))),(junction+wrist)*.5)
	muzzle=to_global(root+axis*(growth*1.15))
	bud.position=root+axis*(growth*1.09)
	var light:=growth*smoothstep(.62,IGNITION,age)
	bud.scale=Vector3.ONE*maxf(.001,light*(.13+.035*sin(age*37)))
	bud.visible=light>.01

func trace_beam(deal_damage: bool) -> void:
	var direction:Vector3=(heading*cos(pitch)+Vector3.UP*sin(pitch)).normalized()
	var world:=get_world_3d().direct_space_state
	var chest:Vector3=hero.global_position+Vector3.UP*(1.0 if hero.form.natural else 1.25)
	var obstruction:=world.intersect_ray(PhysicsRayQueryParameters3D.create(chest,muzzle,1|8))
	var origin:=muzzle
	var length:=0.0
	if obstruction.is_empty():
		length=REACH
		obstruction=world.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*REACH,1|8))
		if not obstruction.is_empty():length=origin.distance_to(obstruction.position)
	beam_length=length
	beam.visible=length>.04
	if length>.04:
		beam.global_transform=Transform3D(Basis.looking_at(direction,Vector3.UP,true),origin)
		draw_stream(length)
	if not deal_damage:return
	var ctx:Dictionary=hero.game.new_context("saguaro_lance")
	ctx.chain=cast_chain
	ctx.impact_from=origin
	if length>.04:
		hit_box.size=Vector3(.52,.52,length)
		hit_query.transform=Transform3D(beam.global_basis,origin+direction*length*.5)
		var contacts:=world.intersect_shape(hit_query,64)
		if cast_chain.kills==0:
			for hit in contacts:
				var captive=hit.collider
				if captive is EnemyActor and captive.pull_credit>0 and not captive.pull_chain.is_empty() and hero.game.line_of_sight(origin,captive.aim_center()):
					cast_chain=captive.pull_chain
					ctx.chain=cast_chain
					if "saguaro_lance" not in cast_chain.steps:cast_chain.steps.append("saguaro_lance")
					break
		for hit in contacts:
			var enemy=hit.collider
			if enemy is EnemyActor and not enemy.dead and hero.game.line_of_sight(origin,enemy.aim_center()):
				enemy.receive_hit(DAMAGE,false,ctx)
				if enemy.dead:direct_kills+=1
				if not running:return
	if not obstruction.is_empty():
		if obstruction.collider is BreakableProp:obstruction.collider.receive_hit(DAMAGE,false,ctx)
		hero.game.effects.burst(obstruction.position,Color("fbc685"),4,.75)
	Sound.play("shot",-14,1.45)
	hero.game.shake(.045)

func draw_stream(length: float) -> void:
	var pulse:=1.0+.18*sin(age*31.0)
	sap.position.z=length*.5
	sap.scale=Vector3(.047*pulse,length,.047*pulse)
	var visible_count:=clampi(ceili(length/.19),1,NEEDLES)
	needles.visible_instance_count=visible_count
	for i in visible_count:
		var progress:=fposmod(float(i)/visible_count+age*6.3/length,1.0)
		var angle:=float(i%4)*TAU/4.0 + progress*length*1.3-age*13.0
		var radius:=minf(.21,length*.2)*(.5+.5*sin(PI*progress))*pulse
		var offset:=Vector3(cos(angle)*radius,sin(angle)*radius,progress*length)
		var flare:=Basis(Vector3.BACK,angle)*Basis(Vector3.UP,PI-.14)
		var stretch:=minf(1.7,length*minf(progress,1.0-progress)/.23)
		needles.set_instance_transform(i,Transform3D(flare.scaled_local(Vector3(2.0,2.0,maxf(.002,stretch))),offset))

func phase_name() -> String:
	if age<IGNITION:return "CHARGING"
	if age<BEAM_END:return "FIRING"
	return "RECOVERING"

func update_camera() -> void:
	if not camera_rig:return
	if age>=CUT_END:
		end_camera()
		return
	camera_weight=smoothstep(0,.26,age)*(1-smoothstep(1.07,CUT_END,age))
	var side:=Vector3(cast_heading.z,0,-cast_heading.x)
	var front:Vector3=(side*lerpf(.57,1.0,smoothstep(.55,1.14,age))+cast_heading*lerpf(1.0,.55,smoothstep(.55,1.14,age))+Vector3.UP*.14).normalized()
	var focus:Vector3=hero.global_position+Vector3.UP*(1.03 if hero.form.natural else 1.30)+cast_heading*.55
	camera_rig.frame(hero.game.camera,focus,front,lerpf(2.65,3.8,smoothstep(.65,1.18,age)),camera_weight)

func end_camera() -> void:
	camera_weight=0
	if camera_rig:
		hero.game.camera.make_current()
		camera_rig.queue_free()
		camera_rig=null

func finish() -> void:
	running=false
	growth=0
	brace=0
	fusion=0
	gun_stowed=false
	beam_length=0
	for prop in hero.form.held:prop.show()
	if pose:pose.active=false
	end_camera()
	hide()
