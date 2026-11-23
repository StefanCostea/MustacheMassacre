extends "res://tests/autoplay.gd"

enum Opening { DRAW, FLIGHT, BRACE, BEAM, COMPLETE }
var opening := Opening.DRAW
var beat_time := 0.0
var targets: Array[EnemyActor] = []
var flanker_arrived := false
var next_special := "high_noon"
var flight_kills := 0

func setup(director: GameDirector) -> void:
	super.setup(director)
	record_run = "--autoplay-specials" in OS.get_cmdline_user_args()
	actions.special_casts = {"high_noon":0, "saguaro_lance":0}
	game.start_run()
	game.player.position = Vector3(-2.8,0,4.4)
	# Use the wave's first outlaws for the two demonstrations. Let the wave
	# director resume its regular spawn cadence after the launcher retracts.
	game.spawn_cooldown = 20.0
	stage_cast()

func stage_cast() -> void:
	game.player.equipped_special = next_special
	game.player.combat_idle = 0
	game.player.stache = 100
	targets = game.stage_preview_group(next_special)
	beat_time = 0.0

func try_special() -> bool:
	var player := game.player
	if player.form.running or player.lance.running: return false
	player.equipped_special = next_special
	if not super.try_special(): return false
	actions.special_casts[next_special] += 1
	next_special = "saguaro_lance" if next_special == "high_noon" else "high_noon"
	return true

func _physics_process(delta: float) -> void:
	if opening == Opening.COMPLETE:
		super._physics_process(delta)
		return
	if get_tree().paused or not game.is_fighting(): return
	var player := game.player
	beat_time += delta
	var target: EnemyActor
	for enemy in targets:
		if is_instance_valid(enemy) and not enemy.dead:
			target = enemy
			player.test_aim = enemy.aim_center()
			break
	match opening:
		Opening.DRAW, Opening.BRACE:
			if not target:
				# A lingering practice vortex can clear the staged group.
				targets = game.enemies.duplicate()
				game.spawn_cooldown = 0.0
			elif beat_time >= .8:
				player.stache = 100
				if not try_special(): return
				opening = Opening.FLIGHT if opening == Opening.DRAW else Opening.BEAM
		Opening.FLIGHT:
			if not player.form.running:
				flight_kills = game.kills
				opening = Opening.BRACE
				stage_cast()
				return
			var age := player.form.age
			player.test_move = Vector2.RIGHT if age > 2.2 and age < 2.85 else Vector2.ZERO
			if age >= 2.6 and not flanker_arrived and not game.spawn_queue.is_empty():
				flanker_arrived = true
				var pos := player.position + Vector3(-3.0,0,3.4)
				pos.y = 0
				targets.append(game.spawn_enemy(game.spawn_queue.pop_front(),pos))
			if age >= 2.4 and target and player.try_fire():
				actions.shots += 1
		Opening.BEAM:
			if not player.lance.running:
				opening = Opening.COMPLETE
				targets.clear()
				game.spawn_cooldown = .45
				print("SPECIALS_OPENING ",JSON.stringify({"seconds":game.run_time,
					"high_noon_kills":flight_kills, "saguaro_lance_kills":game.kills-flight_kills}))
