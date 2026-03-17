extends Control

@onready var joystick_base: Control = $Joystick/Base
@onready var joystick_knob: Control = $Joystick/Knob
@onready var btn_attack: Button = $Buttons/Grid/Attack
@onready var btn_dodge: Button = $Buttons/Grid/Dodge
@onready var btn_parry: Button = $Buttons/Grid/Parry
@onready var btn_skill1: Button = $Buttons/Grid/Skill1
@onready var btn_skill2: Button = $Buttons/Grid/Skill2
@onready var btn_skill3: Button = $Buttons/Grid/Skill3

var _dragging := false
var _radius := 1.0
var _center := Vector2.ZERO
var _move_vec := Vector2.ZERO

func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available()
	mouse_filter = Control.MOUSE_FILTER_PASS
	_setup_joystick()
	_bind_button(btn_attack, "attack_light")
	_bind_button(btn_dodge, "dodge")
	_bind_button(btn_parry, "parry")
	_bind_button(btn_skill1, "skill_1")
	_bind_button(btn_skill2, "skill_2")
	_bind_button(btn_skill3, "skill_3")

func _setup_joystick() -> void:
	_center = joystick_base.size * 0.5
	_radius = min(joystick_base.size.x, joystick_base.size.y) * 0.45
	joystick_knob.position = _center - joystick_knob.size * 0.5

func _process(_delta: float) -> void:
	if not visible:
		return
	_apply_move_actions()

func _apply_move_actions() -> void:
	_set_action("move_left", _move_vec.x < -0.2)
	_set_action("move_right", _move_vec.x > 0.2)
	_set_action("move_up", _move_vec.y < -0.2)
	_set_action("move_down", _move_vec.y > 0.2)

func _set_action(action_name: String, active: bool) -> void:
	if active:
		Input.action_press(action_name)
	else:
		Input.action_release(action_name)

func _bind_button(button: Button, action_name: String) -> void:
	button.pressed.connect(func(): Input.action_press(action_name))
	button.button_up.connect(func(): Input.action_release(action_name))

func _on_base_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_dragging = true
			_update_joystick(touch.position)
		else:
			_dragging = false
			_reset_joystick()
	elif event is InputEventScreenDrag:
		if _dragging:
			_update_joystick((event as InputEventScreenDrag).position)

func _update_joystick(pos: Vector2) -> void:
	var local := pos - joystick_base.global_position
	var offset := local - _center
	if offset.length() > _radius:
		offset = offset.normalized() * _radius
	_move_vec = offset / _radius
	joystick_knob.position = _center + offset - joystick_knob.size * 0.5

func _reset_joystick() -> void:
	_move_vec = Vector2.ZERO
	joystick_knob.position = _center - joystick_knob.size * 0.5
