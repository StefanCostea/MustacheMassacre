extends SkeletonModifier3D

# Applied after the normal animation mixer. Godot restores the underlying pose
# when the modifier ends, including a gait that was already in progress.
var form
var rig: Skeleton3D
var ids := {}

func bind(skeleton: Skeleton3D, owner_form) -> void:
	rig = skeleton
	form = owner_form
	var natural := rig.find_bone("mixamorig_Head") >= 0
	var naming := {
		"head": ["head","Head"], "shoulder": ["upper_arm.R","RightArm"],
		"elbow": ["forearm.R","RightForeArm"], "wrist": ["hand.R","RightHand"],
		"free_arm": ["upper_arm.L","LeftArm"], "free_elbow": ["forearm.L","LeftForeArm"], "free_wrist": ["hand.L","LeftHand"],
		"leg_r": ["thigh.R","RightUpLeg"], "knee_r": ["shin.R","RightLeg"], "boot_r": ["foot.R","RightFoot"],
		"leg_l": ["thigh.L","LeftUpLeg"], "knee_l": ["shin.L","LeftLeg"], "boot_l": ["foot.L","LeftFoot"],
	}
	for key in naming:
		ids[key] = rig.find_bone("mixamorig_"+naming[key][1] if natural else naming[key][0])
	for name_ in ["weapon.R","stache_root.R","stache_mid.R","stache_root.L","stache_mid.L"]:
		ids[name_] = rig.find_bone(name_)
	active = false

func redirect(parent: int, child: int, local_direction: Vector3, weight: float) -> void:
	if parent < 0 or child < 0 or weight < .001: return
	var pose := rig.get_bone_global_pose(parent)
	var current := (rig.get_bone_global_pose(child).origin-pose.origin).normalized()
	var desired: Vector3 = (rig.global_basis.inverse()*form.hero.visual.global_basis*local_direction).normalized()
	if current.is_zero_approx(): return
	var turn := Quaternion.IDENTITY.slerp(Quaternion(current,desired),weight)
	pose.basis = Basis(turn)*pose.basis
	rig.set_bone_global_pose(parent,pose)


func raise_head(weight: float, tilt: float) -> void:
	var head: int = ids.head
	if head < 0 or weight <= 0: return
	var pose := rig.get_bone_global_pose(head)
	var neutral := rig.get_bone_global_rest(head).basis.orthonormalized()
	var across: Vector3 = (rig.global_basis.inverse()*form.hero.visual.global_basis.x).normalized()
	var upright := neutral.rotated(across,tilt).get_rotation_quaternion()
	var rotation := pose.basis.orthonormalized().get_rotation_quaternion().slerp(upright,weight)
	pose.basis = Basis(rotation).scaled_local(pose.basis.get_scale())
	rig.set_bone_global_pose(head,pose)
