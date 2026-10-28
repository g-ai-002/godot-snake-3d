class_name CameraRig
extends Node3D

## 可环绕的 3D 镜头：右键拖动 / Q E 调整方位，滚轮缩放，死亡时抖动。

var base_distance := 30.0
var distance := 30.0
var target_distance := 30.0
var yaw := 0.0
var target_yaw := 0.0
var pitch := deg_to_rad(55.0)
var target_pitch := deg_to_rad(55.0)
var shake := 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.fov = 44.0
	camera.near = 0.1
	camera.far = 300.0
	_place()


func configure(new_cols: int, new_rows: int) -> void:
	base_distance = maxf(float(new_cols), float(new_rows)) * 1.6 + 10.0
	distance = base_distance
	target_distance = base_distance
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


func _process(delta: float) -> void:
	var smoothing := 1.0 - pow(0.0006, delta)
	yaw = lerp_angle(yaw, target_yaw, smoothing)
	pitch = lerpf(pitch, target_pitch, smoothing)
	distance = lerpf(distance, target_distance, smoothing)

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
	camera.position = Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)
