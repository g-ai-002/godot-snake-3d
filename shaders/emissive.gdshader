shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// 通用自发光材质：菲涅耳边光 + 环绕身体的能量环 + 轻微清漆层。
// use_vertex_color 用于 MultiMesh 蛇身的逐实例渐变。

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 rim_color : source_color = vec4(0.65, 1.0, 0.95, 1.0);
uniform float emission_energy = 1.2;
uniform float rim_strength = 0.85;
uniform float ring_strength = 0.35;
uniform float shape_speed = 1.0;
uniform bool use_vertex_color = false;
uniform float roughness_value = 0.18;
uniform float metallic_value = 0.5;
uniform float energy = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = albedo.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}

	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.6);
	// 沿高度方向流动的环状高光，像鳞片间的能量带
	float rings = 0.5 + 0.5 * sin(world_pos.y * 30.0 - TIME * 3.2 * shape_speed);
	float ring = smoothstep(0.72, 1.0, rings);

	ALBEDO = base * 0.34;
	EMISSION = base * emission_energy * (0.55 + 0.45 * ring)
		+ rim_color.rgb * fres * rim_strength * (0.7 + energy * 0.7)
		+ base * ring * ring_strength;

	RIM = rim_strength * 0.55;
	RIM_TINT = 0.4;
	CLEARCOAT = 0.7;
	CLEARCOAT_ROUGHNESS = 0.12;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	SPECULAR = 0.65;
}
