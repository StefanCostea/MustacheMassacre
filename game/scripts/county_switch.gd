extends StaticBody3D

signal activated
var lock_time := 0.
func _ready() -> void:
	add_to_group("county_switches")
	collision_layer=8
	collision_mask=0
	var collider:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(.95,1.7,.95)
	collider.shape=box
	collider.position.y=.85
	add_child(collider)
func _physics_process(delta:float) -> void:
	lock_time=maxf(0,lock_time-delta)
func receive_hit(_damage:float,_critical:=false,_context:Dictionary={}) -> void:
	if lock_time<=0:
		lock_time=.45
		activated.emit()
