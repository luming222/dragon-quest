extends Node3D

@export var length := 6.0
@export var width := 2.0
@export var damage := 12.0
@export var duration := 0.25
@export var color := Color(0.6, 0.9, 1.0, 0.6)
@export var direction := Vector3.FORWARD
@export var impact_scene: PackedScene = preload("res://scenes/SkillImpact.tscn")
@export var element := -1
@export var source_pos := Vector3.ZERO
var source_actor: Node = null

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _hit_ids := {}

func _ready() -> void:
	_setup_mesh()
	_apply_damage()
	_animate()
	_cleanup_after(duration)

func _setup_mesh() -> void:
	if mesh_instance.mesh is BoxMesh:
		(mesh_instance.mesh as BoxMesh).size = Vector3(1.0, 0.2, 1.0)
	var dir := _safe_dir()
	look_at(global_position + dir, Vector3.UP)
	mesh_instance.scale = Vector3(width, 0.2, length)
	mesh_instance.position = Vector3(0, 0.1, -length * 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy = 1.1
	mesh_instance.material_override = mat

func _apply_damage() -> void:
	var dir := _safe_dir().normalized()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D):
			continue
		var target := enemy as Node3D
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		var forward_dist := dir.dot(to_target)
		if forward_dist < 0.0 or forward_dist > length:
			continue
		var side_dist := (to_target - dir * forward_dist).length()
		if side_dist > width * 0.5:
			continue
		_apply_damage_to(target)

func _apply_damage_to(target: Node) -> void:
	if target == null:
		return
	var candidate: Node = target
	if not candidate.has_method("take_hit") and candidate.get_parent():
		candidate = candidate.get_parent()
	if not candidate.has_method("take_hit"):
		return
	var id := candidate.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true
	if candidate.has_method("take_hit"):
		if _method_has_arg_count(candidate, "take_hit", 3):
			var final_damage := damage
			var cm := _get_combat_manager()
			if cm:
				final_damage = float(cm.call("register_hit", source_actor, candidate, damage, element, source_pos))
			candidate.call("take_hit", final_damage, element, source_pos)
		else:
			candidate.call("take_hit", damage)
	_spawn_impact(candidate)

func _spawn_impact(target: Node) -> void:
	if impact_scene == null:
		return
	if not (target is Node3D):
		return
	var impact := impact_scene.instantiate()
	if impact == null:
		return
	_set_if_property(impact, "color", Color(color.r, color.g, color.b, 0.9))
	_set_if_property(impact, "size", 0.5 + width * 0.15)
	var root := get_tree().current_scene
	if root:
		root.add_child(impact)
	else:
		add_child(impact)
	impact.global_position = (target as Node3D).global_position + Vector3(0, 0.6, 0)

func _set_if_property(target: Object, prop_name: String, value: Variant) -> void:
	if target == null:
		return
	for info in target.get_property_list():
		if info.has("name") and info["name"] == prop_name:
			target.set(prop_name, value)
			return

func _method_has_arg_count(target: Object, method_name: String, count: int) -> bool:
	for info in target.get_method_list():
		if info.has("name") and info["name"] == method_name:
			if info.has("args"):
				return info["args"].size() >= count
	return false

func _animate() -> void:
	mesh_instance.scale = Vector3(width * 0.2, 0.15, length * 0.2)
	var tween := create_tween()
	tween.tween_property(mesh_instance, "scale", Vector3(width, 0.2, length), duration)
	var mat := mesh_instance.material_override
	if mat:
		tween.parallel().tween_property(mat, "albedo_color", Color(color.r, color.g, color.b, 0.0), duration)

func _cleanup_after(wait_time: float) -> void:
	await get_tree().create_timer(wait_time).timeout
	queue_free()

func _safe_dir() -> Vector3:
	if direction.length() < 0.01:
		return Vector3.FORWARD
	return direction.normalized()

func _get_combat_manager() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.get_node_or_null("CombatManager")
