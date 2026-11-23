class_name CombatProjectile
extends Node3D

var game
var velocity: Vector3 = Vector3.ZERO
var damage: float = 12.0
var team: String = "enemy"
var remaining: float = 3.0
var context: Dictionary = {}
var bounces: int = 0
var launcher_shot := false
var critical := false
var explosive := false
var marked: WeakRef
var lob: bool = false
var origin: Vector3
var target: Vector3
var age: float = 0.0
var flight: float = .9
var collision_exclude: Array[RID] = []

func setup(director, pos: Vector3, vel: Vector3, amount: float, faction: String, ctx: Dictionary = {}) -> void:
	game=director;position=pos;velocity=vel;damage=amount;team=faction;context=ctx
	add_to_group("projectiles")
	# The budget limits optional needle meshes; collision and hostile bullets remain authoritative.
	if team=="enemy" or get_tree().get_nodes_in_group("projectiles").size()<=game.config.max_projectiles:
		MeshKit.instance(self, MeshKit.projectile_mesh(team == "enemy"), Vector3.ZERO, null)
	if vel.length_squared()>.001:look_at(position+vel,Vector3.UP)

func set_launcher_shot(is_critical: bool, hops: int, burst: bool, mark: EnemyActor) -> void:
	launcher_shot=true;critical=is_critical;bounces=hops;explosive=burst
	remaining=.80
	if mark:marked=weakref(mark)
	# These are the primary weapon and the silhouette that identifies each precision shot.
	if get_child_count()==0:MeshKit.instance(self,MeshKit.projectile_mesh(false),Vector3.ZERO,null)
	scale=Vector3(2.9,2.9,2.45)

func set_lob(end: Vector3, duration: float) -> void:
	lob=true;origin=position;target=end;flight=duration
	for child in get_children():
		child.hide()
		child.queue_free()
	add_child(BadlandsEnemyMotion.EGG_BOMB.instantiate())

static func lob_position(start: Vector3, end: Vector3, progress: float) -> Vector3:
	return start.lerp(end,progress) + Vector3.UP * (4.0*progress*(1-progress)*1.35)

func _break_egg(at: Vector3) -> void:
	if team=="enemy":game.player.near_dodge(at+Vector3.UP,1.95)
	game.effects.egg_shells(at)
	game.explode(at,1.6,damage,team,context)
	queue_free()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game.player):queue_free();return
	var dt: float = delta*(game.hostile_time_scale if team=="enemy" else 1.0)
	remaining-=dt
	if remaining<=0:queue_free();return
	if marked:
		var enemy = marked.get_ref()
		if is_instance_valid(enemy) and not enemy.dead:
			var to_mark: Vector3=enemy.aim_center()-global_position
			if to_mark.length_squared()>.00001:velocity=to_mark.normalized()*30
		else:marked=null
		if velocity.length_squared()>.001:look_at(global_position+velocity)
	var before:=global_position
	if lob:
		age+=dt
		var t:=minf(1,age/flight)
		global_position=lob_position(origin,target,t)
		rotate_x(dt*5.5)
	else:global_position+=velocity*dt
	var mask:=1|8|(2 if team=="enemy" else 4)
	var query:=PhysicsRayQueryParameters3D.create(before,global_position,mask,collision_exclude)
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if team=="enemy" and not lob and game.player.dash_left>0 and before.distance_squared_to(global_position)>.000001:
		var end:Vector3=hit.position if not hit.is_empty() else global_position
		if before.distance_squared_to(end)>.000001:
			game.player.near_dodge(Geometry3D.get_closest_point_to_segment(game.player.global_position+Vector3.UP,before,end),.85)
	if lob:
		if not hit.is_empty(): _break_egg(hit.position)
		elif age >= flight: _break_egg(target)
		return
	if not hit.is_empty():
		var object=hit.collider
		marked=null
		if explosive:
			explosive=false
			game.explode(hit.position,game.config.explosive_radius,game.config.explosive_damage,"player",context)
		if object.has_method("receive_hit") and (team=="player" or not object.is_in_group("county_switches")):
			context.impact_from=before
			object.receive_hit(damage,critical,context)
			if team=="player" and bounces>0 and object is EnemyActor:
				bounces-=1
				context.visited.append(object.get_instance_id())
				var next=game.nearest_chain_target(object.global_position,context.get("visited",[]),4.5)
				if is_instance_valid(next):
					if launcher_shot:damage*=game.ricochet_retention()
					collision_exclude.append(object.get_rid())
					global_position=hit.position
					velocity=(next.aim_center()-global_position).normalized()*(30 if launcher_shot else 13)
					look_at(global_position+velocity)
					return
		game.effects.burst(hit.position,CombatEffects.DANGER if team=="enemy" else CombatEffects.GREEN,4,.6)
		queue_free()
