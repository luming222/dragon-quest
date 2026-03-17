extends Node

signal wave_started(wave_index: int, label: String, target_kills: int)
signal wave_progress(wave_index: int, kills: int, target_kills: int)
signal wave_cleared(wave_index: int)
signal elite_started(label: String)
signal elite_cleared()
signal boss_started(boss: Node)
signal boss_phase_changed(phase: int)
signal boss_defeated()

@export var player_path: NodePath = NodePath("../Player")
@export var enemy_melee_scene: PackedScene = preload("res://scenes/EnemyDummy.tscn")
@export var enemy_ranged_scene: PackedScene = preload("res://scenes/EnemyRanged.tscn")
@export var enemy_charger_scene: PackedScene = preload("res://scenes/EnemyCharger.tscn")
@export var boss_fallback_scene: PackedScene = preload("res://scenes/EnemyMiniBoss.tscn")
@export var level_data_path := "res://world/level_data.json"
@export var equipment_pool_path := "res://data/equipment_pool.json"
@export var affix_pool_path := "res://data/affix_pool.json"

var _player: Node3D = null
var _run_profile: Dictionary = {}
var _arena: Dictionary = {}
var _wave_table: Array = []
var _elite_profile: Dictionary = {}
var _boss_profile: Dictionary = {}
var _loot_table: Array = []
var _difficulty_curve: Array = []

var _equipment_pool: Array = []
var _affix_pool: Array = []

var _active_mode := "idle"
var _active_wave_index := -1
var _wave_data: Dictionary = {}
var _wave_time := 0.0
var _spawn_timer := 0.0
var _kills_this_wave := 0
var _enemies_alive := 0
var _boss_ref: Node = null
var _elapsed_runtime := 0.0

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_load_data()
	_load_build_data()

func _process(delta: float) -> void:
	if _active_mode == "idle":
		return
	_elapsed_runtime += delta
	if _active_mode == "wave":
		_wave_time += delta
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_wave_batch()
			_spawn_timer = float(_wave_data.get("spawn_interval", 2.0))
		var target_kills := int(_wave_data.get("target_kills", 6))
		if _kills_this_wave >= target_kills:
			_clear_active_wave()
		elif _wave_time >= float(_wave_data.get("duration", 40.0)) and _kills_this_wave >= int(target_kills * 0.7):
			_clear_active_wave()

func start_run() -> void:
	_clear_enemies()
	_active_mode = "idle"
	_active_wave_index = -1
	_wave_data = {}
	_wave_time = 0.0
	_spawn_timer = 0.0
	_kills_this_wave = 0
	_enemies_alive = 0
	_boss_ref = null
	_elapsed_runtime = 0.0

func get_prepare_time() -> float:
	return float(_run_profile.get("prepare_time", 3.0))

func get_wave_count() -> int:
	return _wave_table.size()

func start_wave(index: int) -> void:
	if index < 0 or index >= _wave_table.size():
		return
	_clear_enemies()
	_active_mode = "wave"
	_active_wave_index = index
	_wave_data = _wave_table[index]
	_wave_time = 0.0
	_spawn_timer = 0.0
	_kills_this_wave = 0
	_enemies_alive = 0
	var label := String(_wave_data.get("label", "Wave"))
	var target_kills := int(_wave_data.get("target_kills", 6))
	wave_started.emit(index, label, target_kills)

func start_elite() -> void:
	_clear_enemies()
	_active_mode = "elite"
	_active_wave_index = -1
	_kills_this_wave = 0
	_enemies_alive = 0
	var elite_type := String(_elite_profile.get("enemy_type", "charger"))
	var count := int(_elite_profile.get("count", 2))
	elite_started.emit(String(_elite_profile.get("label", "Elite")))
	for i in range(count):
		_spawn_enemy_type(elite_type, i, count)

func start_boss() -> void:
	_clear_enemies()
	_active_mode = "boss"
	_active_wave_index = -1
	_kills_this_wave = 0
	_enemies_alive = 0
	var scene: PackedScene = _load_boss_scene()
	if scene == null:
		scene = boss_fallback_scene
	if scene == null:
		return
	var boss := scene.instantiate()
	if boss == null:
		return
	_apply_difficulty_to_enemy(boss)
	var parent := get_parent()
	if parent:
		parent.add_child(boss)
	else:
		add_child(boss)
	await get_tree().process_frame
	if boss is Node3D:
		(boss as Node3D).global_position = _pick_spawn_point(0, 1)
	if boss.has_method("enter_phase"):
		boss.call("enter_phase", 1)
	if boss.has_signal("phase_changed"):
		boss.connect("phase_changed", Callable(self, "_on_boss_phase_changed"))
	if boss.has_signal("died"):
		boss.connect("died", Callable(self, "_on_boss_died"))
	_enemies_alive = 1
	_boss_ref = boss
	boss_started.emit(boss)

func get_supply_choices() -> Array:
	var count := int(_boss_profile.get("supply_choices", 2))
	return roll_loot_choices(count)

func get_active_boss() -> Node:
	if _boss_ref != null and is_instance_valid(_boss_ref):
		return _boss_ref
	return null

func roll_loot_choices(count: int = 3) -> Array:
	var choices: Array = []
	if count <= 0:
		return choices
	for _i in range(count):
		var slot_entry: Dictionary = _weighted_pick(_loot_table)
		if slot_entry.is_empty():
			continue
		var slot := String(slot_entry.get("slot", "weapon"))
		var rarity := String(slot_entry.get("rarity", "common"))
		var equipment := _pick_equipment(slot, rarity)
		if equipment.is_empty():
			continue
		var allowed_affixes: Array = equipment.get("affixes", [])
		var affix := _pick_affix(allowed_affixes)
		choices.append({
			"slot": slot,
			"rarity": rarity,
			"item_id": String(equipment.get("item_id", "item")),
			"base_stat": equipment.get("base_stat", {}),
			"affix": affix,
		})
	return choices

func is_boss_alive() -> bool:
	return _boss_ref != null and is_instance_valid(_boss_ref)

func get_difficulty_multiplier() -> Dictionary:
	var hp_mult := 1.0
	var damage_mult := 1.0
	for row_var in _difficulty_curve:
		var row: Dictionary = row_var
		if _elapsed_runtime >= float(row.get("time", 0.0)):
			hp_mult = float(row.get("hp_mult", hp_mult))
			damage_mult = float(row.get("damage_mult", damage_mult))
	return {
		"hp_mult": hp_mult,
		"damage_mult": damage_mult,
	}

func _spawn_wave_batch() -> void:
	var batch_size := int(_wave_data.get("batch_size", 2))
	var enemy_mix: Array = _wave_data.get("enemy_mix", ["melee"])
	if enemy_mix.is_empty():
		enemy_mix = ["melee"]
	for i in range(batch_size):
		var kind := String(enemy_mix[randi() % enemy_mix.size()])
		_spawn_enemy_type(kind, i, batch_size)

func _spawn_enemy_type(type_name: String, index: int, count: int) -> void:
	var scene := _get_enemy_scene(type_name)
	if scene == null:
		return
	var enemy := scene.instantiate()
	if enemy == null:
		return
	_apply_difficulty_to_enemy(enemy)
	var parent := get_parent()
	if parent:
		parent.add_child(enemy)
	else:
		add_child(enemy)
	await get_tree().process_frame
	if enemy is Node3D:
		(enemy as Node3D).global_position = _pick_spawn_point(index, count)
	if enemy.has_signal("died"):
		enemy.connect("died", Callable(self, "_on_enemy_died"))
	_enemies_alive += 1

func _pick_spawn_point(index: int, count: int) -> Vector3:
	var base_pos := Vector3.ZERO
	if _player and _player.is_inside_tree():
		base_pos = _player.global_position
	var radius := float(_arena.get("spawn_radius", 12.0))
	var angle: float = TAU * float(index) / max(float(count), 1.0)
	var lane_z := float(_arena.get("lane_z", 0.0))
	var x := base_pos.x + cos(angle) * radius
	x = clamp(x, float(_arena.get("left_bound", -40.0)), float(_arena.get("right_bound", 40.0)))
	return Vector3(x, 0.0, lane_z)

func _apply_difficulty_to_enemy(enemy: Node) -> void:
	var mult := get_difficulty_multiplier()
	if enemy.has_method("set"):
		var hp_mult := float(mult.get("hp_mult", 1.0))
		var max_hp_val: Variant = enemy.get("max_hp")
		if typeof(max_hp_val) == TYPE_FLOAT or typeof(max_hp_val) == TYPE_INT:
			enemy.set("max_hp", float(max_hp_val) * hp_mult)

func _on_enemy_died() -> void:
	_enemies_alive = max(0, _enemies_alive - 1)
	if _active_mode == "wave":
		_kills_this_wave += 1
		wave_progress.emit(_active_wave_index, _kills_this_wave, int(_wave_data.get("target_kills", 0)))
	elif _active_mode == "elite" and _enemies_alive == 0:
		_active_mode = "idle"
		elite_cleared.emit()

func _on_boss_phase_changed(phase: int) -> void:
	var normalized_phase := 1 if phase <= 1 else 2
	boss_phase_changed.emit(normalized_phase)

func _on_boss_died() -> void:
	_enemies_alive = 0
	_active_mode = "idle"
	_boss_ref = null
	boss_defeated.emit()

func _clear_active_wave() -> void:
	_active_mode = "idle"
	_clear_enemies()
	wave_cleared.emit(_active_wave_index)

func _clear_enemies() -> void:
	var parent := get_parent()
	var nodes := parent.get_children() if parent else get_children()
	for node in nodes:
		if node is Node and node.is_in_group("enemies"):
			node.queue_free()
	_enemies_alive = 0

func _get_enemy_scene(type_name: String) -> PackedScene:
	match type_name:
		"ranged":
			return enemy_ranged_scene
		"charger":
			return enemy_charger_scene
		_:
			return enemy_melee_scene

func _load_boss_scene() -> PackedScene:
	var scene_path := String(_boss_profile.get("scene", ""))
	if scene_path == "":
		return boss_fallback_scene
	var loaded := ResourceLoader.load(scene_path)
	if loaded is PackedScene:
		return loaded
	return boss_fallback_scene

func _load_data() -> void:
	var data := _load_json_dict(level_data_path)
	_run_profile = data.get("run_profile", {})
	_arena = data.get("arena", {})
	_wave_table = data.get("wave_table", [])
	_elite_profile = data.get("elite_profile", {})
	_boss_profile = data.get("boss_profile", {})
	_loot_table = data.get("loot_table", [])
	_difficulty_curve = data.get("difficulty_curve", [])

func _load_build_data() -> void:
	_equipment_pool = _load_json_array(equipment_pool_path)
	_affix_pool = _load_json_array(affix_pool_path)

func _load_json_dict(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data = json.get_data()
	return data if data is Dictionary else {}

func _load_json_array(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return []
	var data = json.get_data()
	return data if data is Array else []

func _weighted_pick(rows: Array) -> Dictionary:
	if rows.is_empty():
		return {}
	var total := 0.0
	for row_var in rows:
		var row: Dictionary = row_var
		total += float(row.get("drop_weight", 1.0))
	if total <= 0.0:
		return {}
	var roll := randf() * total
	var acc := 0.0
	for row_var in rows:
		var row: Dictionary = row_var
		acc += float(row.get("drop_weight", 1.0))
		if roll <= acc:
			return row
	return rows.back()

func _pick_equipment(slot: String, rarity: String) -> Dictionary:
	var candidates: Array = []
	for row_var in _equipment_pool:
		var row: Dictionary = row_var
		if String(row.get("slot", "")) != slot:
			continue
		if String(row.get("rarity", "")) != rarity:
			continue
		candidates.append(row)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]

func _pick_affix(allowed_ids: Array) -> Dictionary:
	if _affix_pool.is_empty():
		return {}
	var candidates: Array = []
	for row_var in _affix_pool:
		var row: Dictionary = row_var
		if allowed_ids.is_empty() or allowed_ids.has(row.get("affix_id", "")):
			candidates.append(row)
	if candidates.is_empty():
		return {}
	var affix: Dictionary = candidates[randi() % candidates.size()]
	var rolled: Dictionary = {}
	var roll_range: Dictionary = affix.get("roll_range", {})
	for key in roll_range.keys():
		var val: Variant = roll_range[key]
		if val is Array and val.size() >= 2:
			rolled[key] = randf_range(float(val[0]), float(val[1]))
	var out := affix.duplicate(true)
	out["rolled"] = rolled
	return out
