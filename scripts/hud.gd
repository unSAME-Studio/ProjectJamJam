extends CanvasLayer
## Captions (L2 world-anchored, L3 full screen) built from Caption controls,
## XP-style system popups, combo counter, recycle counter, cold-open hint.
## All driven by Stats signals.

const L2_MAX := 3
const L2_LIFE := 2.2
const MERGE_WINDOW := 1.0
const SUFFIX_DEFAULT := "涌现出来了。"

var _l2: Array = []            # [{cap, anchor, key, count, tier, time, offset}]
var _l3: Caption
var _l3_tween: Tween
var _combo: RichTextLabel
var _recycle: Label
var _hint: Label
var _popups: VBoxContainer
var _body_count: Label
var _camera: Camera3D
var _started := false


func _ready() -> void:
	layer = 10
	_build()
	Stats.emerged.connect(_on_emerged)
	Stats.collapsed.connect(_on_collapsed)
	Stats.combo_changed.connect(_on_combo)
	Stats.archived.connect(_on_archived)
	Stats.body_count_changed.connect(func(n): _body_count.text = "物体 %d / %d" % [n, Stats.MAX_BODIES])
	Stats.first_release.connect(_on_first_release)
	_set_started(false)


func _build() -> void:
	_combo = RichTextLabel.new()
	_combo.bbcode_enabled = true
	_combo.scroll_active = false
	_combo.autowrap_mode = TextServer.AUTOWRAP_OFF
	_combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo.add_theme_font_override("normal_font", Boot.font_display)
	_combo.add_theme_font_size_override("normal_font_size", 54)
	_combo.add_theme_constant_override("outline_size", 12)
	_combo.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.28))
	_combo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_combo.add_theme_constant_override("shadow_offset_x", 4)
	_combo.add_theme_constant_override("shadow_offset_y", 4)
	_combo.install_effect(Caption.effect())
	_combo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combo.size = Vector2(560, 110)
	_combo.position = Vector2(-580, 16)
	_combo.pivot_offset = Vector2(560, 55)
	_combo.visible = false
	add_child(_combo)

	_recycle = _small_label(Vector2(20, -60), 22, Color(0.9, 0.9, 0.9))
	_recycle.text = "回收站 0"
	add_child(_recycle)
	_body_count = _small_label(Vector2(20, -34), 16, Color(0.7, 0.7, 0.7))
	_body_count.text = "物体 0"
	add_child(_body_count)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.size = Vector2(800, 40)
	_hint.position = Vector2(-400, -90)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.text = "按住 空格 / 鼠标左键 ……然后松开"
	add_child(_hint)

	_popups = VBoxContainer.new()
	_popups.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_popups.size = Vector2(360, 300)
	_popups.position = Vector2(-380, -330)
	_popups.alignment = BoxContainer.ALIGNMENT_END
	_popups.add_theme_constant_override("separation", 8)
	add_child(_popups)


func _small_label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", int(size * 0.25))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return l


func set_camera(c: Camera3D) -> void:
	_camera = c


func _set_started(v: bool) -> void:
	_started = v
	_combo.visible = v and Stats.combo > 1
	_recycle.visible = v
	_body_count.visible = v
	_popups.visible = v


func _on_first_release() -> void:
	_set_started(true)
	var t := _hint.create_tween()
	t.tween_property(_hint, "modulate:a", 0.0, 1.5)
	show_l3("游戏", SUFFIX_DEFAULT, 4)
	Juice.ui_sfx("startup", -4.0)


# ---------- splitting a line into NAME + SUFFIX ----------

static func split_line(line: String, fallback_name: String) -> Array:
	## "钱涌现出来了。" -> ["钱", "涌现出来了。"]; "您赢了。" -> [fallback, "您赢了。"]
	var i := line.find("涌现出来了")
	if i > 0:
		return [line.substr(0, i), line.substr(i)]
	if i == 0:
		return [fallback_name, line]
	return [fallback_name, line if line != "" else SUFFIX_DEFAULT]


# ---------- events ----------

func _on_emerged(def, emitted_def, pos: Vector3, _count: int, _by_player: bool) -> void:
	var emitted_name: String = emitted_def.name if emitted_def else def.name
	var parts := split_line(def.line, emitted_name)
	var tier: int = max(emitted_def.tier if emitted_def else 1, 1)
	show_l2(parts[0], parts[1], pos, tier)
	if (emitted_def and emitted_def.tier >= 3) or (def.anchored and def.size in ["L", "XL"]):
		popup(parts[0] + parts[1])
		Juice.ui_sfx("didi", -10.0, randf_range(0.95, 1.1))


func _on_collapsed(into_def, pos: Vector3, n: int, source_def) -> void:
	var parts := split_line(into_def.line if into_def.emits.is_empty() else "", into_def.name)
	if into_def.tier >= 4:
		show_l3(parts[0], parts[1], into_def.tier)
	else:
		show_l2(parts[0], parts[1], pos, into_def.tier + 2)
	popup("%s ×%d → %s" % [source_def.name, n, into_def.name])
	Juice.ui_sfx("chime", -6.0, 1.0 + (into_def.tier - 3) * 0.08)


func _on_combo(c: int) -> void:
	if not _started:
		return
	if c <= 1:
		if _combo.visible:
			var t := _combo.create_tween()
			t.tween_property(_combo, "modulate:a", 0.0, 0.4)
			t.tween_callback(func(): _combo.visible = false)
		return
	_combo.visible = true
	_combo.modulate.a = 1.0
	var sz: float = 54.0 + min(c, 40) * 1.2
	_combo.add_theme_font_size_override("normal_font_size", int(sz))
	var txt := "连涌 ×%d！" % c
	_combo.text = "[right][wordart n=%d amp=%d freq=3 bulge=0.15 speed=0.6]%s[/wordart][/right]" % [txt.length(), int(sz * 0.12), txt]
	var t := _combo.create_tween()
	_combo.scale = Vector2.ONE * 1.25
	t.tween_property(_combo, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if c in [10, 30, 60, 100]:
		show_l3("连涌 ×%d" % c, "！！！", 4)


func _on_archived(_def) -> void:
	_recycle.text = "回收站 %d" % Stats.recycled


# ---------- captions ----------

func show_l2(name_text: String, suffix_text: String, anchor: Vector3, tier: int = 2) -> void:
	var key := name_text + "|" + suffix_text
	for e in _l2:
		if e.key == key and Stats.now() - e.time < MERGE_WINDOW + L2_LIFE:
			e.count += 1
			e.time = Stats.now()
			e.anchor = anchor
			e.cap.set_count(e.count)
			e.cap.pop(1.2)
			return
	if _l2.size() >= L2_MAX:
		_l2.sort_custom(func(a, b): return a.tier < b.tier or (a.tier == b.tier and a.time < b.time))
		var victim = _l2.pop_front()
		victim.cap.queue_free()
	var cap := Caption.new()
	cap.setup(name_text, suffix_text, tier, false)
	add_child(cap)
	_l2.append({"cap": cap, "anchor": anchor, "key": key, "count": 1, "tier": tier, "time": Stats.now(),
		"offset": Vector2(randf_range(-40, 40), randf_range(-30, 10))})
	cap.pop(1.6)


func show_l3(name_text: String, suffix_text: String, tier: int = 5) -> void:
	if _l3 and is_instance_valid(_l3):
		_l3.queue_free()
	_l3 = Caption.new()
	_l3.setup(name_text, suffix_text, tier, true)
	add_child(_l3)
	var vp := get_viewport().get_visible_rect().size
	_l3.position = (vp - _l3.size) * 0.5 - Vector2(0, vp.y * 0.08)
	_l3.pop(2.2)
	if _l3_tween and _l3_tween.is_valid():
		_l3_tween.kill()
	_l3_tween = _l3.create_tween()
	_l3_tween.tween_interval(2.4)
	_l3_tween.tween_property(_l3, "modulate:a", 0.0, 0.4)
	_l3_tween.tween_callback(_l3.queue_free)
	Juice.shake(0.35, 0.35)
	Juice.slowmo(0.25, 0.15)
	Juice.ui_sfx("powerup", -4.0)


func popup(body_text: String) -> void:
	while _popups.get_child_count() >= 3:
		var old := _popups.get_child(0)
		_popups.remove_child(old)
		old.queue_free()
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.93, 0.9)
	style.border_color = Color(0.05, 0.25, 0.75)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	var title := Label.new()
	title.text = "  系统提示                                   ×"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.05, 0.3, 0.85)
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", ts)
	tp.add_child(title)
	v.add_child(tp)
	var body := Label.new()
	body.text = "  " + body_text
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	body.custom_minimum_size = Vector2(340, 44)
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(body)
	var ok := Label.new()
	ok.text = "[ 确定 ]"
	ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok.add_theme_font_size_override("font_size", 16)
	ok.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	v.add_child(ok)
	_popups.add_child(panel)
	panel.modulate.a = 0.0
	var t := panel.create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.1)
	t.tween_interval(3.2)
	t.tween_property(panel, "modulate:a", 0.0, 0.3)
	t.tween_callback(panel.queue_free)


func _process(_delta: float) -> void:
	if _camera == null:
		return
	var now := Stats.now()
	var i := 0
	while i < _l2.size():
		var e: Dictionary = _l2[i]
		var age: float = now - e.time
		if age > L2_LIFE:
			e.cap.queue_free()
			_l2.remove_at(i)
			continue
		var p: Vector3 = e.anchor + Vector3(0, 1.2 + age * 0.5, 0)
		if _camera.is_position_behind(p):
			e.cap.visible = false
		else:
			e.cap.visible = true
			var sp := _camera.unproject_position(p)
			e.cap.position = sp - e.cap.pivot_offset + e.offset
		if age > L2_LIFE - 0.4:
			e.cap.modulate.a = (L2_LIFE - age) / 0.4
		i += 1
