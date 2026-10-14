class_name ObjectCaption
extends Control
## Caption for a single object emerging: the NAME is live WordArt (gradient,
## wave, shadow), the suffix is plain flat POP text that doesn't move — the
## contrast is the point.
##   normal  「钱」涌现出来了。      white suffix, red outline
##   first   「钱」涌现出来了！      first time ever seen: bigger, yellow suffix
##   crit    「钱」涌现出来了！      暴击 (emits ×2): biggest, red-on-white suffix, flash + shake

const MAX_NAME_PX := 900.0

var kind := "normal"
var tier := 1
var _base_suffix := ""
var _name: WordArtLine
var _suffix: Label
var _px := 60


func setup(p_name: String, p_suffix: String, p_tier: int, p_kind: String = "normal") -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	kind = p_kind
	tier = p_tier
	_base_suffix = p_suffix
	var boost: float = {"normal": 1.0, "first": 1.2, "crit": 1.35}.get(kind, 1.0)
	_px = int(min((54 + tier * 10) * boost, MAX_NAME_PX / max(p_name.length() * 1.06, 1.0)))
	_name = WordArtLine.make(p_name, "", _px, {
		"palette": Caption.PALETTE_KEYS[abs(p_name.hash()) % Caption.PALETTE_KEYS.size()],
		"amp": 0.36 if kind == "crit" else 0.32,
		"speed": 0.55 if kind == "crit" else 0.35,
	})
	add_child(_name)
	_suffix = Label.new()
	_suffix.add_theme_font_override("font", Boot.font_happy)
	var fill := Color.WHITE
	var line := Color(0.9, 0.08, 0.12)
	var ratio := 0.55
	match kind:
		"first":
			fill = Color(1.0, 0.9, 0.1)
			ratio = 0.62
		"crit":
			fill = Color(1.0, 0.1, 0.12)
			line = Color.WHITE
			ratio = 0.7
	var spx := int(_px * ratio)
	_suffix.add_theme_font_size_override("font_size", spx)
	_suffix.add_theme_color_override("font_color", fill)
	_suffix.add_theme_color_override("font_outline_color", line)
	_suffix.add_theme_constant_override("outline_size", int(spx * 0.3))
	_suffix.add_theme_color_override("font_shadow_color", Color(0.1, 0.03, 0.27, 0.85))
	_suffix.add_theme_constant_override("shadow_offset_x", int(spx * 0.08))
	_suffix.add_theme_constant_override("shadow_offset_y", int(spx * 0.08))
	_suffix.add_theme_constant_override("shadow_outline_size", int(spx * 0.3))
	add_child(_suffix)
	_layout(p_suffix)


func set_count(n: int) -> void:
	_layout(("×%d " % n if n > 1 else "") + _base_suffix)
	_suffix.scale = Vector2.ONE * 1.3
	var t := _suffix.create_tween()
	t.tween_property(_suffix, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _layout(suffix: String) -> void:
	_suffix.text = suffix
	var spx: int = _suffix.get_theme_font_size("font_size")
	var sz := Boot.font_happy.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, spx)
	# WordArtLine pads its texture for the frame and shadow; tuck the suffix in.
	var name_right := _name.size.x - _px * (_name.outer + _name.shadow + 0.08) - 4.0
	_suffix.size = sz
	_suffix.pivot_offset = Vector2(0, sz.y * 0.5)
	_suffix.position = Vector2(name_right + _px * 0.04, _name.size.y * 0.5 - sz.y * 0.5 + _px * 0.12)
	size = Vector2(_suffix.position.x + sz.x + 8.0, _name.size.y)
	pivot_offset = size * 0.5


func pop_in(from_scale: float = 1.5) -> void:
	var s := from_scale * (1.4 if kind == "crit" else (1.15 if kind == "first" else 1.0))
	modulate.a = 1.0
	scale = Vector2.ONE * s
	rotation = deg_to_rad(randf_range(-6, 6) * (1.8 if kind == "crit" else 1.0))
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation", deg_to_rad(randf_range(-2, 2)), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# the flat suffix lands a beat later: 啪
	_suffix.scale = Vector2.ZERO
	var st := _suffix.create_tween()
	st.tween_interval(0.1 if kind == "normal" else 0.16)
	st.tween_property(_suffix, "scale", Vector2.ONE * (1.35 if kind != "normal" else 1.15), 0.08)
	st.tween_property(_suffix, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
