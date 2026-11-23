class_name BadlandsProps
extends RefCounted

# The GLBs share a ground-centred pivot and contain a single textured static mesh.
# Godot keeps these resources shared across the repeating fence, rocks and breakables.
const MODELS := {
	"saloon": preload("res://assets/environment/props/saloon.glb"),
	"water_tower": preload("res://assets/environment/props/water_tower.glb"),
	"wagon": preload("res://assets/environment/props/wagon.glb"),
	"bell": preload("res://assets/environment/props/bell.glb"),
	"fuel_drum": preload("res://assets/environment/props/fuel_drum.glb"),
	"citrus_crates": preload("res://assets/environment/props/citrus_crates.glb"),
	"hay_bales": preload("res://assets/environment/props/hay_bales.glb"),
	"trough": preload("res://assets/environment/props/trough.glb"),
	"saguaro": preload("res://assets/environment/props/saguaro.glb"),
	"mesa": preload("res://assets/environment/props/mesa.glb"),
	"fence": preload("res://assets/environment/props/fence.glb"),
	"agave_rocks": preload("res://assets/environment/props/agave_rocks.glb"),
	"lantern": preload("res://assets/environment/props/lantern.glb"),
	"tumbleweed": preload("res://assets/environment/props/tumbleweed.glb"),
	"sacks": preload("res://assets/environment/props/sacks.glb"),
	"wanted": preload("res://assets/environment/props/wanted.glb"),
}

static var straw_material: ShaderMaterial
static var water_material: ShaderMaterial

static func place(parent: Node3D, kind: String, point: Vector3, yaw := 0.0, size := Vector3.ONE) -> Node3D:
	var model: Node3D = MODELS[kind].instantiate()
	model.position = point
	model.rotation.y = yaw
	model.scale = size
	if kind == "hay_bales":
		var bale: MeshInstance3D = model.find_child("hay_bales", true, false) as MeshInstance3D
		if bale:
			if not straw_material:
				var paint: StandardMaterial3D = bale.mesh.surface_get_material(0)
				straw_material = ShaderMaterial.new()
				straw_material.shader = preload("res://assets/environment/pressed_straw.gdshader")
				straw_material.set_shader_parameter("painted", paint.albedo_texture)
			bale.material_override = straw_material
	elif kind == "trough":
		if not water_material:
			water_material = ShaderMaterial.new()
			water_material.shader = preload("res://assets/environment/cistern_water.gdshader")
		var pool := PlaneMesh.new()
		pool.size = Vector2(2.27, .76)
		MeshKit.instance(model, pool, Vector3(.195, 1.536, 0), water_material)
	parent.add_child(model)
	return model
