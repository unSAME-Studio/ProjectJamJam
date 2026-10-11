class_name WordArtLine
extends Control
## One line of 千禧年 WordArt built from stacked RichTextLabels that all carry
## the same text and the same [wa] wave, so they move together:
##   1. extrusion  — N dark copies stepping down-right (hard 3D block shadow)
##   2. rim        — per-segment coloured outline over a dark outer outline
##   3. fill       — wordart_fill shader: rainbow / chrome / fire / flat
## Segments let one line mix looks, e.g. a rainbow NAME + a POP suffix.

const FILL_SHADER := preload("res://assets/shaders/wordart_fill.gdshader")
const DARK := Color(0.1, 0.03, 0.27)

# style -> [fill colour (sentinels read by the shader), rim colour]
const STYLES := {
	"rainbow": [Color(1, 0, 1), Color.WHITE],
	"chrome": [Color(0, 1, 1), Color.WHITE],
	"fire": [Color(1, 0, 0.5), Color(1.0, 0.92, 0.2)],
	"pop": [Color.WHITE, Color(0.9, 0.08, 0.12)],
	"pop_yellow": [Color(1.0, 0.95, 0.23), Color(0.9, 0.08, 0.12)],
	"blue": [Color(0.15, 0.35, 1.0), Color.WHITE],
}

var segments: Array = []     # [{text, style, scale, font}]
var glyph_px := 100
var extrude_steps := 7
var extrude_px := 0.022      # per step, in glyph units
var wave_amp := 0.1          # in glyph units
var wave_freq := 2.2
var arch := 0.3
var line_width := 2800.0
var _layers: Array = []
var _fill: RichTextLabel

static var _fx: WaveFx


static func fx() -> WaveFx:
	if _fx == null:
		_fx = WaveFx.new()
	return _fx


static func make(p_segments: Array, p_glyph_px: int, opts: Dictionary = {}) -> WordArtLine:
	var w := WordArtLine.new()
	w.segments = p_segments
	w.glyph_px = p_glyph_px
	for key in opts:
		w.set(key, opts[key])
	return w


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rebuild()


func rebuild() -> void:
	for l in _layers:
		l.queue_free()
	_layers.clear()
	var h := glyph_px * 1.9
	size = Vector2(line_width, h)
	pivot_offset = size * 0.5
	var outer := int(glyph_px * 0.2)
	var rim := int(glyph_px * 0.1)
	var step := glyph_px * extrude_px
	# 1. extrusion, back to front
	for i in range(extrude_steps, 0, -1):
		var l := _layer(_bb("dark"), outer)
		l.position = Vector2(step * i, step * i)
		l.add_theme_color_override("default_color", DARK)
		l.add_theme_color_override("font_outline_color", DARK)
	# 2. outer dark outline + coloured rim (rim outline drawn over the dark one)
	var o := _layer(_bb("dark"), outer)
	o.add_theme_color_override("default_color", DARK)
	o.add_theme_color_override("font_outline_color", DARK)
	_layer(_bb("rim"), rim)
	# 3. fill
	_fill = _layer(_bb("fill"), 0)
	var m := ShaderMaterial.new()
	m.shader = FILL_SHADER
	m.set_shader_parameter("box_size", size)
	m.set_shader_parameter("glyph_px", float(glyph_px))
	_fill.material = m


func _layer(bb: String, outline: int) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_contents = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = size
	l.install_effect(fx())
	l.add_theme_font_override("normal_font", Boot.font_heavy)
	l.add_theme_font_size_override("normal_font_size", glyph_px)
	l.add_theme_constant_override("outline_size", outline)
	l.text = bb
	add_child(l)
	_layers.append(l)
	return l


func _bb(pass_kind: String) -> String:
	var n := 0
	for s in segments:
		n += String(s.text).length()
	var body := ""
	for s in segments:
		var st: Array = STYLES.get(s.get("style", "rainbow"), STYLES.rainbow)
		var px := int(glyph_px * float(s.get("scale", 1.0)))
		var font_path: String = s.get("font", Boot.FONT_HEAVY_PATH)
		var open := "[font=%s][font_size=%d]" % [font_path, px]
		var close := "[/font_size][/font]"
		match pass_kind:
			"rim":
				var rc: Color = st[1]
				open += "[color=#%s][outline_color=#%s]" % [rc.to_html(false), rc.to_html(false)]
				close = "[/outline_color][/color]" + close
			"fill":
				var fc: Color = st[0]
				open += "[color=#%s]" % fc.to_html(false)
				close = "[/color]" + close
		body += open + String(s.text) + close
	return "[center][wa n=%d amp=%d freq=%.2f arch=%.2f]%s[/wa][/center]" % [
		n, int(glyph_px * wave_amp), wave_freq, arch, body]


func pop_in(from_scale: float = 1.5) -> void:
	modulate.a = 1.0
	scale = Vector2.ONE * from_scale
	rotation = deg_to_rad(randf_range(-6, 6))
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation", deg_to_rad(randf_range(-2, 2)), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
