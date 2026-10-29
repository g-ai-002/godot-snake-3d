shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// 蛇在地面上留下的能量拖尾：顶点色负责渐隐，整体颜色由主题注入。

uniform vec4 trail_color : source_color = vec4(0.2, 1.0, 0.75, 1.0);
uniform float strength = 0.55;

void fragment() {
	ALBEDO = trail_color.rgb * COLOR.rgb;
	ALPHA = COLOR.a * trail_color.a * strength;
}
