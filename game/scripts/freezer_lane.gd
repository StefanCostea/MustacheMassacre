extends Node3D

const WARNING := 1.45
const ACTIVE := 2.40
const OPENING := 2.1
const WIDTH := 2.7
const ICE := Color("85e5ff")
var age := 0.0
var game: GameDirector
var sheriff: EnemyActor
var sheet: MeshInstance3D
var marks := Node3D.new()
var fired := false
var exposed := false
var damage_clock := 0.0

func setup(director: GameDirector, boss: EnemyActor) -> void:
	game=director
	sheriff=boss
	position.z=game.player.position.z if game.county else clampf(game.player.position.z,-9,9)
	position.x=boss.position.x if game.county else 0.
	add_child(marks)
	var edge:=MeshKit.material(ICE,.45,.2,1.2)
	for side:float in [-1.,1.]:
		MeshKit.box(marks,Vector3(27,.025,.075),Vector3(0,.055,side*WIDTH*.5),edge,.01)
	for i in range(-6,7):
		var stripe:=MeshKit.box(marks,Vector3(.11,.02,WIDTH*.88),Vector3(i*2,.05,0),edge,.01)
		stripe.rotation.y=.42
	sheet=MeshKit.box(self,Vector3(27,.055,WIDTH),Vector3(0,.046,0),MeshKit.material(Color(.27,.78,.98,.58),.17,.4,.4),.018)
	sheet.hide()
	sheriff.state="vent"
	sheriff.velocity=Vector3.ZERO
	if sheriff.visual.motion:sheriff.visual.motion.windup(WARNING,true)
	game.ui.toast("FREEZER BURN","Leave the striped lane before the vent opens.",ICE)
	Sound.play("warning",-4,.65)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(sheriff) or sheriff.dead or not game.is_fighting():
		queue_free()
		return
	age+=delta*game.hostile_time_scale
	if sheriff.hatch:
		var close_at:=WARNING+ACTIVE+OPENING
		sheriff.hatch.rotation.y=-1.99*smoothstep(WARNING-.20,WARNING+.1,age)*(1.-smoothstep(close_at-.24,close_at,age))
	if age<WARNING:
		marks.scale.z=.92+.08*cos(TAU*age/.34)
		return
	if not fired:
		fired=true
		marks.show()
		sheet.show()
		if sheriff.visual.motion:sheriff.visual.motion.strike(ACTIVE)
		var nozzle:=sheriff.visual.motion.socket(&"Vent") if sheriff.visual.motion else sheriff.aim_center()
		game.effects.tracer(nozzle,Vector3(sheriff.position.x,.15,position.z),ICE,.11)
		game.effects.burst(nozzle,ICE,22,1.3)
		Sound.play("explosion",-5,.72)
	if age<WARNING+ACTIVE:
		damage_clock-=delta
		var hero:=game.player
		if absf(hero.position.x-position.x)<13.5 and absf(hero.position.z-position.z)<=WIDTH*.5 and hero.position.y<.35 and damage_clock<=0:
			if hero.receive_hit(15):
				damage_clock=.9
		return
	if not exposed:
		exposed=true
		hide()
		sheriff.state="vent_open"
		if sheriff.visual.motion:sheriff.visual.motion.recover()
		game.ui.toast("VENT EXPOSED","Hit the sheriff while the coils cool.",CombatEffects.GOLD)
		game.effects.caption(sheriff.aim_center()+Vector3.UP,"EXPOSED ×1.5",CombatEffects.GOLD)
	if age>=WARNING+ACTIVE+OPENING:
		if sheriff.hatch:sheriff.hatch.rotation.y=0
		sheriff.state="recover"
		sheriff.timer=.3
		queue_free()
