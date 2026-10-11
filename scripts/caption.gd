class_name Caption
extends RichTextLabel
## One line, no wrap, no stickers:
##   NAME   — chunky display font, WordArt rainbow sweep + wave + arch
##   SUFFIX — round font, flat colour with a fat outline (supermarket POP)
## e.g.  [钱](rainbow, waving)[涌现出来了。](white, red outline)

const LINE_WIDTH := 2600.0
const MAX_LINE_PX := 1400.0
const SUFFIX_FONT := "res://assets/fonts/ZCOOLKuaiLe-Regular.ttf"

var name_text := ""
var suffix_text := ""
var tier := 1
var fullscreen := false
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
	bbcode_enabled = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_OFF
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	install_effect(effect())
	add_theme_font_override("normal_font", Boot.font_display)
	add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.28))
	add_theme_color_override("font_shadow_color", Color(0.1, 0.0, 0.2, 0.75))
	_refresh()


func set_count(n: int) -> void:
	_count = n
	_refresh()


func _name_size() -> int:
	var base := (150 + tier * 6) if fullscreen else (44 + tier * 10)
	# Keep the whole line on screen: name chars count 1, suffix chars ~0.55.
	var units := float(name_text.length() + (3 if _count > 1 else 0)) + suffix_text.length() * 0.55
	return int(min(base, MAX_LINE_PX / max(units, 1.0)))


func _refresh() -> void:
	var ns := _name_size()
	var ss := int(ns * 0.55)
	var h := ns * 1.7
	size = Vector2(LINE_WIDTH, h)
	pivot_offset = size * 0.5
	add_theme_font_size_override("normal_font_size", ns)
	add_theme_constant_override("outline_size", int(ns * 0.16))
	add_theme_constant_override("shadow_offset_x", int(ns * 0.07))
	add_theme_constant_override("shadow_offset_y", int(ns * 0.07))

	var nm := name_text
	if _count > 1:
		nm += "×%d" % _count
	var suffix_color := "#ffffff"
	var suffix_outline := "#e0141e"
	if tier >= 3 or fullscreen:
		suffix_color = "#fff23a"
		suffix_outline = "#1a1460"
	var amp := int(ns * (0.1 if fullscreen else 0.14))
	text = "[center][wordart n=%d amp=%d freq=%.2f bulge=%.2f speed=0.45]%s[/wordart][font=%s][font_size=%d][outline_size=%d][outline_color=%s][color=%s][wave amp=%d freq=3]%s[/wave][/color][/outline_color][/outline_size][/font_size][/font][/center]" % [
		nm.length(), amp, 2.2 if fullscreen else 2.8, 0.3, nm,
		SUFFIX_FONT, ss, int(ss * 0.3), suffix_outline, suffix_color, int(ns * 0.05), suffix_text]


func pop_in(from_scale: float = 1.5) -> void:
	modulate.a = 1.0
	scale = Vector2.ONE * from_scale
	rotation = deg_to_rad(randf_range(-6, 6))
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation", deg_to_rad(randf_range(-2, 2)), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
