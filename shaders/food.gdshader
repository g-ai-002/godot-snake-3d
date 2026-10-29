shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// 食物/道具：内核自发光 + 菲涅耳外壳 + 呼吸脉冲。

uniform vec4 base_color : source_color = vec4(1.0, 0.3, 0.4, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.85, 0.9, 1.0);
uniform float emission_energy = 2.6;

void fragment() {
	float pulse = 0.84 + 0.16 * sin(TIME * 4.2);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);

	ALBEDO = base_color.rgb * 0.55;
	EMISSION = base_color.rgb * emission_energy * pulse * (0.8 + 0.6 * fres)
		+ core_color.rgb * (1.0 - fres) * 0.6;
	ROUGHNESS = 0.2;
	METALLIC = 0.35;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.08;
}
