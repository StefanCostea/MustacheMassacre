extends Node

# Used by verify_mouse_tracking.py on an isolated X11 display. Combat timing is
# disabled so this checks real mouse input, menus and drawing without enemy AI.
var game: GameDirector
var directory: String
var busy: bool = false
var motion_events: int = 0

func setup(director: GameDirector) -> void:
	game=director;process_mode=Node.PROCESS_MODE_ALWAYS
	directory=OS.get_environment("LASTCALL_MOUSE_TEST_DIR")
	assert(not directory.is_empty())
	game.set_process(false)
	publish_ready.call_deferred()

func publish_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await snapshot("ready")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:motion_events+=1

func _process(_delta: float) -> void:
	var path:=directory+"/command.json"
	if busy or not FileAccess.file_exists(path):return
	var request:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path);busy=true
	handle(request)

func handle(request: Dictionary) -> void:
	match request.action:
		"start":game.start_run()
		"pause", "resume":game.ui.toggle_pause()
		"upgrade":game.show_upgrades()
		"choose":game.choose_upgrade(game.options[0])
		"wave":game.start_wave(2)
		"results":
			game.player.receive_hit(1000)
			await get_tree().create_timer(1.2,true).timeout
		"quit":game.quit_application();return
	await get_tree().process_frame
	await get_tree().process_frame
	await snapshot(request.id)
	busy=false

func snapshot(id: String) -> void:
	await RenderingServer.frame_post_draw
	var viewport:=get_viewport()
	var mouse:=viewport.get_mouse_position()
	var aim:=game.camera.unproject_position(game.player.aim_point)
	var pos:=DisplayServer.window_get_position()
	var size:=DisplayServer.window_get_size()
	var image:=viewport.get_texture().get_image()
	image.save_png(directory+"/"+id+".png")
	var report:={"mouse":[mouse.x,mouse.y],"aim_screen":[aim.x,aim.y],"mouse_mode":Input.mouse_mode,"focused":get_window().has_focus(),"window_position":[pos.x,pos.y],"window_size":[size.x,size.y],"viewport_size":[viewport.get_visible_rect().size.x,viewport.get_visible_rect().size.y],"render_size":[image.get_width(),image.get_height()],"panel":game.ui.panel_kind,"paused":get_tree().paused,"motion_events":motion_events,"toast_timer":game.ui.toast_timer,"shots":game.player.shot_count}
	var controls:=[]
	for child in game.ui.host.find_children("*","Button",true,false):
		var rect:Rect2=child.get_global_rect()
		controls.append({"text":child.text,"center":[rect.get_center().x,rect.get_center().y]})
	report["buttons"]=controls
	var file:=FileAccess.open(directory+"/"+id+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report));file.close()
