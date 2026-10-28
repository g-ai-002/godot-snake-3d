class_name BoardView
extends Node3D

## 3D 棋盘：自发光地面、厚底座、发光边框、MultiMesh 墙体与传送门光环。

const CELL := 1.0
const WALL_HEIGHT := 0.9

var cols := 20
var rows := 20
var walls := {}
var portals := {}
var colors: Dictionary = Palette.get_theme("neon")
var time := 0.0

var _floor: MeshInstance3D
var _slab: MeshInstance3D
var _floor_material: ShaderMaterial
var _wall_multi: MultiMeshInstance3D
var _wall_material: StandardMaterial3D
var _rim: Node3D
var _portal_root: Node3D
var _portal_material: StandardMaterial3D


func _ready() -> void:
	_floor = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	_floor.mesh = plane
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = preload("res://shaders/board.gdshader")
	_floor.material_override = _floor_material
	add_child(_floor)

	_slab = MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(1.0, 0.7, 1.0)
	_slab.mesh = slab_mesh
	var slab_material := StandardMaterial3D.new()
	slab_material.albedo_color = Color("#050b12")
	slab_material.roughness = 0.9
	_slab.material_override = slab_material
	add_child(_slab)

	_rim = Node3D.new()
	add_child(_rim)

	_wall_material = StandardMaterial3D.new()
	_wall_material.emission_enabled = true
	_wall_material.roughness = 0.4
	_wall_material.metallic = 0.25

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

	_portal_material = StandardMaterial3D.new()
	_portal_material.emission_enabled = true
	_portal_material.emission_energy_multiplier = 2.6
	_portal_material.metallic = 0.4
	_portal_material.roughness = 0.3

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
	_floor_material.set_shader_parameter("glow_strength", 0.9)

	_wall_material.albedo_color = colors["wall"].darkened(0.25)
	_wall_material.emission = colors["wall_edge"]
	_wall_material.emission_energy_multiplier = 0.5

	_portal_material.albedo_color = colors["special"].darkened(0.65)
	_portal_material.emission = colors["special"]

	_rebuild_walls()
	_rebuild_rim()
	_rebuild_portals()


func _rebuild_walls() -> void:
	var multi: MultiMesh = _wall_multi.multimesh
	multi.instance_count = maxi(1, walls.size())
	var index := 0
	for cell in walls:
		var position := cell_world(cell) + Vector3(0.0, WALL_HEIGHT * 0.5, 0.0)
		multi.set_instance_transform(index, Transform3D(Basis(), position))
		index += 1
	_wall_multi.visible = not walls.is_empty()


func _rebuild_rim() -> void:
	for child in _rim.get_children():
		child.queue_free()

	var material := StandardMaterial3D.new()
	material.albedo_color = colors["frame"].darkened(0.55)
	material.emission_enabled = true
	material.emission = colors["frame"]
	material.emission_energy_multiplier = 1.2
	material.metallic = 0.4
	material.roughness = 0.3

	var half_x := cols * 0.5 + 0.4
	var half_z := rows * 0.5 + 0.4
	var pieces := [
		[Vector3(0.0, 0.16, -half_z), Vector3(cols + 1.6, 0.32, 0.4)],
		[Vector3(0.0, 0.16, half_z), Vector3(cols + 1.6, 0.32, 0.4)],
		[Vector3(-half_x, 0.16, 0.0), Vector3(0.4, 0.32, rows + 1.6)],
		[Vector3(half_x, 0.16, 0.0), Vector3(0.4, 0.32, rows + 1.6)],
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


func _rebuild_portals() -> void:
	for child in _portal_root.get_children():
		child.queue_free()

	for cell in portals:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.28
		torus.outer_radius = 0.4
		torus.rings = 32
		torus.ring_segments = 12
		ring.mesh = torus
		ring.position = cell_world(cell) + Vector3(0.0, 0.6, 0.0)
		ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		ring.material_override = _portal_material
		ring.set_meta("phase", randf() * TAU)
		_portal_root.add_child(ring)

		var light := OmniLight3D.new()
		light.light_color = colors["special"]
		light.light_energy = 1.2
		light.omni_range = 3.0
		ring.add_child(light)


func _process(delta: float) -> void:
	if portals.is_empty():
		return
	time += delta
	for ring in _portal_root.get_children():
		if not is_instance_valid(ring):
			continue
		var phase: float = ring.get_meta("phase", 0.0)
		ring.scale = Vector3.ONE * (1.0 + sin(time * 2.0 + phase) * 0.07)
		var light := ring.get_child(0) as OmniLight3D if ring.get_child_count() > 0 else null
		if light != null:
			light.light_energy = 1.1 + sin(time * 3.0 + phase) * 0.3


func cell_world(cell: Vector2i) -> Vector3:
	return Vector3(
		cell.x + 0.5 - cols * 0.5,
		0.0,
		cell.y + 0.5 - rows * 0.5
	)
