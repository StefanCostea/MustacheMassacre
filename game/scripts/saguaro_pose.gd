extends "res://scripts/espino_special_pose.gd"

func _process_modification() -> void:
	if not form.running:return
	# Open both elbows first, then draw the wrists to a shared line below the eyes.
	var brace: float = form.brace
	var join: float = form.fusion
	raise_head(brace,-.21)
	for left in [false,true]:
		var side := 1.0 if left else -1.0
		var shoulder: int = ids.free_arm if left else ids.shoulder
		var elbow: int = ids.free_elbow if left else ids.elbow
		var wrist: int = ids.free_wrist if left else ids.wrist
		redirect(shoulder,elbow,Vector3(side*lerpf(.76,.42,join),-.54,.74),brace)
		redirect(elbow,wrist,Vector3(-side*lerpf(.14,.96,join),.20,.86),brace)
		if wrist>=0:
			rig.set_bone_pose_scale(wrist,rig.get_bone_pose_scale(wrist)*lerpf(1,.035,form.growth))
	redirect(ids.leg_r,ids.knee_r,Vector3(-.38,-.91,.22),brace*.48)
	redirect(ids.leg_l,ids.knee_l,Vector3(.34,-.90,-.22),brace*.48)
	var weapon: int = ids["weapon.R"]
	if weapon>=0 and form.gun_stowed:
		rig.set_bone_pose_scale(weapon,rig.get_bone_pose_scale(weapon)*.001)
	form.sample_wrists()
