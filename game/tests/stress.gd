extends Node

# Deliberately invulnerable diagnostic scene, separate from the normal autoplay.
var game: GameDirector
var elapsed: float = 0
var samples: Array[float] = []
var draws: Array[float] = []
var points: Array[Vector3] = []
var next_spawn: int = 0
var captured: bool = false
var done: bool = false

func setup(director: GameDirector) -> void:
	game=director;game.start_run();game.spawn_queue.clear();game.state=GameDirector.RunState.BOSS
	game.player.test_mode=true;game.player.upgrades=["bounce","prickly","explosive","trigger","magnet","quickdraw"]
	for z in [-8.0,-5.0,-2.0,2.0,5.0,8.0]:
		for x in [-11.0,-8.0,-3.0,2.0,8.0,11.0]:
			var p:=Vector3(x,0,z)
			if game.arena.point_clear(p):points.append(p)
	for i in range(35):
		game.spawn_enemy(["fridge","chili","pigeon"][i%3],points[i%points.size()]);next_spawn+=1
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0

func _process(delta: float) -> void:
	if done:return
	elapsed+=delta
	if elapsed>8:samples.append(delta*1000);draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	game.player.invulnerable=10
	if game.live_count()<35:
		var type:String=["fridge","chili","pigeon"][next_spawn%3]
		game.spawn_enemy(type,points[next_spawn%points.size()]);next_spawn+=1
	var p:=game.player
	p.test_move=Vector2(sin(elapsed*.4),cos(elapsed*.4))
	var target=game.nearest_chain_target(p.position,[],14)
	if target:
		p.test_aim=target.aim_center() if target.flying else target.global_position
		p.try_fire()
		if p.ammo==0:p.reload_input()
		if p.reload_elapsed>.70 and not p.reload_attempted:p.reload_input()
		p.arm_ricochet();p.cast_vortex()
		if elapsed>10 and p.frenzy_left<=0:p.stache=100;p.high_noon()
	if elapsed>18 and not captured:
		captured=true;capture()
	if elapsed>=53:finish()

func capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://stress.png")

func finish() -> void:
	done=true;samples.sort();draws.sort()
	var report:={"scenario":"35 mixed enemies, all upgrades, recurring Frenzy; invulnerable diagnostic only","width":get_viewport().get_visible_rect().size.x,"height":get_viewport().get_visible_rect().size.y,"sample_count":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"median_draw_calls":draws[draws.size()/2],"max_draw_calls":draws[-1],"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"projectiles":get_tree().get_nodes_in_group("projectiles").size(),"nodes":get_tree().get_node_count()}
	report.physical_render_width=get_viewport().get_texture().get_width();report.physical_render_height=get_viewport().get_texture().get_height()
	var file:=FileAccess.open("user://performance.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("PERFORMANCE ",JSON.stringify(report));game.quit_application()
