shader_type spatial;
render_mode cull_disabled, blend_add, unshaded, depth_draw_never;

// 食物上方直冲天空的光柱：加法混合 + 上淡出 + 流动条纹，远远就能看到食物位置。

uniform vec4 beam_color : source_color = vec4(1.0, 0.4, 0.5, 1.0);
uniform float strength = 0.5;
uniform float streak_count = 26.0;

void fragment() {
	float fade = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.7);
	float streak = 0.5 + 0.5 * sin(UV.x * streak_count + TIME * 2.4);
	float band = 0.6 + 0.4 * sin(UV.y * 12.0 - TIME * 1.6);

	ALBEDO = beam_color.rgb;
	ALPHA = fade * (0.22 + 0.4 * streak) * band * strength;
}
