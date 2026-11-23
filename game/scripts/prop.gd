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
	visual = BadlandsProps.place(self, "fuel_drum" if kind == "barrel" else "citrus_crates", Vector3.ZERO)
	var shape := CollisionShape3D.new()
	shape.position.y = .7
	if kind == "barrel":
		var cylinder := CylinderShape3D.new()
		cylinder.radius = .40
		cylinder.height = 1.4
		shape.shape = cylinder
	else:
		health = 25
		var box := BoxShape3D.new()
		box.size = Vector3(.85, 1.4, .85)
		shape.shape = box
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
			game.effects.prop_fragments(global_position+Vector3.UP*.52, false)
			Sound.play("explosion",-12,1.5)
			queue_free()

func _process(delta: float) -> void:
	if fuse<0 or spent:return
	fuse-=delta
	visual.scale=Vector3.ONE*(1+.035*sin(fuse*70))
	if fuse<=0:
		spent=true;collision_layer=0
		game.effects.prop_fragments(global_position+Vector3.UP*.54, true)
		game.explode(global_position+Vector3.UP*.6,2.3,60.0,"both",{})
		queue_free()
