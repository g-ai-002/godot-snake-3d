shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// 棋盘地面：湿滑金属面板 + 发光缝隙 + 沿对角线流动的能量 + 微表面法线扰动。
// SSR 开启时会反射蛇身与灯光，形成接近实时的镜面质感。
// 噪声采样控制在个位数，保证集成显卡也能跑满帧。

uniform vec4 base_color : source_color = vec4(0.008, 0.016, 0.03, 1.0);
uniform vec4 line_color : source_color = vec4(0.08, 0.4, 0.5, 1.0);
uniform vec4 glow_color : source_color = vec4(0.2, 0.95, 0.72, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.25, 0.62, 1.0);
uniform float glow_strength = 1.4;
uniform float energy = 0.0;

varying vec3 world_pos;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 local = fract(p);
	vec2 edge = min(local, 1.0 - local);

	float seam = smoothstep(0.0, 0.035, min(edge.x, edge.y));
	float line = 1.0 - smoothstep(0.0, 0.012, min(edge.x, edge.y));

	float grain = noise2(p * 2.4) * 0.6 + noise2(p * 7.0) * 0.4;
	float micro = noise2(p * 24.0);

	vec3 base = base_color.rgb * (0.7 + 0.65 * grain);
	ALBEDO = mix(base * 1.5, base * 0.55, seam);
	ALBEDO = mix(ALBEDO, base_color.rgb * 0.35, (1.0 - seam) * 0.6);

	// 用噪声梯度扰动法线，制造打磨不均的金属反光
	float nx = noise2(p * 9.0 + vec2(0.03, 0.0)) - noise2(p * 9.0 - vec2(0.03, 0.0));
	float nz = noise2(p * 9.0 + vec2(0.0, 0.03)) - noise2(p * 9.0 - vec2(0.0, 0.03));
	NORMAL = normalize(NORMAL + vec3(nx, 0.0, nz) * 0.32);

	float flow = 0.5 + 0.5 * sin(TIME * 1.5 - (p.x + p.y) * 0.5);
	float scan = smoothstep(0.9, 0.0, abs(fract((p.x + p.y) * 0.02 - TIME * 0.05) - 0.5));

	vec3 emission = glow_color.rgb * line * glow_strength * (0.6 + 0.4 * flow);
	emission += accent_color.rgb * line * scan * (0.35 + energy * 1.2);
	emission += line_color.rgb * smoothstep(0.06, 0.0, min(edge.x, edge.y)) * 0.25;
	EMISSION = emission;

	ROUGHNESS = mix(0.14, 0.4, micro) + (1.0 - seam) * 0.25;
	METALLIC = 0.72;
	SPECULAR = 0.6;
}
