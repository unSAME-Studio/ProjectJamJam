shader_type canvas_item;

// Vertical chrome band over a text label: a bright highlight that slides up
// and down, darker toward the bottom. The per-glyph rainbow comes from the
// WordArt RichTextEffect; this only shades it.
uniform float height = 100.0;
uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float sweep_speed = 0.35;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float t = clamp(lp.y / max(height, 1.0), 0.0, 1.0);
	float band = 0.3 + 0.12 * sin(TIME * sweep_speed * 6.2831);
	float hi = 1.0 - smoothstep(0.0, 0.22, abs(t - band));
	float shade = smoothstep(0.55, 1.0, t) * 0.45;
	vec3 col = COLOR.rgb;
	col = mix(col, vec3(1.0), hi * strength);
	col *= 1.0 - shade * strength;
	COLOR = vec4(col, COLOR.a) * tex;
}
