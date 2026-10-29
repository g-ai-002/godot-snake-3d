shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// 棋盘之外的大地面：暗色金属 + 稀疏网格 + 远处融入雾气，负责撑起空间纵深。

uniform vec4 base_color : source_color = vec4(0.005, 0.009, 0.018, 1.0);
uniform vec4 grid_color : source_color = vec4(0.05, 0.16, 0.2, 1.0);
uniform float grid_scale = 0.25;
uniform float fade_distance = 70.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 cell = p * grid_scale;
	vec2 edge = min(fract(cell), 1.0 - fract(cell));
	float line = 1.0 - smoothstep(0.0, 0.02, min(edge.x, edge.y));

	float dist = length(p);
	float fade = smoothstep(fade_distance, 6.0, dist);

	ALBEDO = base_color.rgb;
	EMISSION = grid_color.rgb * line * 0.35 * fade;
	ROUGHNESS = 0.24;
	METALLIC = 0.55;
}
