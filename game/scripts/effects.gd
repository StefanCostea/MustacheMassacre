class_name CombatEffects
extends Node3D

const GOLD := Color("ffd475")
const DANGER := Color("f25b81")
const GREEN := Color("9de06a")
var active: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func add_effect(node: Node3D, life: float, motion: Vector3 = Vector3.ZERO, grow: float = 0.0, threat: bool = false, hostile_clock: bool = false) -> void:
	if active.size()>=180:
		for i in range(active.size()):
			if not active[i].threat:
				if is_instance_valid(active[i].node):active[i].node.queue_free()
				active.remove_at(i);break
	active.append({"node":node,"age":0.0,"life":life,"motion":motion,"grow":grow,"scale":node.scale,"threat":threat,"hostile_clock":hostile_clock})

func tracer(from: Vector3, to: Vector3, color: Color = GOLD, width: float = .025) -> void:
	if from.distance_to(to)<.01:return
	var beam := MeshKit.beam(self,from,to,width,MeshKit.material(color,.4,.1,2.8))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_effect(beam,.10)

func burst(pos: Vector3, color: Color = GOLD, count: int = 9, power: float = 1.0) -> void:
	for i in range(count):
		var dir := Vector3(rng.randf_range(-1,1),rng.randf_range(.1,1),rng.randf_range(-1,1)).normalized()
		var shard := MeshKit.sphere(self,pos,Vector3.ONE*rng.randf_range(.025,.065),MeshKit.material(color,.5,.0,1.3))
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_effect(shard,rng.randf_range(.18,.42),dir*rng.randf_range(1.3,4)*power,-.8)

func prop_fragments(pos: Vector3, fuel: bool) -> void:
	var enamel := MeshKit.material(Color("ab4733"),.63,.25)
	var boards := MeshKit.timber(Color("98683f"))
	for i in 6:
		var a := i*TAU/6. + rng.randf_range(-.28,.28)
		var outward := Vector3(cos(a),rng.randf_range(.36,.88),sin(a))
		var shard := MeshKit.box(self,Vector3(.075,.035,rng.randf_range(.14,.29)),pos+outward*.17,enamel if fuel else boards,.011)
		shard.rotation = Vector3(.6,a,.34*i)
		add_effect(shard,.34+rng.randf_range(0,.16),outward*(3.8 if fuel else 2.3),-.9)

func egg_shells(pos: Vector3) -> void:
	for i in 8:
		var angle := i * TAU / 8.0
		var outward := Vector3(cos(angle),.45+randf()*.5,sin(angle))
		var chip := MeshKit.sphere(self,pos,Vector3(.085,.029,.057),MeshKit.material(Color("ffe6bd")))
		chip.rotation = Vector3(angle,.4,angle*.6)
		add_effect(chip,.29+rng.randf_range(0,.13),outward*2.6,-1.2)

func fall_contact(pos: Vector3, kind: String) -> void:
	var heavy := kind in ["fridge","boss"]
	var count := 9 if heavy else 5
	var size := .135 if kind == "boss" else .095 if heavy else .059
	var dust := MeshKit.material(Color("b39876"),.97)
	for i in count:
		var angle := TAU*i/count+rng.randf_range(-.16,.16)
		var radial := Vector3(cos(angle),0,sin(angle))
		var puff := MeshKit.sphere(self,pos+radial*size,Vector3(1.45,.66,1)*size,dust)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_effect(puff,.28+rng.randf_range(0,.12),radial*(1.75 if heavy else 1.0)+Vector3.UP*.14,-1.7)

func ring(pos: Vector3, radius: float, color: Color, life: float, grow: float = 0.0, hostile_clock: bool = true) -> Node3D:
	var o := MeshKit.ring(self,Vector3(pos.x,.04,pos.z),radius,.045,MeshKit.material(color,.7,0,.9))
	add_effect(o,life,Vector3.ZERO,grow,color==DANGER,color==DANGER and hostile_clock)
	return o

func warning_line(from: Vector3, to: Vector3, life: float, width: float = .04) -> void:
	var o := MeshKit.beam(self,Vector3(from.x,.045,from.z),Vector3(to.x,.045,to.z),width,MeshKit.material(DANGER,.6,0,1.0))
	add_effect(o,life,Vector3.ZERO,0,true,true)

func number(pos: Vector3, amount: float, critical: bool) -> void:
	caption(pos,str(roundi(amount))+ ("!" if critical else ""),GOLD if critical else Color("f4e5c9"),38 if critical else 28)

func caption(pos: Vector3, value: String, color: Color, size: int = 30) -> void:
	var label := MeshKit.label(self,value,pos,size,color,.006)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 8
	add_effect(label,.65,Vector3(0,.8,0))

func _process(delta: float) -> void:
	for i in range(active.size()-1,-1,-1):
		var e: Dictionary = active[i]
		if not is_instance_valid(e.node):active.remove_at(i);continue
		e.age += delta*(get_parent().hostile_time_scale if e.hostile_clock else 1.0)
		if e.age>=e.life:e.node.queue_free();active.remove_at(i);continue
		e.node.position += e.motion*delta
		if e.grow!=0:e.node.scale=e.scale*maxf(.03,1+e.grow*e.age/e.life)
		if e.node is Label3D:e.node.modulate.a = minf(1,(1-e.age/e.life)*3)
		elif not e.threat and e.age/e.life>.75:e.node.scale*=maxf(.01,1-delta*6)
