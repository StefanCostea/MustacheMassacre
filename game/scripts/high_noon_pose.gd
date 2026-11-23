extends "res://scripts/espino_special_pose.gd"

func _process_modification() -> void:
	if not form or not form.running: return
	var flight: float = form.spread
	raise_head(smoothstep(.14,.60,form.age)*smoothstep(.08,.48,form.hero.frenzy_left),-.16)
	redirect(ids.shoulder, ids.elbow, Vector3(-.83,-.94,.25), form.arm_growth)
	redirect(ids.free_arm, ids.free_elbow, Vector3(.8,-.31,-.40), flight*.88)
	redirect(ids.leg_r,ids.knee_r,Vector3(-.41,-.88,.27),flight)
	redirect(ids.leg_l,ids.knee_l,Vector3(.36,-.93,-.23),flight)
	redirect(ids.knee_r,ids.boot_r,Vector3(.03,-.55,-.83),flight)
	redirect(ids.knee_l,ids.boot_l,Vector3(.09,-.51,-.86),flight)
	var let_go:=smoothstep(.04,.25,form.age)*(1-smoothstep(.33,.64,form.age))
	redirect(ids.shoulder,ids.elbow,Vector3(-.72,-.70,.47),let_go*.94)
	redirect(ids.elbow,ids.wrist,Vector3(-.46,-.43,.78),let_go*.96)
	var elbow: int = ids.elbow
	if elbow >= 0:
		rig.set_bone_pose_scale(elbow,rig.get_bone_pose_scale(elbow)*lerpf(1,.014,form.arm_growth))
	var weapon: int = ids["weapon.R"]
	if weapon >= 0 and form.released:
		rig.set_bone_pose_scale(weapon,rig.get_bone_pose_scale(weapon)*.001)
	form.follow_pose()
	form.follow_moustache()
