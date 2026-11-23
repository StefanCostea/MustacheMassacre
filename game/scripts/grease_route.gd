extends Node

var game: GameDirector
var choice := ""
var stage := 0
var elite: EnemyActor
var splash_at := Vector3.ZERO
var oil_warning := -1.0
var oil_cooldown := 3.0
var reward_due := false

func enter(path: String) -> void:
	if choice!="" or path not in ["freight","fry_line"] or game.state!=GameDirector.RunState.VICTORY:return
	choice=path
	game.ui.close_panel()
	game.get_tree().paused=false
	for child in game.actors.get_children():
		if child!=game.player:
			game.actors.remove_child(child)
			child.queue_free()
	game.enemies.clear()
	game.boss=null
	game.bottleneck.clear()
	var previous:=game.arena
	game.remove_child(previous)
	previous.queue_free()
	game.arena=preload("res://scripts/grease_city.gd").new()
	game.add_child(game.arena)
	game.arena.build(game)
	game.player.position=Vector3(0,0,7)
	game.player.health=minf(100,game.player.health+25)
	game.player.input_lock=.3
	start_stage(1)

func start_stage(index: int) -> void:
	stage=index
	game.wave=4+stage
	game.state=GameDirector.RunState.COMBAT
	game.spawn_queue.clear()
	var kinds:Array=["chili","fridge","chili","pigeon"] if choice=="freight" else ["repair","fridge","skillet","pigeon","chili"]
	game.encounter=WaveSpec.new()
	game.encounter.group_interval=3.2
	game.encounter.group_size=3
	game.spawn_group_left=3
	game.spawn_cooldown=1.0
	for i in (10 if index==2 else 8 if choice=="freight" else 14):
		game.spawn_queue.append(kinds[i%kinds.size()])
	if index==1 and choice=="fry_line":
		elite=game.spawn_enemy("skillet",Vector3(0,0,-6.8))
		elite.is_elite=true
		elite.scale=Vector3.ONE*1.24
		elite.max_health=190
		elite.health=190
		MeshKit.label(elite,"HEAD FRY COOK",Vector3.UP*1.9,24,CombatEffects.GOLD,.007)
	game.ui.toast("GREASE CITY",title(),CombatEffects.GOLD)

func title() -> String:
	if stage==2:return "THE DRIVE-THRU EXIT"
	return "THE FRY LINE" if choice=="fry_line" else "WAX FREIGHT"

func cleared() -> void:
	if stage==2:
		game.finish_run(true)
		return
	if choice=="freight":
		game.award_wax(12)
		start_stage(2)
		game.ui.toast("FREIGHT DELIVERED","12 wax bounty. Clear the drive-thru exit.",CombatEffects.GOLD)
	else:
		reward_due=true
		game.show_upgrades()

func _physics_process(delta: float) -> void:
	if stage!=1 or not is_instance_valid(elite) or elite.dead or not game.is_fighting():return
	var dt:=delta*game.hostile_time_scale
	if oil_warning>=0:
		oil_warning-=dt
		if oil_warning<0:
			game.explode(splash_at,1.7,18,"enemy",{})
			oil_cooldown=4.2
		return
	oil_cooldown-=dt
	if oil_cooldown<=0:
		splash_at=game.player.position
		splash_at.y=.06
		oil_warning=1.05
		game.effects.ring(splash_at,1.7,CombatEffects.DANGER,oil_warning)
		Sound.play("warning",-9,.82)
