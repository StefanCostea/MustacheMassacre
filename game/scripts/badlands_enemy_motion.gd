class_name BadlandsEnemyMotion
extends Node3D

const EGG_BOMB := preload("res://assets/enemies/props/egg_bomb.tscn")
const CRUISE_HEIGHT := 1.95
const TAKEOFF_TIME := .8
const CRASH_CONTACT := .665
const IMPACT_PHASE := {"pigeon": CRASH_CONTACT, "fridge": .615, "chili": .76, "boss": .71, "skillet":.66, "repair":.7}
const MODELS := {
	"fridge": preload("res://assets/enemies/animated/fridge_bruiser.glb"),
	"chili": preload("res://assets/enemies/animated/chili_bandit.glb"),
	"pigeon": preload("res://assets/enemies/animated/pigeon_bomber.glb"),
	"boss": preload("res://assets/enemies/animated/el_frigorifico.glb"),
	"skillet": preload("res://assets/enemies/animated/skillet_outlaw.glb"),
	"repair": preload("res://assets/enemies/animated/repair_appliance.glb")
}

var animator: AnimationPlayer
var skeleton: Skeleton3D
var clip: StringName = &""
var kind: String
var ice_sequence := false
var dead := false
var payload: Node3D
var death_keeps_egg := false
var local_travel := Vector2.ZERO

static func ascent(progress: float) -> float:
	return smoothstep(.20, 1.0, progress)

static func descent(progress: float) -> float:
	var t := clampf((progress - .09) / (CRASH_CONTACT - .09), 0, 1)
	return t * t

func build(enemy_kind: String) -> void:
	kind = enemy_kind
	var model: Node3D = MODELS[kind].instantiate()
	add_child(model)
	animator = model.find_children("*", "AnimationPlayer", true, false)[0]
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name in [&"idle", &"move", &"strafe_left", &"strafe_right", &"backstep"]:
		if animator.has_animation(name): animator.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	if kind == "pigeon":
		payload = EGG_BOMB.instantiate()
		add_child(payload)
	play_clip(&"idle", 0.0, 0.0)
	animator.seek(fmod(float(get_instance_id() % 997) * 0.17, animator.current_animation_length), true)

func play_clip(name: StringName, seconds := 0.0, blend := 0.055) -> void:
	clip = name
	animator.speed_scale = 1.0
	var speed := animator.get_animation(name).length / seconds if seconds > 0.0 else 1.0
	# Restart even on the second and third round of a burst.
	if animator.current_animation == name:
		animator.stop(true)
	animator.play(name, blend, speed)
	animator.advance(0.0)
	sync_payload()

func sync_payload() -> void:
	if not payload: return
	var phase := 1.0
	if animator.is_playing():
		phase = animator.current_animation_position / animator.current_animation_length
	var loaded := 1.0
	if clip == &"attack": loaded = 0
	elif clip == &"recover": loaded = smoothstep(.51,.78,phase)
	elif clip == &"takeoff": loaded = smoothstep(.32,.58,phase)
	elif clip == &"death": loaded = 1.0 - smoothstep(.52,.66,phase) if death_keeps_egg else 0.0
	payload.visible = loaded > .02
	payload.scale = Vector3.ONE * maxf(.001,loaded)
	payload.position = to_local(socket(&"Egg"))
	if loaded < 1 and clip in [&"recover", &"takeoff"]:
		payload.position += Vector3(0,.44,-.02)*(1-loaded)
	payload.rotation.z = -.19

func windup(seconds: float, ice: bool) -> void:
	ice_sequence = ice
	play_clip(&"ice_windup" if ice else &"windup", seconds)

func strike(seconds := 0.0) -> void:
	play_clip(&"ice_attack" if ice_sequence else &"attack", seconds, 0.0)

func recover() -> void:
	play_clip(&"ice_recover" if ice_sequence else &"recover")

func hurt() -> void:
	if not dead and clip in [&"idle", &"move", &"hurt"]:
		play_clip(&"hurt", 0.0, 0.025)

func die() -> float:
	dead = true
	death_keeps_egg = payload != null and payload.visible
	play_clip(&"death", 0.0, 0.06)
	return animator.get_animation(&"death").length

func tick(delta: float, travel: float, state: String) -> void:
	animator.advance(delta)
	sync_payload()
	if dead:
		return
	if state == "recover":
		var recovering: StringName = &"ice_recover" if ice_sequence else &"recover"
		if clip != recovering and (clip not in [&"attack", &"ice_attack"] or not animator.is_playing()):
			recover()
	elif state in ["chase", "idle"]:
		if clip == &"hurt" and animator.is_playing():
			return
		var next: StringName = &"move" if travel > 0.2 else &"idle"
		if kind=="chili" and next==&"move":
			if absf(local_travel.x)>absf(local_travel.y)*1.20:
				next = &"strafe_left" if local_travel.x<0 else &"strafe_right"
			elif local_travel.y<-.20: next=&"backstep"
		if clip != next:
			play_clip(next, 0.0, 0.10)
		if kind=="chili" and next!=&"idle":
			animator.speed_scale=clampf(travel/1.65,.65,1.65)

func socket(name: StringName) -> Vector3:
	var bone := skeleton.find_bone(name)
	assert(bone >= 0, "Missing enemy attack socket %s" % name)
	return skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
