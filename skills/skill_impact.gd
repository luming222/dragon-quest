extends Node3D

@export var color := Color(1, 1, 1, 0.9)
@export var duration := 0.18
@export var size := 0.6

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	_setup_mesh()
	_animate()
	_cleanup_after(duration)

func _setup_mesh() -> void:
	if mesh_instance.mesh is SphereMesh:
		var mesh := mesh_instance.mesh as SphereMesh
		mesh.radius = 0.5
		mesh.height = 1.0
	mesh_instance.scale = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy = 1.1
	mesh_instance.material_override = mat

func _animate() -> void:
	mesh_instance.scale = Vector3.ONE * (size * 0.3)
	var tween := create_tween()
	tween.tween_property(mesh_instance, "scale", Vector3.ONE * (size * 1.1), duration)
	var mat := mesh_instance.material_override
	if mat:
		tween.parallel().tween_property(mat, "albedo_color", Color(color.r, color.g, color.b, 0.0), duration)

func _cleanup_after(wait_time: float) -> void:
	await get_tree().create_timer(wait_time).timeout
	queue_free()
