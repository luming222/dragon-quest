extends Node

signal clash_window_started(actor: Node)
signal clash_window_ended(actor: Node, success: bool)
signal hit_registered(attacker: Node, target: Node, damage: float, element: int)
signal element_stack_changed(target: Node, element: int, stacks: int)
signal resonance_triggered(actor: Node, element: int, stacks: int)

@export var elements_data_path := "res://data/elements.json"

var _clash_windows := {}
var _hitstop_active := false
var _saved_time_scale := 1.0
var _element_rules: Dictionary = {}
var _element_stacks: Dictionary = {}

func _ready() -> void:
	_load_element_rules()

func _load_element_rules() -> void:
	var file := FileAccess.open(elements_data_path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var rows: Array = json.get_data()
	for row_var in rows:
		var row: Dictionary = row_var
		var id := int(row.get("element_id", -1))
		if id < 0:
			continue
		_element_rules[id] = row

func open_clash_window(actor: Node, duration: float = 0.8) -> void:
	if not actor:
		return
	var id := actor.get_instance_id()
	if _clash_windows.has(id):
		return
	_clash_windows[id] = {
		"actor": actor,
		"end_time": Time.get_ticks_msec() + int(duration * 1000.0),
		"resonated": false
	}
	clash_window_started.emit(actor)

func can_resonate(actor: Node) -> bool:
	if not actor:
		return false
	return _clash_windows.has(actor.get_instance_id())

func register_resonance(actor: Node) -> bool:
	if not actor:
		return false
	var id := actor.get_instance_id()
	if not _clash_windows.has(id):
		return false
	var data: Dictionary = _clash_windows[id]
	data["resonated"] = true
	_clash_windows[id] = data
	if actor.has_method("get_element_state"):
		var element_state: Dictionary = actor.call("get_element_state")
		var element_name := String(element_state.get("name", "Fire"))
		var element := _element_name_to_id(element_name)
		var stacks := get_element_stacks_for_actor(actor, element)
		resonance_triggered.emit(actor, element, stacks)
		clear_element_stacks_for_actor(actor, element)
	return true

func request_hitstop(duration: float = 0.06, time_scale: float = 0.1) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	_saved_time_scale = Engine.time_scale
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = _saved_time_scale
	_hitstop_active = false

func register_hit(attacker: Node, target: Node, damage: float, element: int, _source_pos: Vector3 = Vector3.ZERO) -> float:
	var final_damage := damage
	if target and element >= 0:
		_apply_element_stack(target, element)
		if _is_counter_element(attacker, element):
			final_damage *= 1.12
	hit_registered.emit(attacker, target, final_damage, element)
	return final_damage

func get_element_stacks(target: Node) -> Dictionary:
	if target == null:
		return {}
	var id := target.get_instance_id()
	return _element_stacks.get(id, {})

func get_element_stacks_for_actor(actor: Node, element: int) -> int:
	if actor == null:
		return 0
	var id := actor.get_instance_id()
	var stacks: Dictionary = _element_stacks.get(id, {})
	return int(stacks.get(element, 0))

func clear_element_stacks_for_actor(actor: Node, element: int) -> void:
	if actor == null:
		return
	var id := actor.get_instance_id()
	if not _element_stacks.has(id):
		return
	var stacks: Dictionary = _element_stacks[id]
	stacks[element] = 0
	_element_stacks[id] = stacks
	element_stack_changed.emit(actor, element, 0)

func _apply_element_stack(target: Node, element: int) -> void:
	var id := target.get_instance_id()
	var stacks: Dictionary = _element_stacks.get(id, {})
	var current := int(stacks.get(element, 0))
	var rule: Dictionary = _element_rules.get(element, {})
	var max_stacks := int(rule.get("max_stacks", 3))
	current = min(max_stacks, current + 1)
	stacks[element] = current
	_element_stacks[id] = stacks
	element_stack_changed.emit(target, element, current)

func _is_counter_element(attacker: Node, element: int) -> bool:
	if attacker == null:
		return false
	if not attacker.has_method("get_element_state"):
		return false
	var element_state: Dictionary = attacker.call("get_element_state")
	var actor_element := _element_name_to_id(String(element_state.get("name", "Fire")))
	if not _element_rules.has(actor_element):
		return false
	var rule: Dictionary = _element_rules[actor_element]
	return int(rule.get("counter_relation", -1)) == element

func _element_name_to_id(name: String) -> int:
	match name:
		"Fire":
			return 0
		"Wood":
			return 1
		"Metal":
			return 2
		"Earth":
			return 3
		"Water":
			return 4
		_:
			return 0

func _process(_delta: float) -> void:
	if _clash_windows.is_empty():
		return
	var now := Time.get_ticks_msec()
	var to_remove: Array = []
	for id in _clash_windows.keys():
		var data: Dictionary = _clash_windows[id]
		if now >= data["end_time"]:
			var actor: Node = data["actor"]
			var success := bool(data["resonated"])
			clash_window_ended.emit(actor, success)
			to_remove.append(id)
	for id in to_remove:
		_clash_windows.erase(id)
