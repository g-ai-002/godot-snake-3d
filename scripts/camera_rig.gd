class_name CameraRig
extends Node3D

## 可环绕的 3D 镜头：右键拖动 / Q E 调整方位，滚轮缩放，死亡时抖动。
## 额外提供呼吸感、进食推镜与景深，让画面更像电影镜头而不是固定俯视。

var base_distance := 30.0
var distance := 30.0
var target_distance := 30.0
var yaw := 0.0
var target_yaw := 0.0
var pitch := deg_to_rad(55.0)
var target_pitch := deg_to_rad(55.0)
var shake := 0.0

var _base_fov := 44.0
var _punch := 0.0
var _time := 0.0
var _attributes := CameraAttributesPractical.new()

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.fov = _base_fov
	camera.near = 0.1
	camera.far = 320.0
	_configure_attributes()
	_place()


func _configure_attributes() -> void:
	_attributes.dof_blur_far_enabled = true
	_attributes.dof_blur_far_distance = base_distance + 10.0
	_attributes.dof_blur_far_transition = base_distance * 0.9
	_attributes.dof_blur_amount = 0.05
	_attributes.dof_blur_near_enabled = false
	camera.attributes = _attributes


func configure(new_cols: int, new_rows: int) -> void:
	base_distance = maxf(float(new_cols), float(new_rows)) * 1.6 + 10.0
	distance = base_distance
	target_distance = base_distance
	_attributes.dof_blur_far_distance = base_distance + 10.0
	_attributes.dof_blur_far_transition = base_distance * 0.9
	_place()


func orbit(relative: Vector2) -> void:
	target_yaw -= relative.x * 0.006
	target_pitch = clampf(target_pitch + relative.y * 0.004, deg_to_rad(24.0), deg_to_rad(80.0))


func zoom(steps: int) -> void:
	target_distance = clampf(
		target_distance * pow(1.1, steps),
		base_distance * 0.55,
		base_distance * 1.75
	)


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


## 进食时的轻微推镜，与 shake 分开，避免影响“吃食物不抖动”的行为约定。
func add_punch(amount: float) -> void:
	_punch = maxf(_punch, amount)


func _process(delta: float) -> void:
	_time += delta
	var smoothing := 1.0 - pow(0.0006, delta)
	yaw = lerp_angle(yaw, target_yaw, smoothing)
	pitch = lerpf(pitch, target_pitch, smoothing)
	distance = lerpf(distance, target_distance, smoothing)

	_punch = move_toward(_punch, 0.0, delta * 2.2)
	camera.fov = _base_fov - _punch * 1.1

	if shake > 0.01:
		shake = move_toward(shake, 0.0, delta * 1.5)
		camera.h_offset = randf_range(-shake, shake) * 0.35
		camera.v_offset = randf_range(-shake, shake) * 0.35
	else:
		shake = 0.0
		camera.h_offset = 0.0
		camera.v_offset = 0.0

	_place()


func _place() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	# 极缓慢的呼吸位移，避免画面完全静止显得“死”
	var breath_x := sin(_time * 0.43) * 0.06
	var breath_y := sin(_time * 0.71) * 0.12
	camera.position = Vector3(
		breath_x,
		sin(pitch) * distance + breath_y,
		cos(pitch) * distance
	)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
