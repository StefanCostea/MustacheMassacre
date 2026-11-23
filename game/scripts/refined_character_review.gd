extends Node3D

# Independent asset review. The playable hero remains unchanged until acceptance.
@export_file("*.glb") var asset_path: String = "res://assets/characters/don_espino_refined_review/don_espino_review.glb"
@export var review_title: String = "DON ESPINO · ANIMATION PILOT · NOT APPROVED"
@export var review_note: String = "Review arm / weapon and leg deformation before gameplay use."
@export var capture_folder: String = "res://../desgin/renders/don_espino/refined_workflow/"
var model: Node3D
var animator: AnimationPlayer
var clips: PackedStringArray = []
var clip_index: int = 0
var status: Label
var turntable: Node3D

func _ready() -> void:
	var world:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("29231e")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("c8d1df")
	environment.ambient_light_energy=.65
	world.environment=environment;add_child(world)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-40,-35,0);key.light_energy=1.5;key.shadow_enabled=true;add_child(key)
	var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(12,12);floor.mesh=plane
	var material:=StandardMaterial3D.new();material.albedo_color=Color("6a5846");floor.material_override=material;add_child(floor)
	turntable=Node3D.new();add_child(turntable)
	model=load(asset_path).instantiate();turntable.add_child(model)
	var players:=model.find_children("*","AnimationPlayer",true,false)
	if not players.is_empty():
		animator=players[0]
		for clip in animator.get_animation_list():
			if clip!="RESET":
				clips.append(clip)
				if clip in ["idle","walk","run_forward","run_backward","strafe_left","strafe_right"]:animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.1
	add_child(camera);camera.position=Vector3(4,2.7,6);camera.look_at(Vector3(0,1.5,0));camera.current=true
	var layer:=CanvasLayer.new();add_child(layer)
	status=Label.new();status.position=Vector2(30,25);status.add_theme_font_size_override("font_size",20);layer.add_child(status)
	_show_clip()
	print("REFINED_REVIEW skeletons=",model.find_children("*","Skeleton3D",true,false).size()," clips=",clips)
	if "--refined-review-capture" in OS.get_cmdline_user_args():
		var folder:=ProjectSettings.globalize_path(capture_folder)
		for index in range(maxi(1,clips.size())):
			clip_index=index;_show_clip()
			if animator and not clips.is_empty():
				animator.seek(animator.current_animation_length*.3,true);animator.pause()
			for i in range(8):await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var name:="static" if clips.is_empty() else clips[index].validate_filename()
			get_viewport().get_texture().get_image().save_png(folder+"09_godot_"+name+".png")
		_quit()

func _show_clip() -> void:
	if clips.is_empty():
		status.text="DON ESPINO · REFINED MESH REVIEW\nStatic preparation only · no accepted rig or animations yet\nA / D: turn character   ·   Esc: close"
	else:
		var clip:=clips[clip_index]
		animator.play(clip)
		status.text=review_title+"\n%s   ·   Left / Right: select clip   ·   Space: replay\nA / D: turn character   ·   Esc: close\n"%clip+review_note

func _process(delta: float) -> void:
	turntable.rotation.y+=Input.get_axis("move_left","move_right")*delta

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):_quit()
	if clips.is_empty():return
	if event.is_action_pressed("ui_accept"):_show_clip()
	if event.is_action_pressed("ui_right"):clip_index=(clip_index+1)%clips.size();_show_clip()
	if event.is_action_pressed("ui_left"):clip_index=posmod(clip_index-1,clips.size());_show_clip()

func _quit() -> void:
	for voice in Sound.voices:voice.stop();voice.stream=null
	if Sound.music:Sound.music.stop();Sound.music.stream=null
	if DisplayServer.get_name()!="headless":await get_tree().create_timer(.12,true).timeout
	get_tree().quit()
