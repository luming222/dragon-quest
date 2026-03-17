extends CharacterBody3D

signal died

@export var max_hp := 45.0
@export var attack_interval := 2.4
@export var attack_windup := 0.4
@export var attack_range := 7.0
@export var keep_distance := 4.5
@export var move_speed := 2.2
@export var knockback_strength := 5.5
@export var burn_dps := 2.5
@export var burn_tick := 0.4
@export var slow_multiplier := 0.65
@export var slow_duration := 2.0
@export var freeze_duration := 0.3
@export var vulnerable_duration := 2.0
@export var vulnerable_multiplier := 1.2
@export var earth_stun_duration := 0.18
@export var combat_manager_path: NodePath = NodePath("../CombatManager")
@export var player_path: NodePath = NodePath("../Player")
@export var skill_pulse_scene: PackedScene = preload("res://scenes/SkillPulse.tscn")

var _hp := 45.0
var _attack_timer := 0.0
var _combat_manager: Node = null
var _player: Node3D = null
var _anim: AnimationPlayer = null
var _mesh_overrides: Array = []
var _stun_time := 0.0
var _slow_time := 0.0
var _slow_mult := 1.0
var _burn_time := 0.0
var _burn_tick_time := 0.0
var _vulnerable_time := 0.0
var _knockback_velocity := Vector3.ZERO
var _knockback_time := 0.0
var _floor_offset := 0.0

@onready var model_root: Node = $Model

const ELEMENT_FIRE := 0
const ELEMENT_WOOD := 1
const ELEMENT_METAL := 2
const ELEMENT_EARTH := 3
const ELEMENT_WATER := 4

func _ready() -> void:
	_hp = max_hp
	_combat_manager = get_node_or_null(combat_manager_path)
	_player = get_node_or_null(player_path)
	add_to_group("enemies")
	_ensure_fallback_animation(model_root)
	_anim = _find_animation_player(model_root)
	if _anim and _anim.has_animation("idle"):
		_anim.play("idle")
	_cache_mesh_overrides()
	_floor_offset = _calc_floor_offset()

func _exit_tree() -> void:
	_release_mesh_overrides()

func _physics_process(delta: float) -> void:
	_apply_terrain_height()
	if _player == null:
		_player = get_node_or_null(player_path)
		if _player == null:
			return
	if not _player.is_inside_tree():
		return
	_update_status(delta)
	if _stun_time > 0.0:
		_apply_knockback(delta)
		velocity = _knockback_velocity
		move_and_slide()
		_apply_terrain_height()
		return
	_follow_player(delta)
	_attack_timer += delta
	if _attack_timer >= attack_interval:
		_attack_timer = 0.0
		_try_attack()
	velocity.x *= _slow_mult
	velocity.z *= _slow_mult
	_apply_knockback(delta)
	velocity.y = 0.0
	move_and_slide()
	_apply_terrain_height()
	_update_animation()

func _apply_terrain_height() -> void:
	var parent_node := get_parent()
	if parent_node and parent_node.has_method("get_terrain_height_at"):
		var height: float = float(parent_node.call("get_terrain_height_at", global_position.x, global_position.z))
		global_position.y = height + _floor_offset

func _calc_floor_offset() -> float:
	var shape_node := get_node_or_null("CollisionShape3D")
	if shape_node == null:
		return 0.9
	var collider := shape_node as CollisionShape3D
	if collider == null or collider.shape == null:
		return 0.9
	var shape := collider.shape
	if shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		return cap.height * 0.5 + cap.radius
	if shape is SphereShape3D:
		var sph := shape as SphereShape3D
		return sph.radius
	if shape is BoxShape3D:
		var box := shape as BoxShape3D
		return box.size.y * 0.5
	return 0.9

func _follow_player(delta: float) -> void:
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	_update_facing(to_player)
	var dist := to_player.length()
	if dist < keep_distance:
		var away := -to_player.normalized()
		velocity.x = away.x * move_speed
		velocity.z = away.z * move_speed
		return
	if dist > attack_range:
		var dir := to_player.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		return
	velocity.x = lerp(velocity.x, 0.0, 8.0 * delta)
	velocity.z = lerp(velocity.z, 0.0, 8.0 * delta)

func _try_attack() -> void:
	if _player == null or not _player.is_inside_tree():
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist > attack_range:
		return
	_attack_sequence()

func _attack_sequence() -> void:
	await get_tree().create_timer(attack_windup).timeout
	if _player == null or not _player.is_inside_tree():
		return
	if not is_inside_tree():
		return
	if skill_pulse_scene == null:
		return
	var pulse := skill_pulse_scene.instantiate()
	pulse.radius = 1.6
	pulse.damage = 8.0
	pulse.duration = 0.25
	pulse.color = Color(0.5, 0.8, 1.0, 0.5)
	var root := get_tree().current_scene
	if root:
		root.add_child(pulse)
	else:
		add_child(pulse)
	var target_pos := _player.global_position + Vector3(0, 0.2, 0)
	pulse.global_position = target_pos

func take_hit(damage: float, element: int = -1, source_pos: Vector3 = Vector3.ZERO) -> void:
	var final_damage: float = damage
	if _vulnerable_time > 0.0:
		final_damage *= vulnerable_multiplier
	_hp -= final_damage
	_flash_hit()
	if _combat_manager:
		_combat_manager.call("request_hitstop", 0.05, 0.08)
	if element >= 0:
		_apply_element_effect(element, source_pos)
	if _hp <= 0.0:
		died.emit()
		queue_free()

func _apply_element_effect(element: int, source_pos: Vector3) -> void:
	match element:
		ELEMENT_FIRE:
			_burn_time = max(_burn_time, 2.2)
			_burn_tick_time = min(_burn_tick_time, burn_tick)
		ELEMENT_WOOD:
			_slow_time = max(_slow_time, slow_duration)
			_slow_mult = slow_multiplier
		ELEMENT_METAL:
			_vulnerable_time = max(_vulnerable_time, vulnerable_duration)
		ELEMENT_EARTH:
			_stun_time = max(_stun_time, earth_stun_duration)
			_apply_knockback_from(source_pos, knockback_strength * 1.4)
		ELEMENT_WATER:
			_stun_time = max(_stun_time, freeze_duration)
			_slow_time = max(_slow_time, slow_duration * 0.6)
			_slow_mult = min(_slow_mult, 0.5)
	_apply_knockback_from(source_pos, knockback_strength)

func _apply_knockback_from(source_pos: Vector3, strength: float) -> void:
	var dir := global_position - source_pos
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	_knockback_velocity = dir.normalized() * strength
	_knockback_time = max(_knockback_time, 0.16)

func _apply_knockback(delta: float) -> void:
	if _knockback_time <= 0.0:
		_knockback_velocity = Vector3.ZERO
		return
	_knockback_time -= delta
	_knockback_velocity = _knockback_velocity.lerp(Vector3.ZERO, 8.0 * delta)

func _update_status(delta: float) -> void:
	if _burn_time > 0.0:
		_burn_time -= delta
		_burn_tick_time -= delta
		if _burn_tick_time <= 0.0:
			_burn_tick_time = burn_tick
			_hp -= burn_dps * burn_tick
			if _hp <= 0.0:
				died.emit()
				queue_free()
				return
	if _slow_time > 0.0:
		_slow_time -= delta
		_slow_mult = slow_multiplier
	else:
		_slow_mult = 1.0
	if _vulnerable_time > 0.0:
		_vulnerable_time -= delta
	if _stun_time > 0.0:
		_stun_time -= delta

func _flash_hit() -> void:
	if _mesh_overrides.is_empty():
		return
	for entry in _mesh_overrides:
		entry["mesh"].material_override = entry["flash"]
	await get_tree().create_timer(0.08).timeout
	for entry in _mesh_overrides:
		entry["mesh"].material_override = entry["base"]

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	var anim := root.find_child("AnimationPlayer", true, false)
	if anim is AnimationPlayer:
		return anim
	for child in root.get_children():
		if child is AnimationPlayer:
			return child
	return null

func _cache_mesh_overrides() -> void:
	if model_root == null:
		return
	var meshes := model_root.find_children("*", "MeshInstance3D", true, false)
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		var base := mesh.material_override
		var flash := StandardMaterial3D.new()
		flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash.albedo_color = Color(1, 1, 1, 1)
		_mesh_overrides.append({"mesh": mesh, "base": base, "flash": flash})

func _release_mesh_overrides() -> void:
	if _mesh_overrides.is_empty():
		return
	for entry_var in _mesh_overrides:
		if not (entry_var is Dictionary):
			continue
		var entry: Dictionary = entry_var
		var mesh: MeshInstance3D = entry.get("mesh", null)
		if mesh and is_instance_valid(mesh):
			mesh.material_override = entry.get("base", null)
		entry["mesh"] = null
		entry["base"] = null
		entry["flash"] = null
	_mesh_overrides.clear()

func _update_facing(dir: Vector3) -> void:
	if model_root == null:
		return
	if dir.length() < 0.01:
		return
	var node3d := model_root as Node3D
	if node3d == null:
		return
	var yaw := atan2(dir.x, dir.z)
	node3d.rotation.y = yaw

func _on_hurtbox_area_entered(area: Area3D) -> void:
	if area.name != "MeleeArea":
		return
	var damage := 12.0
	var element := -1
	var source_pos := area.global_position
	if area.has_meta("damage"):
		damage = float(area.get_meta("damage"))
	if area.has_meta("element"):
		element = int(area.get_meta("element"))
	if area.has_meta("source_pos"):
		source_pos = area.get_meta("source_pos")
	if element >= 0:
		var final_damage := damage
		if _combat_manager:
			final_damage = float(_combat_manager.call("register_hit", area.get_meta("source_actor", null), self, damage, element, source_pos))
		take_hit(final_damage, element, source_pos)
	else:
		take_hit(damage)

func _update_animation() -> void:
	if _anim == null:
		return
	var moving := velocity.length() > 0.1 or _knockback_time > 0.0
	var anim_name := "walk" if moving else "idle"
	if _anim.current_animation != anim_name and _anim.has_animation(anim_name):
		_anim.play(anim_name)

func _ensure_fallback_animation(root: Node) -> void:
	if root == null:
		return
	var existing := root.find_child("AnimationPlayer", true, false)
	if existing is AnimationPlayer:
		return
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var idle := Animation.new()
	idle.length = 1.2
	idle.loop_mode = Animation.LOOP_LINEAR
	var idle_track := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(idle_track, NodePath("..:position"))
	idle.track_insert_key(idle_track, 0.0, Vector3(0, 0.0, 0))
	idle.track_insert_key(idle_track, 0.6, Vector3(0, 0.05, 0))
	idle.track_insert_key(idle_track, 1.2, Vector3(0, 0.0, 0))
	ap.add_animation("idle", idle)
	var walk := Animation.new()
	walk.length = 0.6
	walk.loop_mode = Animation.LOOP_LINEAR
	var walk_track := walk.add_track(Animation.TYPE_VALUE)
	walk.track_set_path(walk_track, NodePath("..:position"))
	walk.track_insert_key(walk_track, 0.0, Vector3(0, 0.0, 0))
	walk.track_insert_key(walk_track, 0.3, Vector3(0, 0.08, 0))
	walk.track_insert_key(walk_track, 0.6, Vector3(0, 0.0, 0))
	ap.add_animation("walk", walk)


