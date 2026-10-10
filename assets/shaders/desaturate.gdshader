shader_type canvas_item;

// 冷开场：全灰。第一次涌现后从 Logo 落点开始一圈圈上色。
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius : hint_range(0.0, 3.0) = 0.0;
uniform float aspect = 1.78;

void fragment() {
	vec4 col = texture(screen_tex, SCREEN_UV);
	float g = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	vec2 d = (SCREEN_UV - center) * vec2(aspect, 1.0);
	float edge = smoothstep(radius, radius - 0.08, length(d));
	// edge == 1 inside the colored circle
	COLOR = vec4(mix(vec3(g) * 0.9, col.rgb, edge), 1.0);
}
