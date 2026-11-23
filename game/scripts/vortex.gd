class_name TumbleweedVortex
extends Node3D

var game
var target: Vector3
var radius: float = 3.0
var duration: float = 3.5
var tick: float = 0.0
var roll: Node3D
var captive: EnemyActor
var tossed := false
var chain := {}
var settled: bool = false
var circle: Node3D
var strands: Array[Node3D] = []

func setup(director, start: Vector3, end: Vector3, upgraded: bool) -> void:
	game=director;position=start;target=end
	chain=game.new_context("tumbleweed").chain
	radius=game.config.magnetic_radius if upgraded else game.config.vortex_radius
	duration=game.config.vortex_duration+(game.config.magnetic_bonus_seconds if upgraded else 0)
	add_to_group("vortices")
	roll=Node3D.new();add_child(roll)
	BadlandsProps.place(roll, "tumbleweed", Vector3.DOWN * .48)
	for j in range(7):
		var ring:=MeshKit.ring(self,Vector3(0,.08+j*.1,0),radius*(1-float(j)*.085),.018,MeshKit.material(CombatEffects.GREEN.darkened(float(j)*.045),.6,0,.55))
		ring.visible=false
		strands.append(ring)
	circle=MeshKit.ring(self,Vector3(0,.04,0),radius,.055,MeshKit.material(CombatEffects.GREEN,.7,0,.8))
	circle.visible=false

func _physics_process(delta: float) -> void:
	if game.state in [GameDirector.RunState.VICTORY,GameDirector.RunState.DEAD]:
		queue_free()
		return
	roll.rotate_x(delta*9)
	roll.rotate_y(delta*5)
	if not settled:
		position=position.move_toward(target,delta*10)
		if position.distance_to(target)<.1:
			settled=true;circle.visible=true
			for strand in strands:strand.visible=true
		return
	duration-=delta
	tick-=delta
	roll.position.y=.4+sin(duration*8)*.12
	for i in range(strands.size()):
		var strand:=strands[i]
		strand.rotation.y+=delta*(2+i*.4)
		strand.rotation.z=sin(duration*3+i)*.035
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead:continue
		var d: Vector3 = global_position-enemy.global_position
		d.y=0
		if d.length()<radius and game.line_of_sight(global_position+Vector3.UP*.5,enemy.global_position+Vector3.UP*.5):
			enemy.pull_chain=chain
			enemy.pull_credit=2.8
			if not tossed and "fling" in game.player.upgrades and enemy.can_be_flung():
				if not is_instance_valid(captive) or captive.dead or enemy.kind=="fridge":captive=enemy
			enemy.pull_velocity+=d.normalized()*minf(9,d.length()*7)*delta*12*(.2 if enemy.kind=="boss" else 1.0)
			if tick<=0:enemy.receive_hit(2.5,false,{"source":"tumbleweed","generation":1,"chain":chain})
	if duration<=1.7 and not tossed and is_instance_valid(captive) and captive.can_be_flung() and global_position.distance_to(captive.position)<radius+.3 and game.line_of_sight(global_position+Vector3.UP*.5,captive.aim_center()):
		tossed=true
		var impact:Dictionary=game.new_context("freight")
		impact.chain=chain
		impact.freight=true
		chain.steps.append("freight")
		game.fling_outlaw(captive,impact)
	if tick<=0:tick=.25
	if duration<=0:
		if "aftershock" in game.player.upgrades:
			game.explode(global_position+Vector3.UP*.5,radius,26,"player",game.new_context("aftershock"))
		game.effects.burst(global_position+Vector3.UP*.3,CombatEffects.GREEN,12)
		queue_free()
