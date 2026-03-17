extends CharacterBody3D

signal spirit_changed(current: float, max_value: float)
signal hp_changed(current: float, max_value: float)
signal died
signal skill_cast(slot: int, element: int, level: int)
signal weapon_changed(name: String)
signal guard_changed(current: float, max_value: float)

enum Element { FIRE, WOOD, METAL, EARTH, WATER }

@export var move_speed := 6.0
@export var acceleration := 18.0
@export var dodge_speed := 12.0
@export var dodge_duration := 0.20
@export var dodge_cooldown := 0.60
@export var jump_velocity := 7.5
@export var max_air_jumps := 1
@export var attack_cooldown := 0.35
@export var attack_active_time := 0.15
@export var combo_reset_time := 0.55
@export var parry_cooldown := 0.60
@export var clash_window_duration := 0.80
@export var spirit_max := 100.0
@export var spirit_gain_light := 6.0
@export var spirit_gain_heavy := 10.0
@export var spirit_lock_duration := 0.60
@export var spirit_regen_rate := 6.0
@export var max_hp := 100.0
@export var model_yaw_offset_deg := 0.0
@export var snap_facing := false
@export var snap_angle_deg := 45.0
@export var turn_speed := 12.0
@export var camera_path: NodePath = NodePath("../Camera3D")
@export var side_scroll_mode := false
@export var locked_lane_z := 0.0

@export var combat_manager_path: NodePath = NodePath("../CombatManager")
@export var skill_pulse_scene: PackedScene = preload("res://scenes/SkillPulse.tscn")
@export var skill_line_scene: PackedScene = preload("res://scenes/SkillLine.tscn")
@export var skill_cone_scene: PackedScene = preload("res://scenes/SkillCone.tscn")

@onready var melee_area: Area3D = $MeleeArea
@onready var model_root: Node = $Model

var combat_manager: Node = null
var _camera: Camera3D = null
var _anim: AnimationPlayer = null

var spirit := 50.0
var hp := 100.0
var spirit_tier := 1
var current_element := Element.FIRE
var _defeated := false
var _guard := 0.0

var weapons: Array = [
	{
		"id": "sword",
		"name": "Long Sword",
		"spirit_gain_light": 6.0,
		"spirit_gain_heavy": 10.0,
		"light_combo": [
			{"damage": 8.0, "active": 0.12, "cooldown": 0.24, "knockback": 4.0},
			{"damage": 10.0, "active": 0.13, "cooldown": 0.28, "knockback": 4.6},
			{"damage": 13.0, "active": 0.15, "cooldown": 0.34, "knockback": 5.2}
		],
		"heavy_attack": {"damage": 18.0, "active": 0.18, "cooldown": 0.5, "knockback": 7.5}
	},
	{
		"id": "spear",
		"name": "Spear",
		"spirit_gain_light": 7.0,
		"spirit_gain_heavy": 9.0,
		"light_combo": [
			{"damage": 7.0, "active": 0.11, "cooldown": 0.2, "knockback": 3.8},
			{"damage": 9.0, "active": 0.12, "cooldown": 0.24, "knockback": 4.2},
			{"damage": 12.0, "active": 0.14, "cooldown": 0.3, "knockback": 4.8}
		],
		"heavy_attack": {"damage": 16.0, "active": 0.16, "cooldown": 0.44, "knockback": 6.8}
	},
	{
		"id": "hammer",
		"name": "Hammer",
		"spirit_gain_light": 5.0,
		"spirit_gain_heavy": 12.0,
		"light_combo": [
			{"damage": 10.0, "active": 0.15, "cooldown": 0.32, "knockback": 5.5},
			{"damage": 13.0, "active": 0.17, "cooldown": 0.38, "knockback": 6.2},
			{"damage": 17.0, "active": 0.2, "cooldown": 0.48, "knockback": 7.0}
		],
		"heavy_attack": {"damage": 24.0, "active": 0.24, "cooldown": 0.7, "knockback": 9.0}
	}
]
var current_weapon_index := 0

var skills := {
	1: {"name": "Core", "level": 1, "progress": 0, "progress_needed": 3, "base_cost": 12.0},
	2: {"name": "Focus", "level": 1, "progress": 0, "progress_needed": 3, "base_cost": 16.0},
	3: {"name": "Burst", "level": 1, "progress": 0, "progress_needed": 3, "base_cost": 20.0}
}

var _run_build := {
	"slots": {"weapon": {}, "core": {}, "charm": {}},
	"affixes": [],
	"story_blessings": [],
	"stats": {
		"damage_mult": 0.0,
		"spirit_cost_mult": 1.0,
		"spirit_regen_bonus": 0.0,
		"resonance_bonus": 0.0,
		"damage_reduction": 0.0,
		"boss_bonus": 0.0,
		"parry_guard": 0.0,
		"counter_damage": 0.0,
		"counter_heal": 0.0,
		"guard_spirit": 0.0,
		"max_hp_bonus": 0.0,
		"spirit_max_bonus": 0.0
	}
}

var _dodge_time_left := 0.0
var _dodge_cooldown_left := 0.0
var _attack_lock_until := 0
var _parry_lock_until := 0
var _spirit_lock_until := 0
var _input_locked := false
var _last_move_dir := Vector3.RIGHT
var _combo_index := 0
var _combo_expires_at := 0
var _gravity := 18.0
var _air_jumps_left := 0
var _floor_offset := 0.0

var _light_combo: Array = []
var _heavy_attack: Dictionary = {}

func _ready() -> void:
	melee_area.monitoring = false
	melee_area.area_entered.connect(_on_melee_area_entered)
	combat_manager = get_node_or_null(combat_manager_path)
	_camera = get_node_or_null(camera_path)
	global_position = Vector3(0.0, 0.0, locked_lane_z if side_scroll_mode else 0.0)
	_anim = _find_animation_player(model_root)
	if _anim and _anim.has_animation("idle"):
		_anim.play("idle")
	_apply_weapon(current_weapon_index)
	if combat_manager and combat_manager.has_signal("clash_window_ended"):
		combat_manager.connect("clash_window_ended", Callable(self, "_on_clash_window_ended"))
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	_floor_offset = _calc_floor_offset()
	_recompute_build_stats()
	hp = max_hp
	spirit = clamp(spirit, 0.0, spirit_max)
	_guard = 0.0
	_emit_spirit()
	_emit_hp()
	_emit_guard()

func _physics_process(delta: float) -> void:
	if _defeated:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	_handle_timers(delta)
	_regen_spirit(delta)
	_handle_movement(delta)
	_handle_actions()
	_apply_gravity(delta)
	_update_air_jumps()
	_update_animation()
	move_and_slide()
	if side_scroll_mode:
		global_position.z = locked_lane_z

func _handle_timers(delta: float) -> void:
	if _dodge_time_left > 0.0:
		_dodge_time_left -= delta
	if _dodge_cooldown_left > 0.0:
		_dodge_cooldown_left -= delta

func _handle_movement(delta: float) -> void:
	if _input_locked:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if side_scroll_mode:
			velocity.z = 0.0
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		var right := 1.0 if (Input.is_key_pressed(Key.KEY_D) or Input.is_key_pressed(Key.KEY_RIGHT)) else 0.0
		var left := 1.0 if (Input.is_key_pressed(Key.KEY_A) or Input.is_key_pressed(Key.KEY_LEFT)) else 0.0
		var down := 1.0 if (Input.is_key_pressed(Key.KEY_S) or Input.is_key_pressed(Key.KEY_DOWN)) else 0.0
		var up := 1.0 if (Input.is_key_pressed(Key.KEY_W) or Input.is_key_pressed(Key.KEY_UP)) else 0.0
		input_dir = Vector2(right - left, down - up)
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	var move_dir := Vector3(input_dir.x, 0.0, input_dir.y)
	if side_scroll_mode:
		move_dir = Vector3(input_dir.x, 0.0, 0.0)
	elif _camera:
		var cam_basis := _camera.global_transform.basis
		var forward := cam_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right_dir := cam_basis.x
		right_dir.y = 0.0
		right_dir = right_dir.normalized()
		move_dir = (right_dir * input_dir.x + forward * input_dir.y)
	if move_dir.length() > 0.0:
		_last_move_dir = move_dir.normalized()
		_update_facing(_last_move_dir)
	if _dodge_time_left > 0.0:
		velocity = _last_move_dir * dodge_speed
		velocity.z = 0.0 if side_scroll_mode else velocity.z
		return
	var target := move_dir * move_speed
	velocity.x = lerp(velocity.x, target.x, acceleration * delta)
	velocity.z = lerp(velocity.z, target.z, acceleration * delta)
	if side_scroll_mode:
		velocity.z = 0.0

func _handle_actions() -> void:
	if _input_locked:
		return
	if Input.is_action_just_pressed("dodge"):
		_try_dodge()
	if InputMap.has_action("jump") and Input.is_action_just_pressed("jump"):
		_try_jump()
	if Input.is_action_just_pressed("attack_light"):
		_try_attack(false)
	if Input.is_action_just_pressed("attack_heavy"):
		_try_attack(true)
	if Input.is_action_just_pressed("parry"):
		_try_parry()
	if Input.is_action_just_pressed("skill_1"):
		_cast_skill(1)
	if Input.is_action_just_pressed("skill_2"):
		_cast_skill(2)
	if Input.is_action_just_pressed("skill_3"):
		_cast_skill(3)
	if InputMap.has_action("weapon_1") and Input.is_action_just_pressed("weapon_1"):
		_apply_weapon(0)
	if InputMap.has_action("weapon_2") and Input.is_action_just_pressed("weapon_2"):
		_apply_weapon(1)
	if InputMap.has_action("weapon_3") and Input.is_action_just_pressed("weapon_3"):
		_apply_weapon(2)

func _try_dodge() -> void:
	if _dodge_cooldown_left > 0.0:
		return
	_dodge_time_left = dodge_duration
	_dodge_cooldown_left = dodge_cooldown

func _try_jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity
		_air_jumps_left = max_air_jumps
		return
	if _air_jumps_left <= 0:
		return
	_air_jumps_left -= 1
	velocity.y = jump_velocity

func _try_attack(heavy: bool) -> void:
	if Time.get_ticks_msec() < _attack_lock_until:
		return
	var data: Dictionary = _get_attack_data(heavy)
	var attack_speed_bonus: float = max(-0.6, float(_run_build["stats"].get("attack_speed", 0.0)))
	var speed_mult: float = max(0.4, 1.0 + attack_speed_bonus)
	var cooldown: float = float(data.get("cooldown", attack_cooldown)) / speed_mult
	_attack_lock_until = Time.get_ticks_msec() + int(cooldown * 1000.0)
	var damage := float(data.get("damage", 8.0)) * float(_run_build["stats"].get("damage_mult", 1.0))
	_start_melee_hitbox(
		damage,
		float(data.get("active", attack_active_time)) / max(0.7, speed_mult),
		float(data.get("knockback", 4.0)),
		heavy
	)
	_gain_spirit(heavy)

func _start_melee_hitbox(damage: float, active_time: float, knockback: float, heavy: bool) -> void:
	melee_area.set_meta("damage", damage)
	melee_area.set_meta("element", current_element)
	melee_area.set_meta("source_pos", global_position)
	melee_area.set_meta("source_actor", self)
	melee_area.set_meta("knockback", knockback)
	melee_area.set_meta("heavy", heavy)
	melee_area.set_meta("combo_index", _combo_index)
	melee_area.monitoring = true
	await get_tree().create_timer(active_time).timeout
	melee_area.monitoring = false

func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	if not is_on_floor():
		velocity.y -= _gravity * delta
		if velocity.y <= 0.0:
			var parent_node := get_parent()
			if parent_node and parent_node.has_method("get_terrain_height_at"):
				var height: float = float(parent_node.call("get_terrain_height_at", global_position.x, global_position.z))
				if global_position.y <= height + _floor_offset:
					global_position.y = height + _floor_offset
					velocity.y = 0.0

func _update_air_jumps() -> void:
	if is_on_floor():
		_air_jumps_left = max_air_jumps

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

func get_floor_offset() -> float:
	return _floor_offset

func _on_melee_area_entered(area: Area3D) -> void:
	if combat_manager:
		combat_manager.call("open_clash_window", self, clash_window_duration)

func _get_attack_data(heavy: bool) -> Dictionary:
	var now := Time.get_ticks_msec()
	if heavy:
		_combo_index = 0
		_combo_expires_at = 0
		return _heavy_attack
	if now > _combo_expires_at:
		_combo_index = 0
	var combo_size := _light_combo.size()
	if combo_size <= 0:
		return _heavy_attack
	var idx: int = int(clamp(_combo_index, 0, combo_size - 1))
	var data: Dictionary = _light_combo[idx]
	_combo_index = (_combo_index + 1) % combo_size
	_combo_expires_at = now + int(combo_reset_time * 1000.0)
	return data

func _apply_weapon(index: int) -> void:
	if weapons.is_empty():
		return
	current_weapon_index = clamp(index, 0, weapons.size() - 1)
	var weapon: Dictionary = weapons[current_weapon_index]
	_light_combo = weapon.get("light_combo", [])
	_heavy_attack = weapon.get("heavy_attack", {})
	spirit_gain_light = float(weapon.get("spirit_gain_light", spirit_gain_light))
	spirit_gain_heavy = float(weapon.get("spirit_gain_heavy", spirit_gain_heavy))
	_combo_index = 0
	_combo_expires_at = 0
	weapon_changed.emit(String(weapon.get("name", "Weapon")))

func _gain_spirit(heavy: bool) -> void:
	spirit = min(spirit_max, spirit + (spirit_gain_heavy if heavy else spirit_gain_light))
	_emit_spirit()

func _regen_spirit(delta: float) -> void:
	if spirit_regen_rate <= 0.0:
		return
	if spirit < spirit_max:
		var regen := spirit_regen_rate + float(_run_build["stats"].get("spirit_regen_bonus", 0.0))
		spirit = min(spirit_max, spirit + regen * delta)
		_emit_spirit()

func _try_parry() -> void:
	if Time.get_ticks_msec() < _parry_lock_until:
		return
	if Time.get_ticks_msec() < _spirit_lock_until:
		return
	_parry_lock_until = Time.get_ticks_msec() + int(parry_cooldown * 1000.0)
	if combat_manager:
		combat_manager.call("open_clash_window", self, clash_window_duration)

func _cast_skill(slot: int) -> void:
	if Time.get_ticks_msec() < _spirit_lock_until:
		return
	if not skills.has(slot):
		return
	var data: Dictionary = skills[slot]
	var cost: float = (float(data["base_cost"]) + float(data["level"] - 1) * 4.0) * float(_run_build["stats"].get("spirit_cost_mult", 1.0))
	if spirit < cost:
		return
	spirit -= cost
	_emit_spirit()
	_spawn_skill_effect(slot, data)
	var resonated := false
	if combat_manager and combat_manager.call("can_resonate", self):
		resonated = combat_manager.call("register_resonance", self)
		if resonated:
			_apply_resonance(slot)
	skill_cast.emit(slot, current_element, data["level"])

func _spawn_skill_effect(slot: int, data: Dictionary) -> void:
	var level := int(data["level"])
	var base_radius := 2.0 if slot == 1 else 3.0 if slot == 2 else 4.0
	var base_damage := 8.0 if slot == 1 else 12.0 if slot == 2 else 16.0
	base_damage *= float(_run_build["stats"].get("damage_mult", 1.0))
	var element_color := _element_color(current_element)
	var effect: Node3D = null
	if slot == 1 and skill_pulse_scene:
		effect = skill_pulse_scene.instantiate()
		if effect:
			effect.radius = base_radius + float(level - 1) * 0.3
			effect.damage = base_damage + float(level - 1) * 2.0
			effect.duration = 0.35 + float(level - 1) * 0.04
			effect.color = element_color
	elif slot == 2 and skill_line_scene:
		effect = skill_line_scene.instantiate()
		if effect:
			effect.length = 5.5 + float(level - 1) * 0.6
			effect.width = 1.8 + float(level - 1) * 0.2
			effect.damage = base_damage + float(level - 1) * 2.0
			effect.duration = 0.25 + float(level - 1) * 0.03
			effect.color = element_color
	elif slot == 3 and skill_cone_scene:
		effect = skill_cone_scene.instantiate()
		if effect:
			effect.radius = 6.0 + float(level - 1) * 0.7
			effect.angle_deg = 70.0 + float(level - 1) * 5.0
			effect.damage = base_damage + float(level - 1) * 2.4
			effect.duration = 0.28 + float(level - 1) * 0.03
			effect.color = element_color
	if effect == null:
		return
	var dir := _last_move_dir
	if dir.length() < 0.1:
		dir = Vector3.RIGHT if side_scroll_mode else Vector3.FORWARD
	if _has_property(effect, "direction"):
		effect.set("direction", dir)
	if _has_property(effect, "element"):
		effect.set("element", current_element)
	if _has_property(effect, "source_pos"):
		effect.set("source_pos", global_position)
	if _has_property(effect, "source_actor"):
		effect.set("source_actor", self)
	var root := get_tree().current_scene
	if root:
		root.add_child(effect)
	else:
		add_child(effect)
	if effect is Node3D:
		(effect as Node3D).global_position = global_position + Vector3(0, 0.2, 0)

func _element_color(element: int) -> Color:
	match element:
		Element.FIRE:
			return Color(1, 0.35, 0.2, 0.6)
		Element.WOOD:
			return Color(0.3, 1, 0.4, 0.6)
		Element.METAL:
			return Color(0.7, 0.8, 1, 0.6)
		Element.EARTH:
			return Color(0.8, 0.6, 0.3, 0.6)
		Element.WATER:
			return Color(0.3, 0.6, 1, 0.6)
		_:
			return Color(1, 1, 1, 0.6)

func _apply_resonance(slot: int) -> void:
	var data: Dictionary = skills[slot]
	data["progress"] += 1
	if data["progress"] >= data["progress_needed"]:
		data["progress"] = 0
		data["progress_needed"] += 2
		data["level"] += 1
		skills[slot] = data
	_emit_spirit()

func grant_skill_progress(points: int = 1) -> Array:
	var upgraded: Array = []
	for slot in skills.keys():
		var data: Dictionary = skills[slot]
		data["progress"] += points
		while data["progress"] >= data["progress_needed"]:
			data["progress"] -= data["progress_needed"]
			data["progress_needed"] += 2
			data["level"] += 1
			upgraded.append({
				"slot": slot,
				"level": data["level"],
				"name": data.get("name", "Skill")
			})
		skills[slot] = data
	return upgraded

func _on_clash_window_ended(actor: Node, success: bool) -> void:
	if actor != self:
		return
	if success:
		_trigger_counter_guard()
		return
	if not success:
		_spirit_lock_until = Time.get_ticks_msec() + int(spirit_lock_duration * 1000.0)

func set_current_element(new_element: int) -> void:
	current_element = new_element

func set_element_state(element_name: String, tier: int) -> void:
	spirit_tier = tier
	match element_name:
		"Fire":
			current_element = Element.FIRE
		"Wood":
			current_element = Element.WOOD
		"Metal":
			current_element = Element.METAL
		"Earth":
			current_element = Element.EARTH
		"Water":
			current_element = Element.WATER

func take_hit(damage: float, _element: int = -1, _source_pos: Vector3 = Vector3.ZERO) -> void:
	if _defeated:
		return
	var reduction: float = clamp(float(_run_build["stats"].get("damage_reduction", 0.0)), 0.0, 0.7)
	var final_damage: float = max(1.0, damage * (1.0 - reduction))
	if _guard > 0.0:
		var absorbed: float = min(_guard, final_damage)
		_guard = max(0.0, _guard - absorbed)
		final_damage -= absorbed
		if absorbed > 0.0:
			var spirit_gain: float = float(_run_build["stats"].get("guard_spirit", 0.0))
			if spirit_gain > 0.0:
				spirit = min(spirit_max, spirit + spirit_gain)
				_emit_spirit()
			_emit_guard()
	if final_damage <= 0.0:
		return
	hp = max(0.0, hp - final_damage)
	_emit_hp()
	if hp <= 0.0:
		_defeated = true
		died.emit()

func is_defeated() -> bool:
	return _defeated

func apply_run_build(build_state: Dictionary) -> void:
	if build_state.has("slots"):
		_run_build["slots"] = build_state["slots"]
	if build_state.has("affixes"):
		_run_build["affixes"] = build_state["affixes"]
	if build_state.has("stats"):
		_run_build["stats"] = build_state["stats"]
	_recompute_build_stats()

func on_receive_loot(loot_entry: Dictionary) -> void:
	var slot := String(loot_entry.get("slot", ""))
	if slot == "":
		return
	var slots: Dictionary = _run_build["slots"]
	slots[slot] = loot_entry
	_run_build["slots"] = slots
	var affix: Dictionary = loot_entry.get("affix", {})
	if not affix.is_empty():
		var affixes: Array = _run_build["affixes"]
		affixes.append(affix)
		_run_build["affixes"] = affixes
	_recompute_build_stats()

func apply_story_blessing(blessing_id: String, blessing_stats: Dictionary) -> void:
	if blessing_id == "" or blessing_stats.is_empty():
		return
	var blessings: Array = _run_build.get("story_blessings", [])
	var replaced := false
	for i in range(blessings.size()):
		var blessing: Dictionary = blessings[i]
		if String(blessing.get("id", "")) == blessing_id:
			blessings[i] = {"id": blessing_id, "stats": blessing_stats.duplicate(true)}
			replaced = true
			break
	if not replaced:
		blessings.append({"id": blessing_id, "stats": blessing_stats.duplicate(true)})
	_run_build["story_blessings"] = blessings
	_recompute_build_stats()

func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		velocity.x = 0.0
		velocity.z = 0.0

func get_run_dps_snapshot() -> Dictionary:
	var combo_avg := 0.0
	for hit in _light_combo:
		combo_avg += float(hit.get("damage", 0.0))
	if _light_combo.size() > 0:
		combo_avg /= float(_light_combo.size())
	var dps: float = combo_avg / max(attack_cooldown, 0.1)
	dps *= float(_run_build["stats"].get("damage_mult", 1.0))
	return {
		"estimated_dps": dps,
		"damage_mult": _run_build["stats"].get("damage_mult", 1.0),
		"spirit_regen": spirit_regen_rate + float(_run_build["stats"].get("spirit_regen_bonus", 0.0)),
		"guard": _guard
	}

func _recompute_build_stats() -> void:
	var stats := {
		"damage_mult": 0.0,
		"attack_speed": 0.0,
		"spirit_cost_mult": 1.0,
		"spirit_regen_bonus": 0.0,
		"resonance_bonus": 0.0,
		"damage_reduction": 0.0,
		"boss_bonus": 0.0,
		"elite_bonus": 0.0,
		"stack_cap_bonus": 0.0,
		"parry_guard": 0.0,
		"counter_damage": 0.0,
		"counter_heal": 0.0,
		"guard_spirit": 0.0,
		"max_hp_bonus": 0.0,
		"spirit_max_bonus": 0.0
	}
	var slots: Dictionary = _run_build.get("slots", {})
	for slot_name in slots.keys():
		var loot: Dictionary = slots[slot_name]
		var base_stat: Dictionary = loot.get("base_stat", {})
		for key in base_stat.keys():
			var normalized_key := _normalize_build_stat_key(String(key))
			stats[normalized_key] = float(stats.get(normalized_key, 0.0)) + float(base_stat[key])
	var affixes: Array = _run_build.get("affixes", [])
	for affix_var in affixes:
		var affix: Dictionary = affix_var
		var rolled: Dictionary = affix.get("rolled", {})
		for key in rolled.keys():
			var normalized_key := _normalize_build_stat_key(String(key))
			stats[normalized_key] = float(stats.get(normalized_key, 0.0)) + float(rolled[key])
	var story_blessings: Array = _run_build.get("story_blessings", [])
	for blessing_var in story_blessings:
		var blessing: Dictionary = blessing_var
		var blessing_stats: Dictionary = blessing.get("stats", {})
		for key in blessing_stats.keys():
			var normalized_key := _normalize_build_stat_key(String(key))
			stats[normalized_key] = float(stats.get(normalized_key, 0.0)) + float(blessing_stats[key])
	stats["damage_mult"] = max(0.6, 1.0 + float(stats.get("damage_mult", 0.0)))
	stats["spirit_cost_mult"] = clamp(1.0 - float(stats.get("resonance_bonus", 0.0)) * 0.2, 0.7, 1.1)
	stats["max_hp_bonus"] = float(stats.get("max_hp", 0.0))
	stats["spirit_max_bonus"] = float(stats.get("spirit_max", 0.0))
	_run_build["stats"] = stats
	max_hp = 100.0 + float(stats.get("max_hp_bonus", 0.0))
	spirit_max = 100.0 + float(stats.get("spirit_max_bonus", 0.0))
	_guard = min(_guard, _get_guard_cap())
	hp = min(hp, max_hp)
	spirit = min(spirit, spirit_max)
	_emit_hp()
	_emit_spirit()
	_emit_guard()

func _emit_spirit() -> void:
	spirit_changed.emit(spirit, spirit_max)

func _emit_hp() -> void:
	hp_changed.emit(hp, max_hp)

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

func _update_animation() -> void:
	if _anim == null:
		return
	var moving: bool = abs(velocity.x) > 0.1 or _dodge_time_left > 0.0
	var anim_name := "walk" if moving else "idle"
	if _anim.current_animation != anim_name and _anim.has_animation(anim_name):
		_anim.play(anim_name)

func _update_facing(dir: Vector3) -> void:
	if model_root == null:
		return
	if dir.length() < 0.01:
		return
	var node3d := model_root as Node3D
	if node3d == null:
		return
	var facing := dir.normalized()
	if side_scroll_mode:
		facing = Vector3.RIGHT if dir.x >= 0.0 else Vector3.LEFT
	var yaw := atan2(facing.x, facing.z)
	if not side_scroll_mode and snap_facing:
		var step := deg_to_rad(snap_angle_deg)
		if step > 0.0:
			yaw = round(yaw / step) * step
	var target := yaw + deg_to_rad(model_yaw_offset_deg)
	node3d.rotation.y = lerp_angle(node3d.rotation.y, target, clamp(turn_speed * get_physics_process_delta_time(), 0.0, 1.0))

func get_skill_status() -> Dictionary:
	var status := {}
	for slot in skills.keys():
		var data: Dictionary = skills[slot]
		status[slot] = {
			"level": data["level"],
			"progress": data["progress"],
			"progress_needed": data["progress_needed"],
			"base_cost": data["base_cost"]
		}
	return status

func get_spirit_state() -> Dictionary:
	return {
		"current": spirit,
		"max": spirit_max
	}

func get_hp_state() -> Dictionary:
	return {
		"current": hp,
		"max": max_hp,
		"guard": _guard,
		"guard_max": _get_guard_cap()
	}

func get_guard_state() -> Dictionary:
	return {
		"current": _guard,
		"max": _get_guard_cap()
	}

func get_element_state() -> Dictionary:
	var name := "Fire"
	match current_element:
		Element.FIRE:
			name = "Fire"
		Element.WOOD:
			name = "Wood"
		Element.METAL:
			name = "Metal"
		Element.EARTH:
			name = "Earth"
		Element.WATER:
			name = "Water"
	return {
		"name": name,
		"tier": spirit_tier
	}

func get_weapon_state() -> Dictionary:
	var weapon: Dictionary = {}
	if weapons.size() > 0:
		weapon = weapons[current_weapon_index]
	return {
		"name": weapon.get("name", "Weapon"),
		"index": current_weapon_index + 1
	}

func get_build_state() -> Dictionary:
	return _run_build.duplicate(true)

func _has_property(target: Object, prop_name: String) -> bool:
	if target == null:
		return false
	for info in target.get_property_list():
		if info.has("name") and info["name"] == prop_name:
			return true
	return false

func _normalize_build_stat_key(key: String) -> String:
	match key:
		"spirit_regen":
			return "spirit_regen_bonus"
		_:
			return key

func _trigger_counter_guard() -> void:
	var stats: Dictionary = _run_build["stats"]
	var guard_gain := float(stats.get("parry_guard", 0.0))
	if guard_gain > 0.0:
		_guard = clamp(_guard + guard_gain, 0.0, _get_guard_cap())
		_emit_guard()
	var heal_amount := float(stats.get("counter_heal", 0.0))
	if heal_amount > 0.0:
		hp = min(max_hp, hp + heal_amount)
		_emit_hp()
	var counter_damage := float(stats.get("counter_damage", 0.0))
	if counter_damage > 0.0:
		_emit_counter_burst(counter_damage)
	if guard_gain <= 0.0 and heal_amount <= 0.0 and counter_damage <= 0.0:
		_gain_spirit(false)

func _emit_counter_burst(base_damage: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	if root == null:
		return
	var burst_radius := 4.6
	var damage := base_damage * float(_run_build["stats"].get("damage_mult", 1.0))
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Node3D):
			continue
		var enemy := node as Node3D
		if enemy.global_position.distance_to(global_position) > burst_radius:
			continue
		if not enemy.has_method("take_hit"):
			continue
		var final_damage := damage
		if combat_manager:
			final_damage = float(combat_manager.call("register_hit", self, enemy, damage, current_element, global_position))
		enemy.call("take_hit", final_damage, current_element, global_position)
	if combat_manager:
		combat_manager.call("request_hitstop", 0.04, 0.14)

func _get_guard_cap() -> float:
	return max(12.0, max_hp * 0.45)

func _emit_guard() -> void:
	guard_changed.emit(_guard, _get_guard_cap())
