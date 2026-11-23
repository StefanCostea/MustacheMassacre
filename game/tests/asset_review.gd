extends Node

var game: GameDirector

func setup(director: GameDirector) -> void:
	game=director
	run.call_deferred()

func run() -> void:
	await get_tree().process_frame
	game.set_process(false);game.ui.hide();game.arena.hide()
	for node in game.actors.get_children():
		if node!=game.player:node.hide();node.set_physics_process(false)
	var p:=game.player;p.test_mode=true;p.position=Vector3.ZERO;p.test_aim=Vector3(0,0,8)
	game.camera.position=Vector3(4,2.8,7);game.camera.look_at(Vector3(0,1.2,0));game.camera.size=3.5
	MeshKit.cylinder(game,Vector3(0,-.10,0),2.8,.16,MeshKit.material(Color("a18865")))
	print("ASSET clips=",p.animation_names," muzzle=",p.get_muzzle())
	for m in ClassDB.class_get_method_list("AnimationNodeBlendSpace2D"):
		if m.name=="add_blend_point":print("METHOD ",m)
	var output:=OS.get_user_data_dir()+"/asset_review";DirAccess.make_dir_recursive_absolute(output)
	for pose in ["idle","run_forward","shoot","reload","cast","ultimate","back","death"]:
		p.animation_tree.active=false
		var clip:String="idle" if pose=="back" else pose
		p.animation_player.play(p.animation_names[clip]);p.animation_player.seek(.4 if pose=="reload" else .12,true)
		p.animation_player.pause()
		p.test_aim=Vector3(0,0,-8) if pose=="back" else Vector3(0,0,8)
		if pose=="ultimate":
			p.frenzy_left=6
			p.form.begin()
			p.form.advance(1.1)
			p.form.end_camera()
		elif p.form.running:
			p.frenzy_left=0
			p.form.finish()
			p.position.y=0
		for i in range(4):await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output+"/"+pose+".png")
	print("ASSET_REVIEW ",output)
	game.quit_application()
