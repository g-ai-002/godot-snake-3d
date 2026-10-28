shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// 棋盘地面：世界坐标网格 + 中心辉光 + 缓慢脉冲。

uniform vec4 base_color : source_color = vec4(0.02, 0.04, 0.08, 1.0);
uniform vec4 line_color : source_color = vec4(0.1, 0.5, 0.6, 1.0);
uniform vec4 glow_color : source_color = vec4(0.2, 0.9, 0.7, 1.0);
uniform float glow_strength = 0.8;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 width = max(fwidth(p), vec2(0.0001));
	vec2 grid = abs(fract(p - 0.5) - 0.5) / width;
	float line = 1.0 - smoothstep(0.0, 1.6, min(grid.x, grid.y));
	float pulse = 0.8 + 0.2 * sin(TIME * 1.4 - length(p) * 0.3);

	ALBEDO = mix(base_color.rgb, line_color.rgb, line * 0.6);
	EMISSION = glow_color.rgb * line * glow_strength * pulse
		+ glow_color.rgb * smoothstep(16.0, 0.0, length(p)) * 0.05;
	ROUGHNESS = 0.42;
	METALLIC = 0.12;
}
