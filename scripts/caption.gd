class_name Caption
extends Control
## One caption = NAME (WordArt rainbow wave, chunky display font, chrome band,
## extruded shadow) + SUFFIX (「涌现出来了。」in a different voice: round font,
## white fill, fat colored outline, on a rainbow bar for bigger tiers).
## Fullscreen captions also get a starburst behind them.

const CHROME := preload("res://assets/shaders/wordart_chrome.gdshader")

var name_text := ""
var suffix_text := ""
var tier := 1
var fullscreen := false
var _name_front: RichTextLabel
var _name_back: RichTextLabel
var _suffix: RichTextLabel
var _bar: TextureRect
var _burst: Starburst
var _count := 1

static var _effect: WordArtEffect


static func effect() -> WordArtEffect:
	if _effect == null:
		_effect = WordArtEffect.new()
	return _effect


func setup(p_name: String, p_suffix: String, p_tier: int, p_fullscreen: bool = false) -> void:
	name_text = p_name
	suffix_text = p_suffix
	tier = p_tier
	fullscreen = p_fullscreen
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func set_count(n: int) -> void:
	_count = n
	_refresh_text()


func _name_size() -> int:
	if fullscreen:
		return 150 + tier * 8
	return 50 + tier * 12


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var ns := _name_size()
	var ss := int(ns * 0.5)
	var name_chars: int = max(name_text.length() + (3 if _count > 1 else 0), 1)
	var suffix_chars: int = max(suffix_text.length(), 1)
	var name_w := int(name_chars * ns * 1.15) + ns
	var name_h := int(ns * 1.55)
	var suffix_w := int(suffix_chars * ss * 1.1) + ss
	var suffix_h := int(ss * 1.5)
	var w: int = max(name_w, suffix_w) + 40
	var h: int = name_h + suffix_h
	size = Vector2(w, h)
	pivot_offset = size * 0.5

	if fullscreen or tier >= 4:
		_burst = Starburst.new()
		_burst.size = Vector2(name_w * 1.0 + ns * 0.5, name_h * 1.35)
		_burst.position = Vector2((w - _burst.size.x) * 0.5, (name_h - _burst.size.y) * 0.5)
		_burst.points = 18 if fullscreen else 14
		if tier >= 5:
			_burst.fill = Color(1.0, 0.3, 0.6)
			_burst.fill2 = Color(1.0, 0.75, 0.2)
			_burst.outline = Color(0.2, 0.0, 0.5)
		add_child(_burst)

	# extruded shadow layer, then the front layer
	_name_back = _make_name_label(ns, name_w, name_h, true)
	_name_back.position = Vector2((w - name_w) * 0.5 + ns * 0.08, ns * 0.08)
	add_child(_name_back)
	_name_front = _make_name_label(ns, name_w, name_h, false)
	_name_front.position = Vector2((w - name_w) * 0.5, 0)
	add_child(_name_front)

	if tier >= 3 or fullscreen:
		_bar = TextureRect.new()
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 0.2, 0.2), Color(1, 0.8, 0.1), Color(0.3, 1, 0.3), Color(0.2, 0.7, 1), Color(0.7, 0.3, 1), Color(1, 0.3, 0.7)])
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 256
		gt.height = 8
		_bar.texture = gt
		_bar.size = Vector2(suffix_w, suffix_h * 0.95)
		_bar.position = Vector2((w - suffix_w) * 0.5, name_h - ss * 0.1)
		_bar.rotation = deg_to_rad(-2.5)
		_bar.pivot_offset = _bar.size * 0.5
		add_child(_bar)

	_suffix = RichTextLabel.new()
	_suffix.bbcode_enabled = true
	_suffix.scroll_active = false
	_suffix.autowrap_mode = TextServer.AUTOWRAP_OFF
	_suffix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suffix.size = Vector2(suffix_w, suffix_h)
	_suffix.position = Vector2((w - suffix_w) * 0.5, name_h - ss * 0.1)
	_suffix.pivot_offset = _suffix.size * 0.5
	_suffix.rotation = deg_to_rad(-2.5)
	_suffix.add_theme_font_override("normal_font", Boot.font_happy)
	_suffix.add_theme_font_size_override("normal_font_size", ss)
	_suffix.add_theme_constant_override("outline_size", int(ss * 0.28))
	_suffix.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	_suffix.add_theme_constant_override("shadow_offset_x", int(ss * 0.08))
	_suffix.add_theme_constant_override("shadow_offset_y", int(ss * 0.08))
	if tier >= 3 or fullscreen:
		_suffix.add_theme_color_override("default_color", Color(1.0, 0.95, 0.2))
		_suffix.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.4))
	else:
		_suffix.add_theme_color_override("default_color", Color.WHITE)
		_suffix.add_theme_color_override("font_outline_color", Color(0.9, 0.1, 0.15))
	add_child(_suffix)
	_refresh_text()


func _make_name_label(ns: int, w: int, h: int, back: bool) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(w, h)
	l.add_theme_font_override("normal_font", Boot.font_display)
	l.add_theme_font_size_override("normal_font_size", ns)
	l.add_theme_constant_override("outline_size", int(ns * 0.16))
	l.install_effect(effect())
	if back:
		l.modulate = Color(0.12, 0.0, 0.2, 1.0)
		l.add_theme_color_override("font_outline_color", Color(0.12, 0.0, 0.2))
		l.add_theme_color_override("font_shadow_color", Color(0.12, 0.0, 0.2))
		l.add_theme_constant_override("shadow_offset_x", int(ns * 0.08))
		l.add_theme_constant_override("shadow_offset_y", int(ns * 0.08))
	else:
		l.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.28))
		var m := ShaderMaterial.new()
		m.shader = CHROME
		m.set_shader_parameter("height", float(h))
		m.set_shader_parameter("strength", 0.5)
		l.material = m
	return l


func _refresh_text() -> void:
	var txt := name_text
	if _count > 1:
		txt += " ×%d" % _count
	var n := txt.length()
	var ns := _name_size()
	var amp := int(ns * (0.12 if fullscreen else 0.16))
	var bb := "[center][wordart n=%d amp=%d freq=%.2f bulge=%.2f speed=%.2f]%s[/wordart][/center]" % [
		n, amp, 2.2 if fullscreen else 2.8, 0.35 if fullscreen else 0.28, 0.45, txt]
	var bb_back := bb
	# the back layer must not be rainbow: keep it dark
	_name_front.text = bb
	_name_back.text = bb_back.replace("[wordart", "[wordart sat=0.0")
	_suffix.text = "[center][wave amp=%d freq=3.2]%s[/wave][/center]" % [int(ns * 0.06), suffix_text]


func pop(from_scale: float = 1.5) -> void:
	modulate.a = 1.0
	scale = Vector2.ONE * from_scale
	rotation = deg_to_rad(randf_range(-7, 7))
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation", deg_to_rad(randf_range(-2, 2)), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
