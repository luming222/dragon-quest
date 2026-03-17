extends Control

@export var player_path: NodePath = NodePath("../../Player")
@export var combat_manager_path: NodePath = NodePath("../../CombatManager")
@export var camera_path: NodePath = NodePath("../../Camera3D")

@onready var spirit_bar: ProgressBar = $MarginContainer/TopRow/SpiritBar
@onready var spirit_label: Label = $MarginContainer/TopRow/SpiritLabel
@onready var stage_label: Label = $MarginContainer/TopRow/StageLabel
@onready var element_label: Label = $MarginContainer/TopRow/ElementLabel
@onready var weapon_label: Label = $MarginContainer/TopRow/WeaponLabel
@onready var skill1: Label = $MarginContainer/Skills/Skill1
@onready var skill2: Label = $MarginContainer/Skills/Skill2
@onready var skill3: Label = $MarginContainer/Skills/Skill3
@onready var clash_label: Label = $ClashLabel
@onready var debug_label: Label = $DebugLabel
@onready var flash: ColorRect = $Flash
@onready var transition: ColorRect = $Transition
@onready var stage_banner: Label = $StageBanner
@onready var tree_line1: Label = $SkillTreePanel/VBox/TreeLine1
@onready var tree_line2: Label = $SkillTreePanel/VBox/TreeLine2
@onready var tree_line3: Label = $SkillTreePanel/VBox/TreeLine3

var _player: Node = null
var _combat: Node = null
var _camera: Camera3D = null
var _loot_choice_active := false

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_combat = get_node_or_null(combat_manager_path)
	_camera = get_node_or_null(camera_path)
	if _player and _player.has_signal("spirit_changed"):
		_player.connect("spirit_changed", Callable(self, "_on_spirit_changed"))
	if _player and _player.has_signal("hp_changed"):
		_player.connect("hp_changed", Callable(self, "_on_hp_changed"))
	if _player and _player.has_signal("guard_changed"):
		_player.connect("guard_changed", Callable(self, "_on_guard_changed"))
	if _player and _player.has_signal("skill_cast"):
		_player.connect("skill_cast", Callable(self, "_on_skill_cast"))
	if _combat and _combat.has_signal("clash_window_started"):
		_combat.connect("clash_window_started", Callable(self, "_on_clash_started"))
	if _combat and _combat.has_signal("clash_window_ended"):
		_combat.connect("clash_window_ended", Callable(self, "_on_clash_ended"))
	if _player and _player.has_method("get_spirit_state"):
		var spirit_state: Dictionary = _player.call("get_spirit_state")
		_on_spirit_changed(float(spirit_state.get("current", 0.0)), float(spirit_state.get("max", 100.0)))
	if _player and _player.has_method("get_hp_state"):
		var hp_state: Dictionary = _player.call("get_hp_state")
		_on_hp_changed(float(hp_state.get("current", 0.0)), float(hp_state.get("max", 100.0)))
		_on_guard_changed(float(hp_state.get("guard", 0.0)), float(hp_state.get("guard_max", 0.0)))
	_refresh_skills()
	clash_label.visible = false
	stage_banner.visible = false
	if transition:
		transition.visible = false
	_update_element()
	_update_weapon()
	_update_debug()

func _process(_delta: float) -> void:
	_update_element()
	_update_weapon()
	_update_debug()

func _on_spirit_changed(current: float, max_value: float) -> void:
	spirit_bar.max_value = max_value
	spirit_bar.value = current
	spirit_label.text = "SP %.0f / %.0f" % [current, max_value]

func _on_hp_changed(current: float, max_value: float) -> void:
	var guard_text := ""
	if _player and _player.has_method("get_guard_state"):
		var guard_state: Dictionary = _player.call("get_guard_state")
		var guard_value := float(guard_state.get("current", 0.0))
		if guard_value > 0.0:
			guard_text = "  Guard %.0f" % guard_value
	stage_label.text = "HP %.0f / %.0f%s" % [current, max_value, guard_text]

func _on_guard_changed(current: float, _max_value: float) -> void:
	if _player == null or not _player.has_method("get_hp_state"):
		return
	var hp_state: Dictionary = _player.call("get_hp_state")
	_on_hp_changed(float(hp_state.get("current", 0.0)), float(hp_state.get("max", 100.0)))

func _on_skill_cast(_slot: int, _element: int, _level: int) -> void:
	_refresh_skills()

func _refresh_skills() -> void:
	if _player == null or not _player.has_method("get_skill_status"):
		return
	var status: Dictionary = _player.call("get_skill_status")
	if status.has(1):
		var s1: Dictionary = status[1]
		skill1.text = "S1 Lv%d (%d/%d)" % [s1["level"], s1["progress"], s1["progress_needed"]]
	if status.has(2):
		var s2: Dictionary = status[2]
		skill2.text = "S2 Lv%d (%d/%d)" % [s2["level"], s2["progress"], s2["progress_needed"]]
	if status.has(3):
		var s3: Dictionary = status[3]
		skill3.text = "S3 Lv%d (%d/%d)" % [s3["level"], s3["progress"], s3["progress_needed"]]
	_update_skill_tree(status)

func _update_skill_tree(status: Dictionary) -> void:
	if tree_line1:
		var s1: Dictionary = status.get(1, {})
		tree_line1.text = "Core Lv%d  %d/%d" % [int(s1.get("level", 1)), int(s1.get("progress", 0)), int(s1.get("progress_needed", 0))]
	if tree_line2:
		var s2: Dictionary = status.get(2, {})
		tree_line2.text = "Focus Lv%d  %d/%d" % [int(s2.get("level", 1)), int(s2.get("progress", 0)), int(s2.get("progress_needed", 0))]
	if tree_line3:
		var s3: Dictionary = status.get(3, {})
		tree_line3.text = "Burst Lv%d  %d/%d" % [int(s3.get("level", 1)), int(s3.get("progress", 0)), int(s3.get("progress_needed", 0))]

func set_wave_state(state: Dictionary) -> void:
	var label := String(state.get("label", "Wave"))
	var kills := int(state.get("kills", 0))
	var target_kills := int(state.get("target_kills", 0))
	if element_label == null:
		return
	if target_kills > 0:
		element_label.text = "%s  %d/%d" % [label, kills, target_kills]
	else:
		element_label.text = label

func set_boss_phase(phase: int) -> void:
	if weapon_label:
		weapon_label.text = "Boss P%d" % max(1, phase)
	_show_banner("Boss Phase %d" % max(1, phase), Color(1.0, 0.55, 0.35, 1.0))

func show_loot_choices(choices: Array, title: String = "Choose Loot") -> void:
	if choices.is_empty():
		return
	_loot_choice_active = true
	var build_state: Dictionary = {}
	var equipped_slots: Dictionary = {}
	if _player and _player.has_method("get_build_state"):
		build_state = _player.call("get_build_state")
		equipped_slots = build_state.get("slots", {})
	var lines: Array = [title, "Press 1/2/3 or skill buttons"]
	for i in range(min(3, choices.size())):
		var c: Dictionary = choices[i]
		var slot_name := String(c.get("slot", "slot"))
		var current_item: Dictionary = equipped_slots.get(slot_name, {})
		lines.append(_format_loot_choice(i + 1, c, current_item))
	_show_persistent_banner("\n".join(lines), Color(0.7, 0.9, 1.0, 1.0))

func clear_loot_choices() -> void:
	_loot_choice_active = false
	_hide_stage_banner()

func show_loot_picked(choice: Dictionary) -> void:
	var item_name := String(choice.get("item_id", "item"))
	_show_banner("Picked %s" % item_name, Color(0.55, 1.0, 0.75, 1.0))

func set_run_result(success: bool, summary: Dictionary) -> void:
	var text := "Run Clear" if success else "Run Failed"
	text += "\nTime %.1fs  Kills %d" % [float(summary.get("run_time", 0.0)), int(summary.get("kills", 0))]
	_show_banner(text, Color(0.55, 1.0, 0.65, 1.0) if success else Color(1.0, 0.45, 0.45, 1.0))

func set_stage_label(label_text: String) -> void:
	set_wave_state({"label": label_text})

func show_stage_start(label_text: String) -> void:
	_show_banner(label_text, Color(0.9, 0.95, 1.0, 1.0))

func show_stage_clear() -> void:
	_show_banner("Stage Clear", Color(0.4, 1.0, 0.6, 1.0))

func show_boss_intro(label_text: String) -> void:
	_show_banner(label_text, Color(1.0, 0.45, 0.35, 1.0))

func show_boss_phase(phase: int) -> void:
	set_boss_phase(phase)

func show_skill_upgrade(lines: Array) -> void:
	if lines.is_empty():
		return
	_show_banner("Skill Upgrade\n" + "\n".join(lines), Color(0.6, 0.85, 1.0, 1.0))

func show_story_prompt(text: String) -> void:
	_show_persistent_banner(text, Color(0.96, 0.9, 0.78, 1.0))

func show_story_choices(title: String, choices: Array) -> void:
	if choices.is_empty():
		return
	_loot_choice_active = true
	var lines: Array = [title, "Press E to remember, 1/2/3 to choose"]
	for i in range(min(3, choices.size())):
		var choice: Dictionary = choices[i]
		lines.append("%d. %s" % [i + 1, String(choice.get("text", "Choice"))])
	_show_persistent_banner("\n".join(lines), Color(0.93, 0.86, 0.72, 1.0))

func clear_story_choices() -> void:
	_loot_choice_active = false
	_hide_stage_banner()

func show_story_result(text: String) -> void:
	_show_banner(text, Color(0.85, 0.94, 1.0, 1.0))

func show_boss_exposed(text: String) -> void:
	_show_banner(text, Color(1.0, 0.82, 0.45, 1.0))

func _show_banner(text: String, color: Color) -> void:
	if stage_banner == null:
		return
	_loot_choice_active = false
	stage_banner.text = text
	stage_banner.self_modulate = color
	stage_banner.visible = true
	var tween := create_tween()
	tween.tween_property(stage_banner, "self_modulate", Color(color.r, color.g, color.b, 0.0), 1.2)
	tween.tween_callback(Callable(self, "_hide_stage_banner"))

func _show_persistent_banner(text: String, color: Color) -> void:
	if stage_banner == null:
		return
	stage_banner.text = text
	stage_banner.self_modulate = color
	stage_banner.visible = true

func _hide_stage_banner() -> void:
	if stage_banner:
		stage_banner.visible = false

func _update_element() -> void:
	if _player == null or not _player.has_method("get_element_state"):
		_player = get_node_or_null(player_path)
		if _player == null or not _player.has_method("get_element_state"):
			return
	var data: Dictionary = _player.call("get_element_state")
	if element_label.text == "" and not _loot_choice_active:
		element_label.text = "%s T%d" % [data.get("name", "Fire"), int(data.get("tier", 1))]

func _update_weapon() -> void:
	if _player == null or not _player.has_method("get_weapon_state"):
		_player = get_node_or_null(player_path)
		if _player == null or not _player.has_method("get_weapon_state"):
			return
	if not weapon_label.text.begins_with("Boss"):
		var data: Dictionary = _player.call("get_weapon_state")
		weapon_label.text = "Weapon %s (%d)" % [data.get("name", "Weapon"), int(data.get("index", 1))]

func _on_clash_started(actor: Node) -> void:
	if actor != _player:
		return
	clash_label.text = "CLASH"
	clash_label.visible = true
	_flash(Color(1, 1, 1, 0.25), 0.12)

func _on_clash_ended(actor: Node, success: bool) -> void:
	if actor != _player:
		return
	clash_label.text = "RESONATE" if success else "MISSED"
	_flash(Color(0.2, 1, 0.5, 0.35) if success else Color(1, 0.2, 0.2, 0.35), 0.18)
	await get_tree().create_timer(0.35).timeout
	clash_label.visible = false

func _update_debug() -> void:
	var player_ok := _player != null
	var cam_ok := _camera != null and _camera.current
	var pos_text := "n/a"
	var cam_pos := "n/a"
	if player_ok and _player is Node3D:
		pos_text = str((_player as Node3D).global_position)
	if _camera:
		cam_pos = str(_camera.global_position)
	debug_label.text = "Player:%s Cam:%s Pos:%s CamPos:%s" % [player_ok, cam_ok, pos_text, cam_pos]

func _flash(color: Color, duration: float) -> void:
	flash.color = color
	var tween := create_tween()
	tween.tween_property(flash, "color", Color(color.r, color.g, color.b, 0.0), duration)

func play_transition(color: Color, duration: float = 0.8) -> void:
	if transition == null:
		return
	transition.visible = true
	transition.color = Color(color.r, color.g, color.b, 0.0)
	var tween := create_tween()
	tween.tween_property(transition, "color", Color(color.r, color.g, color.b, 1.0), duration * 0.35)
	tween.tween_interval(duration * 0.2)
	tween.tween_property(transition, "color", Color(color.r, color.g, color.b, 0.0), duration * 0.45)
	tween.tween_callback(Callable(self, "_hide_transition"))

func _hide_transition() -> void:
	if transition:
		transition.visible = false

func _format_loot_choice(index: int, choice: Dictionary, current_item: Dictionary) -> String:
	var item_name := String(choice.get("item_id", "item"))
	var slot_name := String(choice.get("slot", "slot"))
	var rarity := String(choice.get("rarity", "common"))
	var stat_parts: Array = []
	var base_stat: Dictionary = choice.get("base_stat", {})
	for key in base_stat.keys():
		stat_parts.append(_format_stat(String(key), float(base_stat[key])))
	var affix: Dictionary = choice.get("affix", {})
	var affix_name := String(affix.get("affix_id", "none"))
	var rolled: Dictionary = affix.get("rolled", {})
	for key in rolled.keys():
		stat_parts.append(_format_stat(String(key), float(rolled[key])))
	var replace_text := ""
	if not current_item.is_empty():
		replace_text = " | replace %s" % String(current_item.get("item_id", "equipped"))
	var detail_text := ", ".join(stat_parts)
	if detail_text == "":
		detail_text = "No bonus"
	return "%d. %s [%s/%s] %s (%s%s)" % [index, item_name, slot_name, rarity, detail_text, affix_name, replace_text]

func _format_stat(stat_name: String, value: float) -> String:
	match stat_name:
		"damage_mult":
			return "+DMG %d%%" % int(round(value * 100.0))
		"attack_speed":
			return "+AS %d%%" % int(round(value * 100.0))
		"spirit_max":
			return "+SP %.0f" % value
		"spirit_regen":
			return "+Regen %.1f" % value
		"resonance_bonus":
			return "+Res %.0f%%" % round(value * 100.0)
		"max_hp":
			return "+HP %.0f" % value
		"damage_reduction":
			return "+Guard %.0f%%" % round(value * 100.0)
		"boss_bonus":
			return "+Boss %.0f%%" % round(value * 100.0)
		"elite_bonus":
			return "+Elite %.0f%%" % round(value * 100.0)
		"stack_cap_bonus":
			return "+Stack %.0f" % value
		"parry_guard":
			return "+Guard %.0f" % value
		"counter_damage":
			return "+Counter %.0f" % value
		"counter_heal":
			return "+Heal %.0f" % value
		"guard_spirit":
			return "+SP on Guard %.0f" % value
		_:
			return "%s %.2f" % [stat_name, value]
