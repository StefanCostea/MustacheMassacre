extends RefCounted

var folder := "user://playtests"
func current_path() -> String:
	return folder.path_join("current.json")
var active := false
var data := {}
var started := false
var results_pending := false

func open_session() -> void:
	active=true
	DirAccess.make_dir_recursive_absolute(folder)
	if FileAccess.file_exists(current_path()):
		var decoded=JSON.parse_string(FileAccess.get_file_as_string(current_path()))
		if decoded is Dictionary and decoded.get("runs",null) is Array:
			data=decoded
			if data.runs.size()<2:
				results_pending=not data.get("result",{}).is_empty()
				return
			# A completed pair was committed before its archive was finalized.
			if not save(folder.path_join(str(data.id)+".json")):
				active=false
				return
	data={"id":"%d-%d"%[int(Time.get_unix_time_from_system()),Time.get_ticks_usec()],"runs":[],"result":{}}
	save()

func save(path: String="") -> bool:
	if path=="":path=current_path()
	var file:=FileAccess.open(path+".new",FileAccess.WRITE)
	if not file:return false
	file.store_string(JSON.stringify(data,"  "))
	file.close()
	return DirAccess.rename_absolute(path+".new",path)==OK

func begin(hero: EspinoPlayer) -> void:
	if not active:return
	started=true
	data.current={"hero":"coo" if hero.is_coo else "espino","ultimate":"coo_bombing" if hero.is_coo else hero.equipped_special,"field":"egg_drop" if hero.is_coo else hero.field_skill,"picks":[]}
	save()

func picked(key: String, offered: Array) -> void:
	if not started:return
	data.current.picks.append({"offered":offered.duplicate(),"selected":key})
	save()

func finish(game: GameDirector, won: bool) -> void:
	if not started:return
	started=false
	results_pending=true
	data.result={"won":won,"kills":game.kills,"seconds":game.run_time,"chain":game.highest_chain,"cause":game.best_play,"wax":game.wax_earned}
	save()

func answer(big_hit: String, next_build: String) -> bool:
	if not results_pending or big_hit.strip_edges()=="" or (data.runs.is_empty() and next_build.strip_edges()==""):return false
	var record:Dictionary=data.current.duplicate(true)
	record.merge(data.result)
	record.observed_cause=big_hit.strip_edges()
	record.next_intent=next_build.strip_edges()
	var prior_result:Dictionary=data.result
	data.runs.append(record)
	var complete:bool=data.runs.size()==2
	data.result={}
	if not save():
		data.runs.pop_back()
		data.result=prior_result
		return false
	if complete:
		if save(folder.path_join(str(data.id)+".json")):
			DirAccess.remove_absolute(current_path())
		active=false
	results_pending=false
	return true
