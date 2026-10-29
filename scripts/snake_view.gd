class_name SnakeView
extends Node3D

## 3D 蛇：MultiMesh 圆柱蛇身（逐实例渐变）+ 球形关节 + 高细节蛇头 + 地面能量拖尾。
## 圆柱比方盒的法线更平滑，配合清漆与菲涅耳边光，看起来像发光的胶质生物。

const MAX_INSTANCES := 1200
const BODY_Y := 0.46
const BODY_RADIUS := 0.4
const TRAIL_POINTS := 22

var cols := 20
var rows := 20
var colors: Dictionary = Palette.get_theme("neon")

var _segments: MultiMeshInstance3D
var _joints: MultiMeshInstance3D
var _segment_multi: MultiMesh
var _joint_multi: MultiMesh
var _body_material: ShaderMaterial
var _head: Node3D
var _head_material: ShaderMaterial
var _snout_material: ShaderMaterial
var _eye_material: StandardMaterial3D
var _crest_material: StandardMaterial3D
var _tongue_material: StandardMaterial3D
var _jaw_material: StandardMaterial3D
var _tongue: MeshInstance3D
var _shield: MeshInstance3D
var _shield_material: ShaderMaterial
var _head_light: OmniLight3D
var _head_spot: SpotLight3D
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_material: ShaderMaterial
var _trail_points: Array[Vector3] = []
var _time := 0.0
var _dead := false
var _energy := 0.0


func _ready() -> void:
	var body_shader: Shader = preload("res://shaders/emissive.gdshader")

	_body_material = ShaderMaterial.new()
	_body_material.shader = body_shader
	_body_material.set_shader_parameter("albedo", Color.WHITE)
	_body_material.set_shader_parameter("emission_energy", 1.6)
	_body_material.set_shader_parameter("use_vertex_color", true)
	_body_material.set_shader_parameter("ring_strength", 0.3)
	_body_material.set_shader_parameter("roughness_value", 0.16)
	_body_material.set_shader_parameter("metallic_value", 0.55)

	# 身体：圆柱沿 Y 轴，用四元数把它旋转到线段方向，串起来就是无接缝的蛇身
	_segment_multi = MultiMesh.new()
	_segment_multi.transform_format = MultiMesh.TRANSFORM_3D
	_segment_multi.use_colors = true
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = BODY_RADIUS
	cylinder.bottom_radius = BODY_RADIUS
	cylinder.height = 1.0
	cylinder.radial_segments = 18
	cylinder.rings = 1
	_segment_multi.mesh = cylinder
	_segment_multi.instance_count = MAX_INSTANCES
	_segment_multi.visible_instance_count = 0

	_segments = MultiMeshInstance3D.new()
	_segments.multimesh = _segment_multi
	_segments.material_override = _body_material
	_segments.extra_cull_margin = 64.0
	add_child(_segments)

	_joint_multi = MultiMesh.new()
	_joint_multi.transform_format = MultiMesh.TRANSFORM_3D
	_joint_multi.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = BODY_RADIUS * 1.02
	sphere.height = BODY_RADIUS * 2.04
	sphere.radial_segments = 20
	sphere.rings = 10
	_joint_multi.mesh = sphere
	_joint_multi.instance_count = MAX_INSTANCES
	_joint_multi.visible_instance_count = 0

	_joints = MultiMeshInstance3D.new()
	_joints.multimesh = _joint_multi
	_joints.material_override = _body_material
	_joints.extra_cull_margin = 64.0
	add_child(_joints)

	_build_head(body_shader)
	_build_shield()
	_build_trail()

	apply_colors(colors)


func _build_head(body_shader: Shader) -> void:
	_head = Node3D.new()
	add_child(_head)

	_head_material = ShaderMaterial.new()
	_head_material.shader = body_shader
	_head_material.set_shader_parameter("use_vertex_color", false)
	_head_material.set_shader_parameter("emission_energy", 2.1)
	_head_material.set_shader_parameter("rim_strength", 1.1)
	_head_material.set_shader_parameter("ring_strength", 0.2)
	_head_material.set_shader_parameter("roughness_value", 0.14)
	_head_material.set_shader_parameter("metallic_value", 0.5)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.5
	head_mesh.height = 0.94
	head_mesh.radial_segments = 28
	head_mesh.rings = 14
	var head_instance := MeshInstance3D.new()
	head_instance.mesh = head_mesh
	head_instance.material_override = _head_material
	head_instance.scale = Vector3(1.06, 0.92, 1.16)
	_head.add_child(head_instance)

	# 吻部：让头不再是完美球体，正面更有“生物感”
	_snout_material = ShaderMaterial.new()
	_snout_material.shader = body_shader
	_snout_material.set_shader_parameter("use_vertex_color", false)
	_snout_material.set_shader_parameter("emission_energy", 1.7)
	_snout_material.set_shader_parameter("ring_strength", 0.15)
	var snout_mesh := SphereMesh.new()
	snout_mesh.radius = 0.31
	snout_mesh.height = 0.58
	snout_mesh.radial_segments = 20
	snout_mesh.rings = 10
	var snout := MeshInstance3D.new()
	snout.mesh = snout_mesh
	snout.material_override = _snout_material
	snout.position = Vector3(0.0, -0.06, 0.34)
	snout.scale = Vector3(0.92, 0.72, 0.95)
	_head.add_child(snout)

	_jaw_material = StandardMaterial3D.new()
	_jaw_material.roughness = 0.42
	_jaw_material.metallic = 0.3
	var jaw_mesh := SphereMesh.new()
	jaw_mesh.radius = 0.3
	jaw_mesh.height = 0.5
	jaw_mesh.radial_segments = 18
	jaw_mesh.rings = 8
	var jaw := MeshInstance3D.new()
	jaw.mesh = jaw_mesh
	jaw.material_override = _jaw_material
	jaw.position = Vector3(0.0, -0.22, 0.28)
	jaw.scale = Vector3(0.9, 0.55, 0.86)
	_head.add_child(jaw)

	_eye_material = StandardMaterial3D.new()
	_eye_material.emission_enabled = true
	_eye_material.emission_energy_multiplier = 5.0
	_eye_material.roughness = 0.08
	_eye_material.metallic = 0.2
	var pupil_material := StandardMaterial3D.new()
	pupil_material.albedo_color = Color("#03070c")
	pupil_material.roughness = 0.05
	pupil_material.metallic = 0.1
	for x in [-0.235, 0.235]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.1
		eye_mesh.height = 0.2
		eye_mesh.radial_segments = 14
		eye_mesh.rings = 7
		eye.mesh = eye_mesh
		eye.position = Vector3(x, 0.16, 0.34)
		eye.material_override = _eye_material
		_head.add_child(eye)

		var pupil := MeshInstance3D.new()
		var pupil_mesh := SphereMesh.new()
		pupil_mesh.radius = 0.045
		pupil_mesh.height = 0.09
		pupil_mesh.radial_segments = 10
		pupil_mesh.rings = 5
		pupil.mesh = pupil_mesh
		pupil.position = Vector3(x, 0.16, 0.42)
		pupil.material_override = pupil_material
		_head.add_child(pupil)

	_crest_material = StandardMaterial3D.new()
	_crest_material.emission_enabled = true
	_crest_material.emission_energy_multiplier = 2.6
	_crest_material.roughness = 0.24
	_crest_material.metallic = 0.5
	for side in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(0.05, 0.3, 0.48)
		fin.mesh = fin_mesh
		fin.material_override = _crest_material
		fin.position = Vector3(0.17 * side, 0.4, -0.16)
		fin.rotation = Vector3(-0.32, 0.0, -0.34 * side)
		_head.add_child(fin)

	_tongue_material = StandardMaterial3D.new()
	_tongue_material.emission_enabled = true
	_tongue_material.emission_energy_multiplier = 2.0
	_tongue_material.roughness = 0.3
	_tongue = MeshInstance3D.new()
	var tongue_mesh := BoxMesh.new()
	tongue_mesh.size = Vector3(0.05, 0.03, 0.5)
	_tongue.mesh = tongue_mesh
	_tongue.material_override = _tongue_material
	_tongue.position = Vector3(0.0, -0.13, 0.6)
	_tongue.visible = false
	_head.add_child(_tongue)

	_head_light = OmniLight3D.new()
	_head_light.light_energy = 1.1
	_head_light.omni_range = 6.0
	_head_light.position = Vector3(0.0, 0.28, 0.1)
	_head.add_child(_head_light)

	# 头部聚光灯：在雾里打出一道锥形光，蛇走到哪亮到哪
	_head_spot = SpotLight3D.new()
	_head_spot.light_energy = 4.5
	_head_spot.spot_range = 9.0
	_head_spot.spot_angle = 44.0
	_head_spot.spot_angle_attenuation = 1.4
	_head_spot.light_volumetric_fog_energy = 2.5
	_head_spot.position = Vector3(0.0, 0.22, 0.15)
	_head_spot.rotation_degrees = Vector3(-58.0, 180.0, 0.0)
	_head_spot.shadow_enabled = (
		RenderingServer.get_current_rendering_method() == "forward_plus"
	)
	_head.add_child(_head_spot)


func _build_shield() -> void:
	_shield_material = ShaderMaterial.new()
	_shield_material.shader = preload("res://shaders/shield.gdshader")
	_shield = MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius = 0.78
	shell.height = 1.56
	shell.radial_segments = 24
	shell.rings = 12
	_shield.mesh = shell
	_shield.material_override = _shield_material
	_shield.visible = false
	_head.add_child(_shield)


func _build_trail() -> void:
	_trail_material = ShaderMaterial.new()
	_trail_material.shader = preload("res://shaders/trail.gdshader")
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.material_override = _trail_material
	_trail.extra_cull_margin = 64.0
	add_child(_trail)


func configure(new_cols: int, new_rows: int, new_colors: Dictionary) -> void:
	cols = new_cols
	rows = new_rows
	_trail_points.clear()
	apply_colors(new_colors)


func apply_colors(new_colors: Dictionary) -> void:
	colors = new_colors
	_head_material.set_shader_parameter("albedo", colors["head"])
	_head_material.set_shader_parameter("rim_color", colors["body"])
	_snout_material.set_shader_parameter("albedo", colors["head"].darkened(0.12))
	_snout_material.set_shader_parameter("rim_color", colors["body"])
	_eye_material.emission = colors["accent"]
	_crest_material.emission = colors["accent"]
	_tongue_material.emission = colors["danger"]
	_jaw_material.albedo_color = colors["body"].darkened(0.6)
	_shield_material.set_shader_parameter("shield_color", colors["accent"])
	_trail_material.set_shader_parameter("trail_color", colors["glow"])
	_head_light.light_color = colors["body"]
	_head_spot.light_color = colors["glow"]
	if _dead:
		_set_dead_look()


func set_energy(value: float) -> void:
	if is_equal_approx(_energy, value):
		return
	_energy = value
	_body_material.set_shader_parameter("energy", value)
	_head_material.set_shader_parameter("energy", value)
	_snout_material.set_shader_parameter("energy", value)


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
		var length := delta.length()
		if length > 2.0 or length < 0.001:
			continue
		var axis := Vector3.UP
		var target := delta / length
		var basis := Basis(Quaternion(axis, target)) * Basis.from_scale(Vector3(1.0, length + 0.06, 1.0))
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
	_update_trail(points[0])


func set_dead(value: bool) -> void:
	if _dead == value:
		return
	_dead = value
	if value:
		_set_dead_look()
	else:
		_head_material.set_shader_parameter("albedo", colors["head"])
		_head_material.set_shader_parameter("rim_color", colors["body"])
		_snout_material.set_shader_parameter("albedo", colors["head"].darkened(0.12))
		_eye_material.emission = colors["accent"]
		_eye_material.emission_energy_multiplier = 5.0
		_crest_material.emission = colors["accent"]
		_trail_material.set_shader_parameter("trail_color", colors["glow"])


func _set_dead_look() -> void:
	_head_material.set_shader_parameter("albedo", colors["danger"])
	_head_material.set_shader_parameter("rim_color", colors["danger"])
	_snout_material.set_shader_parameter("albedo", colors["danger"].darkened(0.15))
	_eye_material.emission = colors["danger"]
	_eye_material.emission_energy_multiplier = 9.0
	_crest_material.emission = colors["danger"]
	_trail_material.set_shader_parameter("trail_color", colors["danger"])


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


func _update_trail(head_pos: Vector3) -> void:
	var flat := Vector3(head_pos.x, 0.035, head_pos.z)
	if _trail_points.is_empty():
		_trail_points.append(flat)
	elif flat.distance_to(_trail_points[_trail_points.size() - 1]) > 2.5:
		# 传送门跳跃时断开拖尾，避免拉出一条横跨棋盘的直线
		_trail_points.clear()
		_trail_points.append(flat)
	elif flat.distance_to(_trail_points[_trail_points.size() - 1]) > 0.05:
		_trail_points.append(flat)
		if _trail_points.size() > TRAIL_POINTS:
			_trail_points.pop_front()

	_trail_mesh.clear_surfaces()
	if _trail_points.size() < 2:
		return

	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var total := float(_trail_points.size())
	for i in _trail_points.size():
		var point := _trail_points[i]
		var prev := _trail_points[maxi(i - 1, 0)]
		var next := _trail_points[mini(i + 1, _trail_points.size() - 1)]
		var dir := next - prev
		dir.y = 0.0
		if dir.length() < 0.0001:
			dir = Vector3(0.0, 0.0, 1.0)
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0.0, dir.x)
		var t := float(i) / total
		var width := 0.34 * (0.25 + t * 0.75)
		var alpha := pow(t, 1.6) * 0.75
		_trail_mesh.surface_set_color(Color(1.0, 1.0, 1.0, alpha))
		_trail_mesh.surface_add_vertex(point + side * width)
		_trail_mesh.surface_set_color(Color(1.0, 1.0, 1.0, alpha))
		_trail_mesh.surface_add_vertex(point - side * width)
	_trail_mesh.surface_end()


func _process(delta: float) -> void:
	_time += delta
	if _shield.visible:
		var pulse := 1.0 + sin(_time * 4.0) * 0.04
		_shield.scale = Vector3(pulse, pulse, pulse)
	_head_light.light_energy = 1.0 + sin(_time * 3.0) * 0.2 + _energy * 0.4
	_head_spot.light_energy = 4.0 + sin(_time * 2.4) * 0.5 + _energy * 1.5

	var flick := sin(_time * 4.6)
	_tongue.visible = not _dead and flick > 0.45
	if _tongue.visible:
		_tongue.scale.z = 0.7 + flick * 0.4
