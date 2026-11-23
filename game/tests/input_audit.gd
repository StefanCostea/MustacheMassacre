extends Node

var game: GameDirector
var elapsed: float = 0
var events: Dictionary = {}
var start: Vector3
var max_movement: float = 0
var saw_pause: bool = false
var done: bool = false

func setup(director: GameDirector) -> void:
	game=director;process_mode=Node.PROCESS_MODE_ALWAYS;start=game.player.position
	publish_target.call_deferred()

func publish_target() -> void:
	await get_tree().create_timer(.5).timeout
	var target:Vector2=game.camera.unproject_position(game.enemies[0].position)
	var file:=FileAccess.open("user://input_target.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"x":target.x,"y":target.y}));file.close()
	print("INPUT_AUDIT_READY ",target)

func _input(event: InputEvent) -> void:
	for action in ["move_left","move_right","move_forward","move_back","fire","reload","dash","ricochet","tumbleweed","ultimate","pause","start_run"]:
		if event.is_action_pressed(action):events[action]=int(events.get(action,0))+1

func _process(delta: float) -> void:
	if done:return
	elapsed+=delta;max_movement=maxf(max_movement,game.player.position.distance_to(start));saw_pause=saw_pause or get_tree().paused
	if elapsed>22:
		done=true
		var report:={"events":events,"movement_metres":max_movement,"saw_pause":saw_pause,"shots":game.player.shot_count,"wave":game.wave,"ricochet_spent":game.player.q_cooldown>0,"vortex_count":get_tree().get_nodes_in_group("vortices").size(),"hp":game.player.health,"gpu":RenderingServer.get_video_adapter_name()}
		var file:=FileAccess.open("user://input_audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://input_audit.png")
		print("INPUT_AUDIT ",JSON.stringify(report));game.quit_application()
