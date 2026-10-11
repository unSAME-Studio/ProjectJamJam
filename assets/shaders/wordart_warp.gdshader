shader_type canvas_item;

// Pass 3 of a WordArtLine: the Office-WordArt "Wave" envelope, live.
// Each column of the composed text is squeezed between a top and a bottom
// curve that travel along the line, plus a hard shadow sampled in the
// unwarped space so it bends with the letters.
uniform float band_frac = 0.6;   // source height / output height
uniform float amp = 0.32;
uniform float cycles = 1.15;
uniform float speed = 0.35;      // wave cycles per second
uniform float phase0 = 0.0;
uniform vec2 shadow_uv = vec2(0.01, 0.04);
uniform vec4 dark : source_color = vec4(0.1, 0.03, 0.27, 1.0);

varying vec4 tint;

void vertex() {
	tint = COLOR;   // node modulate only; COLOR in fragment() already holds the unwarped texel
}

vec4 src(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

void fragment() {
	float x = UV.x;
	float a = 6.2831853 * x * cycles + phase0 + TIME * speed * 6.2831853;
	float mid = 0.5 + sin(a) * band_frac * amp * 0.55;
	float half_h = band_frac * 0.5 * (1.0 + 0.28 * cos(a));
	float sy = (UV.y - (mid - half_h)) / (2.0 * half_h);
	vec4 c = src(TEXTURE, vec2(x, sy));
	float sh = src(TEXTURE, vec2(x, sy) - shadow_uv).a;
	float out_a = c.a + sh * (1.0 - c.a);
	vec3 rgb = (c.rgb * c.a + dark.rgb * sh * (1.0 - c.a)) / max(out_a, 0.0001);
	COLOR = vec4(rgb * tint.rgb, out_a * tint.a);
}
