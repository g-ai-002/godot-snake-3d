shader_type sky;

// 程序化深空：渐变天幕 + 双色星云 + 地平线辉光 + 闪烁星点。
// 只用于 Forward+ / Mobile；Web 的 GL Compatibility 回退到 ProceduralSkyMaterial。

uniform vec4 top_color : source_color = vec4(0.008, 0.015, 0.035, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.04, 0.08, 0.15, 1.0);
uniform vec4 nebula_color : source_color = vec4(0.12, 0.55, 0.62, 1.0);
uniform vec4 nebula_color_b : source_color = vec4(0.5, 0.18, 0.58, 1.0);
uniform float nebula_strength = 0.42;
uniform float horizon_glow = 0.3;
uniform float star_brightness = 1.4;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.56);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise2(p);
		p *= 2.04;
		amplitude *= 0.5;
	}
	return value;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(horizon_color.rgb, top_color.rgb, pow(h, 0.55));

	// 地平线附近的一层薄雾辉光
	col += horizon_color.rgb * horizon_glow * exp(-abs(dir.y) * 8.0);

	// 星云：用球面投影避免极点拉伸
	vec2 sph = vec2(atan(dir.x, dir.z), asin(clamp(dir.y, -1.0, 1.0)));
	vec2 uv = sph * vec2(1.0, 2.0);
	float n = fbm(uv * 1.3 + vec2(TIME * 0.004, 0.0));
	float n2 = fbm(uv * 2.8 - vec2(TIME * 0.006, 0.0));
	vec3 nebula = mix(nebula_color.rgb, nebula_color_b.rgb, smoothstep(0.3, 0.8, n2));
	float mask = pow(smoothstep(0.42, 0.95, n), 2.2) * smoothstep(-0.05, 0.45, dir.y);
	col += nebula * mask * nebula_strength;

	// 星点：球面网格哈希，轻微闪烁
	vec2 star_uv = sph * 120.0;
	vec2 cell = floor(star_uv);
	vec2 local = fract(star_uv) - 0.5;
	float rnd = hash21(cell);
	float star = smoothstep(0.11, 0.0, length(local)) * step(0.87, rnd);
	star *= 0.45 + 0.55 * sin(TIME * 1.7 + rnd * 43.0);
	col += vec3(0.82, 0.9, 1.0) * star * star_brightness;

	COLOR = col;
}
