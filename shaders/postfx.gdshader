shader_type canvas_item;
render_mode unshaded;

// 3D 屏幕后处理：色差 + 暗角 + 电影调色 + 胶片颗粒 + 轻微柔光。
// Forward+ 下柔光交给环境 Glow；GL Compatibility 没有 Glow，此时用 bloom_strength 补偿。

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float bloom_strength = 0.0;
uniform float bloom_threshold = 0.62;
uniform float aberration = 0.0024;
uniform float vignette_strength = 0.62;
uniform float grain = 0.03;
uniform float exposure = 1.06;
uniform float contrast = 1.06;
uniform float saturation = 1.1;
uniform float desaturate = 0.0;
uniform float pulse = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.02, 0.05, 0.12, 1.0);
uniform vec4 highlight_tint : source_color = vec4(1.0, 0.95, 0.88, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.56);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 cc = SCREEN_UV - 0.5;
	float r2 = dot(cc, cc);
	vec2 uv = SCREEN_UV + cc * r2 * 0.018;

	float ca = (aberration + pulse * 0.007) * (0.2 + r2 * 3.2);
	vec3 col;
	col.r = texture(screen_texture, uv + cc * ca).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - cc * ca).b;

	if (bloom_strength > 0.001) {
		vec3 bloom = vec3(0.0);
		float weight_sum = 0.0;
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			float angle = fi * 2.39996;
			float radius = (0.2 + fi / 7.0) * 18.0;
			vec2 offset = vec2(cos(angle), sin(angle)) * radius * SCREEN_PIXEL_SIZE;
			vec3 sample_color = texture(screen_texture, uv + offset).rgb;
			float luma = max(max(sample_color.r, sample_color.g), sample_color.b);
			float weight = 1.0 - fi / 8.0 * 0.7;
			bloom += sample_color * smoothstep(bloom_threshold, bloom_threshold + 0.4, luma) * weight;
			weight_sum += weight;
		}
		col += bloom / max(weight_sum, 0.001) * bloom_strength;
	}

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, col * mix(shadow_tint.rgb * 9.0, highlight_tint.rgb, smoothstep(0.0, 0.7, luma)), 0.16);
	col = mix(vec3(luma), col, saturation * (1.0 - desaturate * 0.9));
	col = (col - 0.5) * contrast + 0.5;
	col = clamp(col, 0.0, 1.0);
	col = mix(col, col * (2.51 * col + 0.03) / (col * (2.43 * col + 0.59) + 0.14), 0.4);
	col *= exposure;

	float vig = 1.0 - vignette_strength * smoothstep(0.08, 0.6, r2 * 1.6);
	col *= vig;

	float noise = hash21(SCREEN_UV / max(SCREEN_PIXEL_SIZE, vec2(0.000001)) + fract(TIME) * 137.0) - 0.5;
	col += noise * grain;

	col = mix(col, flash_color.rgb, clamp(flash, 0.0, 1.0));

	COLOR = vec4(col, 1.0);
}
