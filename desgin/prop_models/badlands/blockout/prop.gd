class_name BreakableProp
extends StaticBody3D

var kind: String = "barrel"
var health: float = 35.0
var game
var fuse: float = -1.0
var spent: bool = false
var visual: Node3D

func setup(director, type: String, pos: Vector3) -> void:
	game=director;kind=type;position=pos
	collision_layer=8;collision_mask=0
	add_to_group("breakables")
	visual=Node3D.new();add_child(visual)
	var wood := MeshKit.timber(Color("8c542c"))
	var iron := MeshKit.material(Color("373b36"),.55,.65)
	var shape := CollisionShape3D.new()
	if kind=="barrel":
		var cylinder := CylinderShape3D.new();cylinder.radius=.40;cylinder.height=1.4;shape.shape=cylinder;shape.position.y=.7
		visual.scale.y=1.4/1.05
		for i in range(14):
			var a:=TAU*i/14.0
			var stave:=MeshKit.box(visual,Vector3(.18,1.02,.09),Vector3(cos(a)*.35,.52,sin(a)*.35),wood,.015)
			stave.rotation.y=PI/2-a
		MeshKit.cylinder(visual,Vector3(0,.97,0),.36,.06,wood)
		for y in [.17,.52,.85]:MeshKit.ring(visual,Vector3(0,y,0),.395,.055,iron).scale.y=2.2
		MeshKit.label(visual,"FUEL",Vector3(0,.65,.40),30,Color("f7d285"),.005)
		MeshKit.label(visual,"✹",Vector3(0,.35,.405),40,Color("e38754"),.005)
	else:
		health=25
		var box:=BoxShape3D.new();box.size=Vector3(.85,.85,.85);shape.shape=box;shape.position.y=.425
		MeshKit.box(visual,box.size,shape.position,wood)
		for y in [.1,.75]:MeshKit.box(visual,Vector3(.95,.13,.95),Vector3(0,y,0),iron)
		for i in range(5):MeshKit.box(visual,Vector3(.015,.8,.87),Vector3(-.35+i*.175,.425,0),iron,.002)
		var cross:=MeshKit.box(visual,Vector3(.13,1.0,.10),Vector3(0,.425,.48),wood)
		cross.rotation.z=-.7
		visual.scale.y=1.4/.85
		box.size.y=1.4;shape.position.y=.7
	add_child(shape)

func receive_hit(damage: float, _critical: bool = false, _context: Dictionary = {}) -> void:
	if spent or fuse>=0:return
	health-=damage
	game.effects.burst(global_position+Vector3.UP*.5,CombatEffects.GOLD,5)
	if health<=0:
		if kind=="barrel":
			fuse=.55
			game.effects.ring(global_position,2.3,CombatEffects.DANGER,.55,0,false)
			Sound.play("warning",-7,.9)
		else:
			spent=true;collision_layer=0
			game.effects.burst(global_position+Vector3.UP*.5,Color("ad8050"),12,1.3)
			Sound.play("explosion",-12,1.5)
			queue_free()

func _process(delta: float) -> void:
	if fuse<0 or spent:return
	fuse-=delta
	visual.scale=Vector3.ONE*(1+.035*sin(fuse*70))
	if fuse<=0:
		spent=true;collision_layer=0
		game.explode(global_position+Vector3.UP*.6,2.3,60.0,"both",{})
		queue_free()
