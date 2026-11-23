extends Node3D

const PREVIOUS_MODELS := [
	preload("res://assets/enemies/design_review/fridge_bruiser.glb"),
	preload("res://assets/enemies/design_review/chili_bandit.glb"),
	preload("res://assets/enemies/design_review/pigeon_bomber.glb"),
	preload("res://assets/enemies/design_review/el_frigorifico.glb"),
	preload("res://assets/enemies/design_review/skillet_outlaw.glb"),
	preload("res://assets/enemies/design_review/repair_appliance.glb")
]
const NAMES := ["Fridge Bruiser", "Chili Bandit", "Pigeon Bomber", "El Frigorífico", "Skillet Outlaw", "Repair Appliance"]
const HEIGHTS := [1.58, 1.72, 1.35, 2.60, 1.72, 1.48]
const POSITIONS := [-5.4, -3.25, -1.14, 1.12, 3.44, 5.55]
const KINDS := ["fridge", "chili", "pigeon", "boss", "skillet", "repair"]
const SHOWCASE := ["takeoff", "idle", "move", "windup", "attack", "recover", "ice_windup", "ice_attack", "ice_recover", "hurt", "death", "strafe_left", "strafe_right", "backstep"]
const DURATIONS := [.85, 1.6, 1.8, .75, .95, .75, .8, .56, .74, .35, 1.87,1.3,1.3,1.3]

var figures: Array[Node3D] = []
var motions: Array[BadlandsEnemyMotion] = []
var originals: Array[EnemyVisual] = []
var captions: Array[Label] = []
var camera := Camera3D.new()
var title := Label.new()
var focus := -1
var high_angle := false
var comparison := 0
var step := 0
var elapsed := 0.0
var automatic := true
var fired_rounds := 0
var status := Label.new()
var hostile_time_scale := 1.0
var effects := CombatEffects.new()
var thrown_egg: Node3D
var egg_start: Vector3
var egg_end: Vector3
var egg_age := -1.0
var impacts := {}

func _ready() -> void:
	add_child(effects)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("302925")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("e1e6f1")
	world.environment.ambient_light_energy = 0.63
	world.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 30, 0)
	key.light_color = Color("fff1e1")
	key.light_energy = 1.6
	key.light_specular = 0.55
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 25.0
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30, 150, 0)
	rim.light_color = Color("c4daee")
	rim.light_energy = 0.8
	rim.light_specular = 0.35
	add_child(rim)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(200, 200)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("655950")
	floor_mesh.material = floor_material
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	add_child(floor_instance)
	for i in KINDS.size():
		var pivot := Node3D.new()
		add_child(pivot)
		var motion := BadlandsEnemyMotion.new()
		pivot.add_child(motion)
		motion.build(KINDS[i])
		motions.append(motion)
		pivot.add_child(PREVIOUS_MODELS[i].instantiate())
		var original := EnemyVisual.new()
		pivot.add_child(original)
		original.build(KINDS[i], true)
		originals.append(original)
		figures.append(pivot)
	thrown_egg = BadlandsEnemyMotion.EGG_BOMB.instantiate()
	figures[2].add_child(thrown_egg)
	thrown_egg.hide()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(32, 20)
	layer.add_child(panel)
	title.add_theme_font_override("font", preload("res://assets/fonts/WesternSerif.ttf"))
	title.add_theme_font_size_override("font_size", 36)
	panel.add_child(title)
	var controls := Label.new()
	controls.text = "1–6  Inspect     0  Lineup     ← / →  Clip     Space  Auto     A / D  Turn     B  Compare     Tab  Arena view     Esc  Close"
	controls.add_theme_font_override("font", preload("res://assets/fonts/Interface.ttf"))
	controls.add_theme_font_size_override("font_size", 18)
	panel.add_child(controls)
	panel.add_child(status)
	for enemy_name in NAMES:
		var caption := Label.new()
		caption.text = enemy_name
		caption.add_theme_font_override("font", preload("res://assets/fonts/WesternSerif.ttf"))
		caption.add_theme_font_size_override("font_size", 22)
		caption.add_theme_constant_override("outline_size", 4)
		caption.add_theme_color_override("font_outline_color", Color("38302b"))
		layer.add_child(caption)
		captions.append(caption)
	get_viewport().size_changed.connect(_frame)
	_frame()
	_play_step()

func _frame() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var target := Vector3.UP * 1.32
	title.text = "The Crispy Badlands"
	camera.size = maxf(3.65, 13.6 / aspect)
	var direction := Vector3(0.0, 0.11, 1.0)
	if high_angle:
		direction = Vector3(12, 19, 18)
		camera.size = 17.0
	if focus >= 0:
		title.text = NAMES[focus]
		target.y = HEIGHTS[focus] * 0.52
		camera.size = maxf(HEIGHTS[focus] * 1.36, 2.65 / aspect)
		if focus == 2 and comparison == 0:
			target.y = 1.68
			camera.size = 4.5
		if SHOWCASE[step] == "death" and comparison == 0 and not high_angle:
			direction = Vector3(0,.44,1)
			camera.size *= 1.10
			if focus in [0,1]: target += figures[focus].basis.x*.25*HEIGHTS[focus]
	if comparison == 1: title.text += " · Previous sculpt"
	if comparison == 2: title.text += " · Prototype"
	status.visible = comparison == 0
	thrown_egg.visible = comparison == 0 and egg_age >= 0
	camera.position = target + direction.normalized() * 15.0
	camera.look_at(target)
	var right := camera.global_basis.x
	for i in figures.size():
		var figure := figures[i]
		figure.visible = focus == -1 or i == focus
		figure.position = right * POSITIONS[i] if focus == -1 else Vector3.ZERO
		motions[i].visible = comparison == 0
		figure.get_child(1).visible = comparison == 1
		originals[i].visible = comparison == 2
		var caption := captions[i]
		caption.visible = focus == -1 and not high_angle
		caption.position = camera.unproject_position(figure.position) + Vector2(-caption.size.x * 0.5, 42)

func _process(delta: float) -> void:
	var turn := Input.get_axis("move_left", "move_right")
	for figure in figures:
		if figure.visible:
			figure.rotation.y += turn * delta * 1.7
	if comparison != 0: return
	elapsed += delta
	for motion in motions:
		motion.animator.advance(delta)
		motion.sync_payload()
	_update_flight()
	if SHOWCASE[step] == "death":
		for i in motions.size():
			var kind: String = KINDS[i]
			if not figures[i].visible or impacts.has(i): continue
			if elapsed >= motions[i].animator.get_animation("death").length*float(BadlandsEnemyMotion.IMPACT_PHASE[kind]):
				var point := motions[i].socket(&"Cabinet")
				point.y=.03
				effects.fall_contact(point,kind)
				impacts[i]=true
	if egg_age >= 0:
		egg_age += delta
		thrown_egg.position = CombatProjectile.lob_position(egg_start,egg_end,minf(1,egg_age/.9))
		thrown_egg.rotate_x(delta*5.5)
		if egg_age >= .9:
			if figures[2].visible:
				effects.egg_shells(thrown_egg.global_position)
				effects.ring(thrown_egg.global_position,.32,CombatEffects.DANGER,.35,3,false)
				effects.burst(thrown_egg.global_position,CombatEffects.DANGER,12)
			egg_age=-1
			thrown_egg.hide()
	if SHOWCASE[step] == "attack" and fired_rounds < 3 and elapsed >= fired_rounds * .16:
		motions[1].play_clip(&"attack", .16, 0.0)
		fired_rounds += 1
		_show_shot()
	if SHOWCASE[step] == "attack":
		for i in [1,2]:
			if (i==2 or fired_rounds==3) and motions[i].clip==&"attack" and not motions[i].animator.is_playing():
				motions[i].recover()
	if elapsed >= DURATIONS[step]:
		if automatic: _next_step(1)
		_play_step()

func _next_step(direction: int) -> void:
	step = posmod(step + direction, SHOWCASE.size())
	while focus >= 0 and not motions[focus].animator.has_animation(SHOWCASE[step]):
		step = posmod(step + direction, SHOWCASE.size())

func _play_step() -> void:
	elapsed = 0.0
	fired_rounds = 1
	egg_age = -1
	impacts.clear()
	thrown_egg.hide()
	status.text = ("Auto · " if automatic else "") + str(SHOWCASE[step]).capitalize()
	for i in motions.size():
		var name: StringName = SHOWCASE[step]
		if not motions[i].animator.has_animation(name): name = &"idle"
		var seconds := 0.0
		if name == &"windup" or name == &"ice_windup": seconds = DURATIONS[step]
		if name == &"attack" and i == 1: seconds = .16
		motions[i].play_clip(name, seconds, .045)
	_update_flight()
	_frame()
	if SHOWCASE[step] == "attack":
		_show_shot()
		egg_start = figures[2].to_local(motions[2].socket(&"Egg"))
		egg_end = Vector3(-1.65,.08,1.55)
		egg_age=0
		thrown_egg.position=egg_start
		thrown_egg.rotation=motions[2].payload.rotation
		thrown_egg.show()

func _show_shot() -> void:
	if not figures[1].visible or comparison != 0: return
	var point := motions[1].socket(&"Muzzle")
	effects.tracer(point,point+figures[1].global_basis.z*.42,CombatEffects.DANGER,.018)

func _update_flight() -> void:
	var height := BadlandsEnemyMotion.CRUISE_HEIGHT
	if SHOWCASE[step] == "takeoff":
		height *= BadlandsEnemyMotion.ascent(elapsed / BadlandsEnemyMotion.TAKEOFF_TIME)
	elif SHOWCASE[step] == "death":
		height *= 1.0-BadlandsEnemyMotion.descent(elapsed/motions[2].animator.get_animation("death").length)
	motions[2].position.y = height

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			focus = int(event.keycode) - KEY_1
			if focus >= 0 and not motions[focus].animator.has_animation(SHOWCASE[step]):
				step = SHOWCASE.find("idle")
				_play_step()
		KEY_TAB:
			high_angle = not high_angle
		KEY_B:
			comparison = (comparison + 1) % 3
		KEY_LEFT, KEY_RIGHT:
			comparison = 0
			automatic = false
			_next_step(1 if event.keycode == KEY_RIGHT else -1)
			_play_step()
		KEY_SPACE:
			comparison = 0
			automatic = not automatic
			_play_step()
		KEY_ESCAPE:
			get_tree().quit()
			return
		_:
			return
	_frame()
