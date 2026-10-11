extends Control
## 字体样张. Open scenes/wordart_specimen.tscn and press F6 to look at the
## WordArt styles in motion. With `-- --shots=DIR` it saves a burst of frames
## and quits (used to build the preview GIF).

const ROWS := [
	# [y centre, glyph px, segments]
	[120, 84, [{"text": "两个杀毒软件打起来了", "style": "rainbow"}, {"text": "涌现出来了。", "style": "pop", "scale": 0.55}]],
	[315, 132, [{"text": "城市", "style": "rainbow"}, {"text": "涌现出来了。", "style": "pop_yellow", "scale": 0.55}]],
	[515, 100, [{"text": "资本", "style": "chrome"}, {"text": "涌现出来了。", "style": "pop", "scale": 0.55}]],
	[695, 100, [{"text": "鸽子", "style": "fire"}, {"text": "涌现出来了。", "style": "pop", "scale": 0.55}]],
	[880, 104, [{"text": "地球", "style": "rainbow", "font": "res://assets/fonts/SmileySans-Oblique.ttf"},
		{"text": "涌现出来了。", "style": "pop", "scale": 0.55, "font": "res://assets/fonts/SmileySans-Oblique.ttf"}]],
]
const TAGS := ["A 彩虹波浪 · 长名字", "B 彩虹波浪 · 全屏大字", "C 镀铬", "D 火焰", "E 得意黑（斜体）"]

var _shots_dir := ""
var _t := 0.0
var _frame := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.55, 0.78, 1.0), Color(0.86, 0.93, 1.0), Color(0.62, 0.8, 0.55)])
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(bg)
	var vw := get_viewport().get_visible_rect().size.x
	for i in ROWS.size():
		var row: Array = ROWS[i]
		var w := WordArtLine.make(row[2], row[1], {"line_width": vw})
		add_child(w)
		w.position = Vector2(0, row[0] - w.size.y * 0.5)
		var tag := Label.new()
		tag.text = TAGS[i]
		tag.add_theme_font_size_override("font_size", 18)
		tag.add_theme_color_override("font_color", Color(0.15, 0.15, 0.25))
		tag.position = Vector2(16, row[0] - row[1] * 0.75)
		add_child(tag)


func _process(delta: float) -> void:
	if _shots_dir == "":
		return
	_t += delta
	if _t < 0.6:
		return
	if _frame >= 30:
		get_tree().quit()
		return
	_frame += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/f_%03d.png" % [_shots_dir, _frame])
