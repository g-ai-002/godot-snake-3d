shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// 通用自发光材质：可选乘以 MultiMesh 实例颜色，用于蛇身渐变。

uniform vec4 albedo : source_color = vec4(1.0);
uniform float emission_energy = 1.2;
uniform bool use_vertex_color = false;
uniform float roughness_value = 0.3;
uniform float metallic_value = 0.2;

void fragment() {
	vec3 base = albedo.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	ALBEDO = base;
	EMISSION = base * emission_energy;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
}
