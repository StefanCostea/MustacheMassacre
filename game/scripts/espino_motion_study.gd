extends "res://scripts/refined_character_review.gd"

const PREVIOUS := "res://assets/characters/don_espino_natural_review/don_espino_natural.glb"
const STUDY_CLIPS := ["idle", "shoot", "reload", "run_forward", "strafe_left", "strafe_right", "run_backward", "walk", "death"]

var previous: AnimationPlayer
var previous_pivot: Node3D
var replay_delay := 0.0

func _ready() -> void:
	super()
	previous_pivot = Node3D.new()
	add_child(previous_pivot)
	var old_model: Node3D = load(PREVIOUS).instantiate()
	previous_pivot.add_child(old_model)
	previous = old_model.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in STUDY_CLIPS:
		previous.get_animation(clip).loop_mode = animator.get_animation(clip).loop_mode
	clips = PackedStringArray(STUDY_CLIPS)
	previous_pivot.position.x = -1.5
	turntable.position.x = 1.5
	turntable.rotation_degrees.y = 32
	previous_pivot.rotation = turntable.rotation
	var camera := get_viewport().get_camera_3d()
	camera.position = Vector3(0, 2.6, 8)
	camera.look_at(Vector3.UP * 1.42)
	camera.size = 4.05
	_show_clip()

func _show_clip() -> void:
	if not previous:
		return
	var clip := clips[clip_index]
	for player: AnimationPlayer in [previous, animator]:
		player.stop()
		player.play(clip)
		player.advance(0)
	replay_delay = 0
	status.text = "Previous pass  /  Motion study     ·     %s\n← / →  clip     ·     A / D  rotate     ·     Space  replay     ·     Esc  exit" % clip

func _process(delta: float) -> void:
	super(delta)
	if not previous:
		return
	previous_pivot.rotation = turntable.rotation
	if not animator.is_playing():
		replay_delay += delta
		if replay_delay >= 0.7:
			_show_clip()
