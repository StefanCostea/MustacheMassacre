extends "res://tests/combat_tests.gd"

func run() -> void:
	await frames(3)
	var first:bool=game.playtest.data.runs.is_empty()
	if first:
		game.player.equip_hero("espino")
	else:
		check(game.ui.panel_kind=="loadout","Second run opens the character selector after a scene restart")
		var coo:Button=game.ui.host.find_child("pilot_coo",true,false)
		coo.pressed.emit()
		game.ui.leave_loadout()
	game.start_run()
	game.show_upgrades()
	await frames(3)
	var cards:Array=game.ui.host.find_children("*","Button",true,false)
	cards[0].pressed.emit()
	game.player.receive_hit(1000)
	await frames(96)
	check(game.ui.panel_kind=="playtest" and get_tree().paused,"Run ends in the local two-question form")
	if failed:
		game.quit_application(1)
		return
	var fields:Array=game.ui.host.find_children("*","LineEdit",true,false)
	var submit:Button=game.ui.host.find_children("*","Button",true,false)[0]
	submit.pressed.emit()
	check(game.ui.panel_kind=="playtest" and game.playtest.results_pending,"Empty observation leaves the form open")
	fields[0].text="Automated UI fixture"
	fields[1].text="Test Coo" if first else "Finished"
	if failed:
		game.quit_application(1)
		return
	submit.pressed.emit()
	if first:return
	var survey=game.playtest
	var saved=JSON.parse_string(FileAccess.get_file_as_string(survey.folder.path_join(str(survey.data.id)+".json")))
	check(game.ui.panel_kind=="playtest_finished" and not FileAccess.file_exists(survey.current_path()),"Submitting the second form closes the pair")
	check(saved.runs[0].next_intent=="Test Coo" and saved.runs[1].hero=="coo" and saved.runs[1].field=="egg_drop" and saved.runs[1].picks[0].selected in saved.runs[1].picks[0].offered,"Persisted player intent and actual card selection survive the restart")
	print("PAIRED_UI_TEST checks=",passed+failed," failures=",failed," runs=",saved.runs.size())
	game.quit_application(1 if failed else 0)
