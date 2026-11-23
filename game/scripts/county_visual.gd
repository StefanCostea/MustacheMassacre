extends EnemyVisual

var animator:AnimationPlayer
var clip := ""
var hit_left:=0.

func build(id:String,_original:=false) -> void:
	var model:Node3D=load("res://assets/county/%s.glb"%id).instantiate()
	add_child(model)
	_collect(model)
	animator=model.find_children("*","AnimationPlayer",true,false)[0]
	for loop in ["idle","move"]:animator.get_animation(loop).loop_mode=Animation.LOOP_LINEAR
	play("idle")

func play(next:String,blend:=.09) -> void:
	if next==clip:return
	clip=next
	animator.play(next,blend)

func hit() -> void:
	super.hit()
	hit_left=.15
	play("hurt",.04)

func animate(delta:float,speed:float,state_name:String) -> void:
	if flash>0:
		flash-=delta
		if flash<=0:
			for part in renderers:part.material_overlay=null
	hit_left=maxf(0,hit_left-delta)
	if state_name=="death":play("death",.04)
	elif hit_left>0:return
	elif state_name=="windup":play("windup")
	elif state_name in ["charge","burst","spray"]:play("attack",.035)
	elif state_name=="recover":
		if clip!="attack" or not animator.is_playing():play("recover")
	else:play("move" if speed>.26 else "idle")

func die() -> float:
	play("death",.04)
	return animator.get_animation("death").length
