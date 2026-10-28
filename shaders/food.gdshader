shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// 食物/道具：呼吸式自发光。

uniform vec4 base_color : source_color = vec4(1.0, 0.3, 0.4, 1.0);
uniform float emission_energy = 2.2;

void fragment() {
	float pulse = 0.82 + 0.18 * sin(TIME * 4.0);
	ALBEDO = base_color.rgb;
	EMISSION = base_color.rgb * emission_energy * pulse;
	ROUGHNESS = 0.24;
	METALLIC = 0.3;
}
