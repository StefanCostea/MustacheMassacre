extends RefCounted

# A shot owns the weapon arm. The opposite arm and the lower body continue
# their stride, including when successive rounds overlap the recovery.
const RELEASE_SECONDS := 0.12
var tree: AnimationTree
var skeleton: Skeleton3D
var attachment: BoneAttachment3D
var shoulder: int
var parent: int
var aimed_parent: Quaternion
var time_left := 0.0
var amount := 0.0

func setup(mixer: AnimationTree, graph: AnimationNodeBlendTree, player: AnimationPlayer, clip: StringName) -> void:
	tree = mixer
	var model := player.get_node(player.root_node)
	skeleton = model.find_children("*","Skeleton3D",true,false)[0]
	shoulder = skeleton.find_bone("mixamorig_RightShoulder")
	parent = skeleton.get_bone_parent(shoulder)
	for node: BoneAttachment3D in skeleton.find_children("*","BoneAttachment3D",true,false):
		if node.bone_name == "weapon.R":
			attachment = node
			break

	player.play(clip)
	player.advance(0)
	aimed_parent = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	player.stop()
	var shot := AnimationNodeAnimation.new()
	shot.animation = clip
	var seek := AnimationNodeTimeSeek.new()
	var mix := AnimationNodeBlend2.new()
	mix.filter_enabled = true
	var animation := player.get_animation(clip)
	for i in range(animation.get_track_count()):
		var path := animation.track_get_path(i)
		if path.get_subname_count() == 0:
			continue
		var name := String(path.get_subname(0))
		# Keep the authored upper-back, head and moustache response to recoil.
		if name in ["mixamorig_Spine2","mixamorig_Neck","mixamorig_Head"] or name.begins_with("stache_"):
			mix.set_filter_path(path,true)
			continue
		var index := skeleton.find_bone(name)
		while index >= 0 and index != shoulder:
			index = skeleton.get_bone_parent(index)
		if index == shoulder:
			mix.set_filter_path(path,true)
	graph.add_node("recoil",shot,Vector2(-460,100))
	graph.add_node("trigger",seek,Vector2(-230,100))
	graph.add_node("gun_arm",mix,Vector2(0,80))
	graph.connect_node("trigger",0,"recoil")
	graph.connect_node("gun_arm",0,"locomotion")
	graph.connect_node("gun_arm",1,"trigger")
	tree.mixer_applied.connect(_compensate_for_stride)

func fire(interval: float) -> void:
	time_left = interval + RELEASE_SECONDS
	amount = 1.0
	tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	tree.set("parameters/trigger/seek_request", 0.0)
	tree.set("parameters/gun_arm/blend_amount", amount)
	tree.advance(0)
	# Hitscan and the flash read the newly raised socket in this physics tick.
	attachment.on_skeleton_update()

func advance(delta: float) -> void:
	if time_left <= 0:
		return
	time_left = maxf(0.0,time_left-delta)
	amount = smoothstep(0.0,RELEASE_SECONDS,time_left)
	tree.set("parameters/gun_arm/blend_amount",amount)

func release() -> void:
	time_left = 0.0
	amount = 0.0
	tree.set("parameters/gun_arm/blend_amount",0.0)

func _compensate_for_stride() -> void:
	if amount <= 0:
		return
	# The baked shot is level in its own chest basis. Remove the locomotion
	# chest tilt from this arm while it takes aim; keep the authored wrist kick.
	var gait_parent := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var correction := Quaternion.IDENTITY.slerp(gait_parent.inverse()*aimed_parent,amount)
	skeleton.set_bone_pose_rotation(shoulder,correction*skeleton.get_bone_pose_rotation(shoulder))
