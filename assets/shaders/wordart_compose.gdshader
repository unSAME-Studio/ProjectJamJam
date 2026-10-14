shader_type canvas_item;
render_mode blend_disabled;

// Pass 2 of a WordArtLine (rendered once into a SubViewport).
// core_tex: name glyphs in RED, suffix glyphs in GREEN (flat, unwarped).
// Builds, with SQUARE dilation so corners stay sharp:
//   dark outer frame (name r_out, suffix r_out_s) → white rim (name only)
//   → fill (name: palette gradient along x + print gloss; suffix: flat colour)
// Output is straight alpha (blend_disabled), alpha = outer frame coverage.
uniform sampler2D core_tex : filter_linear, repeat_disable;
uniform vec2 tex_px = vec2(1000.0, 200.0);
uniform float r_rim = 5.0;
uniform float r_out = 13.0;
uniform float r_out_s = 6.0;
uniform float name_x0 = 0.0;
uniform float name_x1 = 100.0;
uniform float glyph_top = 0.0;
uniform float glyph_h = 100.0;
uniform sampler2D palette : filter_linear, repeat_disable;
uniform vec4 suffix_color : source_color = vec4(1.0, 0.88, 0.0, 1.0);
uniform vec4 dark : source_color = vec4(0.1, 0.03, 0.27, 1.0);

void fragment() {
	vec2 inv = 1.0 / tex_px;
	vec4 c = texture(core_tex, UV);
	float core_n = min(c.r, c.a);
	float core_s = min(c.g, c.a);
	float out_n = 0.0;
	float out_s = 0.0;
	float rim_n = 0.0;
	float stp = max(r_out / 8.0, 1.0);
	for (int i = -8; i <= 8; i++) {
		for (int j = -8; j <= 8; j++) {
			vec2 off = vec2(float(i), float(j)) * stp;
			vec4 s = texture(core_tex, UV + off * inv);
			float sn = min(s.r, s.a);
			float ss = min(s.g, s.a);
			float d = max(abs(off.x), abs(off.y));
			out_n = max(out_n, sn);
			if (d <= r_rim + 0.01) { rim_n = max(rim_n, sn); }
			if (d <= r_out_s + 0.01) { out_s = max(out_s, ss); }
		}
	}
	// extra fine ring for the thin rim (coarse grid may skip it at small sizes)
	for (int k = 0; k < 16; k++) {
		float ang = float(k) / 16.0 * 6.2831853;
		vec2 dir = vec2(cos(ang), sin(ang));
		dir /= max(abs(dir.x), abs(dir.y));     // project onto the square
		vec4 s = texture(core_tex, UV + dir * r_rim * inv);
		rim_n = max(rim_n, min(s.r, s.a));
		vec4 s2 = texture(core_tex, UV + dir * r_out_s * inv);
		out_s = max(out_s, min(s2.g, s2.a));
	}
	float outer = max(out_n, out_s);
	float rim = max(rim_n, core_s);
	float core = max(core_n, core_s);

	vec2 p = UV * tex_px;
	float u = clamp((p.x - name_x0) / max(name_x1 - name_x0, 1.0), 0.0, 1.0);
	vec3 fill_n = texture(palette, vec2(u, 0.5)).rgb;
	float y = (p.y - glyph_top) / glyph_h;
	fill_n *= 1.0 + 0.35 * clamp(0.42 - y, 0.0, 1.0) * 2.2 - 0.25 * clamp(y - 0.62, 0.0, 1.0) * 2.6;
	vec3 fill = core_n >= core_s ? fill_n : suffix_color.rgb;

	vec3 col = dark.rgb;
	col = mix(col, vec3(1.0), rim);
	col = mix(col, fill, core);
	COLOR = vec4(col, outer);
}
