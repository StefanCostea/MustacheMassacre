extends EnemyActor

# The variant is presentation and behaviour. The base profile preserves knockback,
# ricochets, reception of special attacks and the existing navigation controller.
const PROFILES := {
	"mustard":["chili",46.,2.25,13.,14.],
	"puppet":["fridge",42.,2.9,4.7,11.],
	"brush":["fridge",68.,2.3,4.4,14.],
	"dodgem":["fridge",80.,2.7,8.5,18.],
	"flushness":["fridge",375.,1.25,10.,17.],
	"cook":["skillet",130.,2.2,4.5,16.],
}
var variant: String
var struck:Dictionary = {}

func configure(director,id:String,at:Vector3) -> void:
	variant=id
	var profile:Array=PROFILES[id]
	setup(director,profile[0],at)
	spec=spec.duplicate()
	max_health=profile[1]
	health=max_health
	movement_speed=profile[2]
	spec.attack_range=profile[3]
	spec.damage=profile[4]
	if id=="cook":
		var white:=MeshKit.material(Color("fff1d7"))
		MeshKit.cylinder(visual,Vector3.UP*1.63,.25,.28,white)
		for i in 5:
			MeshKit.sphere(visual,Vector3(sin(i*TAU/5)*.145,1.85,cos(i*TAU/5)*.145),Vector3(.19,.18,.19),white)
	if id=="flushness" or id=="dodgem":
		var collider:CollisionShape3D=get_child(0)
		var capsule:CapsuleShape3D=collider.shape
		capsule.radius=.7
		capsule.height=2.6 if id=="flushness" else 1.42
		collider.position.y=capsule.height*.5

func build_visual() -> void:
	if variant=="cook":
		super.build_visual()
		return
	visual=preload("res://scripts/county_visual.gd").new()
	add_child(visual)
	visual.build(variant)

func can_be_flung() -> bool:
	return variant!="flushness" and super.can_be_flung()

func _begin_attack(dir:Vector3) -> void:
	super._begin_attack(dir)
	struck.clear()
	if variant in ["dodgem","mustard","flushness"]:
		timer=.93 if variant=="dodgem" else .82
		game.effects.warning_line(position,position+dir*spec.attack_range,timer,.08)

func _release_attack() -> void:
	if variant in ["mustard","flushness"]:
		var origin:=aim_center()+direction*.55
		if variant=="mustard":
			game.spawn_projectile(origin,direction*15,14,"enemy")
		else:
			for angle:float in [-.27,-.135,0.,.135,.27]:
				game.spawn_projectile(origin,direction.rotated(Vector3.UP,angle)*8.,spec.damage,"enemy")
		Sound.play("shot",-8,1.32 if variant=="mustard" else .62)
		visual.animate(0,0,"spray")
		state="recover"
		timer=.92
		return
	super._release_attack()
	if variant=="dodgem":timer=.98
	if variant=="brush" and position.distance_to(game.player.position)<2.8:
		game.player.knockback+=direction*6.5

func _physics_process(delta:float) -> void:
	if dead and not visual.motion:
		death_time-=delta
		visual.animate(delta,0,"death")
		if death_time<.28:
			for part in visual.renderers:part.transparency=clampf(1.-death_time/.28,0,1)
		if death_time<=0:queue_free()
		return
	super._physics_process(delta)
	if dead or variant!="dodgem" or state!="charge":return
	for other in game.enemies:
		if not is_instance_valid(other) or other==self or other.dead or struck.has(other.get_instance_id()):continue
		if position.distance_to(other.position)<1.65:
			struck[other.get_instance_id()]=true
			other.receive_hit(32,false,game.new_context("bumper_car"))
			game.effects.burst(other.aim_center(),CombatEffects.GOLD,8)

func collapse() -> void:
	if visual.motion:
		super.collapse()
	elif not dead:
		dead=true
		collision_layer=0
		death_time=visual.die()+.24
