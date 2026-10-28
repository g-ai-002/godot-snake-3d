class_name FoodView
extends Node3D

## 3D 食物/道具：自发光网格 + 悬浮光环 + 点光源 + 环绕粒子。

const KIND_COLORS := {
	"speed_up": Color("#ffd166"),
	"slow_down": Color("#6ec6ff"),
	"shield": Color("#c09bff"),
	"magnet": Color("#ff8fd1"),
	"double": Color("#ffe066"),
}

var colors: Dictionary = Palette.get_theme("neon")
var kind := ""

var _pivot: Node3D
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _light: OmniLight3D
var _particles: GPUParticles3D
var _particle_material: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)

	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/food.gdshader")
	_mesh = MeshInstance3D.new()
	_mesh.material_override = _material
	_pivot.add_child(_mesh)

	_ring_material = StandardMaterial3D.new()
	_ring_material.emission_enabled = true
	_ring_material.emission_energy_multiplier = 1.8
	_ring_material.roughness = 0.25
	_ring_material.metallic = 0.6
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.56
	torus.rings = 32
	torus.ring_segments = 8
	_ring.mesh = torus
	_ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_ring.material_override = _ring_material
	_pivot.add_child(_ring)

	_light = OmniLight3D.new()
	_light.omni_range = 4.0
	_light.light_energy = 1.2
	_light.shadow_enabled = false
	_pivot.add_child(_light)

	_particles = GPUParticles3D.new()
	_particles.amount = 18
	_particles.lifetime = 1.3
	_particles.preprocess = 1.0
	_particles.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.42
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0
	process.initial_velocity_min = 0.15
	process.initial_velocity_max = 0.6
	process.gravity = Vector3(0.0, 0.35, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.2
	_particles.process_material = process
	var spark := SphereMesh.new()
	spark.radius = 0.035
	spark.height = 0.07
	_particle_material = StandardMaterial3D.new()
	_particle_material.emission_enabled = true
	_particle_material.emission_energy_multiplier = 4.0
	spark.material = _particle_material
	_particles.draw_pass_1 = spark
	_particles.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	_pivot.add_child(_particles)


func configure(new_kind: String, new_colors: Dictionary) -> void:
	kind = new_kind
	colors = new_colors
	var color := current_color()
	_material.set_shader_parameter("base_color", color)
	_mesh.mesh = _shape_mesh(kind)
	_mesh.scale = Vector3(1.55, 1.0, 1.0) if kind == "double" else Vector3.ONE
	_ring_material.albedo_color = Color(color, 0.3)
	_ring_material.emission = color
	_light.light_color = color
	_particle_material.albedo_color = color
	_particle_material.emission = color
	_particles.emitting = true


func current_color() -> Color:
	if kind == "":
		return colors["food"]
	return KIND_COLORS.get(kind, colors["accent"])


func _process(delta: float) -> void:
	_time += delta
	_pivot.position.y = 0.12 + sin(_time * 2.4) * 0.1
	_pivot.rotation.y += delta * 0.9
	var pulse := 1.0 + sin(_time * 2.0) * 0.06
	_ring.scale = Vector3(pulse, pulse, pulse)
	_light.light_energy = 1.1 + sin(_time * 3.5) * 0.25


func _shape_mesh(shape_kind: String) -> Mesh:
	var result: Mesh
	match shape_kind:
		"speed_up":
			var prism := PrismMesh.new()
			prism.size = Vector3(0.46, 0.5, 0.46)
			result = prism
		"slow_down":
			var box := BoxMesh.new()
			box.size = Vector3(0.44, 0.44, 0.44)
			result = box
		"shield":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.18
			torus.outer_radius = 0.3
			torus.rings = 24
			torus.ring_segments = 8
			result = torus
		"magnet":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.2
			cylinder.bottom_radius = 0.28
			cylinder.height = 0.5
			result = cylinder
		"double":
			var sphere := SphereMesh.new()
			sphere.radius = 0.24
			sphere.height = 0.48
			result = sphere
		_:
			var apple := SphereMesh.new()
			apple.radius = 0.26
			apple.height = 0.52
			result = apple
	return result
