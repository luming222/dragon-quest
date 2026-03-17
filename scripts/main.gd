extends Node3D

@onready var cam: Camera3D = $Camera3D
@onready var player: Node3D = $Player
@onready var omni: OmniLight3D = $OmniLight3D
@onready var fill_light: OmniLight3D = $FillLight
@onready var dir_light: DirectionalLight3D = $DirectionalLight3D
@onready var combat_manager: Node = $CombatManager
@onready var level_manager: Node = $LevelManager
@onready var run_manager: Node = $RunManager
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var floor: MeshInstance3D = $Floor
@onready var floor_body: StaticBody3D = $FloorBody
@onready var floor_collider: CollisionShape3D = $FloorBody/CollisionShape3D
@onready var arena_walls: Node3D = $ArenaWalls
@onready var terrain: Node = $Terrain
@onready var theme_sets: Node3D = $ThemeSets
@onready var underground_set: Node3D = $ThemeSets/UndergroundSet
@onready var surface_set: Node3D = $ThemeSets/SurfaceSet
@onready var sky_set: Node3D = $ThemeSets/SkySet
@onready var ming: Node3D = $Ming
@onready var hud: Control = $CanvasLayer/HUD

var camera_offset := Vector3(0.0, 6.0, 10.0)
var _yaw := 0.0
var _pitch := -25.0
var _distance := 12.0
@export var zoom_min := 6.0
@export var zoom_max := 22.0
@export var zoom_step := 1.2
var _rotating := false
var _mouse_sense := 0.25
@export var side_scroll_camera := false
@export var side_camera_offset := Vector3(0.0, 7.0, 14.0)
var _shake_time := 0.0
var _shake_strength := 0.0
var _floor_reapply_frames := 0
var _earth_wave_hint_stage := 0
var _earth_symbols_root: Node3D = null
var _earth_boss_arena_root: Node3D = null
var _earth_boss_heart_mesh: MeshInstance3D = null
var _earth_boss_heart_material: StandardMaterial3D = null
var _earth_boss_heart_base_color := Color(0.62, 0.5, 0.32)
var _earth_boss_heart_glow_tween: Tween = null
var _earth_boss_ring_materials: Array[StandardMaterial3D] = []
var _earth_boss_ring_base_colors: Array[Color] = []
var _earth_boss_ring_glow_tween: Tween = null
var _earth_shrine_rune_materials: Array[StandardMaterial3D] = []
var _earth_shrine_rune_base_colors: Array[Color] = []
var _earth_shrine_rune_glow_tween: Tween = null
var _earth_shrine_idle_time := 0.0
var _earth_boss_accent_light: OmniLight3D = null
var _earth_boss_accent_light_tween: Tween = null
var _earth_stage_light_tween: Tween = null
var _earth_stone_preview_materials: Array[StandardMaterial3D] = []
var _earth_tablet: Node3D = null
var _earth_waystone: Node3D = null
var _earth_story_choice_active := false
var _earth_story_pending_choices: Array = []
var _earth_story_started := false
var _earth_second_story_active := false
var _earth_second_story_completed := false
var _earth_story_completed := false
var _earth_tablet_prompt_visible := false
@export var terrain_enabled := true
@export var terrain_size_override := 0.0
@export var terrain_grid := 120
@export var terrain_height_amp := 3.0
@export var terrain_height_freq := 0.025
@export var terrain_height_octaves := 4
@export var terrain_height_gain := 0.5
@export var terrain_height_lacunarity := 2.0
@export var terrain_flat_center := true
@export var terrain_flat_radius := 18.0
@export var terrain_edge_transition := 8.0
@export var terrain_edge_height_scale := 0.3
@export var floor_use_ao := false
@export var floor_use_pbr := true
@export var floor_force_unshaded := false
var _terrain_noise: FastNoiseLite = null
var _floor_texture_paths := {
	"albedo": "res://assets/polyhaven_textures/aerial_grass_rock/aerial_grass_rock_diff_1k.jpg",
	"normal": "res://assets/polyhaven_textures/aerial_grass_rock/aerial_grass_rock_nor_gl_1k.jpg",
	"arm": "res://assets/polyhaven_textures/aerial_grass_rock/aerial_grass_rock_arm_1k.jpg"
}
const EARTH_SLICE_REGION := "earth"
const EARTH_SLICE_STAGE := "earth_intro_path"
const EARTH_STONE_ALBEDO_PATH := "res://assets/polyhaven_textures/aerial_grass_rock/aerial_grass_rock_diff_1k.jpg"
const EARTH_STONE_NORMAL_PATH := "res://assets/polyhaven_textures/aerial_grass_rock/aerial_grass_rock_nor_gl_1k.jpg"
const EARTH_STONE_ARM_PATH := "res://assets/polyhaven_textures/aerial_grass_rock/aerial_grass_rock_arm_1k.jpg"
var _theme_data := {
	"fire": {
		"layer": "underground",
		"floor": Color(0.32, 0.16, 0.12),
		"wall": Color(0.25, 0.12, 0.1),
		"sky_top": Color(0.35, 0.17, 0.2),
		"sky_horizon": Color(0.65, 0.3, 0.2),
		"ground_bottom": Color(0.08, 0.05, 0.05),
		"ground_horizon": Color(0.2, 0.1, 0.12),
		"ambient_energy": 1.0,
		"sun_color": Color(1.0, 0.6, 0.4),
		"sun_energy": 0.6,
		"dir_energy": 2.2,
		"transition": Color(0.55, 0.1, 0.1)
	},
	"wood": {
		"layer": "surface",
		"floor": Color(0.16, 0.28, 0.16),
		"wall": Color(0.12, 0.22, 0.12),
		"sky_top": Color(0.35, 0.55, 0.85),
		"sky_horizon": Color(0.7, 0.85, 0.95),
		"ground_bottom": Color(0.12, 0.2, 0.14),
		"ground_horizon": Color(0.3, 0.45, 0.3),
		"ambient_energy": 1.5,
		"sun_color": Color(1.0, 0.95, 0.85),
		"sun_energy": 0.75,
		"dir_energy": 2.4,
		"transition": Color(0.2, 0.45, 0.2)
	},
	"metal": {
		"layer": "surface",
		"floor": Color(0.25, 0.25, 0.28),
		"wall": Color(0.2, 0.2, 0.25),
		"sky_top": Color(0.4, 0.48, 0.6),
		"sky_horizon": Color(0.7, 0.75, 0.85),
		"ground_bottom": Color(0.12, 0.12, 0.16),
		"ground_horizon": Color(0.25, 0.27, 0.32),
		"ambient_energy": 1.3,
		"sun_color": Color(0.9, 0.95, 1.0),
		"sun_energy": 0.65,
		"dir_energy": 2.1,
		"transition": Color(0.35, 0.4, 0.5)
	},
	"earth": {
		"layer": "surface",
		"floor": Color(0.32, 0.24, 0.16),
		"wall": Color(0.26, 0.2, 0.14),
		"sky_top": Color(0.45, 0.5, 0.6),
		"sky_horizon": Color(0.75, 0.75, 0.8),
		"ground_bottom": Color(0.18, 0.12, 0.08),
		"ground_horizon": Color(0.4, 0.3, 0.2),
		"ambient_energy": 1.35,
		"sun_color": Color(1.0, 0.92, 0.8),
		"sun_energy": 0.7,
		"dir_energy": 2.3,
		"transition": Color(0.4, 0.3, 0.2)
	},
	"water": {
		"layer": "sky",
		"floor": Color(0.12, 0.18, 0.28),
		"wall": Color(0.1, 0.14, 0.22),
		"sky_top": Color(0.25, 0.4, 0.7),
		"sky_horizon": Color(0.55, 0.75, 0.95),
		"ground_bottom": Color(0.05, 0.08, 0.12),
		"ground_horizon": Color(0.2, 0.3, 0.4),
		"ambient_energy": 1.4,
		"sun_color": Color(0.8, 0.9, 1.0),
		"sun_energy": 0.6,
		"dir_energy": 2.0,
		"transition": Color(0.2, 0.35, 0.6)
	}
}

func _ready() -> void:
	_ensure_input_map()
	_apply_floor_textures()
	_apply_magic_post()
	if terrain_enabled:
		_setup_terrain_noise()
		_build_terrain_mesh()
		if player:
			var offset := 0.6
			if player.has_method("get_floor_offset"):
				offset = float(player.call("get_floor_offset"))
			player.global_position.y = get_terrain_height_at(player.global_position.x, player.global_position.z) + offset
	# 2.5D look: orthographic camera with a 45-degree-ish angle.
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 60.0
	_update_camera()
	cam.current = true
	if combat_manager:
		combat_manager.connect("clash_window_ended", Callable(self, "_on_clash_window_ended"))
	if level_manager:
		if level_manager.has_signal("wave_started"):
			level_manager.connect("wave_started", Callable(self, "_on_wave_started"))
		if level_manager.has_signal("wave_progress"):
			level_manager.connect("wave_progress", Callable(self, "_on_wave_progress"))
		if level_manager.has_signal("elite_started"):
			level_manager.connect("elite_started", Callable(self, "_on_elite_started"))
		if level_manager.has_signal("boss_started"):
			level_manager.connect("boss_started", Callable(self, "_on_boss_started"))
	if run_manager and run_manager.has_signal("run_state_changed"):
		run_manager.connect("run_state_changed", Callable(self, "_on_run_state_changed"))
	_set_theme_visibility("surface")
	_begin_earth_vertical_slice()

func _process(_delta: float) -> void:
	if not player:
		return
	_update_camera()
	_update_earth_story_prompt()
	_update_earth_shrine_idle_glow(_delta)
	if omni:
		omni.global_position = cam.global_position
	if _floor_reapply_frames > 0:
		_floor_reapply_frames -= 1
		_apply_floor_textures()

func _input(event: InputEvent) -> void:
	if _earth_story_choice_active:
		if Input.is_action_just_pressed("skill_1"):
			_select_earth_story_choice(0)
			get_viewport().set_input_as_handled()
			return
		elif Input.is_action_just_pressed("skill_2"):
			_select_earth_story_choice(1)
			get_viewport().set_input_as_handled()
			return
		elif Input.is_action_just_pressed("skill_3"):
			_select_earth_story_choice(2)
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed("interact") and _can_start_earth_story_event():
		_open_earth_story_choices()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var btn := event as InputEventMouseButton
		if btn.button_index == MOUSE_BUTTON_RIGHT:
			_rotating = btn.pressed and not side_scroll_camera
		if not side_scroll_camera and btn.pressed and btn.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clamp(_distance - zoom_step, zoom_min, zoom_max)
		elif not side_scroll_camera and btn.pressed and btn.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clamp(_distance + zoom_step, zoom_min, zoom_max)
	if event is InputEventMouseMotion and _rotating and not side_scroll_camera:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * _mouse_sense
		_pitch = clamp(_pitch - motion.relative.y * _mouse_sense, -70.0, -10.0)
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == Key.KEY_F3:
				side_scroll_camera = not side_scroll_camera
				if player and player.has_method("set"):
					player.set("side_scroll_mode", side_scroll_camera)
				if side_scroll_camera and player and player is Node3D:
					var p := player as Node3D
					p.global_position.z = 0.0
			elif key_event.keycode == Key.KEY_F5:
				if run_manager and run_manager.has_method("start_run"):
					run_manager.call("start_run")
			elif key_event.keycode == Key.KEY_F6:
				if level_manager and level_manager.has_method("start_boss"):
					level_manager.call("start_boss")

func _update_camera() -> void:
	if not player:
		return
	if side_scroll_camera:
		var shake := Vector3.ZERO
		if _shake_time > 0.0:
			_shake_time -= get_process_delta_time()
			shake = Vector3(
				randf_range(-_shake_strength, _shake_strength),
				randf_range(-_shake_strength, _shake_strength),
				randf_range(-_shake_strength, _shake_strength)
			)
		cam.position = player.global_position + side_camera_offset + shake
		cam.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		return
	var basis := Basis(Vector3.UP, deg_to_rad(_yaw))
	var pitch_rot := Basis(Vector3.RIGHT, deg_to_rad(_pitch))
	var dir: Vector3 = (basis * pitch_rot) * Vector3(0, 0, 1)
	dir = dir.normalized()
	var shake := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= get_process_delta_time()
		shake = Vector3(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
	cam.position = player.global_position + dir * _distance + Vector3(0, 1.5, 0) + shake
	cam.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)

func _setup_terrain_noise() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = int(Time.get_unix_time_from_system())
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = terrain_height_freq
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = int(terrain_height_octaves)
	noise.fractal_gain = terrain_height_gain
	noise.fractal_lacunarity = terrain_height_lacunarity
	_terrain_noise = noise

func _build_terrain_mesh() -> void:
	if floor == null or floor.mesh == null:
		return
	var size_x: float = 80.0
	var size_z: float = 80.0
	if floor.mesh is PlaneMesh:
		var plane: PlaneMesh = floor.mesh as PlaneMesh
		size_x = plane.size.x
		size_z = plane.size.y
	if terrain_size_override > 0.0:
		size_x = terrain_size_override
		size_z = terrain_size_override
	var grid: int = int(max(8, terrain_grid))
	var step_x: float = size_x / float(grid)
	var step_z: float = size_z / float(grid)
	var half_x: float = size_x * 0.5
	var half_z: float = size_z * 0.5
	var verts_w: int = grid + 1
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(verts_w * verts_w)
	for z in range(verts_w):
		for x in range(verts_w):
			var wx: float = lerp(-half_x, half_x, float(x) / float(grid))
			var wz: float = lerp(-half_z, half_z, float(z) / float(grid))
			heights[x + z * verts_w] = _sample_height(wx, wz)
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(verts_w * verts_w)
	for z in range(verts_w):
		for x in range(verts_w):
			var h_l: float = heights[max(x - 1, 0) + z * verts_w]
			var h_r: float = heights[min(x + 1, grid) + z * verts_w]
			var h_d: float = heights[x + max(z - 1, 0) * verts_w]
			var h_u: float = heights[x + min(z + 1, grid) * verts_w]
			var dx: float = (h_r - h_l) / max(step_x * 2.0, 0.001)
			var dz: float = (h_u - h_d) / max(step_z * 2.0, 0.001)
			var n: Vector3 = Vector3(-dx, 1.0, -dz).normalized()
			normals[x + z * verts_w] = n
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(grid):
		for x in range(grid):
			var x0: int = x
			var x1: int = x + 1
			var z0: int = z
			var z1: int = z + 1
			var i00: int = x0 + z0 * verts_w
			var i10: int = x1 + z0 * verts_w
			var i01: int = x0 + z1 * verts_w
			var i11: int = x1 + z1 * verts_w
			var wx0: float = lerp(-half_x, half_x, float(x0) / float(grid))
			var wx1: float = lerp(-half_x, half_x, float(x1) / float(grid))
			var wz0: float = lerp(-half_z, half_z, float(z0) / float(grid))
			var wz1: float = lerp(-half_z, half_z, float(z1) / float(grid))
			var uv00: Vector2 = Vector2(float(x0) / float(grid), float(z0) / float(grid))
			var uv10: Vector2 = Vector2(float(x1) / float(grid), float(z0) / float(grid))
			var uv01: Vector2 = Vector2(float(x0) / float(grid), float(z1) / float(grid))
			var uv11: Vector2 = Vector2(float(x1) / float(grid), float(z1) / float(grid))
			# Triangle 1 (counter-clockwise)
			st.set_normal(normals[i00])
			st.set_uv(uv00)
			st.add_vertex(Vector3(wx0, heights[i00], wz0))
			st.set_normal(normals[i10])
			st.set_uv(uv10)
			st.add_vertex(Vector3(wx1, heights[i10], wz0))
			st.set_normal(normals[i11])
			st.set_uv(uv11)
			st.add_vertex(Vector3(wx1, heights[i11], wz1))
			# Triangle 2 (counter-clockwise)
			st.set_normal(normals[i00])
			st.set_uv(uv00)
			st.add_vertex(Vector3(wx0, heights[i00], wz0))
			st.set_normal(normals[i11])
			st.set_uv(uv11)
			st.add_vertex(Vector3(wx1, heights[i11], wz1))
			st.set_normal(normals[i01])
			st.set_uv(uv01)
			st.add_vertex(Vector3(wx0, heights[i01], wz1))
	st.generate_tangents()
	var mesh: ArrayMesh = st.commit() as ArrayMesh
	if mesh != null:
		floor.mesh = mesh
		if floor_body and floor_collider:
			floor_body.position = Vector3.ZERO
			floor_collider.shape = mesh.create_trimesh_shape()

func _sample_height(x: float, z: float) -> float:
	if _terrain_noise == null:
		return 0.0
	var n: float = _terrain_noise.get_noise_2d(x, z)
	var height: float = n * terrain_height_amp
	if not terrain_flat_center:
		return height
	var dist: float = Vector2(x, z).length()
	if dist <= terrain_flat_radius:
		return 0.0
	var transition: float = max(terrain_edge_transition, 0.001)
	var edge_weight: float = smoothstep(terrain_flat_radius, terrain_flat_radius + transition, dist)
	return height * edge_weight * terrain_edge_height_scale

func get_terrain_height_at(x: float, z: float) -> float:
	if not terrain_enabled:
		return 0.0
	return _sample_height(x, z)

func _on_clash_window_ended(_actor: Node, success: bool) -> void:
	_shake_time = 0.15 if success else 0.1
	_shake_strength = 0.18 if success else 0.1
	if success:
		_trigger_boss_break()

func _ensure_input_map() -> void:
	_add_action_if_missing("move_left", [Key.KEY_A, Key.KEY_LEFT])
	_add_action_if_missing("move_right", [Key.KEY_D, Key.KEY_RIGHT])
	_add_action_if_missing("move_up", [Key.KEY_W, Key.KEY_UP])
	_add_action_if_missing("move_down", [Key.KEY_S, Key.KEY_DOWN])
	_add_action_if_missing("attack_light", [], [MOUSE_BUTTON_LEFT])
	_add_action_if_missing("attack_heavy", [], [MOUSE_BUTTON_RIGHT])
	_add_action_if_missing("dodge", [Key.KEY_SPACE])
	_add_action_if_missing("parry", [Key.KEY_F])
	_add_action_if_missing("jump", [Key.KEY_J])
	_add_action_if_missing("skill_1", [Key.KEY_1])
	_add_action_if_missing("skill_2", [Key.KEY_2])
	_add_action_if_missing("skill_3", [Key.KEY_3])
	_add_action_if_missing("weapon_1", [Key.KEY_4])
	_add_action_if_missing("weapon_2", [Key.KEY_5])
	_add_action_if_missing("weapon_3", [Key.KEY_6])
	_add_action_if_missing("interact", [Key.KEY_E])
	_add_key_to_action("move_left", Key.KEY_A)
	_add_key_to_action("move_left", Key.KEY_LEFT)
	_add_key_to_action("move_right", Key.KEY_D)
	_add_key_to_action("move_right", Key.KEY_RIGHT)
	_add_key_to_action("move_up", Key.KEY_W)
	_add_key_to_action("move_up", Key.KEY_UP)
	_add_key_to_action("move_down", Key.KEY_S)
	_add_key_to_action("move_down", Key.KEY_DOWN)
	_add_key_to_action("skill_1", Key.KEY_1)
	_add_key_to_action("skill_2", Key.KEY_2)
	_add_key_to_action("skill_3", Key.KEY_3)
	_add_key_to_action("skill_1", Key.KEY_KP_1)
	_add_key_to_action("skill_2", Key.KEY_KP_2)
	_add_key_to_action("skill_3", Key.KEY_KP_3)

func apply_region_theme(region_id: String) -> Color:
	var data: Dictionary = _theme_data.get(region_id, {})
	var layer := String(data.get("layer", "surface"))
	_set_theme_visibility(layer)
	_apply_floor_color(data.get("floor", Color(0.22, 0.24, 0.18)))
	_apply_floor_textures()
	_floor_reapply_frames = 20
	_apply_wall_color(data.get("wall", data.get("floor", Color(0.22, 0.24, 0.18))))
	if dir_light:
		dir_light.light_color = data.get("sun_color", Color(1, 1, 1))
		dir_light.light_energy = float(data.get("dir_energy", 2.0)) * 1.6
		dir_light.shadow_opacity = 0.62
		dir_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		env.ambient_light_color = Color(1, 1, 1, 1)
		env.ambient_light_energy = max(2.8, float(data.get("ambient_energy", 1.4)) * 1.6)
		_set_env_property(env, "ambient_light_sky_contribution", 1.0)
		_set_env_property(env, "fog_enabled", true)
		_set_env_property(env, "fog_light_color", Color(0.74, 0.66, 0.56, 1.0))
		_set_env_property(env, "fog_light_energy", 0.45)
		_set_env_property(env, "fog_density", 0.0055)
		if env.sky and env.sky.sky_material and env.sky.sky_material is ProceduralSkyMaterial:
			var sky := env.sky.sky_material as ProceduralSkyMaterial
			sky.sky_top_color = data.get("sky_top", Color(0.4, 0.6, 0.8))
			sky.sky_horizon_color = data.get("sky_horizon", Color(0.7, 0.8, 0.9))
			sky.ground_bottom_color = data.get("ground_bottom", Color(0.1, 0.12, 0.16))
			sky.ground_horizon_color = data.get("ground_horizon", Color(0.25, 0.28, 0.32))
	if omni:
		omni.light_energy = 2.6
		omni.light_color = Color(0.98, 0.9, 0.8, 1.0)
		omni.omni_range = 24.0
	if fill_light:
		fill_light.light_energy = 2.1
		fill_light.light_color = Color(0.78, 0.72, 0.68, 1.0)
		fill_light.omni_range = 32.0
	return data.get("transition", Color(0, 0, 0))

func apply_stage_layout(stage_id: String, region_id: String) -> void:
	if terrain and terrain.has_method("build_layout"):
		terrain.call("build_layout", stage_id, region_id)

func _begin_earth_vertical_slice() -> void:
	if _is_quit_boot():
		return
	var transition_color := apply_region_theme(EARTH_SLICE_REGION)
	apply_stage_layout(EARTH_SLICE_STAGE, EARTH_SLICE_REGION)
	_setup_earth_symbols()
	_apply_earth_intro_lighting()
	_setup_ming_intro()
	if player and player.has_method("set_element_state"):
		player.call("set_element_state", "Earth", 1)
	if hud and hud.has_method("play_transition"):
		hud.call("play_transition", transition_color, 1.0)
	_run_earth_intro()

func _run_earth_intro() -> void:
	if hud == null:
		_start_vertical_slice_run()
		return
	hud.call("show_stage_start", "Earth Nation\nThe road remembers every burden.")
	await get_tree().create_timer(1.5).timeout
	hud.call("show_stage_start", "Old terraces. Wind-worn stone. A path that climbs slowly.")
	await get_tree().create_timer(1.6).timeout
	hud.call("show_stage_start", "Ming: 土不争先，但记得所有重量。")
	await get_tree().create_timer(1.8).timeout
	if ming and ming.has_method("set_intro_active"):
		ming.call("set_intro_active", true)
	_start_vertical_slice_run()

func _start_vertical_slice_run() -> void:
	_earth_wave_hint_stage = 0
	if _earth_story_completed:
		if run_manager and run_manager.has_method("start_run"):
			run_manager.call("start_run")
		return
	_earth_story_started = true
	_earth_second_story_active = false
	_earth_second_story_completed = false
	if hud and hud.has_method("show_story_prompt"):
		hud.call("show_story_prompt", "Stone Tablet\n靠近残碑，按 E 聆听它留下的重量。")

func _setup_ming_intro() -> void:
	if ming == null:
		return
	if ming.has_method("set_focus_target") and player and player is Node3D:
		ming.call("set_focus_target", player)
	var base_position := Vector3(-4.2, get_terrain_height_at(-4.2, 5.8) + 0.2, 5.8)
	if ming.has_method("set_anchor_position"):
		ming.call("set_anchor_position", base_position)
	if ming.has_method("set_intro_active"):
		ming.call("set_intro_active", true)

func _on_wave_started(wave_index: int, label: String, _target_kills: int) -> void:
	if hud == null:
		return
	_set_earth_boss_arena_active(false)
	_apply_earth_intro_lighting()
	if wave_index == 0:
		_earth_wave_hint_stage = 1
		hud.call("show_stage_start", "%s\nMing: 先接招，再反手。按 F 抢住重心。" % label)
	elif wave_index == 1:
		hud.call("show_stage_start", "%s\nMing: 土稳住你，水帮你挪位，火替你收尾。" % label)

func _on_wave_progress(wave_index: int, kills: int, _target_kills: int) -> void:
	if hud == null or wave_index != 0:
		return
	if kills >= 1 and _earth_wave_hint_stage == 1:
		_earth_wave_hint_stage = 2
		hud.call("show_stage_start", "Ming: 看到没？Guard 先替你接下第一口伤。")
	elif kills >= 3 and _earth_wave_hint_stage == 2:
		_earth_wave_hint_stage = 3
		hud.call("show_stage_start", "Ming: 别贪第三下，留气等他先乱。")

func _on_elite_started(_label: String) -> void:
	_set_earth_boss_arena_active(false)
	_apply_earth_intro_lighting()
	if hud and hud.has_method("show_stage_start"):
		hud.call("show_stage_start", "Ming: 冲阵最怕你急。等他撞空，你再把势打回去。")

func _on_boss_started(_boss: Node) -> void:
	_set_earth_boss_arena_active(true)
	_apply_earth_boss_zone_lighting()
	_reset_earth_boss_heart_glow()
	if ming and ming.has_method("set_intro_active"):
		ming.call("set_intro_active", false)
	if _boss and _boss.has_signal("burden_exposed"):
		if not _boss.is_connected("burden_exposed", Callable(self, "_on_boss_burden_exposed")):
			_boss.connect("burden_exposed", Callable(self, "_on_boss_burden_exposed"))
	_show_boss_memory_echoes()

func _show_boss_memory_echoes() -> void:
	if hud == null or not hud.has_method("show_stage_start"):
		return
	var blessing_ids := _get_story_blessing_ids()
	hud.call("show_stage_start", "Keeper of the Burden\n%s" % _get_keeper_memory_echo(blessing_ids))
	var ming_echo := _get_ming_memory_echo(blessing_ids)
	if ming_echo == "":
		return
	await get_tree().create_timer(1.8).timeout
	if hud and hud.has_method("show_stage_start"):
		hud.call("show_stage_start", ming_echo)

func _get_story_blessing_ids() -> Array[String]:
	var ids: Array[String] = []
	if player == null or not player.has_method("get_build_state"):
		return ids
	var build_state: Dictionary = player.call("get_build_state")
	var blessings: Array = build_state.get("story_blessings", [])
	for blessing_var in blessings:
		if not (blessing_var is Dictionary):
			continue
		var blessing: Dictionary = blessing_var
		var blessing_id := String(blessing.get("id", ""))
		if blessing_id != "":
			ids.append(blessing_id)
	return ids

func _get_keeper_memory_echo(blessing_ids: Array[String]) -> String:
	if blessing_ids.has("tablet_burden_vow"):
		return "You straightened an old burden. Now show me what your shoulders can keep."
	if blessing_ids.has("tablet_seed_crack"):
		return "You left breath inside the stone. Keep breathing when the mountain leans back."
	if blessing_ids.has("tablet_name_ash"):
		return "You remembered the nameless. Then remember this weight when it strikes."
	return "Break the rush, and the stone heart opens."

func _get_ming_memory_echo(blessing_ids: Array[String]) -> String:
	if blessing_ids.has("cairn_shared_load"):
		return "Ming: 你替后来的人垒稳了路，现在先把眼前这座山接住。"
	if blessing_ids.has("cairn_breath_between"):
		return "Ming: 你给石缝留了气，这会儿别慌，把自己的气也留住。"
	if blessing_ids.has("cairn_mark_the_way"):
		return "Ming: 你替别人指了路，现在就顺着那条路，把它的破绽看出来。"
	return "Ming: 记住前面停下来的那一刻，别被它第一下重势带走。"

func _on_run_state_changed(state_name: String) -> void:
	if hud == null:
		return
	match state_name:
		"ELITE":
			_set_earth_boss_arena_active(false)
			_apply_earth_intro_lighting()
			if hud.has_method("show_stage_start"):
				hud.call("show_stage_start", "Ming: 接得住这阵沙，才接得住后面的山。")
		"PREPARE":
			_set_earth_boss_arena_active(false)
			_apply_earth_intro_lighting()
			if ming and ming.has_method("set_intro_active"):
				ming.call("set_intro_active", true)
		"RESULT":
			_set_earth_boss_arena_active(true)
			_apply_earth_boss_zone_lighting()
			if ming and ming.has_method("set_intro_active"):
				ming.call("set_intro_active", true)

func _apply_earth_intro_lighting() -> void:
	if _earth_stage_light_tween:
		_earth_stage_light_tween.kill()
	_earth_stage_light_tween = create_tween()
	if dir_light:
		dir_light.light_color = Color(1.0, 0.9, 0.78, 1.0)
		_earth_stage_light_tween.parallel().tween_property(dir_light, "light_energy", 3.75, 0.45)
		_earth_stage_light_tween.parallel().tween_property(dir_light, "rotation_degrees", Vector3(-45.0, -24.0, 0.0), 0.45)
	if omni:
		omni.light_color = Color(1.0, 0.88, 0.74, 1.0)
		_earth_stage_light_tween.parallel().tween_property(omni, "light_energy", 2.8, 0.45)
	if fill_light:
		fill_light.light_color = Color(0.86, 0.76, 0.66, 1.0)
		_earth_stage_light_tween.parallel().tween_property(fill_light, "light_energy", 2.2, 0.45)
	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		env.ambient_light_energy = 3.15
		_set_env_property(env, "fog_light_color", Color(0.78, 0.68, 0.56, 1.0))
		_set_env_property(env, "fog_density", 0.0042)

func _apply_earth_boss_zone_lighting() -> void:
	if _earth_stage_light_tween:
		_earth_stage_light_tween.kill()
	_earth_stage_light_tween = create_tween()
	if dir_light:
		dir_light.light_color = Color(0.82, 0.84, 0.88, 1.0)
		_earth_stage_light_tween.parallel().tween_property(dir_light, "light_energy", 2.9, 0.55)
		_earth_stage_light_tween.parallel().tween_property(dir_light, "rotation_degrees", Vector3(-56.0, -42.0, 0.0), 0.55)
	if omni:
		omni.light_color = Color(0.76, 0.8, 0.88, 1.0)
		_earth_stage_light_tween.parallel().tween_property(omni, "light_energy", 1.7, 0.55)
	if fill_light:
		fill_light.light_color = Color(0.62, 0.68, 0.76, 1.0)
		_earth_stage_light_tween.parallel().tween_property(fill_light, "light_energy", 1.55, 0.55)
	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		env.ambient_light_energy = 2.55
		_set_env_property(env, "fog_light_color", Color(0.54, 0.58, 0.64, 1.0))
		_set_env_property(env, "fog_density", 0.0072)

func _is_quit_boot() -> bool:
	for arg_var in OS.get_cmdline_args():
		var arg_text: String = String(arg_var)
		if arg_text == "--quit":
			return true
	return false

func _trigger_boss_break() -> void:
	if level_manager == null or not level_manager.has_method("get_active_boss"):
		return
	var boss: Node = level_manager.call("get_active_boss")
	if boss and boss.has_method("register_break_event"):
		boss.call("register_break_event", "guard_counter")

func _on_boss_burden_exposed(_duration: float, reason: String) -> void:
	if hud == null or not hud.has_method("show_boss_exposed"):
		return
	_pulse_earth_boss_heart(_duration)
	var text := "石心外露——现在反打。"
	match reason:
		"guard":
			text = "你接住了它的重势——石心外露。"
		"resonance":
			text = "共振震开了外壳——快压上去。"
		_:
			text = "它撞空了——石心外露。"
	hud.call("show_boss_exposed", text)

func _setup_earth_symbols() -> void:
	if surface_set == null:
		return
	if _earth_symbols_root and is_instance_valid(_earth_symbols_root):
		_earth_symbols_root.queue_free()
	_earth_symbols_root = Node3D.new()
	_earth_symbols_root.name = "EarthSymbols"
	surface_set.add_child(_earth_symbols_root)
	var intro_mass_dark := Color(0.36, 0.28, 0.19)
	var intro_mass_mid := Color(0.41, 0.32, 0.22)
	var intro_dust := Color(0.4, 0.31, 0.21)
	var intro_dust_dark := Color(0.34, 0.26, 0.18)
	var intro_slab_main := Color(0.56, 0.44, 0.3)
	var intro_slab_warm := Color(0.6, 0.48, 0.32)
	var intro_slab_soft := Color(0.5, 0.39, 0.27)
	_create_stone_mass(Vector3(-10.8, 0.0, 4.8), Vector3(4.8, 3.2, 6.8), intro_mass_dark)
	_create_stone_mass(Vector3(-10.4, 0.0, 11.4), Vector3(3.8, 2.8, 5.6), intro_mass_mid)
	_create_stone_mass(Vector3(10.8, 0.0, 9.8), Vector3(4.6, 3.0, 7.2), intro_mass_dark)
	_create_stone_mass(Vector3(9.8, 0.0, 16.8), Vector3(4.2, 3.4, 5.8), intro_mass_mid)
	_create_dust_band(Vector3(-5.2, 0.0, 5.8), Vector3(6.4, 0.018, 4.9), intro_dust)
	_create_dust_band(Vector3(-2.2, 0.0, 8.8), Vector3(5.4, 0.018, 4.1), intro_dust)
	_create_dust_band(Vector3(1.1, 0.0, 12.1), Vector3(4.8, 0.018, 3.7), intro_dust)
	_create_dust_band(Vector3(4.7, 0.0, 15.0), Vector3(5.9, 0.018, 4.2), intro_dust_dark)
	_create_dust_band(Vector3(1.1, 0.0, 18.0), Vector3(8.7, 0.02, 3.8), Color(0.31, 0.24, 0.17))
	_create_dust_band(Vector3(-7.6, 0.0, 5.9), Vector3(1.9, 0.014, 3.9), intro_dust_dark)
	_create_dust_band(Vector3(7.2, 0.0, 15.4), Vector3(2.1, 0.014, 4.1), intro_dust_dark)
	_create_ground_slab(Vector3(-5.8, 0.0, 5.6), Vector3(5.6, 0.08, 5.4), intro_slab_main)
	_create_ground_slab(Vector3(-2.6, 0.0, 8.7), Vector3(4.6, 0.08, 3.8), intro_slab_warm)
	_create_ground_slab(Vector3(0.9, 0.0, 11.9), Vector3(3.8, 0.08, 3.2), intro_slab_warm)
	_create_ground_slab(Vector3(4.6, 0.0, 14.7), Vector3(5.4, 0.08, 3.8), intro_slab_main)
	_create_ground_slab(Vector3(1.1, 0.0, 18.0), Vector3(8.0, 0.08, 3.4), intro_slab_soft)
	_create_broken_wall_cluster(Vector3(-8.6, 0.0, 7.8), Vector3(2.8, 2.2, 0.9), Color(0.36, 0.28, 0.2), true)
	_create_broken_wall_cluster(Vector3(-7.2, 0.0, 12.3), Vector3(2.1, 1.7, 0.8), Color(0.35, 0.27, 0.19), true)
	_create_broken_wall_cluster(Vector3(8.1, 0.0, 11.6), Vector3(2.3, 1.8, 0.8), Color(0.35, 0.27, 0.19), false)
	_create_broken_wall_cluster(Vector3(8.9, 0.0, 16.9), Vector3(3.0, 2.4, 0.95), Color(0.34, 0.26, 0.18), false)
	_create_side_platform(Vector3(-9.9, 0.0, 9.1), Vector3(2.8, 0.32, 3.8), Color(0.37, 0.29, 0.21))
	_create_side_platform(Vector3(9.6, 0.0, 14.1), Vector3(3.0, 0.34, 4.0), Color(0.37, 0.29, 0.21))
	_create_rubble_strip(Vector3(-8.8, 0.0, 6.6), 6, Vector3(0.95, 0.18, 0.7), Vector3(0.95, 0.0, 1.18), Color(0.36, 0.28, 0.2), true)
	_create_rubble_strip(Vector3(-7.4, 0.0, 11.2), 5, Vector3(0.82, 0.16, 0.62), Vector3(0.9, 0.0, 1.05), Color(0.35, 0.27, 0.19), true)
	_create_rubble_strip(Vector3(7.9, 0.0, 10.8), 5, Vector3(0.82, 0.16, 0.62), Vector3(0.92, 0.0, 1.04), Color(0.35, 0.27, 0.19), false)
	_create_rubble_strip(Vector3(9.1, 0.0, 16.1), 6, Vector3(1.0, 0.18, 0.72), Vector3(0.98, 0.0, 1.12), Color(0.34, 0.26, 0.18), false)
	_create_scattered_slabs(Vector3(-4.6, 0.0, 7.4), 4, Vector3(0.78, 0.08, 0.52), Color(0.43, 0.34, 0.23))
	_create_scattered_slabs(Vector3(4.9, 0.0, 14.2), 5, Vector3(0.72, 0.08, 0.48), Color(0.41, 0.32, 0.22))
	_create_path_edge_band(Vector3(-9.0, 0.0, 7.2), 10.6, 0.75, Color(0.5, 0.39, 0.26))
	_create_path_edge_band(Vector3(8.2, 0.0, 13.5), 10.2, 0.75, Color(0.5, 0.39, 0.26))
	_create_path_edge_band(Vector3(-2.5, 0.0, 17.8), 3.2, 0.62, Color(0.54, 0.42, 0.28))
	_create_path_edge_band(Vector3(4.7, 0.0, 17.8), 3.2, 0.62, Color(0.54, 0.42, 0.28))
	_create_path_footprints(Vector3(-5.9, 0.0, 5.4), Vector3(1.1, 0.0, 1.28), 5, Color(0.35, 0.28, 0.2))
	_create_path_footprints(Vector3(-2.0, 0.0, 9.7), Vector3(1.08, 0.0, 1.1), 4, Color(0.34, 0.27, 0.19))
	_create_path_footprints(Vector3(1.8, 0.0, 13.2), Vector3(1.0, 0.0, 1.08), 4, Color(0.34, 0.27, 0.19))
	_create_stone_step(Vector3(-7.8, 0.0, 5.6), Vector3(3.8, 0.7, 5.2), Color(0.36, 0.29, 0.2))
	_create_stone_step(Vector3(6.8, 0.0, 15.0), Vector3(4.0, 0.6, 4.6), Color(0.36, 0.28, 0.2))
	_create_stone_step(Vector3(1.1, 0.0, 17.2), Vector3(6.4, 0.46, 1.5), Color(0.5, 0.38, 0.24))
	_create_stone_marker(Vector3(-10.6, 0.0, 4.3), Vector3(1.6, 3.4, 1.4), Color(0.4, 0.31, 0.21))
	_create_stone_marker(Vector3(-6.9, 0.0, 10.6), Vector3(0.9, 1.9, 0.9), Color(0.41, 0.32, 0.22))
	_create_stone_marker(Vector3(7.6, 0.0, 11.9), Vector3(1.0, 2.1, 1.0), Color(0.4, 0.31, 0.21))
	_create_stone_marker(Vector3(10.0, 0.0, 17.3), Vector3(1.8, 2.4, 1.4), Color(0.33, 0.26, 0.18))
	_create_stone_gate(Vector3(1.1, 0.0, 18.0), 6.4, 5.0, 0.9, Color(0.43, 0.33, 0.22))
	_earth_tablet = _create_story_tablet(Vector3(-3.2, 0.0, 9.1), Vector3(1.35, 3.0, 0.62), Color(0.58, 0.46, 0.3))
	_earth_waystone = _create_memory_cairn(Vector3(4.7, 0.0, 15.0), Vector3(1.8, 2.1, 1.8), Color(0.43, 0.34, 0.23))
	_create_story_rune_cluster(Vector3(-3.2, 0.0, 9.1), 2.4, Color(0.56, 0.45, 0.3))
	_create_story_rune_cluster(Vector3(4.7, 0.0, 15.0), 2.0, Color(0.52, 0.41, 0.28))
	_setup_earth_boss_arena()
	_set_earth_boss_arena_active(false)

func _create_stone_marker(pos: Vector3, scale: Vector3, color: Color) -> void:
	if _earth_symbols_root == null:
		return
	var root := Node3D.new()
	root.name = "StoneMarker"
	root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.14, 0.0), Vector3(scale.x * 1.28, scale.y * 0.18, scale.z * 1.2), color.darkened(0.14))
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.56, 0.0), Vector3(scale.x * 0.9, scale.y * 0.74, scale.z * 0.86), color, Vector3(0.0, 6.0, 1.5))
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.97, 0.02), Vector3(scale.x * 0.72, scale.y * 0.18, scale.z * 0.78), color.lightened(0.06), Vector3(-4.0, -8.0, 0.0))
	_earth_symbols_root.add_child(root)

func _create_stone_step(pos: Vector3, scale: Vector3, color: Color) -> void:
	if _earth_symbols_root == null:
		return
	var root := Node3D.new()
	root.name = "StoneStep"
	root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.26, 0.0), Vector3(scale.x * 1.02, scale.y * 0.52, scale.z), color.darkened(0.12))
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.56, 0.0), Vector3(scale.x, scale.y * 0.34, scale.z * 0.94), color)
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.78, -scale.z * 0.08), Vector3(scale.x * 0.82, scale.y * 0.12, scale.z * 0.72), color.lightened(0.05))
	_earth_symbols_root.add_child(root)

func _create_stone_mass(pos: Vector3, scale: Vector3, color: Color) -> void:
	if _earth_symbols_root == null:
		return
	var root := Node3D.new()
	root.name = "StoneMass"
	root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.45, 0.0), Vector3(scale.x, scale.y * 0.9, scale.z), color.darkened(0.08))
	_add_stone_piece(root, Vector3(-scale.x * 0.18, scale.y * 0.88, -scale.z * 0.08), Vector3(scale.x * 0.52, scale.y * 0.32, scale.z * 0.56), color, Vector3(0.0, -8.0, -3.0))
	_add_stone_piece(root, Vector3(scale.x * 0.2, scale.y * 0.95, scale.z * 0.12), Vector3(scale.x * 0.46, scale.y * 0.26, scale.z * 0.48), color.lightened(0.03), Vector3(0.0, 10.0, 2.0))
	_add_stone_piece(root, Vector3(0.0, scale.y * 1.12, 0.0), Vector3(scale.x * 0.62, scale.y * 0.14, scale.z * 0.42), color.lightened(0.08), Vector3(-2.0, 6.0, 0.0))
	_earth_symbols_root.add_child(root)

func _create_side_platform(pos: Vector3, scale: Vector3, color: Color) -> void:
	if _earth_symbols_root == null:
		return
	var root := Node3D.new()
	root.name = "SidePlatform"
	root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.22, 0.0), Vector3(scale.x * 1.04, scale.y * 0.46, scale.z * 1.02), color.darkened(0.16))
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.56, 0.0), Vector3(scale.x, scale.y * 0.38, scale.z), color)
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.8, -scale.z * 0.08), Vector3(scale.x * 0.78, scale.y * 0.12, scale.z * 0.68), color.lightened(0.04))
	_earth_symbols_root.add_child(root)

func _create_broken_wall_cluster(pos: Vector3, scale: Vector3, color: Color, lean_left: bool) -> void:
	if _earth_symbols_root == null:
		return
	var root := Node3D.new()
	root.name = "BrokenWallCluster"
	root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
	var lean_sign := -1.0 if lean_left else 1.0
	_add_stone_piece(root, Vector3(-scale.x * 0.26, scale.y * 0.46, 0.0), Vector3(scale.x * 0.34, scale.y * 0.92, scale.z), color.darkened(0.12), Vector3(0.0, 0.0, 4.0 * lean_sign))
	_add_stone_piece(root, Vector3(scale.x * 0.08, scale.y * 0.38, 0.0), Vector3(scale.x * 0.26, scale.y * 0.76, scale.z * 0.92), color, Vector3(0.0, 0.0, -6.0 * lean_sign))
	_add_stone_piece(root, Vector3(scale.x * 0.34, scale.y * 0.22, 0.0), Vector3(scale.x * 0.18, scale.y * 0.44, scale.z * 0.84), color.lightened(0.03), Vector3(0.0, 0.0, 9.0 * lean_sign))
	_add_stone_piece(root, Vector3(0.0, 0.1, 0.0), Vector3(scale.x * 1.12, 0.18, scale.z * 1.14), color.darkened(0.18))
	_earth_symbols_root.add_child(root)

func _create_dust_band(pos: Vector3, scale: Vector3, color: Color) -> void:
	if _earth_symbols_root == null:
		return
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z) + scale.y * 0.5, pos.z)
	mesh_instance.scale = scale
	var mat := _make_earth_stone_material(color, 3.4)
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.normal_scale = 0.22
	mat.emission_enabled = false
	mesh_instance.material_override = mat
	_earth_stone_preview_materials.append(mat)
	_earth_symbols_root.add_child(mesh_instance)

func _create_rubble_strip(start: Vector3, count: int, piece_scale: Vector3, step: Vector3, color: Color, lean_left: bool) -> void:
	if _earth_symbols_root == null or count <= 0:
		return
	var side_sign := -1.0 if lean_left else 1.0
	for i in range(count):
		var pos := start + step * float(i)
		var root := Node3D.new()
		root.name = "RubblePiece"
		root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
		var yaw := side_sign * (8.0 + float(i % 3) * 6.0)
		_add_stone_piece(root, Vector3(0.0, piece_scale.y * 0.55, 0.0), piece_scale, color.darkened(0.1), Vector3(0.0, yaw, side_sign * 6.0))
		_add_stone_piece(root, Vector3(side_sign * piece_scale.x * 0.18, piece_scale.y * 0.92, -piece_scale.z * 0.08), Vector3(piece_scale.x * 0.46, piece_scale.y * 0.26, piece_scale.z * 0.42), color.lightened(0.04), Vector3(0.0, -yaw * 0.7, -side_sign * 10.0))
		_earth_symbols_root.add_child(root)

func _create_scattered_slabs(center: Vector3, count: int, slab_scale: Vector3, color: Color) -> void:
	if _earth_symbols_root == null or count <= 0:
		return
	for i in range(count):
		var x_offset := -1.4 + float(i) * 0.82
		var z_offset := sin(float(i) * 1.3) * 0.55
		var root := Node3D.new()
		root.name = "ScatteredSlab"
		var px := center.x + x_offset
		var pz := center.z + z_offset
		root.position = Vector3(px, get_terrain_height_at(px, pz), pz)
		_add_stone_piece(root, Vector3(0.0, slab_scale.y * 0.5, 0.0), slab_scale, color.darkened(0.08), Vector3(0.0, -18.0 + float(i) * 9.0, 2.0 - float(i % 2) * 4.0), 2.8)
		_earth_symbols_root.add_child(root)

func _create_story_tablet(pos: Vector3, scale: Vector3, color: Color) -> Node3D:
	if _earth_symbols_root == null:
		return null
	var root := Node3D.new()
	root.name = "StoryTablet"
	root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
	_add_stone_piece(root, Vector3(0.0, 0.26, 0.0), Vector3(scale.x * 1.65, 0.52, scale.z * 2.0), color.darkened(0.18))
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.52, 0.0), Vector3(scale.x, scale.y, scale.z), color)
	_add_stone_piece(root, Vector3(0.0, scale.y * 1.04, 0.0), Vector3(scale.x * 0.78, scale.y * 0.12, scale.z * 0.9), color.lightened(0.05))
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.52, -scale.z * 0.42), Vector3(scale.x * 0.18, scale.y * 0.82, scale.z * 0.35), color.darkened(0.1))
	_earth_symbols_root.add_child(root)
	return root

func _create_memory_cairn(pos: Vector3, scale: Vector3, color: Color) -> Node3D:
	if _earth_symbols_root == null:
		return null
	var root := Node3D.new()
	root.name = "MemoryCairn"
	root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3.ONE
	base.mesh = base_mesh
	base.position = Vector3(0.0, 0.22, 0.0)
	base.scale = Vector3(scale.x * 1.4, 0.44, scale.z * 1.3)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = color.darkened(0.18)
	base_mat.roughness = 1.0
	base.material_override = base_mat
	root.add_child(base)
	for i in range(3):
		var stone := MeshInstance3D.new()
		var stone_mesh := BoxMesh.new()
		stone_mesh.size = Vector3.ONE
		stone.mesh = stone_mesh
		stone.position = Vector3(-0.25 + float(i) * 0.25, 0.55 + float(i) * 0.18, 0.08 * float(i % 2))
		stone.scale = Vector3(scale.x * (0.52 - float(i) * 0.08), scale.y * (0.32 + float(i) * 0.06), scale.z * (0.4 - float(i) * 0.05))
		stone.rotation_degrees = Vector3(0.0, -12.0 + float(i) * 10.0, 4.0 - float(i) * 2.0)
		var stone_mat := StandardMaterial3D.new()
		stone_mat.albedo_color = color.lerp(Color(0.6, 0.52, 0.38), float(i) * 0.16)
		stone_mat.roughness = 1.0
		stone.material_override = stone_mat
		root.add_child(stone)
	_earth_symbols_root.add_child(root)
	return root

func _create_stone_gate(center: Vector3, width: float, height: float, depth: float, color: Color) -> void:
	if _earth_symbols_root == null:
		return
	var root := Node3D.new()
	root.name = "StoneGate"
	root.position = Vector3(center.x, get_terrain_height_at(center.x, center.z), center.z)
	var post_half_gap := width * 0.5
	var post_size := Vector3(0.7, height, depth)
	for side in [-1.0, 1.0]:
		_add_stone_piece(root, Vector3(post_half_gap * side, post_size.y * 0.22, 0.0), Vector3(post_size.x * 1.36, post_size.y * 0.22, post_size.z * 1.18), color.darkened(0.14))
		_add_stone_piece(root, Vector3(post_half_gap * side, post_size.y * 0.58, 0.0), Vector3(post_size.x, post_size.y * 0.72, post_size.z), color.darkened(0.04), Vector3(0.0, side * 3.0, 0.0))
		_add_stone_piece(root, Vector3(post_half_gap * side, post_size.y * 0.97, 0.0), Vector3(post_size.x * 1.12, post_size.y * 0.12, post_size.z * 1.1), color.lightened(0.04))
	_add_stone_piece(root, Vector3(0.0, height - 0.55, 0.0), Vector3(width + 1.4, 0.9, depth + 0.18), color)
	_add_stone_piece(root, Vector3(0.0, height - 1.05, -depth * 0.1), Vector3(width + 0.7, 0.34, depth * 0.68), color.darkened(0.08))
	_add_stone_piece(root, Vector3(0.0, 0.14, 0.0), Vector3(width + 0.9, 0.28, depth + 0.38), color.darkened(0.16))
	_earth_symbols_root.add_child(root)

func _create_ground_slab(pos: Vector3, scale: Vector3, color: Color, parent_node: Node3D = null) -> void:
	var target_parent := parent_node if parent_node != null else _earth_symbols_root
	if target_parent == null:
		return
	var root := Node3D.new()
	root.name = "GroundSlab"
	root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.22, 0.0), Vector3(scale.x * 1.05, max(0.08, scale.y * 0.48), scale.z * 1.04), color.darkened(0.16))
	var top := _add_stone_piece(root, Vector3(0.0, scale.y * 0.54, 0.0), Vector3(scale.x, max(0.04, scale.y * 0.46), scale.z), color, Vector3.ZERO, 1.8)
	if top.material_override is StandardMaterial3D:
		var mat := top.material_override as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = color.darkened(0.75)
		mat.emission_energy_multiplier = 0.0
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.72, -scale.z * 0.06), Vector3(scale.x * 0.82, max(0.03, scale.y * 0.12), scale.z * 0.66), color.lightened(0.05))
	target_parent.add_child(root)
	if target_parent == _earth_boss_arena_root:
		_earth_boss_ring_materials.append(top.material_override as StandardMaterial3D)
		_earth_boss_ring_base_colors.append(color)

func _create_path_edge_band(pos: Vector3, length_z: float, width_x: float, color: Color) -> void:
	_create_ground_slab(pos, Vector3(width_x, 0.06, length_z), color)

func _create_path_footprints(start_pos: Vector3, step: Vector3, count: int, color: Color) -> void:
	if count <= 0:
		return
	for i in range(count):
		var offset := step * float(i)
		var side := -0.34 if i % 2 == 0 else 0.34
		var pos := Vector3(start_pos.x + side, start_pos.y, start_pos.z) + offset
		create_small_footprint(pos, color)

func create_small_footprint(pos: Vector3, color: Color) -> void:
	_create_ground_slab(pos, Vector3(0.32, 0.025, 0.48), color)

func _setup_earth_boss_arena() -> void:
	if _earth_symbols_root == null:
		return
	if _earth_boss_arena_root and is_instance_valid(_earth_boss_arena_root):
		_earth_boss_arena_root.queue_free()
	_earth_boss_ring_materials.clear()
	_earth_boss_ring_base_colors.clear()
	_earth_shrine_rune_materials.clear()
	_earth_shrine_rune_base_colors.clear()
	_earth_boss_arena_root = Node3D.new()
	_earth_boss_arena_root.name = "BossArena"
	_earth_symbols_root.add_child(_earth_boss_arena_root)
	var boss_floor_dark := Color(0.24, 0.2, 0.18)
	var boss_floor_mid := Color(0.29, 0.23, 0.2)
	var boss_wall := Color(0.22, 0.18, 0.17)
	var boss_trim := Color(0.56, 0.47, 0.34)
	var boss_glow := Color(0.72, 0.61, 0.42)
	_create_ground_slab(Vector3(0.0, 0.0, 0.0), Vector3(7.0, 0.08, 7.0), boss_floor_dark, _earth_boss_arena_root)
	_create_ground_slab(Vector3(0.0, 0.0, -5.6), Vector3(4.4, 0.06, 5.2), boss_floor_mid, _earth_boss_arena_root)
	_create_ground_slab(Vector3(0.0, 0.0, 5.2), Vector3(5.0, 0.05, 2.6), boss_floor_mid, _earth_boss_arena_root)
	_create_boss_shrine_backdrop(Vector3(0.0, 0.0, -14.6), boss_wall, boss_trim)
	_create_boss_ground_link(Vector3(0.0, 0.0, -10.6), 9.2, Color(0.34, 0.28, 0.24), boss_glow)
	_create_boss_stone_heart(Vector3(0.0, 0.0, 0.0), Color(0.31, 0.24, 0.2), boss_glow)
	_create_boss_ring_pillar(Vector3(0.0, 0.0, -11.2), Vector3(1.6, 4.4, 1.6), Color(0.28, 0.23, 0.2))
	_create_boss_ring_pillar(Vector3(8.6, 0.0, -7.2), Vector3(1.3, 3.5, 1.3), Color(0.27, 0.22, 0.2))
	_create_boss_ring_pillar(Vector3(-8.6, 0.0, -7.2), Vector3(1.3, 3.5, 1.3), Color(0.27, 0.22, 0.2))
	_create_boss_ring_pillar(Vector3(10.8, 0.0, 3.0), Vector3(1.2, 2.8, 1.2), Color(0.25, 0.2, 0.18))
	_create_boss_ring_pillar(Vector3(-10.8, 0.0, 3.0), Vector3(1.2, 2.8, 1.2), Color(0.25, 0.2, 0.18))
	_create_boss_side_ruin(Vector3(-12.4, 0.0, -1.2), Vector3(3.8, 3.6, 1.2), Color(0.24, 0.2, 0.18), true)
	_create_boss_side_ruin(Vector3(12.4, 0.0, -1.2), Vector3(3.8, 3.6, 1.2), Color(0.24, 0.2, 0.18), false)
	_create_boss_ground_ring(Vector3(0.0, 0.0, 0.0), 8.0, 16, boss_trim)
	_create_boss_ground_ring(Vector3(0.0, 0.0, 0.0), 11.4, 22, Color(0.33, 0.27, 0.24))
	_create_boss_ring_arc(Vector3(0.0, 0.0, 0.0), 11.8, 14, Color(0.4, 0.32, 0.27))

func _set_earth_boss_arena_active(active: bool) -> void:
	if _earth_boss_arena_root and is_instance_valid(_earth_boss_arena_root):
		_earth_boss_arena_root.visible = active

func _create_boss_stone_heart(pos: Vector3, core_color: Color, trim_color: Color) -> void:
	if _earth_boss_arena_root == null:
		return
	_earth_boss_heart_base_color = trim_color
	var root := Node3D.new()
	root.name = "StoneHeart"
	root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.6
	base_mesh.bottom_radius = 2.1
	base_mesh.height = 0.6
	base.mesh = base_mesh
	base.position = Vector3(0.0, 0.3, 0.0)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = core_color.darkened(0.12)
	base_mat.roughness = 1.0
	base.material_override = base_mat
	root.add_child(base)
	var heart := MeshInstance3D.new()
	var heart_mesh := BoxMesh.new()
	heart_mesh.size = Vector3(1.8, 2.4, 1.8)
	heart.mesh = heart_mesh
	heart.position = Vector3(0.0, 1.6, 0.0)
	heart.rotation_degrees = Vector3(8.0, 25.0, 6.0)
	var heart_mat := StandardMaterial3D.new()
	heart_mat.albedo_color = trim_color
	heart_mat.roughness = 0.96
	heart_mat.emission_enabled = true
	heart_mat.emission = trim_color.darkened(0.7)
	heart_mat.emission_energy_multiplier = 0.0
	heart.material_override = heart_mat
	root.add_child(heart)
	_earth_boss_heart_mesh = heart
	_earth_boss_heart_material = heart_mat
	_earth_boss_arena_root.add_child(root)

func _create_boss_shrine_backdrop(center: Vector3, base_color: Color, trim_color: Color) -> void:
	if _earth_boss_arena_root == null:
		return
	var root := Node3D.new()
	root.name = "BossShrineBackdrop"
	root.position = Vector3(center.x, get_terrain_height_at(center.x, center.z), center.z)
	_add_stone_piece(root, Vector3(0.0, 0.45, 0.0), Vector3(9.8, 0.9, 3.2), base_color.darkened(0.12))
	_add_stone_piece(root, Vector3(0.0, 1.55, -0.2), Vector3(8.6, 1.2, 2.6), base_color.darkened(0.06))
	_add_stone_piece(root, Vector3(0.0, 3.8, -0.45), Vector3(7.4, 3.4, 2.2), base_color)
	_add_stone_piece(root, Vector3(-5.35, 3.15, 0.15), Vector3(2.2, 4.8, 2.4), base_color.darkened(0.08), Vector3(0.0, -7.0, 0.0))
	_add_stone_piece(root, Vector3(5.35, 3.15, 0.15), Vector3(2.2, 4.8, 2.4), base_color.darkened(0.08), Vector3(0.0, 7.0, 0.0))
	_add_stone_piece(root, Vector3(-7.8, 2.2, 0.6), Vector3(2.6, 2.8, 2.2), base_color.darkened(0.16), Vector3(0.0, -12.0, 0.0))
	_add_stone_piece(root, Vector3(7.8, 2.2, 0.6), Vector3(2.6, 2.8, 2.2), base_color.darkened(0.16), Vector3(0.0, 12.0, 0.0))
	_add_stone_piece(root, Vector3(0.0, 6.1, -0.35), Vector3(8.8, 0.9, 2.3), trim_color)
	_add_stone_piece(root, Vector3(0.0, 7.05, -0.15), Vector3(5.2, 0.7, 1.9), trim_color.lightened(0.05))
	_add_stone_piece(root, Vector3(0.0, 4.2, 0.82), Vector3(3.1, 4.1, 0.85), trim_color.darkened(0.08))
	_add_stone_piece(root, Vector3(0.0, 4.15, 1.22), Vector3(1.55, 2.8, 0.42), trim_color.lightened(0.08))
	_add_stone_piece(root, Vector3(-2.45, 3.2, 0.62), Vector3(0.78, 2.6, 0.74), trim_color.darkened(0.04))
	_add_stone_piece(root, Vector3(2.45, 3.2, 0.62), Vector3(0.78, 2.6, 0.74), trim_color.darkened(0.04))
	_add_stone_piece(root, Vector3(-3.25, 0.82, 1.1), Vector3(1.9, 0.52, 1.0), base_color.darkened(0.1))
	_add_stone_piece(root, Vector3(3.25, 0.82, 1.1), Vector3(1.9, 0.52, 1.0), base_color.darkened(0.1))
	_add_stone_piece(root, Vector3(0.0, 0.92, 1.22), Vector3(3.4, 0.46, 1.1), base_color)
	_add_shrine_rune_line(root, Vector3(0.0, 4.95, 1.66), Vector3(0.22, 1.9, 0.08), trim_color.lightened(0.18))
	_add_shrine_rune_line(root, Vector3(0.0, 3.78, 1.66), Vector3(1.75, 0.16, 0.08), trim_color.lightened(0.12))
	_add_shrine_rune_line(root, Vector3(-1.12, 2.75, 1.66), Vector3(0.18, 1.12, 0.08), trim_color)
	_add_shrine_rune_line(root, Vector3(1.12, 2.75, 1.66), Vector3(0.18, 1.12, 0.08), trim_color)
	_add_shrine_rune_line(root, Vector3(0.0, 2.18, 1.66), Vector3(2.85, 0.14, 0.08), trim_color.darkened(0.05))
	_add_shrine_rune_line(root, Vector3(-2.08, 3.35, 1.62), Vector3(0.9, 0.12, 0.08), trim_color.darkened(0.02), Vector3(0.0, 0.0, 24.0))
	_add_shrine_rune_line(root, Vector3(2.08, 3.35, 1.62), Vector3(0.9, 0.12, 0.08), trim_color.darkened(0.02), Vector3(0.0, 0.0, -24.0))
	_add_shrine_rune_line(root, Vector3(-1.98, 1.4, 1.58), Vector3(0.78, 0.12, 0.08), trim_color.darkened(0.08), Vector3(0.0, 0.0, -18.0))
	_add_shrine_rune_line(root, Vector3(1.98, 1.4, 1.58), Vector3(0.78, 0.12, 0.08), trim_color.darkened(0.08), Vector3(0.0, 0.0, 18.0))
	var accent := OmniLight3D.new()
	accent.name = "ShrineAccentLight"
	accent.position = Vector3(0.0, 4.4, 2.6)
	accent.light_color = Color(0.95, 0.78, 0.54, 1.0)
	accent.light_energy = 0.0
	accent.omni_range = 22.0
	accent.shadow_enabled = false
	root.add_child(accent)
	_earth_boss_accent_light = accent
	_earth_boss_arena_root.add_child(root)

func _create_boss_ground_link(start: Vector3, length_z: float, base_color: Color, glow_color: Color) -> void:
	if _earth_boss_arena_root == null:
		return
	_create_ground_slab(Vector3(start.x, start.y, start.z + length_z * 0.5), Vector3(1.35, 0.035, length_z), base_color, _earth_boss_arena_root)
	for i in range(4):
		var t: float = float(i) / 3.0
		var z: float = lerp(start.z + 1.1, start.z + length_z - 1.0, t)
		_create_ground_slab(Vector3(-1.55, 0.0, z), Vector3(0.42, 0.03, 0.82), base_color.darkened(0.08), _earth_boss_arena_root)
		_create_ground_slab(Vector3(1.55, 0.0, z), Vector3(0.42, 0.03, 0.82), base_color.darkened(0.08), _earth_boss_arena_root)
	_create_ground_slab(Vector3(0.0, 0.0, start.z + 1.8), Vector3(3.2, 0.03, 0.34), glow_color.darkened(0.08), _earth_boss_arena_root)
	_create_ground_slab(Vector3(0.0, 0.0, start.z + 4.2), Vector3(2.5, 0.03, 0.26), glow_color.darkened(0.12), _earth_boss_arena_root)
	_create_ground_slab(Vector3(0.0, 0.0, start.z + 6.7), Vector3(1.7, 0.03, 0.22), glow_color.darkened(0.15), _earth_boss_arena_root)

func _create_boss_side_ruin(pos: Vector3, scale: Vector3, color: Color, lean_left: bool) -> void:
	if _earth_boss_arena_root == null:
		return
	var root := Node3D.new()
	root.name = "BossSideRuin"
	root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
	var side_sign: float = -1.0 if lean_left else 1.0
	_add_stone_piece(root, Vector3(-scale.x * 0.18, scale.y * 0.44, 0.0), Vector3(scale.x * 0.34, scale.y * 0.88, scale.z), color.darkened(0.1), Vector3(0.0, 0.0, 5.0 * side_sign))
	_add_stone_piece(root, Vector3(scale.x * 0.1, scale.y * 0.34, 0.0), Vector3(scale.x * 0.22, scale.y * 0.68, scale.z * 0.94), color, Vector3(0.0, 0.0, -7.0 * side_sign))
	_add_stone_piece(root, Vector3(scale.x * 0.34, scale.y * 0.2, 0.0), Vector3(scale.x * 0.16, scale.y * 0.4, scale.z * 0.82), color.lightened(0.03), Vector3(0.0, 0.0, 10.0 * side_sign))
	_add_stone_piece(root, Vector3(0.0, 0.1, 0.0), Vector3(scale.x, 0.2, scale.z * 1.18), color.darkened(0.16))
	_earth_boss_arena_root.add_child(root)

func _create_story_rune_cluster(center: Vector3, radius: float, glow_color: Color) -> void:
	if _earth_symbols_root == null:
		return
	var root := Node3D.new()
	root.name = "StoryRuneCluster"
	root.position = Vector3(center.x, get_terrain_height_at(center.x, center.z), center.z)
	_add_story_rune_line(root, Vector3(0.0, 0.03, radius * 0.62), Vector3(radius * 1.15, 0.03, 0.12), glow_color.darkened(0.12))
	_add_story_rune_line(root, Vector3(0.0, 0.03, radius * 0.22), Vector3(radius * 0.7, 0.025, 0.1), glow_color.darkened(0.18))
	_add_story_rune_line(root, Vector3(0.0, 0.04, -radius * 0.12), Vector3(0.14, 0.03, radius * 0.95), glow_color)
	_add_story_rune_line(root, Vector3(-radius * 0.42, 0.03, radius * 0.08), Vector3(0.1, 0.025, radius * 0.55), glow_color.darkened(0.08))
	_add_story_rune_line(root, Vector3(radius * 0.42, 0.03, radius * 0.08), Vector3(0.1, 0.025, radius * 0.55), glow_color.darkened(0.08))
	_add_story_rune_line(root, Vector3(-radius * 0.54, 0.03, -radius * 0.28), Vector3(radius * 0.34, 0.025, 0.08), glow_color.darkened(0.16), Vector3(0.0, 0.0, -24.0))
	_add_story_rune_line(root, Vector3(radius * 0.54, 0.03, -radius * 0.28), Vector3(radius * 0.34, 0.025, 0.08), glow_color.darkened(0.16), Vector3(0.0, 0.0, 24.0))
	_earth_symbols_root.add_child(root)

func _pulse_earth_boss_heart(duration: float) -> void:
	if _earth_boss_heart_material == null:
		return
	if _earth_boss_heart_glow_tween:
		_earth_boss_heart_glow_tween.kill()
	_earth_boss_heart_material.albedo_color = _earth_boss_heart_base_color.lerp(Color(0.95, 0.82, 0.52), 0.7)
	_earth_boss_heart_material.emission = Color(0.95, 0.78, 0.38)
	_earth_boss_heart_material.emission_energy_multiplier = 1.8
	_earth_boss_heart_glow_tween = create_tween()
	_earth_boss_heart_glow_tween.tween_interval(max(0.12, duration * 0.45))
	_earth_boss_heart_glow_tween.tween_property(_earth_boss_heart_material, "albedo_color", _earth_boss_heart_base_color, max(0.2, duration * 0.55))
	_earth_boss_heart_glow_tween.parallel().tween_property(_earth_boss_heart_material, "emission_energy_multiplier", 0.0, max(0.2, duration * 0.55))
	_earth_boss_heart_glow_tween.parallel().tween_property(_earth_boss_heart_material, "emission", _earth_boss_heart_base_color.darkened(0.7), max(0.2, duration * 0.55))
	_pulse_earth_boss_ground_rings(duration)
	_pulse_earth_shrine_runes(duration)
	_pulse_earth_boss_lighting(duration)

func _reset_earth_boss_heart_glow() -> void:
	if _earth_boss_heart_glow_tween:
		_earth_boss_heart_glow_tween.kill()
		_earth_boss_heart_glow_tween = null
	if _earth_boss_ring_glow_tween:
		_earth_boss_ring_glow_tween.kill()
		_earth_boss_ring_glow_tween = null
	if _earth_shrine_rune_glow_tween:
		_earth_shrine_rune_glow_tween.kill()
		_earth_shrine_rune_glow_tween = null
	if _earth_boss_accent_light_tween:
		_earth_boss_accent_light_tween.kill()
		_earth_boss_accent_light_tween = null
	if _earth_stage_light_tween:
		_earth_stage_light_tween.kill()
		_earth_stage_light_tween = null
	if _earth_shrine_rune_glow_tween:
		_earth_shrine_rune_glow_tween.kill()
		_earth_shrine_rune_glow_tween = null
	if _earth_boss_accent_light_tween:
		_earth_boss_accent_light_tween.kill()
		_earth_boss_accent_light_tween = null
	if _earth_boss_heart_material == null:
		return
	_earth_boss_heart_material.albedo_color = _earth_boss_heart_base_color
	_earth_boss_heart_material.emission = _earth_boss_heart_base_color.darkened(0.7)
	_earth_boss_heart_material.emission_energy_multiplier = 0.0
	for i in range(min(_earth_boss_ring_materials.size(), _earth_boss_ring_base_colors.size())):
		var ring_mat: StandardMaterial3D = _earth_boss_ring_materials[i]
		if ring_mat == null:
			continue
		var base_color: Color = _earth_boss_ring_base_colors[i]
		ring_mat.albedo_color = base_color
		ring_mat.emission_enabled = true
		ring_mat.emission = base_color.darkened(0.75)
		ring_mat.emission_energy_multiplier = 0.0
	for i in range(min(_earth_shrine_rune_materials.size(), _earth_shrine_rune_base_colors.size())):
		var rune_mat: StandardMaterial3D = _earth_shrine_rune_materials[i]
		if rune_mat == null:
			continue
		var rune_color: Color = _earth_shrine_rune_base_colors[i]
		rune_mat.albedo_color = rune_color.lightened(0.08)
		rune_mat.emission = rune_color
		rune_mat.emission_energy_multiplier = 1.35
	if _earth_boss_accent_light:
		_earth_boss_accent_light.light_energy = 0.0
		_earth_boss_accent_light.light_color = Color(0.95, 0.78, 0.54, 1.0)

func _pulse_earth_boss_ground_rings(duration: float) -> void:
	if _earth_boss_ring_materials.is_empty():
		return
	if _earth_boss_ring_glow_tween:
		_earth_boss_ring_glow_tween.kill()
	for i in range(min(_earth_boss_ring_materials.size(), _earth_boss_ring_base_colors.size())):
		var ring_mat: StandardMaterial3D = _earth_boss_ring_materials[i]
		if ring_mat == null:
			continue
		var base_color: Color = _earth_boss_ring_base_colors[i]
		ring_mat.albedo_color = base_color.lerp(Color(0.86, 0.7, 0.42), 0.45)
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(0.82, 0.64, 0.34)
		ring_mat.emission_energy_multiplier = 0.85
	_earth_boss_ring_glow_tween = create_tween()
	_earth_boss_ring_glow_tween.tween_interval(max(0.1, duration * 0.4))
	for i in range(min(_earth_boss_ring_materials.size(), _earth_boss_ring_base_colors.size())):
		var ring_mat: StandardMaterial3D = _earth_boss_ring_materials[i]
		if ring_mat == null:
			continue
		var base_color: Color = _earth_boss_ring_base_colors[i]
		_earth_boss_ring_glow_tween.parallel().tween_property(ring_mat, "albedo_color", base_color, max(0.18, duration * 0.6))
		_earth_boss_ring_glow_tween.parallel().tween_property(ring_mat, "emission_energy_multiplier", 0.0, max(0.18, duration * 0.6))
		_earth_boss_ring_glow_tween.parallel().tween_property(ring_mat, "emission", base_color.darkened(0.75), max(0.18, duration * 0.6))

func _pulse_earth_shrine_runes(duration: float) -> void:
	if _earth_shrine_rune_materials.is_empty():
		return
	if _earth_shrine_rune_glow_tween:
		_earth_shrine_rune_glow_tween.kill()
	for i in range(min(_earth_shrine_rune_materials.size(), _earth_shrine_rune_base_colors.size())):
		var rune_mat: StandardMaterial3D = _earth_shrine_rune_materials[i]
		if rune_mat == null:
			continue
		var base_color: Color = _earth_shrine_rune_base_colors[i]
		rune_mat.albedo_color = base_color.lightened(0.2)
		rune_mat.emission = base_color.lightened(0.12)
		rune_mat.emission_energy_multiplier = 2.2
	_earth_shrine_rune_glow_tween = create_tween()
	_earth_shrine_rune_glow_tween.tween_interval(max(0.08, duration * 0.35))
	for i in range(min(_earth_shrine_rune_materials.size(), _earth_shrine_rune_base_colors.size())):
		var rune_mat: StandardMaterial3D = _earth_shrine_rune_materials[i]
		if rune_mat == null:
			continue
		var base_color: Color = _earth_shrine_rune_base_colors[i]
		_earth_shrine_rune_glow_tween.parallel().tween_property(rune_mat, "albedo_color", base_color.lightened(0.08), max(0.2, duration * 0.65))
		_earth_shrine_rune_glow_tween.parallel().tween_property(rune_mat, "emission", base_color, max(0.2, duration * 0.65))
		_earth_shrine_rune_glow_tween.parallel().tween_property(rune_mat, "emission_energy_multiplier", 1.35, max(0.2, duration * 0.65))

func _pulse_earth_boss_lighting(duration: float) -> void:
	if _earth_boss_accent_light == null:
		return
	if _earth_boss_accent_light_tween:
		_earth_boss_accent_light_tween.kill()
	_earth_boss_accent_light.light_color = Color(1.0, 0.84, 0.6, 1.0)
	_earth_boss_accent_light.light_energy = 2.1
	_earth_boss_accent_light.omni_range = 22.0
	if fill_light:
		fill_light.light_energy = 2.5
		fill_light.light_color = Color(0.88, 0.8, 0.7, 1.0)
	_earth_boss_accent_light_tween = create_tween()
	_earth_boss_accent_light_tween.tween_interval(max(0.08, duration * 0.35))
	_earth_boss_accent_light_tween.parallel().tween_property(_earth_boss_accent_light, "light_energy", 0.0, max(0.2, duration * 0.65))
	_earth_boss_accent_light_tween.parallel().tween_property(_earth_boss_accent_light, "light_color", Color(0.95, 0.78, 0.54, 1.0), max(0.2, duration * 0.65))
	if fill_light:
		_earth_boss_accent_light_tween.parallel().tween_property(fill_light, "light_energy", 2.1, max(0.2, duration * 0.65))
		_earth_boss_accent_light_tween.parallel().tween_property(fill_light, "light_color", Color(0.78, 0.72, 0.68, 1.0), max(0.2, duration * 0.65))

func _update_earth_shrine_idle_glow(delta: float) -> void:
	if _earth_shrine_rune_materials.is_empty():
		return
	if _earth_shrine_rune_glow_tween != null:
		return
	_earth_shrine_idle_time += delta
	var pulse: float = 0.5 + 0.5 * sin(_earth_shrine_idle_time * 1.35)
	var energy: float = lerp(0.95, 1.35, pulse)
	for i in range(min(_earth_shrine_rune_materials.size(), _earth_shrine_rune_base_colors.size())):
		var rune_mat: StandardMaterial3D = _earth_shrine_rune_materials[i]
		if rune_mat == null:
			continue
		var base_color: Color = _earth_shrine_rune_base_colors[i]
		rune_mat.albedo_color = base_color.lightened(0.05 + pulse * 0.06)
		rune_mat.emission = base_color.lightened(pulse * 0.05)
		rune_mat.emission_energy_multiplier = energy

func _create_boss_ring_pillar(pos: Vector3, scale: Vector3, color: Color) -> void:
	if _earth_boss_arena_root == null:
		return
	var root := Node3D.new()
	root.name = "BossPillar"
	root.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z), pos.z)
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.14, 0.0), Vector3(scale.x * 1.45, scale.y * 0.18, scale.z * 1.45), color.darkened(0.16))
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.52, 0.0), Vector3(scale.x, scale.y * 0.76, scale.z), color)
	_add_stone_piece(root, Vector3(0.0, scale.y * 0.93, 0.0), Vector3(scale.x * 1.2, scale.y * 0.14, scale.z * 1.2), color.lightened(0.04))
	_earth_boss_arena_root.add_child(root)

func _add_stone_piece(parent: Node3D, local_pos: Vector3, scale: Vector3, color: Color, rotation_deg: Vector3 = Vector3.ZERO, uv_scale: float = 2.2) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh_instance.mesh = mesh
	mesh_instance.position = local_pos
	mesh_instance.scale = scale
	mesh_instance.rotation_degrees = rotation_deg
	var mat := _make_earth_stone_material(color, uv_scale)
	mesh_instance.material_override = mat
	_earth_stone_preview_materials.append(mat)
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_shrine_rune_line(parent: Node3D, local_pos: Vector3, scale: Vector3, glow_color: Color, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh_instance.mesh = mesh
	mesh_instance.position = local_pos
	mesh_instance.scale = scale
	mesh_instance.rotation_degrees = rotation_deg
	var mat := StandardMaterial3D.new()
	mat.albedo_color = glow_color.lightened(0.08)
	mat.roughness = 0.3
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 1.35
	mat.disable_receive_shadows = true
	mesh_instance.material_override = mat
	_earth_stone_preview_materials.append(mat)
	_earth_shrine_rune_materials.append(mat)
	_earth_shrine_rune_base_colors.append(glow_color)
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_story_rune_line(parent: Node3D, local_pos: Vector3, scale: Vector3, glow_color: Color, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh_instance.mesh = mesh
	mesh_instance.position = local_pos
	mesh_instance.scale = scale
	mesh_instance.rotation_degrees = rotation_deg
	var mat := StandardMaterial3D.new()
	mat.albedo_color = glow_color.lightened(0.04)
	mat.roughness = 0.42
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 0.38
	mat.disable_receive_shadows = true
	mesh_instance.material_override = mat
	_earth_stone_preview_materials.append(mat)
	parent.add_child(mesh_instance)
	return mesh_instance

func _make_earth_stone_material(color: Color, uv_scale: float = 2.2) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = color
	mat.roughness = 0.96
	mat.metallic = 0.0
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	mat.uv1_triplanar_sharpness = 0.75
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var albedo_tex := _load_texture(EARTH_STONE_ALBEDO_PATH)
	if albedo_tex:
		mat.albedo_texture = albedo_tex
	var normal_tex := _load_texture(EARTH_STONE_NORMAL_PATH)
	if normal_tex:
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
		mat.normal_scale = 0.7
	var arm_tex := _load_texture(EARTH_STONE_ARM_PATH)
	if arm_tex:
		mat.ao_enabled = true
		mat.ao_texture = arm_tex
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.ao_light_affect = 0.6
		mat.roughness_texture = arm_tex
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		mat.metallic_texture = arm_tex
		mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	return mat

func _create_boss_ring_arc(center: Vector3, radius: float, segment_count: int, color: Color) -> void:
	if _earth_boss_arena_root == null:
		return
	for i in range(segment_count):
		var angle: float = TAU * float(i) / float(max(segment_count, 1))
		var pos := Vector3(center.x + cos(angle) * radius, 0.0, center.z + sin(angle) * radius)
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh_instance.mesh = mesh
		mesh_instance.position = Vector3(pos.x, get_terrain_height_at(pos.x, pos.z) + 0.08, pos.z)
		mesh_instance.scale = Vector3(1.6, 0.16, 0.7)
		mesh_instance.rotation.y = -angle
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		mesh_instance.material_override = mat
		_earth_boss_arena_root.add_child(mesh_instance)

func _create_boss_ground_ring(center: Vector3, radius: float, segment_count: int, color: Color) -> void:
	if _earth_boss_arena_root == null:
		return
	for i in range(segment_count):
		var angle: float = TAU * float(i) / float(max(segment_count, 1))
		var pos := Vector3(center.x + cos(angle) * radius, 0.0, center.z + sin(angle) * radius)
		_create_ground_slab(pos, Vector3(1.25, 0.05, 0.42), color, _earth_boss_arena_root)
		var child_count := _earth_boss_arena_root.get_child_count()
		if child_count > 0:
			var ring_piece := _earth_boss_arena_root.get_child(child_count - 1)
			if ring_piece is Node3D:
				(ring_piece as Node3D).rotation.y = -angle

func _update_earth_story_prompt() -> void:
	if not _earth_story_started or _earth_story_completed or _earth_story_choice_active:
		return
	if hud == null or not hud.has_method("show_story_prompt"):
		return
	var should_show := _can_start_earth_story_event()
	if should_show == _earth_tablet_prompt_visible:
		return
	_earth_tablet_prompt_visible = should_show
	if should_show:
		if _earth_second_story_active:
			hud.call("show_story_prompt", "Roadside Cairn\n按 E 收拾旧路留下的三块石。")
		else:
			hud.call("show_story_prompt", "Stone Tablet\n按 E 读碑。土记得每一个停下的人。")
	else:
		hud.call("clear_story_choices")

func _can_start_earth_story_event() -> bool:
	if not _earth_story_started or _earth_story_completed or _earth_story_choice_active:
		return false
	var target := _get_active_story_target()
	if player == null or target == null or not is_instance_valid(target):
		return false
	if not (player is Node3D):
		return false
	return (player as Node3D).global_position.distance_to(target.global_position) <= 3.2

func _get_active_story_target() -> Node3D:
	if _earth_second_story_active and not _earth_second_story_completed:
		return _earth_waystone
	return _earth_tablet

func _open_earth_story_choices() -> void:
	if hud == null or not hud.has_method("show_story_choices"):
		return
	_earth_story_choice_active = true
	_earth_tablet_prompt_visible = false
	if player and player.has_method("set_input_locked"):
		player.call("set_input_locked", true)
	if _earth_second_story_active:
		_earth_story_pending_choices = [
			{
				"id": "cairn_shared_load",
				"text": "把歪掉的石重新垒稳。",
				"result": "你替后来的人把路边石垒稳，脚下的步子也跟着沉了下来。",
				"ming": "Ming: 路边的小事，也有人要接着做。",
				"stats": {
					"max_hp": 8.0,
					"damage_reduction": 0.03
				}
			},
			{
				"id": "cairn_breath_between",
				"text": "在石缝里留出一口透气。",
				"result": "你没有把石压死，只给它们之间留了一口风。",
				"ming": "Ming: 太满会碎，能留缝的，反而能久。",
				"stats": {
					"spirit_regen": 1.2,
					"guard_spirit": 2.0
				}
			},
			{
				"id": "cairn_mark_the_way",
				"text": "把最亮的一块石转向前路。",
				"result": "你没有回头看，只替后来的人把路指得更清楚了一点。",
				"ming": "Ming: 真正记路的人，不会只替自己看见。",
				"stats": {
					"damage_mult": 0.04,
					"attack_speed": 0.05
				}
			}
		]
		hud.call("show_story_choices", "路旁石堆：‘有人停下，不是为了歇，而是为了让后面的人认得这条路。’", _earth_story_pending_choices)
		return
	_earth_story_pending_choices = [
		{
			"id": "tablet_burden_vow",
			"text": "替无名旅人把石担扶正。",
			"result": "你扶正了旧担，手臂发酸，心却稳了下来。",
			"ming": "Ming: 土先托住别人，才托得住自己。",
			"stats": {
				"damage_reduction": 0.04,
				"parry_guard": 6.0
			}
		},
		{
			"id": "tablet_seed_crack",
			"text": "把一粒种子按进碑缝里。",
			"result": "石缝里留了一点潮气，你的呼吸也慢慢匀了。",
			"ming": "Ming: 裂纹不一定是坏事，它也会替人留路。",
			"stats": {
				"spirit_regen": 1.5,
				"resonance_bonus": 0.1
			}
		},
		{
			"id": "tablet_name_ash",
			"text": "轻轻拂掉碑上的尘，记住名字。",
			"result": "你没有带走任何东西，只把那份重量记在了心里。",
			"ming": "Ming: 记住名字的人，出手会更准，也更慢。",
			"stats": {
				"damage_mult": 0.06,
				"counter_damage": 6.0
			}
		}
	]
	hud.call("show_story_choices", "残碑：‘路会替愿意停下的人留一口气。’", _earth_story_pending_choices)

func _select_earth_story_choice(index: int) -> void:
	if index < 0 or index >= _earth_story_pending_choices.size():
		return
	var choice: Dictionary = _earth_story_pending_choices[index]
	_earth_story_choice_active = false
	_earth_story_pending_choices.clear()
	if hud and hud.has_method("clear_story_choices"):
		hud.call("clear_story_choices")
	if player and player.has_method("apply_story_blessing"):
		player.call("apply_story_blessing", String(choice.get("id", "")), choice.get("stats", {}))
	if player and player.has_method("set_input_locked"):
		player.call("set_input_locked", false)
	if hud and hud.has_method("show_story_result"):
		hud.call("show_story_result", "%s\n%s" % [String(choice.get("result", "")), String(choice.get("ming", ""))])
	await get_tree().create_timer(1.6).timeout
	if not _earth_second_story_active:
		_earth_second_story_active = true
		_earth_story_completed = false
		_earth_tablet_prompt_visible = false
		if hud and hud.has_method("show_stage_start"):
			hud.call("show_stage_start", "Ming: 再往前走一点。路边那堆石，也在等你给它一个说法。")
		return
	_earth_second_story_completed = true
	_earth_story_completed = true
	if run_manager and run_manager.has_method("start_run"):
		run_manager.call("start_run")

func _set_theme_visibility(layer: String) -> void:
	if underground_set:
		underground_set.visible = layer == "underground"
	if surface_set:
		surface_set.visible = layer == "surface"
	if sky_set:
		sky_set.visible = layer == "sky"

func _apply_floor_color(color: Color) -> void:
	if floor == null:
		return
	var mat: StandardMaterial3D = _ensure_standard_material(floor)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if mat.albedo_texture:
		mat.albedo_color = Color(1.4, 1.4, 1.4, 1.0)
	else:
		mat.albedo_color = color
	mat.roughness = 1.0

func _apply_wall_color(color: Color) -> void:
	if arena_walls == null:
		return
	for child in arena_walls.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = _ensure_standard_material(child)
			mat.albedo_color = color
			mat.roughness = 1.0

func _ensure_standard_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	var mat := mesh.material_override
	if mat == null or not (mat is StandardMaterial3D):
		mat = StandardMaterial3D.new()
		mesh.material_override = mat
	return mat as StandardMaterial3D

func _apply_floor_textures() -> void:
	if floor == null:
		return
	var mat: StandardMaterial3D = _ensure_standard_material(floor)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if floor_force_unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var albedo_path: String = _floor_texture_paths.get("albedo", "")
	var normal_path: String = _floor_texture_paths.get("normal", "")
	var arm_path: String = _floor_texture_paths.get("arm", "")
	var tile_scale := 6.0
	if floor.mesh is PlaneMesh:
		var plane := floor.mesh as PlaneMesh
		tile_scale = max(1.0, plane.size.x / 20.0)
	var albedo_tex: Texture2D = _load_texture(albedo_path)
	var normal_tex: Texture2D = _load_texture(normal_path)
	var arm_tex: Texture2D = _load_texture(arm_path)
	if albedo_tex:
		mat.albedo_texture = albedo_tex
	mat.albedo_color = Color(0.95, 0.95, 0.95, 1.0)
	if normal_tex:
		if floor_use_pbr:
			mat.normal_texture = normal_tex
			mat.normal_scale = 0.45
		else:
			mat.normal_texture = null
			mat.normal_scale = 0.0
	if arm_tex:
		if floor_use_ao:
			mat.ao_texture = arm_tex
			mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			mat.ao_light_affect = 0.08
		else:
			mat.ao_texture = null
			mat.ao_light_affect = 0.0
		if floor_use_pbr:
			mat.roughness_texture = arm_tex
			mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			mat.metallic_texture = arm_tex
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
			mat.metallic = 0.0
		else:
			mat.roughness_texture = null
			mat.metallic_texture = null
			mat.roughness = 0.95
			mat.metallic = 0.0
	mat.uv1_scale = Vector3(tile_scale, tile_scale, 1.0)
	mat.emission_enabled = false
	mat.emission = Color(0, 0, 0)
	mat.emission_energy = 0.0
	mat.disable_receive_shadows = false
	mat.roughness = 0.85

func _apply_magic_post() -> void:
	if world_env == null:
		return
	var env := world_env.environment
	if env == null:
		return
	_set_env_property(env, "auto_exposure_enabled", false)
	_set_env_property(env, "auto_exposure_min_sensitivity", 0.6)
	_set_env_property(env, "auto_exposure_max_sensitivity", 0.6)
	_set_env_property(env, "tonemap_mode", 3)
	_set_env_property(env, "tonemap_exposure", 0.9)
	_set_env_property(env, "tonemap_white", 1.3)
	_set_env_property(env, "glow_enabled", true)
	_set_env_property(env, "glow_intensity", 0.7)
	_set_env_property(env, "glow_strength", 0.9)
	_set_env_property(env, "glow_bloom", 0.1)
	_set_env_property(env, "glow_hdr_threshold", 1.0)
	_set_env_property(env, "glow_blend_mode", 1)
	_set_env_property(env, "adjustment_enabled", true)
	_set_env_property(env, "adjustment_brightness", 0.98)
	_set_env_property(env, "adjustment_contrast", 1.02)
	_set_env_property(env, "adjustment_saturation", 1.05)

func _set_env_property(env: Environment, prop_name: String, value: Variant) -> void:
	for info in env.get_property_list():
		if info.has("name") and info["name"] == prop_name:
			env.set(prop_name, value)
			return

func _exit_tree() -> void:
	_release_runtime_materials()

func _release_runtime_materials() -> void:
	if terrain and terrain.has_method("release_runtime_resources"):
		terrain.call("release_runtime_resources")
	if _earth_boss_heart_glow_tween:
		_earth_boss_heart_glow_tween.kill()
		_earth_boss_heart_glow_tween = null
	if _earth_boss_ring_glow_tween:
		_earth_boss_ring_glow_tween.kill()
		_earth_boss_ring_glow_tween = null
	if floor:
		var floor_mat := floor.material_override
		if floor_mat is StandardMaterial3D:
			var standard_floor := floor_mat as StandardMaterial3D
			standard_floor.albedo_texture = null
			standard_floor.normal_texture = null
			standard_floor.roughness_texture = null
			standard_floor.metallic_texture = null
			standard_floor.ao_texture = null
		floor.material_override = null
	if arena_walls:
		for child in arena_walls.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = null
	if _earth_symbols_root and is_instance_valid(_earth_symbols_root):
		_clear_node_materials_recursive(_earth_symbols_root)
		_earth_symbols_root.free()
		_earth_symbols_root = null
	_earth_boss_arena_root = null
	_earth_boss_heart_mesh = null
	_earth_boss_heart_material = null
	_earth_boss_accent_light = null
	_earth_boss_ring_materials.clear()
	_earth_boss_ring_base_colors.clear()
	_earth_shrine_rune_materials.clear()
	_earth_shrine_rune_base_colors.clear()
	_earth_shrine_idle_time = 0.0
	for mat in _earth_stone_preview_materials:
		if mat == null:
			continue
		mat.albedo_texture = null
		mat.normal_texture = null
		mat.roughness_texture = null
		mat.metallic_texture = null
		mat.ao_texture = null
	_earth_stone_preview_materials.clear()

func _clear_node_materials_recursive(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var override_mat := mesh_instance.material_override
		if override_mat is StandardMaterial3D:
			var standard_mat := override_mat as StandardMaterial3D
			standard_mat.albedo_texture = null
			standard_mat.normal_texture = null
			standard_mat.roughness_texture = null
			standard_mat.metallic_texture = null
			standard_mat.ao_texture = null
		mesh_instance.material_override = null
	for child in node.get_children():
		_clear_node_materials_recursive(child)

func _load_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	return res as Texture2D

func _add_action_if_missing(action: String, keys: Array = [], mouse_buttons: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for btn in mouse_buttons:
		var mev := InputEventMouseButton.new()
		mev.button_index = btn
		InputMap.action_add_event(action, mev)

func _add_key_to_action(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	if InputMap.action_has_event(action, ev):
		return
	InputMap.action_add_event(action, ev)
