shader_type canvas_item;

// Fill layer of a WordArtLine. Glyph colour picks the fill:
//   #ff00ff  rainbow, bands bent by a moving sine wave
//   #00ffff  chrome (sky blue → white horizon → dark → pale)
//   #ff0080  fire (red bottom → yellow top, wavy boundary)
//   anything else: kept as a flat colour, plus the same top gloss.
uniform vec2 box_size = vec2(1000.0, 200.0);
uniform float glyph_px = 100.0;
uniform float speed = 0.35;
uniform float wave_amp = 0.12;
uniform float hue_span = 0.85;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

bool is_key(vec3 c, vec3 key) {
	return distance(c, key) < 0.06;
}

void fragment() {
	float a = COLOR.a;
	vec3 key = COLOR.rgb;
	float x = lp.x / glyph_px;                          // in glyph units
	float y = (lp.y - (box_size.y * 0.5 - glyph_px * 0.55)) / glyph_px;  // 0 top .. 1 bottom of the glyph band
	float wobble = sin(y * 6.0 + x * 2.2 - TIME * 3.0);
	vec3 col = key;
	if (is_key(key, vec3(1.0, 0.0, 1.0))) {
		float h = x * hue_span * 0.18 + wobble * wave_amp - TIME * speed;
		col = hsv2rgb(vec3(fract(h), 0.92, 1.0));
	} else if (is_key(key, vec3(0.0, 1.0, 1.0))) {
		float t = clamp(y + wobble * 0.06, 0.0, 1.0);
		vec3 sky = vec3(0.35, 0.75, 1.0);
		vec3 hor = vec3(1.0, 1.0, 1.0);
		vec3 dark = vec3(0.12, 0.1, 0.35);
		vec3 low = vec3(0.75, 0.6, 1.0);
		col = t < 0.5 ? mix(sky, hor, smoothstep(0.0, 0.5, t)) : (t < 0.58 ? mix(hor, dark, smoothstep(0.5, 0.58, t)) : mix(dark, low, smoothstep(0.58, 1.0, t)));
	} else if (is_key(key, vec3(1.0, 0.0, 0.5))) {
		float t = clamp(y + wobble * 0.08, 0.0, 1.0);
		col = mix(vec3(1.0, 0.95, 0.2), vec3(0.95, 0.05, 0.1), smoothstep(0.25, 0.85, t));
	}
	// print gloss: lighter top third, slightly darker bottom
	col = mix(col, vec3(1.0), smoothstep(0.38, 0.0, y) * 0.35);
	col *= 1.0 - smoothstep(0.75, 1.1, y) * 0.18;
	COLOR = vec4(col, a);
}
