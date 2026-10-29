shader_type spatial;
render_mode cull_disabled, blend_add, unshaded, depth_draw_never;

// 护盾：加法混合的能量球壳，菲涅耳边缘 + 经纬网格 + 呼吸闪烁。

uniform vec4 shield_color : source_color = vec4(0.75, 0.6, 1.0, 1.0);
uniform float strength = 0.8;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);

	vec2 p = vec2(atan(world_pos.x, world_pos.z) * 3.2, world_pos.y * 6.4);
	vec2 grid = abs(fract(p) - 0.5);
	float cell = smoothstep(0.44, 0.5, max(grid.x, grid.y));
	float ripple = 0.5 + 0.5 * sin(world_pos.y * 14.0 - TIME * 4.0);

	ALBEDO = shield_color.rgb;
	ALPHA = (fres * 0.6 + cell * 0.12 + ripple * 0.05) * strength;
}
