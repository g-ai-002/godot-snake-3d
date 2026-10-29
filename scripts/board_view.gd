class_name BoardView
extends Node3D

## 3D 棋盘：湿滑发光地面 + 厚底座 + 发光棱边墙体 + 传送门 + 四角光柱。
## 四角聚光灯配合体积雾形成光锥，是这一版“电影感”的主要来源。

const CELL := 1.0
const WALL_HEIGHT := 0.9
const GROUND_SIZE := 260.0

var cols := 20
var rows := 20
var walls := {}
var portals := {}
var colors: Dictionary = Palette.get_theme("neon")
var time := 0.0

var _floor: MeshInstance3D
var _slab: MeshInstance3D
var _ground: MeshInstance3D
var _floor_material: ShaderMaterial
var _ground_material: ShaderMaterial
var _wall_multi: MultiMeshInstance3D
var _wall_cap: MultiMeshInstance3D
var _wall_material: ShaderMaterial
var _rim: Node3D
var _pillars: Node3D
var _portal_root: Node3D
var _portal_material: StandardMaterial3D
var _portal_disc_material: StandardMaterial3D
var _energy := 0.0


func _ready() -> void:
	_floor = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	_floor.mesh = plane
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = preload("res://shaders/board.gdshader")
	_floor.material_override = _floor_material
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor)

	_slab = MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(1.0, 0.7, 1.0)
	_slab.mesh = slab_mesh
	var slab_material := StandardMaterial3D.new()
	slab_material.albedo_color = Color("#04080e")
	slab_material.roughness = 0.55
	slab_material.metallic = 0.6
	_slab.material_override = slab_material
	add_child(_slab)

	_ground = MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	_ground.mesh = ground_mesh
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = preload("res://shaders/ground.gdshader")
	_ground.material_override = _ground_material
	_ground.position = Vector3(0.0, -0.76, 0.0)
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ground)

	_wall_material = ShaderMaterial.new()
	_wall_material.shader = preload("res://shaders/wall.gdshader")
	_wall_material.set_shader_parameter("wall_height", WALL_HEIGHT)

	_wall_multi = MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.92, WALL_HEIGHT, 0.92)
	multi.mesh = box
	multi.instance_count = 1
	_wall_multi.multimesh = multi
	_wall_multi.material_override = _wall_material
	_wall_multi.extra_cull_margin = 64.0
	add_child(_wall_multi)

	var cap_material := StandardMaterial3D.new()
	cap_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cap_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cap_material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)

	_wall_cap = MultiMeshInstance3D.new()
	var cap_multi := MultiMesh.new()
	cap_multi.transform_format = MultiMesh.TRANSFORM_3D
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(0.98, 0.045, 0.98)
	cap_multi.mesh = cap_box
	cap_multi.instance_count = 1
	_wall_cap.multimesh = cap_multi
	_wall_cap.material_override = cap_material
	_wall_cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall_cap.extra_cull_margin = 64.0
	add_child(_wall_cap)

	_rim = Node3D.new()
	add_child(_rim)

	_pillars = Node3D.new()
	add_child(_pillars)

	_portal_material = StandardMaterial3D.new()
	_portal_material.emission_enabled = true
	_portal_material.emission_energy_multiplier = 5.0
	_portal_material.metallic = 0.4
	_portal_material.roughness = 0.25

	_portal_disc_material = StandardMaterial3D.new()
	_portal_disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_portal_disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_portal_disc_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_portal_disc_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_portal_root = Node3D.new()
	add_child(_portal_root)


func configure(
	new_cols: int,
	new_rows: int,
	new_walls: Dictionary,
	new_portals: Dictionary,
	new_colors: Dictionary
) -> void:
	cols = new_cols
	rows = new_rows
	walls = new_walls
	portals = new_portals
	colors = new_colors

	var plane: PlaneMesh = _floor.mesh
	plane.size = Vector2(cols, rows)
	var slab_mesh: BoxMesh = _slab.mesh
	slab_mesh.size = Vector3(cols + 1.6, 0.7, rows + 1.6)
	_slab.position = Vector3(0.0, -0.36, 0.0)

	_floor_material.set_shader_parameter("base_color", colors["board"])
	_floor_material.set_shader_parameter("line_color", colors["grid"])
	_floor_material.set_shader_parameter("glow_color", colors["glow"])
	_floor_material.set_shader_parameter("accent_color", colors["accent_alt"])
	_floor_material.set_shader_parameter("glow_strength", 1.5)
	_floor_material.set_shader_parameter("board_size", Vector2(cols, rows))
	_floor_material.set_shader_parameter("energy", _energy)

	_ground_material.set_shader_parameter("base_color", colors["bg_bottom"].darkened(0.4))
	_ground_material.set_shader_parameter("grid_color", colors["grid"])

	_wall_material.set_shader_parameter("albedo_color", colors["wall"].darkened(0.2))
	_wall_material.set_shader_parameter("edge_color", colors["wall_edge"])
	_wall_material.set_shader_parameter("edge_energy", 2.2)
	_wall_material.set_shader_parameter("energy", _energy)

	var cap_material := _wall_cap.material_override as StandardMaterial3D
	cap_material.albedo_color = Color(colors["wall_edge"], 0.9)

	_portal_material.albedo_color = colors["special"].darkened(0.6)
	_portal_material.emission = colors["special"]
	_portal_disc_material.albedo_color = Color(colors["special"], 0.35)

	_rebuild_walls()
	_rebuild_rim()
	_rebuild_pillars()
	_rebuild_portals()


func set_energy(value: float) -> void:
	if is_equal_approx(_energy, value):
		return
	_energy = value
	_floor_material.set_shader_parameter("energy", value)
	_wall_material.set_shader_parameter("energy", value)


func _rebuild_walls() -> void:
	var multi: MultiMesh = _wall_multi.multimesh
	var cap: MultiMesh = _wall_cap.multimesh
	var count := maxi(1, walls.size())
	multi.instance_count = count
	cap.instance_count = count
	var index := 0
	for cell in walls:
		var base := cell_world(cell)
		multi.set_instance_transform(
			index, Transform3D(Basis(), base + Vector3(0.0, WALL_HEIGHT * 0.5, 0.0))
		)
		cap.set_instance_transform(
			index, Transform3D(Basis(), base + Vector3(0.0, WALL_HEIGHT + 0.01, 0.0))
		)
		index += 1
	_wall_multi.visible = not walls.is_empty()
	_wall_cap.visible = not walls.is_empty()


func _rebuild_rim() -> void:
	for child in _rim.get_children():
		child.queue_free()

	var material := StandardMaterial3D.new()
	material.albedo_color = colors["frame"].darkened(0.5)
	material.emission_enabled = true
	material.emission = colors["frame"]
	material.emission_energy_multiplier = 2.6
	material.metallic = 0.6
	material.roughness = 0.2

	var half_x := cols * 0.5 + 0.4
	var half_z := rows * 0.5 + 0.4
	var pieces := [
		[Vector3(0.0, 0.16, -half_z), Vector3(cols + 1.6, 0.24, 0.3)],
		[Vector3(0.0, 0.16, half_z), Vector3(cols + 1.6, 0.24, 0.3)],
		[Vector3(-half_x, 0.16, 0.0), Vector3(0.3, 0.24, rows + 1.6)],
		[Vector3(half_x, 0.16, 0.0), Vector3(0.3, 0.24, rows + 1.6)],
	]
	for piece in pieces:
		var size: Vector3 = piece[1]
		var box := BoxMesh.new()
		box.size = size
		var instance := MeshInstance3D.new()
		instance.mesh = box
		instance.position = piece[0]
		instance.material_override = material
		_rim.add_child(instance)


func _rebuild_pillars() -> void:
	for child in _pillars.get_children():
		child.queue_free()

	var column_material := StandardMaterial3D.new()
	column_material.albedo_color = colors["panel"].darkened(0.45)
	column_material.roughness = 0.28
	column_material.metallic = 0.85

	var glow_material := StandardMaterial3D.new()
	glow_material.emission_enabled = true
	glow_material.emission_energy_multiplier = 4.0

	var forward_plus := RenderingServer.get_current_rendering_method() == "forward_plus"
	var offset := Vector2(cols, rows) * 0.5 + Vector2(2.4, 2.4)
	var corners := [
		[Vector3(-offset.x, 0.0, -offset.y), colors["accent"]],
		[Vector3(offset.x, 0.0, -offset.y), colors["special"]],
		[Vector3(-offset.x, 0.0, offset.y), colors["special"]],
		[Vector3(offset.x, 0.0, offset.y), colors["accent"]],
	]
	for corner in corners:
		var base: Vector3 = corner[0]
		var tint: Color = corner[1]
		var column := MeshInstance3D.new()
		var column_mesh := CylinderMesh.new()
		column_mesh.top_radius = 0.34
		column_mesh.bottom_radius = 0.46
		column_mesh.height = 3.6
		column_mesh.radial_segments = 18
		column.mesh = column_mesh
		column.position = base + Vector3(0.0, 1.8, 0.0)
		column.material_override = column_material
		_pillars.add_child(column)

		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.34
		ring_mesh.outer_radius = 0.46
		ring_mesh.rings = 28
		ring_mesh.ring_segments = 8
		ring.mesh = ring_mesh
		ring.position = base + Vector3(0.0, 3.55, 0.0)
		ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		var ring_mat := glow_material.duplicate() as StandardMaterial3D
		ring_mat.emission = tint
		ring.material_override = ring_mat
		_pillars.add_child(ring)

		var spot := SpotLight3D.new()
		spot.position = base + Vector3(0.0, 3.5, 0.0)
		spot.light_color = tint
		spot.light_energy = 5.0
		spot.spot_range = 30.0
		spot.spot_angle = 42.0
		spot.spot_angle_attenuation = 1.3
		spot.light_volumetric_fog_energy = 1.3
		spot.shadow_enabled = forward_plus and base.x > 0.0 and base.z > 0.0
		spot.light_specular = 0.6
		_pillars.add_child(spot)
		spot.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)


func _rebuild_portals() -> void:
	for child in _portal_root.get_children():
		child.queue_free()

	for cell in portals:
		var root := Node3D.new()
		root.position = cell_world(cell) + Vector3(0.0, 0.55, 0.0)
		root.set_meta("phase", randf() * TAU)
		_portal_root.add_child(root)

		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.28
		torus.outer_radius = 0.4
		torus.rings = 32
		torus.ring_segments = 12
		ring.mesh = torus
		ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		ring.material_override = _portal_material
		root.add_child(ring)

		var disc := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.5, 0.5)
		disc.mesh = quad
		disc.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		disc.material_override = _portal_disc_material
		root.add_child(disc)

		var light := OmniLight3D.new()
		light.light_color = colors["special"]
		light.light_energy = 2.2
		light.omni_range = 4.0
		light.light_volumetric_fog_energy = 1.5
		root.add_child(light)


func _process(delta: float) -> void:
	if portals.is_empty():
		return
	time += delta
	for root in _portal_root.get_children():
		if not is_instance_valid(root):
			continue
		var phase: float = root.get_meta("phase", 0.0)
		root.rotation.y += delta * 0.8
		root.scale = Vector3.ONE * (1.0 + sin(time * 2.0 + phase) * 0.07)
		if root.get_child_count() > 2:
			var light := root.get_child(2) as OmniLight3D
			if light != null:
				light.light_energy = 2.0 + sin(time * 3.0 + phase) * 0.6


func cell_world(cell: Vector2i) -> Vector3:
	return Vector3(
		cell.x + 0.5 - cols * 0.5,
		0.0,
		cell.y + 0.5 - rows * 0.5
	)
