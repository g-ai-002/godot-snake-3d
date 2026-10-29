shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// 墙体：深色金属 + 顶部发光棱边 + 菲涅耳轮廓 + 缓慢上行的扫描线。

uniform vec4 albedo_color : source_color = vec4(0.05, 0.09, 0.14, 1.0);
uniform vec4 edge_color : source_color = vec4(0.2, 0.85, 0.95, 1.0);
uniform float edge_energy = 2.0;
uniform float wall_height = 0.9;
uniform float energy = 0.0;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.56);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	float t = clamp(world_pos.y / wall_height, 0.0, 1.0);

	float top_edge = smoothstep(0.88, 1.0, t);
	float scan = smoothstep(0.86, 1.0, sin(world_pos.y * 34.0 - TIME * 2.2) * 0.5 + 0.5);
	float specks = hash21(floor(world_pos.xz * 8.0)) * 0.25;

	ALBEDO = albedo_color.rgb * (0.85 + specks);
	EMISSION = edge_color.rgb * top_edge * edge_energy
		+ edge_color.rgb * fres * 0.55
		+ edge_color.rgb * scan * 0.18
		+ edge_color.rgb * energy * 0.35;
	ROUGHNESS = 0.3;
	METALLIC = 0.65;
	SPECULAR = 0.65;
}
