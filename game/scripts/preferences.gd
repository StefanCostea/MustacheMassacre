extends Node

var settings_path := "user://settings.cfg"
var hero_id := "espino"
var field_skill := "tumbleweed"
var county_shortcuts:Array[String]=[]
var wax := 0
var workshop: Array[String] = []
var special := "high_noon"
var volume: float = 0.8
var music_volume: float = 0.6
var shake_strength: float = 0.65

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	var keys := {"move_left":KEY_A, "move_right":KEY_D, "move_forward":KEY_W, "move_back":KEY_S, "reload":KEY_R, "dash":KEY_SPACE, "ricochet":KEY_Q, "tumbleweed":KEY_E, "ultimate":KEY_F, "pause":KEY_ESCAPE, "start_run":KEY_ENTER, "county_interact":KEY_G, "county_map":KEY_M}
	for action in keys:
		if not InputMap.has_action(action):InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action,event)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire",mouse)

	_bind_mouse("fan_hammer", MOUSE_BUTTON_RIGHT)

func _bind_mouse(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action): return
	InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action,event)

func load_settings() -> void:
	var config := ConfigFile.new()
	hero_id = "espino"
	special = "high_noon"
	field_skill = "tumbleweed"
	wax = 0
	workshop.clear()
	county_shortcuts.clear()
	if config.load(settings_path) == OK:
		var character = config.get_value("loadout","hero","espino")
		if character in ["espino","coo"]:hero_id=character
		var saved = config.get_value("loadout","special","high_noon")
		if saved is String and saved in CombatConfig.SPECIALS:special=saved
		var active = config.get_value("loadout","field_skill","tumbleweed")
		if active is String and active in CombatConfig.FIELD_SKILLS:field_skill=active
		var balance = config.get_value("garage","wax",0)
		if balance is int:wax=maxi(0,balance)
		var roads = config.get_value("county","shortcuts",[])
		if roads is Array:
			for key in ["wheel","freight"]:
				if key in roads:county_shortcuts.append(key)
		var owned = config.get_value("garage","unlocks",[])
		if owned is Array:
			for key in owned:
				if key is String and key in CombatConfig.WORKSHOP and key not in workshop:workshop.append(key)
		volume = config.get_value("audio", "volume", 0.8)
		music_volume = config.get_value("audio", "music", 0.6)
		shake_strength = config.get_value("visual", "shake", 0.65)
	apply()

func apply() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.001)))
	AudioServer.set_bus_volume_db(1,linear_to_db(maxf(music_volume,0.001))-8.0)

func buy_upgrade(key: String) -> bool:
	if key not in CombatConfig.WORKSHOP or key in workshop or wax < CombatConfig.WORKSHOP[key]:return false
	var cost: int = CombatConfig.WORKSHOP[key]
	wax -= cost
	workshop.append(key)
	if save():return true
	workshop.erase(key)
	wax += cost
	return false

func save() -> bool:
	apply()
	var config := ConfigFile.new()
	config.set_value("loadout","hero",hero_id)
	config.set_value("loadout","special",special)
	config.set_value("audio","volume",volume)
	config.set_value("audio","music",music_volume)
	config.set_value("visual","shake",shake_strength)
	config.set_value("loadout","field_skill",field_skill)
	config.set_value("county","shortcuts",county_shortcuts)
	config.set_value("garage","wax",wax)
	config.set_value("garage","unlocks",workshop)
	var temp := settings_path+".new"
	if config.save(temp)!=OK:return false
	return DirAccess.rename_absolute(temp,settings_path)==OK
