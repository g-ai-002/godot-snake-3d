class_name SnakeView
extends Node3D

## 3D 蛇：MultiMesh 盒状身体（实例颜色渐变）+ 球形关节 + 发光蛇头。

const MAX_INSTANCES := 1200
const BODY_Y := 0.46
const BODY_SIZE := 0.8

var cols := 20
var rows := 20
var colors: Dictionary = Palette.get_theme("neon")

var _segments: MultiMeshInstance3D
var _joints: MultiMeshInstance3D
var _segment_multi: MultiMesh
var _joint_multi: MultiMesh
var _head: Node3D
var _head_material: ShaderMaterial
var _eye_material: StandardMaterial3D
var _shield: MeshInstance3D
var _shield_material: StandardMaterial3D
var _head_light: OmniLight3D
var _time := 0.0
var _dead := false


func _ready() -> void:
	var body_shader: Shader = preload("res://shaders/emissive.gdshader")
	var body_material := ShaderMaterial.new()
	body_material.shader = body_shader
	body_material.set_shader_parameter("albedo", Color.WHITE)
	body_material.set_shader_parameter("emission_energy", 1.05)
	body_material.set_shader_parameter("use_vertex_color", true)

	_segment_multi = MultiMesh.new()
	_segment_multi.transform_format = MultiMesh.TRANSFORM_3D
	_segment_multi.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(BODY_SIZE, BODY_SIZE, 1.0)
	_segment_multi.mesh = box
	_segment_multi.instance_count = MAX_INSTANCES
	_segment_multi.visible_instance_count = 0

	_segments = MultiMeshInstance3D.new()
	_segments.multimesh = _segment_multi
	_segments.material_override = body_material
	_segments.extra_cull_margin = 64.0
	add_child(_segments)

	_joint_multi = MultiMesh.new()
	_joint_multi.transform_format = MultiMesh.TRANSFORM_3D
	_joint_multi.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = BODY_SIZE * 0.52
	sphere.height = BODY_SIZE * 1.04
	sphere.radial_segments = 18
	sphere.rings = 9
	_joint_multi.mesh = sphere
	_joint_multi.instance_count = MAX_INSTANCES
	_joint_multi.visible_instance_count = 0

	_joints = MultiMeshInstance3D.new()
	_joints.multimesh = _joint_multi
	_joints.material_override = body_material
	_joints.extra_cull_margin = 64.0
	add_child(_joints)

	_head = Node3D.new()
	add_child(_head)

	_head_material = ShaderMaterial.new()
	_head_material.shader = body_shader
	_head_material.set_shader_parameter("use_vertex_color", false)
	_head_material.set_shader_parameter("emission_energy", 1.5)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.5
	head_mesh.height = 0.94
	head_mesh.radial_segments = 24
	head_mesh.rings = 12
	var head_instance := MeshInstance3D.new()
	head_instance.mesh = head_mesh
	head_instance.material_override = _head_material
	_head.add_child(head_instance)

	_eye_material = StandardMaterial3D.new()
	_eye_material.albedo_color = Color("#050d14")
	_eye_material.roughness = 0.2
	_eye_material.metallic = 0.1
	for x in [-0.23, 0.23]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.105
		eye_mesh.height = 0.21
		eye_mesh.radial_segments = 12
		eye_mesh.rings = 6
		eye.mesh = eye_mesh
		eye.position = Vector3(x, 0.17, 0.39)
		eye.material_override = _eye_material
		_head.add_child(eye)

	_shield_material = StandardMaterial3D.new()
	_shield_material.emission_enabled = true
	_shield_material.emission_energy_multiplier = 2.0
	_shield_material.roughness = 0.2
	_shield_material.metallic = 0.5
	_shield = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.72
	torus.rings = 32
	torus.ring_segments = 10
	_shield.mesh = torus
	_shield.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_shield.material_override = _shield_material
	_shield.visible = false
	_head.add_child(_shield)

	_head_light = OmniLight3D.new()
	_head_light.light_energy = 0.8
	_head_light.omni_range = 4.0
	_head_light.position = Vector3(0.0, 0.25, 0.0)
	_head.add_child(_head_light)

	apply_colors(colors)


func configure(new_cols: int, new_rows: int, new_colors: Dictionary) -> void:
	cols = new_cols
	rows = new_rows
	apply_colors(new_colors)


func apply_colors(new_colors: Dictionary) -> void:
	colors = new_colors
	_head_material.set_shader_parameter("albedo", colors["head"])
	_shield_material.albedo_color = Color(colors["accent"], 0.2)
	_shield_material.emission = colors["accent"]
	_head_light.light_color = colors["body"]
	if _dead:
		_set_dead_look()


func update_snake(
	previous: Array[Vector2i],
	current: Array[Vector2i],
	progress: float,
	direction: Vector2i,
	is_dead: bool,
	shielded: bool
) -> void:
	if current.is_empty():
		return

	var points: Array[Vector3] = []
	for i in current.size():
		var to := cell_world(current[i])
		var from := to
		if i < previous.size():
			from = cell_world(previous[i])
		elif not previous.is_empty():
			from = cell_world(previous[previous.size() - 1])
		points.append(from.lerp(to, progress))

	var count := points.size()
	var segment_count := 0
	for i in count - 1:
		var a := points[i]
		var b := points[i + 1]
		var delta := b - a
		if delta.length() > 2.0:
			continue
		var yaw := atan2(delta.x, delta.z)
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(1.0, 1.0, delta.length() + 0.12))
		_segment_multi.set_instance_transform(
			segment_count,
			Transform3D(basis, (a + b) * 0.5)
		)
		_segment_multi.set_instance_color(segment_count, body_color(float(i) / float(count)))
		segment_count += 1
	_segment_multi.visible_instance_count = segment_count

	var joint_count := 0
	for i in count:
		_joint_multi.set_instance_transform(joint_count, Transform3D(Basis(), points[i]))
		_joint_multi.set_instance_color(joint_count, body_color(float(i) / float(count)))
		joint_count += 1
	_joint_multi.visible_instance_count = joint_count

	_head.position = points[0]
	_head.rotation.y = atan2(float(direction.x), float(direction.y))
	_shield.visible = shielded
	set_dead(is_dead)


func set_dead(value: bool) -> void:
	if _dead == value:
		return
	_dead = value
	if value:
		_set_dead_look()
	else:
		_head_material.set_shader_parameter("albedo", colors["head"])
		_eye_material.emission_enabled = false
		_head.rotation.z = 0.0


func _set_dead_look() -> void:
	_head_material.set_shader_parameter("albedo", colors["danger"])
	_eye_material.emission_enabled = true
	_eye_material.emission = colors["danger"]
	_eye_material.emission_energy_multiplier = 3.0
	_head.rotation.z = 0.35


func body_color(t: float) -> Color:
	if t < 0.35:
		return colors["head"].lerp(colors["body"], t / 0.35)
	return colors["body"].lerp(colors["tail"], (t - 0.35) / 0.65)


func cell_world(cell: Vector2i) -> Vector3:
	return Vector3(
		cell.x + 0.5 - cols * 0.5,
		BODY_Y,
		cell.y + 0.5 - rows * 0.5
	)


func _process(delta: float) -> void:
	_time += delta
	if _shield.visible:
		var pulse := 1.0 + sin(_time * 5.0) * 0.05
		_shield.scale = Vector3(pulse, pulse, pulse)
	_head_light.light_energy = 0.7 + sin(_time * 3.0) * 0.15
