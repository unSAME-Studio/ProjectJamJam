shader_type spatial;
render_mode cull_disabled;

// 千禧年闪字：按世界坐标 + 时间滚动的彩虹。没有模型的东西用它的名字当模型时也用这个。
uniform float speed : hint_range(0.0, 5.0) = 1.2;
uniform float scale : hint_range(0.05, 5.0) = 0.6;
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.1;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

vec3 rainbow(float t) {
	t = fract(t);
	float r = smoothstep(0.0, 1.0, abs(t * 6.0 - 3.0) - 1.0);
	float g = smoothstep(0.0, 1.0, 2.0 - abs(t * 6.0 - 2.0));
	float b = smoothstep(0.0, 1.0, 2.0 - abs(t * 6.0 - 4.0));
	return clamp(vec3(r, g, b), 0.0, 1.0);
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = (world_pos.x + world_pos.y * 0.7) * scale + TIME * speed;
	vec3 c = mix(vec3(0.6), rainbow(t), saturation) * brightness;
	c = mix(c, vec3(1.0), flash);
	ALBEDO = c;
	EMISSION = c * 0.35;
	ROUGHNESS = 0.6;
}
