extends Node

var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var cursor: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name()=="headless":return
	for name in ["shot","hit","kill","dash","reload","perfect","ricochet","vortex","ultimate","hurt","explosion","warning","pickup","ui","victory","defeat"]:
		var path := "res://assets/audio/%s.wav" % name
		if ResourceLoader.exists(path):streams[name] = load(path)
	for i in range(24):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Effects"
		add_child(voice)
		voices.append(voice)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	if ResourceLoader.exists("res://assets/audio/badlands_loop.wav"):
		music.stream = load("res://assets/audio/badlands_loop.wav")
		music.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		music.stream.loop_end=int(music.stream.get_length()*music.stream.mix_rate)
		music.play()

func play(cue: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(cue) or voices.is_empty():return
	var important:=cue in ["warning","hurt","ultimate","victory","defeat"]
	var voice := voices[20+cursor%4 if important else cursor%20]
	cursor += 1
	voice.stream = streams[cue]
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()

func _exit_tree() -> void:
	for voice in voices:voice.stop();voice.stream=null
	if music:music.stop();music.stream=null
	streams.clear()
