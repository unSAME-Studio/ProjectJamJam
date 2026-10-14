class_name WordArtLine
extends Control
## 千禧年 WordArt: one line = NAME (poster gradient, white rim, fat dark frame)
## + SUFFIX (flat yellow, thinner dark frame), bent by a live Office-style
## "Wave" envelope with a hard shadow. Mirrors tools/wordart_preview.py.
##
## Three passes, the first two rendered once into SubViewports:
##   1. core   — flat glyphs; name in red, suffix in green
##   2. compose — square dilation (sharp corners), rim, gradient fill
##   3. warp   — this control's TextureRect bends it every frame

const COMPOSE := preload("res://assets/shaders/wordart_compose.gdshader")
const WARP := preload("res://assets/shaders/wordart_warp.gdshader")
const DARK := Color(0.1, 0.03, 0.27)

# Saturated, slightly dark stops: readable on both sky and grass.
const PALETTES := {
	"热彩": ["#ff1f5a", "#ff7a00", "#ffb800", "#18c13a", "#1d6bff", "#8a2cff"],
	"粉蓝紫": ["#ff2e97", "#a43cff", "#3a5bff", "#00a8ff"],
	"红橙金": ["#e0001b", "#ff5a00", "#ffb000"],
	"绿蓝": ["#00c853", "#00b0ff", "#2962ff"],
}

var name_text := ""
var suffix_text := "涌现出来了。"
var glyph_px := 100
var palette := "热彩"
var suffix_color := Color("#ffe100")
var suffix_scale := 0.62
var embolden := 0.45
var tracking := 0.06
var rim := 0.045
var outer := 0.11
var suffix_outer := 0.75      # relative to the suffix's own size
var shadow := 0.075
var stretch := 1.4
var amp := 0.32
var cycles := 1.15
var speed := 0.35

var _vp_core: SubViewport
var _vp_comp: SubViewport
var _display: TextureRect
var _frames_left := 0

static var _font_cache: Dictionary = {}
static var _palette_cache: Dictionary = {}


static func make(p_name: String, p_suffix: String, p_px: int, opts: Dictionary = {}) -> WordArtLine:
	var w := WordArtLine.new()
	w.name_text = p_name
	w.suffix_text = p_suffix
	w.glyph_px = p_px
	for key in opts:
		w.set(key, opts[key])
	return w


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rebuild()


func set_name_text(t: String) -> void:
	name_text = t
	if is_inside_tree():
		rebuild()


static func heavy_font(px: int, emb: float, track: float) -> Font:
	var key := "%d|%.2f|%.2f" % [px, emb, track]
	if _font_cache.has(key):
		return _font_cache[key]
	var fv := FontVariation.new()
	fv.base_font = Boot.font_heavy
	fv.variation_embolden = emb
	fv.spacing_glyph = int(px * track)
	_font_cache[key] = fv
	return fv


static func palette_texture(key: String) -> Texture2D:
	if _palette_cache.has(key):
		return _palette_cache[key]
	var stops: Array = PALETTES.get(key, PALETTES["热彩"])
	var g := Gradient.new()
	var cols := PackedColorArray()
	var offs := PackedFloat32Array()
	for i in stops.size():
		cols.append(Color(stops[i]))
		offs.append(float(i) / max(stops.size() - 1, 1))
	g.colors = cols
	g.offsets = offs
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	_palette_cache[key] = t
	return t


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var px := glyph_px
	var spx := int(px * suffix_scale)
	var f_name := heavy_font(px, embolden, tracking)
	var f_suf := heavy_font(spx, embolden, tracking)
	var r_out := px * outer
	var pad := int(r_out + px * 0.08) + 4
	var sh := int(px * shadow)
	var wn := f_name.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var ws := f_suf.get_string_size(suffix_text, HORIZONTAL_ALIGNMENT_LEFT, -1, spx).x if suffix_text != "" else 0.0
	var asc := f_name.get_ascent(px)
	var desc := f_name.get_descent(px)
	var src := Vector2i(int(wn + ws) + pad * 2 + sh, int(asc + desc) + pad * 2 + sh)

	# pass 1: flat glyphs
	_vp_core = _viewport(src)
	_vp_core.add_child(_label(name_text, f_name, px, Color(1, 0, 0), Vector2(pad, pad)))
	if suffix_text != "":
		var sy := pad + asc - f_suf.get_ascent(spx)
		_vp_core.add_child(_label(suffix_text, f_suf, spx, Color(0, 1, 0), Vector2(pad + wn, sy)))

	# pass 2: dilate + colour, once
	_vp_comp = _viewport(src)
	var rect := ColorRect.new()
	rect.size = Vector2(src)
	var cm := ShaderMaterial.new()
	cm.shader = COMPOSE
	cm.set_shader_parameter("core_tex", _vp_core.get_texture())
	cm.set_shader_parameter("tex_px", Vector2(src))
	cm.set_shader_parameter("r_rim", px * rim)
	cm.set_shader_parameter("r_out", r_out)
	cm.set_shader_parameter("r_out_s", spx * outer * suffix_outer)
	cm.set_shader_parameter("name_x0", float(pad))
	cm.set_shader_parameter("name_x1", float(pad) + wn)
	cm.set_shader_parameter("glyph_top", float(pad) + asc * 0.12)
	cm.set_shader_parameter("glyph_h", asc * 0.95)
	cm.set_shader_parameter("palette", palette_texture(palette))
	cm.set_shader_parameter("suffix_color", suffix_color)
	cm.set_shader_parameter("dark", DARK)
	rect.material = cm
	_vp_comp.add_child(rect)

	# pass 3: live envelope
	var band := src.y * stretch
	var out_h := band * (1.0 + amp * 2.2) + 4.0
	size = Vector2(src.x, out_h)
	pivot_offset = size * 0.5
	_display = TextureRect.new()
	_display.texture = _vp_comp.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.size = size
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wm := ShaderMaterial.new()
	wm.shader = WARP
	wm.set_shader_parameter("band_frac", band / out_h)
	wm.set_shader_parameter("amp", amp)
	# one wave cycle per ~7 chars, so a 1–2 char name bobs instead of twisting
	var n_chars := float(name_text.length() + suffix_text.length())
	wm.set_shader_parameter("cycles", cycles * clamp(n_chars / 7.0, 0.15, 1.6))
	wm.set_shader_parameter("speed", speed)
	wm.set_shader_parameter("phase0", randf() * TAU)
	wm.set_shader_parameter("shadow_uv", Vector2(float(sh) / src.x, float(sh) / src.y))
	wm.set_shader_parameter("dark", DARK)
	_display.material = wm
	add_child(_display)
	_frames_left = 4


func _viewport(sz: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = sz
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


func _label(t: String, f: Font, px: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	return l


func _process(_delta: float) -> void:
	# The first two passes only need a few frames to settle, then freeze.
	if _frames_left > 0:
		_frames_left -= 1
		if _frames_left == 0:
			if is_instance_valid(_vp_core):
				_vp_core.render_target_update_mode = SubViewport.UPDATE_DISABLED
			if is_instance_valid(_vp_comp):
				_vp_comp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func pop_in(from_scale: float = 1.5) -> void:
	modulate.a = 1.0
	scale = Vector2.ONE * from_scale
	rotation = deg_to_rad(randf_range(-5, 5))
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation", deg_to_rad(randf_range(-2, 2)), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
