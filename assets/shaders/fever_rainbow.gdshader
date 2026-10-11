shader_type canvas_item;
render_mode blend_add;

// 涌现狂热 overlay. Same idea as Love Spinnin's RainbowOverlay (rotating hue
// around the screen centre, additive), but weighted toward the edges so the
// middle of the action stays readable, and pulsing with the beat.
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float speed = 1.2;
uniform float pulse = 4.0;

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 pos = UV - vec2(0.5);
	float ang = atan(pos.y, pos.x);
	float r = length(pos * vec2(1.6, 1.0));
	vec3 rainbow = hsv2rgb(vec3(fract(ang / 6.2831853 + TIME * speed * 0.15), 0.85, 1.0));
	float edge = smoothstep(0.25, 0.85, r);
	float beat = 0.75 + 0.25 * sin(TIME * pulse * 6.2831853 * 0.25);
	COLOR = vec4(rainbow * edge * beat * opacity, 1.0);
}
