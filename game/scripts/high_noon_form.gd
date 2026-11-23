extends Node3D

const ORIGINAL_MORPH = preload("res://assets/characters/high_noon/handlebar_original.glb")
const NATURAL_MORPH = preload("res://assets/characters/high_noon/handlebar_natural.glb")
const ARM = preload("res://assets/characters/high_noon/thorn_arm.glb")
const FALLEN = preload("res://assets/characters/high_noon/fallen_six_shooter.glb")
const Pose = preload("res://scripts/high_noon_pose.gd")
const DROP_AT := .30
const FIRST_SPIKE := 1.06
const CUT_END := 1.78

var hero
var momentum_curl := 0.0
var running := false
var released := false
var landed := false
var age := 0.0
var spread := 0.0
var arm_growth := 0.0
var lift := 0.0
var kick := 0.0
var cast_facing := Vector3.BACK
var shot_facing := Vector3.ZERO
var aim_hold := 0.0
var camera_weight := 0.0
const SpecialCamera = preload("res://scripts/special_camera.gd")
var camera_rig: SpecialCamera
var rig: Skeleton3D
var pose: SkeletonModifier3D
var uncurl := 0.0
var normal_face: MeshInstance3D
var face_shell: MeshInstance3D
var moustache: MeshInstance3D
var uncurl_key: int
var momentum_key: int
var upstroke_key: int
var downstroke_key: int
var hair_bones := PackedInt32Array()
var bind_poses: Array[Transform3D] = []
var head_bind := -1
var arm: Node3D
var tip: Marker3D
var held: Array[MeshInstance3D] = []
var gun_socket: Node3D
var dropped: Node3D
var release_pose: Transform3D
var drop_direction := Vector3.ZERO
var floor_y := 0.0
var natural := false

func setup(player) -> void:
	hero=player
	var skeletons:=hero.visual.find_children("*","Skeleton3D",true,false) as Array
	if not skeletons.is_empty():
		rig=skeletons[0]
		natural=rig.find_bone("mixamorig_Head")>=0
		pose=Pose.new()
		pose.bind(rig,self)
		rig.add_child(pose)
	for part in hero.visual.find_children("*","MeshInstance3D",true,false):
		if part.name in [&"Natural_Separate_Revolver",&"Revolver_Cylinder"]: held.append(part)
	gun_socket=hero.visual.find_child("GunOrigin",true,false)
	if rig: bind_moustache()
	arm=ARM.instantiate()
	add_child(arm)
	var wax:=ShaderMaterial.new()
	wax.shader=preload("res://assets/characters/high_noon/succulent.gdshader")
	for part in arm.find_children("*","MeshInstance3D",true,false):part.material_override=wax
	tip=Marker3D.new()
	arm.add_child(tip)
	tip.position=Vector3(0,0,.835)
	hide()

func bind_moustache() -> void:
	normal_face = hero.visual.find_child("Natural_Skin" if natural else "Runtime_face_hat",true,false)
	var variant: Node = (NATURAL_MORPH if natural else ORIGINAL_MORPH).instantiate()
	face_shell = variant.find_child("NoonFace",true,false)
	moustache = variant.find_child("NoonHandlebar",true,false)
	for part: MeshInstance3D in [face_shell,moustache]:
		part.owner = null
		part.get_parent().remove_child(part)
		normal_face.get_parent().add_child(part)
		part.transform = normal_face.transform
		part.skeleton = part.get_path_to(rig)
		part.hide()
	variant.free()
	var original := normal_face.get_active_material(0) as BaseMaterial3D
	face_shell.set_surface_override_material(0, original)
	if natural:
		var cheek := StandardMaterial3D.new()
		cheek.vertex_color_use_as_albedo = true
		cheek.roughness = .83
		face_shell.set_surface_override_material(1,cheek)
	var hair := ShaderMaterial.new()
	hair.shader = preload("res://assets/characters/high_noon/whiskers.gdshader")
	hair.set_shader_parameter("hair_atlas",original.albedo_texture)
	hair.set_shader_parameter("rough_metal_atlas",original.roughness_texture)
	if original.normal_enabled:
		hair.set_shader_parameter("grooves",original.normal_texture)
		hair.set_shader_parameter("groove_depth",original.normal_scale)
	moustache.material_override = hair
	moustache.extra_cull_margin = 4.0
	uncurl_key = moustache.find_blend_shape_by_name("Uncurl")
	momentum_key = moustache.find_blend_shape_by_name("MomentumCurl")
	upstroke_key = moustache.find_blend_shape_by_name("Upstroke")
	downstroke_key = moustache.find_blend_shape_by_name("Downstroke")

	if natural:
		# At the first frame and on landing these are the original scan weights.
		# In flight all the hair and its vanes follow the same head space.
		moustache.skin = moustache.skin.duplicate()
		for i in moustache.skin.get_bind_count():
			var bone := rig.find_bone(moustache.skin.get_bind_name(i))
			hair_bones.append(bone)
			bind_poses.append(moustache.skin.get_bind_pose(i))
			if bone == pose.ids.head: head_bind = i

func follow_moustache() -> void:
	if not moustache or not moustache.visible or head_bind < 0:return
	var head_skin := rig.get_bone_global_pose(hair_bones[head_bind])*bind_poses[head_bind]
	var blend := smoothstep(0,.4,uncurl)
	for i in hair_bones.size():
		if i==head_bind:continue
		var bone_pose := rig.get_bone_global_pose(hair_bones[i])
		var head_relative := bone_pose.affine_inverse()*head_skin
		# Linear matrix blending keeps each vertex on the segment between its two
		# skinned positions. Rotating inverse bind matrices swings long Mixamo offsets in arcs.
		var start := bind_poses[i]
		var basis := Basis(start.basis.x.lerp(head_relative.basis.x,blend),
				start.basis.y.lerp(head_relative.basis.y,blend),start.basis.z.lerp(head_relative.basis.z,blend))
		moustache.skin.set_bind_pose(i,Transform3D(basis,start.origin.lerp(head_relative.origin,blend)))

func animate_moustache() -> void:
	if not moustache:return
	var changing := uncurl > 0.0
	normal_face.visible = not changing
	face_shell.visible = changing
	moustache.visible = changing
	if not changing:return
	var down := .5-.5*cos((age-.99)*6.2)
	moustache.set_blend_shape_value(uncurl_key,uncurl*(1.0-spread))
	moustache.set_blend_shape_value(upstroke_key,spread*(1.0-down))
	moustache.set_blend_shape_value(downstroke_key,spread*down)
	moustache.set_instance_shader_parameter("gild",.74*smoothstep(.12,.93,uncurl)+.26*spread)
	moustache.set_instance_shader_parameter("fan",spread)

func show_momentum(charge: float) -> void:
	if not moustache:return
	var amount:=smoothstep(.05,1.0,charge)
	if is_equal_approx(amount,momentum_curl):return
	momentum_curl=amount
	moustache.set_blend_shape_value(momentum_key,amount)
	normal_face.visible=amount<=0
	face_shell.visible=amount>0
	moustache.visible=amount>0

func begin() -> void:
	show_momentum(0)
	running=true
	landed=false;age=0;spread=0;arm_growth=0;lift=0;kick=0;aim_hold=0
	cast_facing=hero.aim_direction
	show()
	if pose:pose.active=true
	camera_rig=SpecialCamera.new()
	hero.game.add_child(camera_rig)
	follow_pose()
	update_camera()
	camera_rig.make_current()

func bone_point(key: String, fallback: Vector3) -> Vector3:
	if not rig or pose.ids[key]<0:return fallback
	return to_local(rig.to_global(rig.get_bone_global_pose(pose.ids[key]).origin))

func follow_pose() -> void:
	arm.position=bone_point("elbow",Vector3(-.30,1.14,.13))
	arm.visible=arm_growth>.005
	var grow:=maxf(.005,arm_growth)
	arm.scale=Vector3(grow*(1+.08*kick),grow*(1+.08*kick),grow*(1-.20*kick))
	var direction: Vector3 = shot_facing if aim_hold>0 else hero.visual.global_basis*Vector3(-.45,-.31,.94)
	var local_direction: Vector3 = global_basis.inverse()*direction.normalized()
	if local_direction.length_squared()>.01:
		arm.quaternion=Basis.looking_at(local_direction.normalized(),Vector3.UP,true).get_rotation_quaternion()

func set_spike_aim(target: Vector3) -> void:
	shot_facing=(target-arm.global_position).normalized()
	aim_hold=.16
	kick=1.0
	follow_pose()

func advance(dt: float) -> void:
	if not running:
		show_momentum(0.0 if hero.dead else hero.stache/100.0)
		return
	var left: float=hero.frenzy_left
	age+=dt
	uncurl=smoothstep(.38,.77,age)*smoothstep(.06,.42,left)
	spread=smoothstep(.65,1.055,age)*smoothstep(.26,.68,left)
	animate_moustache()
	arm_growth=smoothstep(.43,.86,age)*smoothstep(.09,.42,left)
	lift=smoothstep(.55,1.06,age)*smoothstep(.05,.56,left)
	kick=move_toward(kick,0,dt*7)
	aim_hold=maxf(0,aim_hold-dt)
	if not released and age>=DROP_AT and left>.5:drop_gun()
	if released:update_gun(left)
	follow_pose()
	if left<=0:finish()

func drop_gun() -> void:
	released=true
	dropped=Node3D.new()
	dropped.name="DroppedRevolver"
	hero.game.actors.add_child(dropped)
	dropped.global_transform = gun_socket.global_transform.orthonormalized() if gun_socket else hero.visual.global_transform
	if held.is_empty():
		var copy:Node3D=FALLEN.instantiate()
		dropped.add_child(copy)
		copy.scale=gun_socket.global_basis.get_scale().abs() if gun_socket else Vector3.ONE*.62
	else:
		for mesh in held:
			var item:=MeshInstance3D.new()
			item.mesh=mesh.mesh
			dropped.add_child(item)
			item.global_transform=mesh.global_transform
			mesh.hide()
	release_pose=dropped.global_transform
	drop_direction=hero.visual.global_basis*Vector3(-.85,0,.25)
	var query:=PhysicsRayQueryParameters3D.create(release_pose.origin+Vector3.UP*.08,release_pose.origin+Vector3.DOWN*4,1|8)
	var hit: Dictionary=hero.get_world_3d().direct_space_state.intersect_ray(query)
	floor_y=hit.position.y if not hit.is_empty() else 0.0

func update_gun(left: float) -> void:
	if not is_instance_valid(dropped):return
	var t:=clampf(age-DROP_AT,0,.9)
	var origin:=release_pose.origin
	var height:=origin.y+1.22*t-5.4*t*t
	var land:float=(1.22+sqrt(1.22*1.22+21.6*maxf(.01,origin.y-floor_y-.11)))/10.8
	var t_land:=maxf(0,t-land)
	if t>=land and not landed:
		landed=true
		Sound.play("ricochet",-14,.70)
		hero.game.effects.fall_contact(Vector3(origin.x+drop_direction.x*land,floor_y,origin.z+drop_direction.z*land),"gun")
	var pos:=origin+drop_direction*(minf(t,land)+.11*(1-exp(-9*t_land)))
	pos.y=maxf(floor_y+.11,height)+.12*maxf(0,sin(t_land*13))*exp(-9*t_land)
	var spin:=clampf(t/land,0,1)
	var resting:=release_pose.basis.rotated(cast_facing,1.40*spin)
	dropped.global_transform=Transform3D(resting,pos)
	if left<.40:
		var recall:=1-smoothstep(.07,.40,left)
		var palm:=bone_point("wrist",Vector3(-.15,1.0,.32))
		dropped.global_position=pos.lerp(to_global(palm),recall)+Vector3.UP*(sin(recall*PI)*.18)
		dropped.scale=Vector3.ONE*maxf(.012,1-recall*.98)

func update_camera() -> void:
	if not is_instance_valid(camera_rig):return
	if age>=CUT_END:
		end_camera()
		return
	var arena: Camera3D=hero.game.camera
	var enter:=smoothstep(0,.25,age)
	var leave:=smoothstep(1.11,CUT_END,age)
	camera_weight=enter*(1-leave)
	var right:=Vector3(cast_facing.z,0,-cast_facing.x)
	var angle:=lerpf(.80,.53,smoothstep(.22,1.22,age))
	var front:Vector3=(cast_facing*cos(angle)+right*sin(angle)+Vector3.UP*lerpf(-.14,-.07,smoothstep(.3,.9,age))).normalized()
	var close_focus:Vector3=hero.global_position+Vector3.UP*(1.12 if natural else 1.38)
	camera_rig.frame(arena,close_focus,front,lerpf(2.58,3.45,smoothstep(.56,1.12,age)),camera_weight)

func end_camera() -> void:
	camera_weight=0
	if is_instance_valid(camera_rig):
		hero.game.camera.make_current()
		camera_rig.queue_free()
		camera_rig=null

func finish() -> void:
	uncurl=0
	animate_moustache()
	running=false;released=false;spread=0;arm_growth=0;lift=0;kick=0;aim_hold=0
	end_camera()
	if pose:pose.active=false
	for mesh in held:mesh.show()
	if is_instance_valid(dropped):dropped.queue_free()
	dropped=null
	hide()
