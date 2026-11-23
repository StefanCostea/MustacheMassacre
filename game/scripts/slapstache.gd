extends Node3D

const WHISKER := preload("res://assets/characters/high_noon/ricochet_curl.glb")
const REACH := 1.85
var game: GameDirector
var whiskers := Node3D.new()
var elapsed := 0.0
var struck := false
var repeat := false

func setup(director: GameDirector, point: Vector3) -> void:
	game=director
	position=point
	rotation.y=atan2(game.player.aim_direction.x,game.player.aim_direction.z)
	repeat="aftershock" in game.player.upgrades
	add_child(whiskers)
	var paint:=StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo=true
	for side: float in [-1.0,1.0]:
		var lobe:Node3D=WHISKER.instantiate()
		whiskers.add_child(lobe)
		lobe.scale=Vector3(side,1,1)*4.4
		for mesh in lobe.find_children("*","MeshInstance3D",true,false):mesh.material_override=paint
	game.effects.ring(point+Vector3.UP*.05,REACH,CombatEffects.GOLD,.38)
	animate()

func animate() -> void:
	var rise:=smoothstep(.07,.34,elapsed)*(1.0-smoothstep(.48,.77,elapsed))
	whiskers.position.y=lerpf(-.22,.62,rise)
	whiskers.scale=Vector3.ONE*maxf(.001,rise)
	whiskers.rotation.z=lerpf(-1.12,.35,smoothstep(.19,.38,elapsed))

func _physics_process(delta: float) -> void:
	if game.player.dead or game.state in [GameDirector.RunState.VICTORY,GameDirector.RunState.DEAD]:
		queue_free()
		return
	elapsed+=delta
	animate()
	if not struck and elapsed>=.34:
		struck=true
		var first:EnemyActor
		var best:=INF
		var ctx:=game.new_context("slap")
		for enemy in game.enemies:
			if not is_instance_valid(enemy) or enemy.dead:continue
			var distance:=global_position.distance_to(enemy.global_position)
			if distance>REACH or not game.line_of_sight(global_position+Vector3.UP*.6,enemy.aim_center()):continue
			enemy.receive_hit(18,false,ctx)
			if distance<best and enemy.can_be_flung():
				best=distance
				first=enemy
		if first:game.fling_outlaw(first,ctx)
		game.effects.burst(global_position+Vector3.UP*.5,CombatEffects.GOLD,14)
		game.shake(.13)
		Sound.play("hit",-3,.72)
	if elapsed>=.8:
		if repeat:
			repeat=false
			elapsed=0
			struck=false
		else:queue_free()
