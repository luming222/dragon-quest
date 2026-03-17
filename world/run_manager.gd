extends Node

signal run_state_changed(state_name: String)
signal run_finished(success: bool, summary: Dictionary)

enum RunState { PREPARE, WAVE, ELITE, BOSS_P1, BOSS_P2, RESULT }

@export var level_manager_path: NodePath = NodePath("../LevelManager")
@export var player_path: NodePath = NodePath("../Player")
@export var hud_path: NodePath = NodePath("../CanvasLayer/HUD")
@export var auto_start_on_ready := false

var _level_manager: Node = null
var _player: Node = null
var _hud: Node = null

var _state: int = RunState.PREPARE
var _state_time := 0.0
var _current_wave := -1
var _kills_total := 0
var _run_time := 0.0
var _active := false
var _boss_phase := 1
var _pending_loot_choices: Array = []
var _pending_loot_title := ""
var _pending_next_step: Dictionary = {}
var _qiyun_event_seen := false

func _ready() -> void:
	_level_manager = get_node_or_null(level_manager_path)
	_player = get_node_or_null(player_path)
	_hud = get_node_or_null(hud_path)
	_bind_signals()
	if auto_start_on_ready:
		start_run()

func _process(delta: float) -> void:
	if _has_pending_loot_choice():
		_handle_loot_choice_input()
		return
	if not _active:
		return
	_state_time += delta
	_run_time += delta
	if _state == RunState.PREPARE and _level_manager:
		var prep_time := float(_level_manager.call("get_prepare_time"))
		if _state_time >= prep_time:
			_start_wave(0)
	if _player and _player.has_method("is_defeated") and _player.call("is_defeated"):
		_finish_run(false)

func start_run() -> void:
	_active = true
	_current_wave = -1
	_kills_total = 0
	_run_time = 0.0
	_boss_phase = 1
	_pending_loot_choices.clear()
	_pending_loot_title = ""
	_pending_next_step = {}
	_qiyun_event_seen = false
	_state = RunState.PREPARE
	_state_time = 0.0
	if _level_manager:
		_level_manager.call("start_run")
	_set_player_input_locked(false)
	_update_hud_state("Prepare", 0, 0)
	if _hud and _hud.has_method("show_stage_start"):
		_hud.call("show_stage_start", "Dustbound Path")
	run_state_changed.emit("PREPARE")

func _bind_signals() -> void:
	if _player and _player.has_signal("died"):
		_player.connect("died", Callable(self, "_on_player_died"))
	if _level_manager == null:
		return
	if _level_manager.has_signal("wave_started"):
		_level_manager.connect("wave_started", Callable(self, "_on_wave_started"))
	if _level_manager.has_signal("wave_progress"):
		_level_manager.connect("wave_progress", Callable(self, "_on_wave_progress"))
	if _level_manager.has_signal("wave_cleared"):
		_level_manager.connect("wave_cleared", Callable(self, "_on_wave_cleared"))
	if _level_manager.has_signal("elite_started"):
		_level_manager.connect("elite_started", Callable(self, "_on_elite_started"))
	if _level_manager.has_signal("elite_cleared"):
		_level_manager.connect("elite_cleared", Callable(self, "_on_elite_cleared"))
	if _level_manager.has_signal("boss_started"):
		_level_manager.connect("boss_started", Callable(self, "_on_boss_started"))
	if _level_manager.has_signal("boss_phase_changed"):
		_level_manager.connect("boss_phase_changed", Callable(self, "_on_boss_phase_changed"))
	if _level_manager.has_signal("boss_defeated"):
		_level_manager.connect("boss_defeated", Callable(self, "_on_boss_defeated"))

func _start_wave(index: int) -> void:
	if _level_manager == null:
		return
	_state = RunState.WAVE
	_state_time = 0.0
	_current_wave = index
	_level_manager.call("start_wave", index)
	run_state_changed.emit("WAVE")

func _start_elite() -> void:
	if _level_manager == null:
		return
	_state = RunState.ELITE
	_state_time = 0.0
	_level_manager.call("start_elite")
	run_state_changed.emit("ELITE")

func _start_boss() -> void:
	if _level_manager == null:
		return
	_state = RunState.BOSS_P1
	_state_time = 0.0
	_boss_phase = 1
	_level_manager.call("start_boss")
	_update_hud_boss_phase(1)
	run_state_changed.emit("BOSS_P1")

func _on_wave_started(wave_index: int, label: String, target_kills: int) -> void:
	_update_hud_state(label, 0, target_kills)

func _on_wave_progress(_wave_index: int, kills: int, target_kills: int) -> void:
	_kills_total += 1
	_update_hud_state("Wave %d" % (_current_wave + 1), kills, target_kills)

func _on_wave_cleared(wave_index: int) -> void:
	if _level_manager == null:
		return
	var total_waves := int(_level_manager.call("get_wave_count"))
	var next_step := {
		"type": "elite" if wave_index + 1 >= total_waves else "wave",
		"wave_index": wave_index + 1,
	}
	if wave_index == 0 and not _qiyun_event_seen:
		_qiyun_event_seen = true
		if _hud and _hud.has_method("show_stage_start"):
			_hud.call("show_stage_start", "Ming: 稳住气，别急着抢势。")
		if _request_loot_choice(_build_qiyun_choices(), "赌一口气韵", next_step):
			return
	if _request_loot_choice(_level_manager.call("roll_loot_choices", 3), "Choose your reward", next_step):
		return
	if wave_index + 1 < total_waves:
		_start_wave(wave_index + 1)
	else:
		_start_elite()

func _on_elite_started(label: String) -> void:
	_update_hud_state(label, 0, 0)

func _on_elite_cleared() -> void:
	if _level_manager == null:
		return
	if _request_loot_choice(_level_manager.call("roll_loot_choices", 3), "Elite reward", {"type": "supply"}):
		return
	_advance_after_loot_choice({"type": "supply"})

func _on_boss_started(_boss: Node) -> void:
	_update_hud_state("Boss", 0, 0)

func _on_boss_phase_changed(phase: int) -> void:
	_boss_phase = phase
	if phase >= 2:
		_state = RunState.BOSS_P2
		run_state_changed.emit("BOSS_P2")
	_update_hud_boss_phase(phase)

func _on_boss_defeated() -> void:
	_finish_run(true)

func _on_player_died() -> void:
	_finish_run(false)

func _finish_run(success: bool) -> void:
	if not _active:
		return
	_active = false
	_pending_loot_choices.clear()
	_pending_loot_title = ""
	_pending_next_step = {}
	_set_player_input_locked(false)
	_state = RunState.RESULT
	_state_time = 0.0
	var summary := {
		"success": success,
		"run_time": _run_time,
		"kills": _kills_total,
		"boss_phase": _boss_phase,
	}
	if _hud and _hud.has_method("set_run_result"):
		_hud.call("set_run_result", success, summary)
	run_finished.emit(success, summary)
	run_state_changed.emit("RESULT")

func _has_pending_loot_choice() -> bool:
	return not _pending_loot_choices.is_empty()

func _request_loot_choice(choices: Array, title: String, next_step: Dictionary) -> bool:
	if choices.is_empty():
		return false
	_pending_loot_choices = choices.duplicate(true)
	_pending_loot_title = title
	_pending_next_step = next_step.duplicate(true)
	_set_player_input_locked(true)
	if _hud and _hud.has_method("show_loot_choices"):
		_hud.call("show_loot_choices", _pending_loot_choices, _pending_loot_title)
	return true

func _handle_loot_choice_input() -> void:
	var selected_index := -1
	if Input.is_action_just_pressed("skill_1"):
		selected_index = 0
	elif Input.is_action_just_pressed("skill_2"):
		selected_index = 1
	elif Input.is_action_just_pressed("skill_3"):
		selected_index = 2
	if selected_index < 0 or selected_index >= _pending_loot_choices.size():
		return
	var selected_choice: Dictionary = _pending_loot_choices[selected_index]
	if _hud and _hud.has_method("clear_loot_choices"):
		_hud.call("clear_loot_choices")
	if _player and _player.has_method("on_receive_loot"):
		_player.call("on_receive_loot", selected_choice)
	if _hud and _hud.has_method("show_loot_picked"):
		_hud.call("show_loot_picked", selected_choice)
	var next_step := _pending_next_step.duplicate(true)
	_pending_loot_choices.clear()
	_pending_loot_title = ""
	_pending_next_step = {}
	_set_player_input_locked(false)
	_advance_after_loot_choice(next_step)

func _advance_after_loot_choice(next_step: Dictionary) -> void:
	var step_type := String(next_step.get("type", ""))
	match step_type:
		"wave":
			_start_wave(int(next_step.get("wave_index", _current_wave + 1)))
		"elite":
			_start_elite()
		"supply":
			if _level_manager == null:
				return
			var supply_choices: Array = _level_manager.call("get_supply_choices")
			if _request_loot_choice(supply_choices, "Choose a supply", {"type": "boss"}):
				return
			_start_boss()
		"boss":
			if _hud and _hud.has_method("show_boss_intro"):
				_hud.call("show_boss_intro", "Ming: 能接住别人的重量，未必接得住自己的。")
			_start_boss()

func _set_player_input_locked(locked: bool) -> void:
	if _player and _player.has_method("set_input_locked"):
		_player.call("set_input_locked", locked)

func _update_hud_state(label: String, kills: int, target_kills: int) -> void:
	if _hud and _hud.has_method("set_wave_state"):
		_hud.call("set_wave_state", {
			"label": label,
			"kills": kills,
			"target_kills": target_kills,
			"wave": _current_wave + 1,
			"time": _run_time,
		})

func _update_hud_boss_phase(phase: int) -> void:
	if _hud and _hud.has_method("set_boss_phase"):
		_hud.call("set_boss_phase", phase)

func _build_qiyun_choices() -> Array:
	return [
		{
			"slot": "core",
			"rarity": "rare",
			"item_id": "stone_vow",
			"base_stat": {
				"damage_reduction": 0.05,
				"parry_guard": 10.0
			},
			"affix": {
				"affix_id": "bulwark",
				"rolled": {
					"parry_guard": 8.0
				}
			}
		},
		{
			"slot": "weapon",
			"rarity": "rare",
			"item_id": "burden_brand",
			"base_stat": {
				"damage_mult": 0.08,
				"counter_damage": 12.0
			},
			"affix": {
				"affix_id": "reversal",
				"rolled": {
					"counter_damage": 10.0
				}
			}
		},
		{
			"slot": "charm",
			"rarity": "rare",
			"item_id": "still_water_gourd",
			"base_stat": {
				"max_hp": 10.0,
				"guard_spirit": 4.0
			},
			"affix": {
				"affix_id": "recovery",
				"rolled": {
					"counter_heal": 3.0
				}
			}
		}
	]
