extends SkeletonModifier3D

var spread := 0.0
var tips: Array[int]=[]

func _process_modification_with_delta(_delta: float) -> void:
	if spread<=0:return
	var rig:=get_skeleton()
	if tips.is_empty():
		for side in ["R","L"]:tips.append(rig.find_bone("Whisker"+side))
	for i in tips.size():
		var bone:=tips[i]
		if bone<0:continue
		# Applied after the animated feather motion and restored by Skeleton3D
		# before the next mixer pass. Both tips follow the deformed parent.
		rig.set_bone_pose_scale(bone,Vector3(1.0+.72*spread,1.,1.))
		var lift:=Quaternion(Vector3.FORWARD,(-1. if i==0 else 1.)*spread*.21)
		rig.set_bone_pose_rotation(bone,rig.get_bone_pose_rotation(bone)*lift)
