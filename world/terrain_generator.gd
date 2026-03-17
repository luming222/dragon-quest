extends Node3D

@export var area_size := 26.0
@export var clear_radius := 3.5
@export var grass_count := 560
@export var tree_count := 8
@export var rock_count := 10
@export var water_count := 6
@export var flower_count := 10
@export var height_enabled := true
@export var height_amplitude := 1.2
@export var height_frequency := 0.06
@export var height_octaves := 3
@export var height_gain := 0.5
@export var height_lacunarity := 2.0
@export var flat_center_ground := true
@export var flat_center_radius := 10.5
@export var flat_edge_transition := 3.0
@export var flat_edge_height_scale := 0.25
@export var mound_count := 8
@export var mound_min_radius := 3.0
@export var mound_max_radius := 6.0
@export var mound_height := 2.0
@export var enable_collisions := true
@export var use_cross_grass := true
@export var grass_plane_width := 0.42
@export var grass_plane_height := 0.92
@export var grass_texture_path := "res://assets/textures/grass_alpha.png"
@export var grass_shader_path := "res://shaders/grass.gdshader"
@export var grass_alpha_clip := 0.32
@export var grass_roughness := 0.9
@export var grass_metallic := 0.0
@export var grass_wind_strength := 0.09
@export var grass_wind_speed := 1.2
@export var grass_wind_scale := 0.6
@export var grass_wind_direction := Vector2(0.8, 0.6)
@export var grass_lod_max_distance := 28.0
@export var grass_lod_fade_distance := 8.0
@export var grass_subsurface_strength := 0.2
@export var regenerate_each_time := true
@export var grass_planes_per_clump := 4
@export var grass_clump_radius := 0.1
@export var grass_color_variation := 0.06
@export var grass_size_variation := 0.12
@export var grass_bend_deg := 2.5
@export var grass_rotation_snap_deg := 30.0
@export var grass_rotation_jitter_deg := 5.0
@export var grass_cluster_count := 26
@export var grass_cluster_radius := 1.9
@export var grass_cluster_jitter := 0.55
@export var grass_tip_width_ratio := 0.22
@export var tree_scene: PackedScene
@export var rock_scene: PackedScene
@export var grass_scene: PackedScene
@export var flower_scene: PackedScene

var _materials := {}
var _grass_mesh: ArrayMesh
var _grass_mesh_key := ""
var _grass_shader: Shader
var _height_noise: FastNoiseLite = null

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _release_runtime_resources()

func _exit_tree() -> void:
    _release_runtime_resources()

func release_runtime_resources() -> void:
    _release_runtime_resources()

func build_layout(stage_id: String, region_id: String) -> void:
    if stage_id == "":
        return
    _ensure_scenes_loaded()
    clear_layout()
    var path := "user://level_layouts/%s.json" % stage_id
    if not regenerate_each_time and FileAccess.file_exists(path):
        var loaded := _load_layout(path)
        if loaded.size() > 0:
            _spawn_from_layout(loaded, region_id)
            return
    var layout := _generate_layout(stage_id, region_id)
    _spawn_from_layout(layout, region_id)
    if not regenerate_each_time:
        _save_layout(path, layout)

func clear_layout() -> void:
    _clear_layout_nodes(false)

func _clear_layout_nodes(immediate: bool) -> void:
    for child in get_children():
        _clear_node_runtime_resources(child)
    for child in get_children():
        if immediate:
            child.free()
        else:
            child.queue_free()

func _release_runtime_resources() -> void:
    _clear_layout_nodes(true)
    for key in _materials.keys():
        var mat_var: Variant = _materials[key]
        if mat_var is Material:
            _cleanup_material(mat_var as Material)
        _materials[key] = null
    _materials.clear()
    _grass_mesh = null
    _grass_mesh_key = ""
    _grass_shader = null
    _height_noise = null

func _clear_node_runtime_resources(node: Node) -> void:
    if node == null:
        return
    if node is MultiMeshInstance3D:
        var mm := node as MultiMeshInstance3D
        if mm.material_override is Material:
            _cleanup_material(mm.material_override as Material)
        mm.material_override = null
        mm.multimesh = null
    elif node is GeometryInstance3D:
        var geometry := node as GeometryInstance3D
        if geometry.material_override is Material:
            _cleanup_material(geometry.material_override as Material)
        geometry.material_override = null
    for child in node.get_children():
        _clear_node_runtime_resources(child)

func _cleanup_material(mat: Material) -> void:
    if mat == null:
        return
    if mat is ShaderMaterial:
        var shader_mat := mat as ShaderMaterial
        shader_mat.set_shader_parameter("albedo_tex", null)
        shader_mat.shader = null
        return
    if mat is StandardMaterial3D:
        var standard_mat := mat as StandardMaterial3D
        standard_mat.albedo_texture = null
        standard_mat.normal_texture = null
        standard_mat.roughness_texture = null
        standard_mat.metallic_texture = null
        standard_mat.ao_texture = null
        standard_mat.emission_texture = null

func _generate_layout(stage_id: String, region_id: String) -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = _make_seed(stage_id, region_id)
    _setup_height_noise(rng.seed)
    var settings := _get_region_settings(region_id)
    var grass_profile: Dictionary = _get_grass_distribution_profile(stage_id, region_id)
    var layout: Array = []
    var grass_clusters := _build_grass_cluster_centers(rng, int(settings.get("grass_cluster_count", grass_cluster_count)), grass_profile)
    for i in range(int(settings["grass_count"])):
        var pos := _random_grass_pos(rng, grass_clusters, grass_profile)
        var size := rng.randf_range(0.28, 0.46)
        var scale := Vector3(
            size * rng.randf_range(0.96, 1.03),
            size * rng.randf_range(0.82, 0.96),
            size * rng.randf_range(0.96, 1.03)
        )
        layout.append(_make_entry("grass", pos, scale))
    for i in range(int(settings["tree_count"])):
        var pos := _random_pos(rng)
        var scale := Vector3.ONE * rng.randf_range(0.8, 1.3)
        layout.append(_make_entry("tree", pos, scale))
    for i in range(int(settings["rock_count"])):
        var pos := _random_pos(rng)
        var scale := Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.4, 0.9), rng.randf_range(0.6, 1.4))
        layout.append(_make_entry("rock", pos, scale))
    for i in range(int(settings["water_count"])):
        var pos := _random_pos(rng)
        var scale := Vector3(rng.randf_range(1.2, 2.4), 1.0, rng.randf_range(1.2, 2.4))
        layout.append(_make_entry("water", pos, scale))
    for i in range(int(settings["flower_count"])):
        var pos := _random_pos(rng)
        var scale := Vector3.ONE * rng.randf_range(0.5, 0.9)
        layout.append(_make_entry("flower", pos, scale))
    for i in range(int(settings["mound_count"])):
        var pos := _random_pos(rng)
        var radius := rng.randf_range(mound_min_radius, mound_max_radius)
        var height := rng.randf_range(mound_height * 0.6, mound_height * 1.2)
        var scale := Vector3(radius, height, radius)
        layout.append(_make_entry("mound", pos, scale))
    return layout

func _spawn_from_layout(layout: Array, region_id: String) -> void:
    var settings := _get_region_settings(region_id)
    var grass_entries: Array = []
    for entry in layout:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var data: Dictionary = entry
        var type_name := String(data.get("type", ""))
        var pos := _vec3_from_array(data.get("pos", [0.0, 0.0, 0.0]))
        var scale := _vec3_from_array(data.get("scale", [1.0, 1.0, 1.0]))
        match type_name:
            "grass":
                if use_cross_grass:
                    grass_entries.append({"pos": pos, "scale": scale})
                else:
                    _spawn_grass(pos, scale, settings)
            "tree":
                _spawn_tree(pos, scale, settings)
            "rock":
                _spawn_rock(pos, scale, settings)
            "water":
                _spawn_water(pos, scale, settings)
            "flower":
                _spawn_flower(pos, scale, settings)
            "mound":
                _spawn_mound(pos, scale, settings)
    if use_cross_grass and grass_entries.size() > 0:
        _spawn_grass_batch(grass_entries, settings)

func _spawn_grass(pos: Vector3, scale: Vector3, settings: Dictionary) -> void:
    if grass_scene:
        _spawn_scene_instance(grass_scene, pos, scale, randf_range(0.0, TAU))
        return
    var mesh := BoxMesh.new()
    mesh.size = Vector3(1.0, 0.2, 1.0)
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = _get_material("grass", settings["grass_color"])
    node.scale = scale
    node.position = pos
    add_child(node)

func _spawn_grass_batch(entries: Array, settings: Dictionary) -> void:
    if entries.is_empty():
        return
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_custom_data = true
    multimesh.instance_count = entries.size()
    multimesh.visible_instance_count = entries.size()
    multimesh.mesh = _get_grass_mesh()
    var mat := _get_grass_material(settings)
    var base_color: Color = settings.get("grass_color", Color(0.25, 0.4, 0.25))
    for i in range(entries.size()):
        var data: Dictionary = entries[i]
        var pos: Vector3 = data.get("pos", Vector3.ZERO)
        var scale: Vector3 = data.get("scale", Vector3.ONE)
        var size_mult := 1.0 + randf_range(-grass_size_variation, grass_size_variation)
        var sx := size_mult * randf_range(0.94, 1.06)
        var sy := size_mult * randf_range(0.88, 1.02)
        var basis := Basis()
        var snap_step: float = deg_to_rad(max(1.0, grass_rotation_snap_deg))
        var yaw: float = round(randf_range(0.0, TAU) / snap_step) * snap_step
        yaw += deg_to_rad(randf_range(-grass_rotation_jitter_deg, grass_rotation_jitter_deg))
        basis = basis.rotated(Vector3.UP, yaw)
        var tilt_x: float = deg_to_rad(randf_range(-grass_bend_deg, grass_bend_deg))
        basis = basis.rotated(Vector3.RIGHT, tilt_x)
        basis = basis.scaled(Vector3(scale.x * sx, scale.y * sy, scale.z * sx))
        var transform := Transform3D(basis, pos)
        multimesh.set_instance_transform(i, transform)
        var tint := Color(
            clamp(base_color.r * (1.0 + randf_range(-grass_color_variation, grass_color_variation)), 0.0, 1.0),
            clamp(base_color.g * (1.0 + randf_range(-grass_color_variation, grass_color_variation)), 0.0, 1.0),
            clamp(base_color.b * (1.0 + randf_range(-grass_color_variation, grass_color_variation)), 0.0, 1.0),
            randf()
        )
        multimesh.set_instance_custom_data(i, tint)
    var holder := MultiMeshInstance3D.new()
    holder.multimesh = multimesh
    holder.material_override = mat
    holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(holder)

func _spawn_tree(pos: Vector3, scale: Vector3, settings: Dictionary) -> void:
    if tree_scene:
        var inst := _spawn_scene_instance(tree_scene, pos, scale, randf_range(0.0, TAU))
        if enable_collisions and inst:
            _add_tree_collision(inst, scale)
        return
    var tree := Node3D.new()
    tree.position = pos
    tree.scale = scale
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.25
    trunk_mesh.bottom_radius = 0.35
    trunk_mesh.height = 2.2
    var trunk := MeshInstance3D.new()
    trunk.mesh = trunk_mesh
    trunk.material_override = _get_material("trunk", settings["trunk_color"])
    trunk.position = Vector3(0, 1.1, 0)
    tree.add_child(trunk)
    var canopy_mesh := BoxMesh.new()
    canopy_mesh.size = Vector3(1.7, 1.2, 1.7)
    var canopy := MeshInstance3D.new()
    canopy.mesh = canopy_mesh
    canopy.material_override = _get_material("leaf", settings["leaf_color"])
    canopy.position = Vector3(0, 2.5, 0)
    canopy.rotation_degrees = Vector3(0.0, 20.0, 0.0)
    tree.add_child(canopy)
    add_child(tree)

func _spawn_rock(pos: Vector3, scale: Vector3, settings: Dictionary) -> void:
    if rock_scene:
        var inst := _spawn_scene_instance(rock_scene, pos, scale, randf_range(0.0, TAU))
        if enable_collisions and inst:
            _add_rock_collision(inst, scale)
        return
    var mesh := BoxMesh.new()
    mesh.size = Vector3(1.0, 1.0, 1.0)
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = _get_material("rock", settings["rock_color"])
    node.scale = scale
    node.position = pos + Vector3(0, scale.y * 0.5, 0)
    add_child(node)

func _spawn_water(pos: Vector3, scale: Vector3, settings: Dictionary) -> void:
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(2.0, 2.0)
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = _get_material("water", settings["water_color"])
    node.scale = Vector3(scale.x, 1.0, scale.z)
    node.position = pos + Vector3(0, 0.02, 0)
    add_child(node)

func _spawn_flower(pos: Vector3, scale: Vector3, settings: Dictionary) -> void:
    if flower_scene:
        _spawn_scene_instance(flower_scene, pos, scale, randf_range(0.0, TAU))
        return
    var mesh := SphereMesh.new()
    mesh.radius = 0.2
    mesh.height = 0.4
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = _get_material("flower", settings["flower_color"])
    node.scale = scale
    node.position = pos + Vector3(0, 0.1, 0)
    add_child(node)

func _spawn_mound(pos: Vector3, scale: Vector3, settings: Dictionary) -> void:
    var mesh := BoxMesh.new()
    mesh.size = Vector3(1.0, 0.7, 1.0)
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = _get_material("mound", settings.get("mound_color", settings.get("rock_color", Color(0.3, 0.3, 0.3))))
    node.scale = Vector3(scale.x, scale.y, scale.z)
    node.position = pos + Vector3(0, scale.y * 0.18, 0)
    node.rotation_degrees = Vector3(0.0, randf_range(0.0, 180.0), 0.0)
    add_child(node)

func _spawn_scene_instance(scene: PackedScene, pos: Vector3, scale: Vector3, yaw: float) -> Node3D:
    var inst := scene.instantiate()
    if inst == null:
        return null
    if inst is Node3D:
        var node := inst as Node3D
        node.position = pos
        node.scale = scale
        node.rotate_y(yaw)
    add_child(inst)
    return inst if inst is Node3D else null

func _get_material(key: String, color: Color) -> StandardMaterial3D:
    if _materials.has(key):
        return _materials[key]
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    mat.albedo_color = color
    mat.roughness = 1.0
    if key == "water":
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.albedo_color.a = 0.6
        mat.roughness = 0.2
        mat.metallic = 0.1
    _materials[key] = mat
    return mat

func _get_grass_mesh() -> ArrayMesh:
    var key := "%s|%s|%s|%s" % [grass_plane_width, grass_plane_height, grass_planes_per_clump, grass_clump_radius]
    if _grass_mesh == null or _grass_mesh_key != key:
        _grass_mesh = _build_grass_mesh()
        _grass_mesh_key = key
    return _grass_mesh

func _build_grass_mesh() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var half_w: float = grass_plane_width * 0.5
    var tip_half_w: float = max(half_w * grass_tip_width_ratio, 0.01)
    var height: float = grass_plane_height
    var plane_count: int = int(max(grass_planes_per_clump, 1))
    for i in range(plane_count):
        var angle: float = float(i) * PI / float(plane_count)
        var dir := Vector3(cos(angle), 0.0, sin(angle))
        var right := Vector3(-sin(angle), 0.0, cos(angle))
        var offset := dir * grass_clump_radius
        var tip_offset := dir * (grass_clump_radius * 0.35)
        var p0 := offset + (-right * half_w)
        var p1 := offset + (right * half_w)
        var p2 := tip_offset + (-right * tip_half_w) + Vector3(0.0, height, 0.0)
        var p3 := tip_offset + (right * tip_half_w) + Vector3(0.0, height, 0.0)
        var normal := Vector3.UP
        st.set_normal(normal)
        st.set_uv(Vector2(0.0, 1.0))
        st.add_vertex(p0)
        st.set_normal(normal)
        st.set_uv(Vector2(1.0, 1.0))
        st.add_vertex(p1)
        st.set_normal(normal)
        st.set_uv(Vector2(0.0, 0.0))
        st.add_vertex(p2)
        st.set_normal(normal)
        st.set_uv(Vector2(1.0, 1.0))
        st.add_vertex(p1)
        st.set_normal(normal)
        st.set_uv(Vector2(1.0, 0.0))
        st.add_vertex(p3)
        st.set_normal(normal)
        st.set_uv(Vector2(0.0, 0.0))
        st.add_vertex(p2)
    return st.commit()

func _get_grass_material(settings: Dictionary) -> Material:
    if _materials.has("grass_blade"):
        var cached: Material
        cached = _materials["grass_blade"]
        if cached is ShaderMaterial:
            _apply_grass_shader_params(cached, settings)
        elif cached is StandardMaterial3D:
            cached.albedo_color = settings.get("grass_color", Color(0.25, 0.4, 0.25))
        return cached
    var shader: Shader = _load_shader(grass_shader_path)
    if shader:
        var mat: ShaderMaterial = ShaderMaterial.new()
        mat.shader = shader
        _apply_grass_shader_params(mat, settings)
        _materials["grass_blade"] = mat
        return mat
    var fallback: StandardMaterial3D = StandardMaterial3D.new()
    fallback.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    fallback.albedo_color = settings.get("grass_color", Color(0.25, 0.4, 0.25))
    fallback.roughness = grass_roughness
    fallback.metallic = grass_metallic
    fallback.cull_mode = BaseMaterial3D.CULL_DISABLED
    fallback.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    fallback.alpha_scissor_threshold = grass_alpha_clip
    var tex: Texture2D = _load_texture(grass_texture_path)
    if tex:
        fallback.albedo_texture = tex
    _materials["grass_blade"] = fallback
    return fallback

func _apply_grass_shader_params(mat: ShaderMaterial, settings: Dictionary) -> void:
    var base_color: Color = settings.get("grass_color", Color(0.25, 0.4, 0.25))
    var tex: Texture2D = _load_texture(grass_texture_path)
    if tex:
        mat.set_shader_parameter("albedo_tex", tex)
    mat.set_shader_parameter("base_tint", base_color)
    mat.set_shader_parameter("alpha_clip", grass_alpha_clip)
    mat.set_shader_parameter("roughness", grass_roughness)
    mat.set_shader_parameter("metallic", grass_metallic)
    mat.set_shader_parameter("wind_strength", grass_wind_strength)
    mat.set_shader_parameter("wind_speed", grass_wind_speed)
    mat.set_shader_parameter("wind_scale", grass_wind_scale)
    mat.set_shader_parameter("wind_dir", grass_wind_direction)
    mat.set_shader_parameter("max_distance", grass_lod_max_distance)
    mat.set_shader_parameter("fade_distance", grass_lod_fade_distance)
    mat.set_shader_parameter("sss_strength", grass_subsurface_strength)

func _random_pos(rng: RandomNumberGenerator) -> Vector3:
    var tries := 0
    while tries < 20:
        var x := rng.randf_range(-area_size * 0.5, area_size * 0.5)
        var z := rng.randf_range(-area_size * 0.5, area_size * 0.5)
        if Vector2(x, z).length() >= clear_radius:
            var y := _get_height(x, z)
            return Vector3(x, y, z)
        tries += 1
    return Vector3(0.0, _get_height(0.0, 0.0), 0.0)

func _build_grass_cluster_centers(rng: RandomNumberGenerator, count: int, grass_profile: Dictionary) -> Array:
    var centers: Array = []
    for i in range(max(1, count)):
        centers.append(_random_pos_filtered(rng, grass_profile))
    return centers

func _random_grass_pos(rng: RandomNumberGenerator, centers: Array, grass_profile: Dictionary) -> Vector3:
    if centers.is_empty():
        return _random_pos_filtered(rng, grass_profile)
    var tries := 0
    while tries < 28:
        var center: Vector3 = centers[rng.randi_range(0, centers.size() - 1)]
        var angle: float = rng.randf_range(0.0, TAU)
        var radius: float = grass_cluster_radius * sqrt(rng.randf())
        var x: float = center.x + cos(angle) * radius + rng.randf_range(-grass_cluster_jitter, grass_cluster_jitter)
        var z: float = center.z + sin(angle) * radius + rng.randf_range(-grass_cluster_jitter, grass_cluster_jitter)
        x = clamp(x, -area_size * 0.5, area_size * 0.5)
        z = clamp(z, -area_size * 0.5, area_size * 0.5)
        var candidate := Vector3(x, _get_height(x, z), z)
        if Vector2(x, z).length() >= clear_radius and _is_grass_allowed(candidate, grass_profile) and rng.randf() <= _get_grass_preference_weight(candidate, grass_profile):
            return candidate
        tries += 1
    return _random_pos_filtered(rng, grass_profile)

func _random_pos_filtered(rng: RandomNumberGenerator, grass_profile: Dictionary) -> Vector3:
    var tries := 0
    while tries < 32:
        var pos := _random_pos(rng)
        if _is_grass_allowed(pos, grass_profile) and rng.randf() <= _get_grass_preference_weight(pos, grass_profile):
            return pos
        tries += 1
    return _random_pos(rng)

func _get_grass_distribution_profile(stage_id: String, region_id: String) -> Dictionary:
    var profile := {
        "road_strip": {},
        "circles": [],
        "prefer_rings": [],
        "prefer_outer_band": {}
    }
    if region_id != "earth":
        return profile
    if stage_id == "earth_intro_path":
        profile["road_strip"] = {
            "center_x": 0.0,
            "half_width": 4.8,
            "z_min": 2.0,
            "z_max": 13.5
        }
        profile["circles"] = [
            {"center": Vector2(-2.6, 8.6), "radius": 2.2},
            {"center": Vector2(-8.0, 4.5), "radius": 1.4},
            {"center": Vector2(-5.8, 7.8), "radius": 1.5},
            {"center": Vector2(5.5, 8.2), "radius": 1.8},
            {"center": Vector2(-1.5, 9.0), "radius": 2.4},
            {"center": Vector2(2.5, 11.0), "radius": 2.8}
        ]
        profile["prefer_rings"] = [
            {"center": Vector2(-2.6, 8.6), "inner": 2.4, "outer": 4.2, "weight": 0.92},
            {"center": Vector2(-1.5, 9.0), "inner": 2.5, "outer": 4.5, "weight": 0.86},
            {"center": Vector2(2.5, 11.0), "inner": 2.9, "outer": 4.9, "weight": 0.82}
        ]
        profile["prefer_outer_band"] = {
            "inner_radius": 8.5,
            "outer_radius": 12.8,
            "weight": 0.78
        }
    return profile

func _is_grass_allowed(pos: Vector3, grass_profile: Dictionary) -> bool:
    if grass_profile.is_empty():
        return true
    var p2 := Vector2(pos.x, pos.z)
    var road_strip: Dictionary = grass_profile.get("road_strip", {})
    if not road_strip.is_empty():
        var center_x: float = float(road_strip.get("center_x", 0.0))
        var half_width: float = float(road_strip.get("half_width", 0.0))
        var z_min: float = float(road_strip.get("z_min", 0.0))
        var z_max: float = float(road_strip.get("z_max", 0.0))
        if p2.x >= center_x - half_width and p2.x <= center_x + half_width and p2.y >= z_min and p2.y <= z_max:
            return false
    var circles: Array = grass_profile.get("circles", [])
    for circle_var in circles:
        var circle: Dictionary = circle_var
        var center: Vector2 = circle.get("center", Vector2.ZERO)
        var radius: float = float(circle.get("radius", 0.0))
        if p2.distance_to(center) <= radius:
            return false
    return true

func _get_grass_preference_weight(pos: Vector3, grass_profile: Dictionary) -> float:
    if grass_profile.is_empty():
        return 1.0
    var p2 := Vector2(pos.x, pos.z)
    var weight := 0.28
    var road_strip: Dictionary = grass_profile.get("road_strip", {})
    if not road_strip.is_empty():
        var center_x: float = float(road_strip.get("center_x", 0.0))
        var half_width: float = float(road_strip.get("half_width", 0.0))
        var z_min: float = float(road_strip.get("z_min", 0.0))
        var z_max: float = float(road_strip.get("z_max", 0.0))
        if p2.y >= z_min and p2.y <= z_max:
            var dx: float = abs(p2.x - center_x)
            if dx > half_width and dx <= half_width + 2.6:
                weight = max(weight, 0.95)
    var prefer_rings: Array = grass_profile.get("prefer_rings", [])
    for ring_var in prefer_rings:
        var ring: Dictionary = ring_var
        var center: Vector2 = ring.get("center", Vector2.ZERO)
        var inner: float = float(ring.get("inner", 0.0))
        var outer: float = float(ring.get("outer", 0.0))
        var ring_weight: float = float(ring.get("weight", 0.75))
        var dist: float = p2.distance_to(center)
        if dist >= inner and dist <= outer:
            weight = max(weight, ring_weight)
    var outer_band: Dictionary = grass_profile.get("prefer_outer_band", {})
    if not outer_band.is_empty():
        var inner_radius: float = float(outer_band.get("inner_radius", 0.0))
        var outer_radius: float = float(outer_band.get("outer_radius", area_size * 0.5))
        var band_weight: float = float(outer_band.get("weight", 0.7))
        var radial_dist: float = p2.length()
        if radial_dist >= inner_radius and radial_dist <= outer_radius:
            weight = max(weight, band_weight)
    return clamp(weight, 0.0, 1.0)

func _make_seed(stage_id: String, region_id: String) -> int:
    return int(hash(stage_id + "_" + region_id))

func _setup_height_noise(seed_value: int) -> void:
    if not height_enabled:
        _height_noise = null
        return
    var noise := FastNoiseLite.new()
    noise.seed = seed_value
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    noise.frequency = height_frequency
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = int(height_octaves)
    noise.fractal_gain = height_gain
    noise.fractal_lacunarity = height_lacunarity
    _height_noise = noise

func _get_height(x: float, z: float) -> float:
    if not height_enabled or _height_noise == null:
        return 0.0
    var n: float = _height_noise.get_noise_2d(x, z)
    var height := n * height_amplitude
    if not flat_center_ground:
        return height
    var dist := Vector2(x, z).length()
    if dist <= flat_center_radius:
        return 0.0
    var transition: float = max(flat_edge_transition, 0.001)
    var edge_weight := smoothstep(flat_center_radius, flat_center_radius + transition, dist)
    return height * edge_weight * flat_edge_height_scale

func _get_region_settings(region_id: String) -> Dictionary:
    match region_id:
        "fire":
            return {
                "grass_count": int(grass_count * 0.4),
                "tree_count": int(tree_count * 0.4),
                "rock_count": int(rock_count * 1.6),
                "water_count": int(water_count * 0.2),
                "flower_count": int(flower_count * 0.2),
                "mound_count": int(mound_count * 1.4),
                "grass_color": Color(0.3, 0.2, 0.15),
                "leaf_color": Color(0.5, 0.2, 0.1),
                "trunk_color": Color(0.35, 0.2, 0.12),
                "rock_color": Color(0.3, 0.2, 0.18),
                "water_color": Color(0.3, 0.15, 0.2, 0.6),
                "flower_color": Color(0.8, 0.35, 0.2),
                "mound_color": Color(0.25, 0.16, 0.12)
            }
        "wood":
            return {
                "grass_count": int(grass_count * 2.0),
                "tree_count": int(tree_count * 1.6),
                "rock_count": int(rock_count * 0.8),
                "water_count": int(water_count * 0.6),
                "flower_count": int(flower_count * 1.4),
                "mound_count": int(mound_count * 1.2),
                "grass_color": Color(0.2, 0.5, 0.25),
                "leaf_color": Color(0.22, 0.6, 0.28),
                "trunk_color": Color(0.35, 0.2, 0.1),
                "rock_color": Color(0.35, 0.35, 0.38),
                "water_color": Color(0.2, 0.4, 0.6, 0.6),
                "flower_color": Color(0.95, 0.85, 0.25),
                "mound_color": Color(0.2, 0.4, 0.22)
            }
        "metal":
            return {
                "grass_count": int(grass_count * 0.5),
                "tree_count": int(tree_count * 0.6),
                "rock_count": int(rock_count * 1.4),
                "water_count": int(water_count * 0.4),
                "flower_count": int(flower_count * 0.3),
                "mound_count": int(mound_count * 1.1),
                "grass_color": Color(0.25, 0.3, 0.25),
                "leaf_color": Color(0.4, 0.5, 0.5),
                "trunk_color": Color(0.35, 0.35, 0.4),
                "rock_color": Color(0.45, 0.45, 0.5),
                "water_color": Color(0.3, 0.4, 0.55, 0.6),
                "flower_color": Color(0.85, 0.85, 0.95),
                "mound_color": Color(0.35, 0.36, 0.4)
            }
        "earth":
            return {
                "grass_count": int(grass_count * 0.82),
                "grass_cluster_count": int(grass_cluster_count * 0.72),
                "tree_count": int(tree_count * 1.0),
                "rock_count": int(rock_count * 1.2),
                "water_count": int(water_count * 0.4),
                "flower_count": int(flower_count * 1.1),
                "mound_count": 0,
                "grass_color": Color(0.42, 0.39, 0.22),
                "leaf_color": Color(0.45, 0.5, 0.2),
                "trunk_color": Color(0.4, 0.25, 0.15),
                "rock_color": Color(0.4, 0.35, 0.25),
                "water_color": Color(0.25, 0.35, 0.45, 0.6),
                "flower_color": Color(0.8, 0.7, 0.3),
                "mound_color": Color(0.3, 0.26, 0.18)
            }
        "water":
            return {
                "grass_count": int(grass_count * 0.6),
                "tree_count": int(tree_count * 0.6),
                "rock_count": int(rock_count * 0.6),
                "water_count": int(water_count * 2.0),
                "flower_count": int(flower_count * 0.6),
                "mound_count": int(mound_count * 0.8),
                "grass_color": Color(0.2, 0.35, 0.4),
                "leaf_color": Color(0.25, 0.45, 0.6),
                "trunk_color": Color(0.3, 0.25, 0.2),
                "rock_color": Color(0.3, 0.35, 0.45),
                "water_color": Color(0.2, 0.45, 0.7, 0.6),
                "flower_color": Color(0.7, 0.85, 0.95),
                "mound_color": Color(0.2, 0.3, 0.35)
            }
        _:
            return {
                "grass_count": grass_count,
                "grass_cluster_count": grass_cluster_count,
                "tree_count": tree_count,
                "rock_count": rock_count,
                "water_count": water_count,
                "flower_count": flower_count,
                "mound_count": mound_count,
                "grass_color": Color(0.25, 0.4, 0.25),
                "leaf_color": Color(0.3, 0.5, 0.3),
                "trunk_color": Color(0.35, 0.2, 0.1),
                "rock_color": Color(0.35, 0.35, 0.35),
                "water_color": Color(0.2, 0.4, 0.6, 0.6),
                "flower_color": Color(0.9, 0.85, 0.2),
                "mound_color": Color(0.3, 0.3, 0.28)
            }

func _make_entry(type_name: String, pos: Vector3, scale: Vector3) -> Dictionary:
    return {
        "type": type_name,
        "pos": _vec3_to_array(pos),
        "scale": _vec3_to_array(scale)
    }

func _vec3_to_array(vec: Vector3) -> Array:
    return [vec.x, vec.y, vec.z]

func _vec3_from_array(arr: Array) -> Vector3:
    if arr.size() < 3:
        return Vector3.ZERO
    return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))

func _save_layout(path: String, layout: Array) -> void:
    var dir := DirAccess.open("user://")
    if dir:
        if not dir.dir_exists("level_layouts"):
            dir.make_dir("level_layouts")
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify(layout, "  "))

func _load_layout(path: String) -> Array:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return []
    var json := JSON.new()
    var err := json.parse(file.get_as_text())
    if err != OK:
        return []
    var data: Variant = json.get_data()
    return data if typeof(data) == TYPE_ARRAY else []

func _ensure_scenes_loaded() -> void:
    if tree_scene == null:
        tree_scene = _try_load_scene("res://assets/polyhaven_nature/fir_sapling/fir_sapling_1k.gltf")
    if rock_scene == null:
        rock_scene = _try_load_scene("res://assets/polyhaven_nature/boulder_01/boulder_01_1k.gltf")
    if grass_scene == null:
        grass_scene = _try_load_scene("res://assets/polyhaven_nature/grass_medium_01/grass_medium_01_1k.gltf")
    if flower_scene == null:
        flower_scene = _try_load_scene("res://assets/polyhaven_nature/dandelion_01/dandelion_01_1k.gltf")

func _try_load_scene(path: String) -> PackedScene:
    if not ResourceLoader.exists(path):
        return null
    var res := ResourceLoader.load(path)
    if res is PackedScene:
        return res
    return null

func _load_texture(path: String) -> Texture2D:
    if path == "" or not ResourceLoader.exists(path):
        return null
    var res := ResourceLoader.load(path)
    return res as Texture2D

func _load_shader(path: String) -> Shader:
    if path == "" or not ResourceLoader.exists(path):
        return null
    var res := ResourceLoader.load(path)
    return res as Shader

func _add_tree_collision(node: Node3D, scale: Vector3) -> void:
    var radius: float = max(scale.x, scale.z) * 0.35
    var height: float = max(1.6, 2.4 * scale.y)
    var shape := CapsuleShape3D.new()
    shape.radius = radius
    shape.height = height
    _add_static_collision(node, shape, Vector3(0, height * 0.5, 0))

func _add_rock_collision(node: Node3D, scale: Vector3) -> void:
    var size: Vector3 = Vector3(scale.x, scale.y, scale.z) * 1.2
    var shape := BoxShape3D.new()
    shape.size = size
    _add_static_collision(node, shape, Vector3(0, size.y * 0.5, 0))

func _add_static_collision(parent: Node3D, shape: Shape3D, offset: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = offset
    var collider := CollisionShape3D.new()
    collider.shape = shape
    body.add_child(collider)
    parent.add_child(body)
