class_name EnemyVisual
extends Node3D

var body: Node3D
var door: Node3D
var feet: Array[Node3D] = []
var wings: Array[Node3D] = []
var kind: String
var time: float = 0.0
var flash: float = 0.0
var renderers: Array[MeshInstance3D] = []
var motion: BadlandsEnemyMotion

func build(type: String, original := false) -> void:
	kind=type
	if not original or kind in ["skillet","repair"]:
		motion = BadlandsEnemyMotion.new()
		add_child(motion)
		motion.build(kind)
		_collect(motion)
		return
	body=Node3D.new();add_child(body)
	if kind in ["fridge","boss"]:_fridge()
	elif kind=="chili":_chili()
	else:_pigeon()
	_collect(body)

func _collect(node: Node) -> void:
	if node is MeshInstance3D:renderers.append(node)
	for child in node.get_children():_collect(child)

func _moustache(parent: Node3D, pos: Vector3, width: float = .18) -> void:
	var hair:=MeshKit.material(Color("30211a"))
	for sign in [-1,1]:
		var lobe:=MeshKit.sphere(parent,pos+Vector3(sign*width*.6,0,0),Vector3(width,.055,.065),hair)
		lobe.rotation.z=sign*.36
		MeshKit.beam(parent,pos+Vector3(sign*width*.95,-.035,0),pos+Vector3(sign*width*1.65,-.095,-.01),.025,hair)

func _hat(parent: Node3D, pos: Vector3, size: float) -> void:
	var brown:=MeshKit.material(Color("68432d"))
	MeshKit.cylinder(parent,pos,size,.07,brown)
	MeshKit.cylinder(parent,pos+Vector3.UP*.15,size*.63,.30,brown)
	MeshKit.cylinder(parent,pos+Vector3.UP*.04,size*.64,.09,MeshKit.material(Color("30251e")))

func _fridge() -> void:
	var enamel:=MeshKit.material(Color("72a7a0") if kind=="fridge" else Color("657b9d"),.45,.2)
	var trim:=MeshKit.material(Color("414a47"),.5,.6)
	MeshKit.box(body,Vector3(.88,1.42,.65),Vector3(0,.84,0),enamel,.095)
	MeshKit.box(body,Vector3(.78,.45,.08),Vector3(0,1.27,.36),enamel)
	door=Node3D.new();door.position=Vector3(-.40,.62,.36);body.add_child(door)
	MeshKit.box(door,Vector3(.78,.77,.08),Vector3(.40,0,0),enamel)
	MeshKit.box(door,Vector3(.06,.25,.08),Vector3(.70,.12,.08),trim)
	MeshKit.box(body,Vector3(.7,.02,.08),Vector3(0,1.0,.38),trim)
	for sign in [-1,1]:
		var eye:=MeshKit.box(body,Vector3(.14,.055,.045),Vector3(sign*.17,1.34,.42),MeshKit.material(Color("ffb553"),.4,0,.7))
		eye.rotation.z=sign*.23
		var foot:=MeshKit.box(self,Vector3(.24,.18,.37),Vector3(sign*.25,.10,.06),trim)
		feet.append(foot)
	_moustache(body,Vector3(0,1.16,.44),.19)
	for j in range(4):MeshKit.box(body,Vector3(.48,.025,.03),Vector3(0,.33+j*.07,-.34),trim,.003)
	if kind=="boss":
		_hat(body,Vector3(0,1.62,0),.70)
		MeshKit.label(body,"★",Vector3(0,1.78,.42),64,Color("ffcf5c"),.007)
		MeshKit.box(body,Vector3(.95,.15,.72),Vector3(0,.58,0),MeshKit.material(Color("795235")))
		MeshKit.label(body,"★",Vector3(0,.60,.39),46,Color("ffd370"),.006)
		scale=Vector3.ONE*1.6

func _chili() -> void:
	var red:=MeshKit.material(Color("c54933"),.65)
	var green:=MeshKit.material(Color("5c783d"))
	MeshKit.sphere(body,Vector3(0,.87,0),Vector3(.33,.57,.28),red)
	MeshKit.sphere(body,Vector3(.11,.38,-.02),Vector3(.20,.30,.19),red)
	MeshKit.beam(body,Vector3(0,1.35,0),Vector3(.12,1.65,-.04),.06,green)
	_hat(body,Vector3(0,1.34,0),.44)
	for sign in [-1,1]:
		MeshKit.sphere(body,Vector3(sign*.12,1.05,.26),Vector3(.055,.045,.035),MeshKit.material(Color("f7d57b"),.4,0,.3))
		MeshKit.beam(body,Vector3(sign*.27,.9,0),Vector3(sign*.43,.7,.12),.045,red)
		var foot:=MeshKit.box(self,Vector3(.15,.22,.26),Vector3(sign*.15,.16,0),MeshKit.material(Color("51402a")))
		feet.append(foot)
	_moustache(body,Vector3(0,.92,.29),.15)
	var gun:=MeshKit.cylinder(body,Vector3(.43,.78,.38),.045,.35,MeshKit.material(Color("9b9d93"),.3,.8))
	gun.rotation.x=PI/2
	MeshKit.box(body,Vector3(.08,.20,.10),Vector3(.43,.70,.25),MeshKit.material(Color("423126")))
	MeshKit.cylinder(body,Vector3(0,.60,0),.30,.12,MeshKit.material(Color("9d773b")))

func _pigeon() -> void:
	var feathers:=MeshKit.material(Color("768ba3"),.8)
	var cream:=MeshKit.material(Color("e0d1ad"))
	var orange:=MeshKit.material(Color("d2994c"))
	MeshKit.sphere(body,Vector3(0,1.0,0),Vector3(.43,.48,.36),feathers)
	MeshKit.sphere(body,Vector3(0,1.47,.17),Vector3(.25,.26,.26),cream)
	MeshKit.sphere(body,Vector3(0,1.36,.40),Vector3(.12,.085,.18),orange)
	for sign in [-1,1]:
		MeshKit.sphere(body,Vector3(sign*.12,1.53,.39),Vector3(.075,.065,.03),MeshKit.material(Color("2a292b"),.3))
		var wing:=Node3D.new();wing.position=Vector3(sign*.35,1.18,0);body.add_child(wing)
		var feather:=MeshKit.sphere(wing,Vector3(sign*.25,0,0),Vector3(.38,.10,.30),feathers)
		feather.rotation.z=-sign*.15
		wings.append(wing)
		MeshKit.beam(body,Vector3(sign*.15,.68,0),Vector3(sign*.15,.45,.06),.035,orange)
		MeshKit.beam(body,Vector3(sign*.15,.45,.06),Vector3(sign*.15,.44,.22),.035,orange)
	_moustache(body,Vector3(0,1.29,.44),.19)
	MeshKit.box(body,Vector3(.66,.15,.58),Vector3(0,.85,0),MeshKit.material(Color("564935")))
	for sign in [-1,1]:MeshKit.sphere(body,Vector3(sign*.31,.82,.18),Vector3(.09,.14,.09),cream)

func hit() -> void:
	if motion: motion.hurt()
	flash=.12
	for renderer in renderers:renderer.material_overlay=MeshKit.material(Color(1,.8,.6,.4),.7,0,.5)

func animate(delta: float, speed: float, state: String) -> void:
	if motion:
		motion.tick(delta, speed, state)
		_fade_hit(delta)
		return
	time+=delta
	body.position.y=sin(time*(12 if speed>.2 else 3))*(.035 if speed>.2 else .012)
	if kind=="pigeon":
		body.position.y+=.08*sin(time*3)
		for i in range(wings.size()):wings[i].rotation.z=(1 if i==0 else -1)*sin(time*10)*.35
	for i in range(feet.size()):feet[i].position.z=sin(time*12+i*PI)*minf(.14,speed*.035)
	if door:door.rotation.y=lerp_angle(door.rotation.y,-1.0 if state=="charge" else 0.0,delta*9)
	body.rotation.x=lerpf(body.rotation.x,-.16 if state=="charge" else 0.0,delta*8)
	_fade_hit(delta)

func _fade_hit(delta: float) -> void:
	if flash>0:
		flash-=delta
		if flash<=0:
			for renderer in renderers:renderer.material_overlay=null
