extends CharacterBody3D

signal died
signal phase_changed(phase: int)
signal burden_exposed(duration: float, reason: String)

@export var max_hp := 180.0
@export var attack_interval := 2.2
@export var windup := 0.5
@export var charge_speed := 8.0
@export var move_speed := 2.2
@export var attack_range := 6.0
@export var charge_damage := 20.0
@export var charge_hit_radius := 1.6
@export var miss_vulnerable_time := 1.35
@export var knockback_strength := 7.0
@export var burn_dps := 3.5
@export var burn_tick := 0.4
@export var slow_multiplier := 0.7
@export var slow_duration := 2.2
@export var freeze_duration := 0.35
@export var vulnerable_duration := 2.2
@export var vulnerable_multiplier := 1.3
@export var earth_stun_duration := 0.2
@export var phase_two_threshold := 0.66
@export var phase_three_threshold := 0.33
@export var resist_multiplier := 0.7
@export var weak_multiplier := 1.35
@export var combat_manager_path: NodePath = NodePath("../CombatManager")
@export var player_path: NodePath = NodePath("../Player")
@export var skill_pulse_scene: PackedScene = preload("res://scenes/SkillPulse.tscn")

@onready var model_root: Node = $Model

var _hp := 180.0
var _attack_timer := 0.0
var _combat_manager: Node = null
var _player: Node3D = null
var _charging := false
var _winding_up := false
var _charge_dir := Vector3.ZERO
var _mesh_overrides: Array = []
var _stun_time := 0.0
var _slow_time := 0.0
var _slow_mult := 1.0
var _burn_time := 0.0
var _burn_tick_time := 0.0
var _vulnerable_time := 0.0
var _knockback_velocity := Vector3.ZERO
var _knockback_time := 0.0
var _phase := 1
var _resist_element := -1
var _weak_element := -1
var _floor_offset := 0.0
var _anim: AnimationPlayer = null
var _charge_hit_player := false
var _burden_exposed_time := 0.0

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
	_update_status(delta)
	_update_phase()
	if _stun_time > 0.0:
		_apply_knockback(delta)
		velocity = _knockback_velocity
		move_and_slide()
		_apply_terrain_height()
		return
	_attack_timer += delta
	if _attack_timer >= attack_interval and not _charging and not _winding_up:
		_attack_timer = 0.0
		_charge_prepare()
	if _charging:
		_check_charge_hit()
		velocity = _charge_dir * charge_speed
	elif _winding_up:
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
	else:
		_follow_player(delta)
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
	if to_player.length() <= attack_range * 0.6:
		velocity.x = lerp(velocity.x, 0.0, 8.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 8.0 * delta)
		return
	var dir := to_player.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

func _charge_prepare() -> void:
	if _player == null or not _player.is_inside_tree():
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > attack_range + 1.5:
		return
	_charge_dir = to_player.normalized()
	_update_facing(to_player)
	_winding_up = true
	_charge_hit_player = false
	_set_highlight_state("telegraph")
	if _combat_manager:
		_combat_manager.call("open_clash_window", _player, windup + 0.2)
	if _phase >= 2:
		_spawn_phase_pulse(2.0, 8.0)
	_start_charge()

func _start_charge() -> void:
	await get_tree().create_timer(windup).timeout
	if not is_inside_tree():
		return
	_winding_up = false
	_charging = true
	_set_highlight_state("charge")
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	_charging = false
	if not _charge_hit_player:
		_vulnerable_time = max(_vulnerable_time, miss_vulnerable_time)
		_expose_burden(miss_vulnerable_time + 0.25)
		if _phase >= 2:
			_spawn_phase_pulse(2.4, 6.0)
	_set_highlight_state("none")

func _check_charge_hit() -> void:
	if _player == null or _charge_hit_player:
		return
	var distance_to_player: float = global_position.distance_to(_player.global_position)
	if distance_to_player > charge_hit_radius:
		return
	_charge_hit_player = true
	if _player.has_method("take_hit"):
		_player.call("take_hit", charge_damage, ELEMENT_EARTH, global_position)
	if _combat_manager:
		_combat_manager.call("request_hitstop", 0.06, 0.1)
	_charging = false
	_set_highlight_state("none")

func take_hit(damage: float, element: int = -1, source_pos: Vector3 = Vector3.ZERO) -> void:
	var final_damage: float = damage
	if _phase >= 2 and _burden_exposed_time <= 0.0:
		final_damage *= 0.45
	if element >= 0:
		if element == _resist_element:
			final_damage *= resist_multiplier
		elif element == _weak_element:
			final_damage *= weak_multiplier
	if _vulnerable_time > 0.0:
		final_damage *= vulnerable_multiplier
	_hp -= final_damage
	_flash_hit()
	if _combat_manager:
		_combat_manager.call("request_hitstop", 0.06, 0.08)
	if element >= 0:
		_apply_element_effect(element, source_pos)
	if _hp <= 0.0:
		died.emit()
		queue_free()

func _apply_element_effect(element: int, source_pos: Vector3) -> void:
	match element:
		ELEMENT_FIRE:
			_burn_time = max(_burn_time, 2.6)
			_burn_tick_time = min(_burn_tick_time, burn_tick)
		ELEMENT_WOOD:
			_slow_time = max(_slow_time, slow_duration)
			_slow_mult = slow_multiplier
		ELEMENT_METAL:
			_vulnerable_time = max(_vulnerable_time, vulnerable_duration)
		ELEMENT_EARTH:
			_stun_time = max(_stun_time, earth_stun_duration)
			_apply_knockback_from(source_pos, knockback_strength * 1.5)
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
	_knockback_time = max(_knockback_time, 0.2)

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
		if _stun_time <= 0.0 and not _charging and not _winding_up:
			_set_highlight_state("none")
	if _burden_exposed_time > 0.0:
		_burden_exposed_time -= delta
		if _burden_exposed_time <= 0.0 and not _charging and not _winding_up:
			_set_highlight_state("none")

func _update_phase() -> void:
	if max_hp <= 0.0:
		return
	var ratio := _hp / max_hp
	if _phase == 1 and ratio <= phase_two_threshold:
		_phase = 2
		attack_interval *= 0.85
		charge_speed *= 1.15
		windup *= 0.85
		_spawn_phase_pulse(2.5, 10.0)
		phase_changed.emit(_phase)
	elif _phase == 2 and ratio <= phase_three_threshold:
		_phase = 3
		attack_interval *= 0.75
		charge_speed *= 1.25
		windup *= 0.8
		move_speed *= 1.1
		_spawn_phase_pulse(3.0, 12.0)
		phase_changed.emit(_phase)

func _spawn_phase_pulse(radius: float, damage: float) -> void:
	if skill_pulse_scene == null:
		return
	var pulse := skill_pulse_scene.instantiate()
	if pulse == null:
		return
	pulse.radius = radius
	pulse.damage = damage
	pulse.duration = 0.3
	pulse.color = Color(1.0, 0.4, 0.2, 0.5)
	var root := get_tree().current_scene
	if root:
		root.add_child(pulse)
	else:
		add_child(pulse)
	pulse.global_position = global_position + Vector3(0, 0.2, 0)

func set_element_affinity(element_id: int) -> void:
	_resist_element = element_id
	_weak_element = _get_weak_element(element_id)

func _get_weak_element(element_id: int) -> int:
	match element_id:
		ELEMENT_FIRE:
			return ELEMENT_WATER
		ELEMENT_WOOD:
			return ELEMENT_METAL
		ELEMENT_METAL:
			return ELEMENT_FIRE
		ELEMENT_EARTH:
			return ELEMENT_WOOD
		ELEMENT_WATER:
			return ELEMENT_EARTH
		_:
			return -1

func _flash_hit() -> void:
	if _mesh_overrides.is_empty():
		return
	for entry in _mesh_overrides:
		entry["mesh"].material_override = entry["flash"]
	await get_tree().create_timer(0.08).timeout
	for entry in _mesh_overrides:
		entry["mesh"].material_override = entry["base"]

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
		var telegraph := StandardMaterial3D.new()
		telegraph.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		telegraph.albedo_color = Color(0.95, 0.76, 0.32, 1.0)
		var charge := StandardMaterial3D.new()
		charge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		charge.albedo_color = Color(0.86, 0.36, 0.18, 1.0)
		_mesh_overrides.append({"mesh": mesh, "base": base, "flash": flash, "telegraph": telegraph, "charge": charge})

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
		entry["telegraph"] = null
		entry["charge"] = null
	_mesh_overrides.clear()

func _set_highlight_state(state: String) -> void:
	if _mesh_overrides.is_empty():
		return
	for entry in _mesh_overrides:
		var mesh: MeshInstance3D = entry["mesh"]
		match state:
			"flash":
				mesh.material_override = entry["flash"]
			"telegraph":
				mesh.material_override = entry["telegraph"]
			"charge":
				mesh.material_override = entry["charge"]
			_:
				mesh.material_override = entry["base"]

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

func enter_phase(phase_id: int) -> void:
	if phase_id <= 1:
		_phase = 1
	else:
		_phase = 2
	phase_changed.emit(_phase)

func get_phase_telegraph() -> String:
	if _phase <= 1:
		return "Dash pressure and short windup charges."
	return "Wider pulses and faster repeated rushes."

func register_break_event(event_id: String) -> void:
	if event_id == "resonance_break":
		_stun_time = max(_stun_time, 0.7)
		_expose_burden(1.2, "resonance")
	elif event_id == "guard_counter":
		_expose_burden(0.9, "guard")

func _expose_burden(duration: float, reason: String = "") -> void:
	_burden_exposed_time = max(_burden_exposed_time, duration)
	_vulnerable_time = max(_vulnerable_time, duration * 0.75)
	_set_highlight_state("flash")
	burden_exposed.emit(duration, reason)
	if _combat_manager:
		_combat_manager.call("request_hitstop", 0.05, 0.12)

func _update_animation() -> void:
	if _anim == null:
		return
	var moving := velocity.length() > 0.1 or _knockback_time > 0.0
	var anim_name := "walk" if moving else "idle"
	if _anim.current_animation != anim_name and _anim.has_animation(anim_name):
		_anim.play(anim_name)

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

