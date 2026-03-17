extends Node3D

@export var bob_height := 0.08
@export var bob_speed := 1.2
@export var facing_speed := 6.0

@onready var model_root: Node3D = $Model

var _anchor_position := Vector3.ZERO
var _focus_target: Node3D = null
var _active := true

func _ready() -> void:
	_anchor_position = global_position

func _process(delta: float) -> void:
	if not _active:
		return
	var time_now := float(Time.get_ticks_msec()) * 0.001
	global_position = Vector3(_anchor_position.x, _anchor_position.y + sin(time_now * bob_speed) * bob_height, _anchor_position.z)
	_update_facing(delta)

func set_focus_target(target: Node3D) -> void:
	_focus_target = target

func set_anchor_position(world_position: Vector3) -> void:
	_anchor_position = world_position
	global_position = world_position

func set_intro_active(active: bool) -> void:
	_active = active
	visible = active
	if not active:
		global_position = _anchor_position

func _update_facing(delta: float) -> void:
	if _focus_target == null or model_root == null:
		return
	var dir := _focus_target.global_position - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(dir.x, dir.z)
	model_root.rotation.y = lerp_angle(model_root.rotation.y, target_yaw, clamp(facing_speed * delta, 0.0, 1.0))
