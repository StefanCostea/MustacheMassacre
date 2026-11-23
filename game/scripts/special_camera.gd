extends Camera3D

func _init() -> void:
	projection = PROJECTION_ORTHOGONAL
	far = 150
	var optics := CameraAttributesPractical.new()
	optics.dof_blur_far_enabled = true
	attributes = optics

func frame(arena: Camera3D, close_focus: Vector3, front: Vector3, close_size: float, weight: float) -> void:
	var arena_ray:=arena.global_basis.z.normalized()
	var view:=arena_ray.slerp(front,weight).normalized()
	var base_focus:=arena.global_position-arena_ray*Vector3(12,19,18).length()
	var focus:=base_focus.lerp(close_focus,weight)
	var distance:=lerpf(Vector3(12,19,18).length(),3.4,weight)
	size=lerpf(arena.size,close_size,weight)
	near=lerpf(arena.near,.24,weight)
	# Keep the lower edge of the orthographic frame above the street through the pullback.
	var min_up:=clampf((size*.5+.06-focus.y)/(distance-near),-.18,.95)
	if view.y<min_up:
		view=Vector3(view.x,0,view.z).normalized()*sqrt(1.0-min_up*min_up)+Vector3.UP*min_up
	global_position=focus+view*distance
	look_at(focus)
	var optics:=attributes as CameraAttributesPractical
	optics.dof_blur_far_distance=distance+1.3
	optics.dof_blur_far_transition=3.0
	optics.dof_blur_amount=.21*weight
