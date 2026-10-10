extends CanvasLayer
## Rainbow captions (L2 world-anchored, L3 full screen), XP-style system
## popups, combo counter, recycle counter, cold-open hint. All driven by Stats.

const L2_MAX := 3
const L2_LIFE := 2.0
const MERGE_WINDOW := 1.0

var _l2: Array = []            # [{label, anchor, text, count, tier, time, offset}]
var _l3: RichTextLabel
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
	_l3 = _make_rich(96)
	_l3.set_anchors_preset(Control.PRESET_CENTER)
	_l3.size = Vector2(1500, 200)
	_l3.position = Vector2(-750, -100)
	_l3.pivot_offset = _l3.size / 2
	_l3.visible = false
	add_child(_l3)

	_combo = _make_rich(54)
	_combo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combo.size = Vector2(500, 90)
	_combo.position = Vector2(-520, 20)
	_combo.pivot_offset = Vector2(500, 45)
	_combo.visible = false
	add_child(_combo)

	_recycle = Label.new()
	_recycle.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_recycle.position = Vector2(20, -60)
	_recycle.add_theme_font_size_override("font_size", 22)
	_recycle.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_recycle.add_theme_constant_override("outline_size", 6)
	_recycle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_recycle.text = "回收站 0"
	add_child(_recycle)

	_body_count = Label.new()
	_body_count.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_body_count.position = Vector2(20, -34)
	_body_count.add_theme_font_size_override("font_size", 16)
	_body_count.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_body_count.add_theme_constant_override("outline_size", 4)
	_body_count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
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


func _make_rich(size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = false
	r.fit_content = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_constant_override("outline_size", int(size * 0.18))
	r.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.25, 1.0))
	r.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	r.add_theme_constant_override("shadow_offset_x", int(size * 0.06))
	r.add_theme_constant_override("shadow_offset_y", int(size * 0.06))
	return r


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
	show_l3("游戏涌现出来了。", 3)
	Juice.ui_sfx("startup", -4.0)


# ---------- events ----------

func _on_emerged(def, emitted_def, pos: Vector3, count: int, by_player: bool) -> void:
	var text: String = def.caption_for(emitted_def.name if emitted_def else def.name)
	var tier: int = max(emitted_def.tier if emitted_def else 1, 1)
	if emitted_def and emitted_def.tier >= 3 or (def.anchored and def.size in ["L", "XL"]):
		show_l2(text, pos, tier)
		popup(text)
		Juice.ui_sfx("didi", -10.0, randf_range(0.95, 1.1))
	else:
		show_l2(text, pos, tier)


func _on_collapsed(into_def, pos: Vector3, n: int, source_def) -> void:
	var text := "%s涌现出来了。" % into_def.name
	if into_def.line != "" and into_def.emits.is_empty():
		text = into_def.line
	if into_def.tier >= 4:
		show_l3(text, into_def.tier)
	else:
		show_l2(text, pos, into_def.tier + 2)
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
	_combo.text = "[right][rainbow freq=0.8 sat=0.85 val=1.0][wave amp=18 freq=6]连涌 ×%d！[/wave][/rainbow][/right]" % c
	var t := _combo.create_tween()
	_combo.scale = Vector2.ONE * 1.25
	t.tween_property(_combo, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if c in [10, 30, 60, 100]:
		show_l3("连涌 ×%d！" % c, 4)


func _on_archived(_def) -> void:
	_recycle.text = "回收站 %d" % Stats.recycled


# ---------- captions ----------

func show_l2(text: String, anchor: Vector3, tier: int = 2) -> void:
	# Merge repeats.
	for e in _l2:
		if e.text == text and Stats.now() - e.time < MERGE_WINDOW + L2_LIFE:
			e.count += 1
			e.time = Stats.now()
			e.anchor = anchor
			_set_l2_text(e)
			_pop(e.label, 1.25)
			return
	if _l2.size() >= L2_MAX:
		# drop the lowest tier / oldest
		_l2.sort_custom(func(a, b): return a.tier < b.tier or (a.tier == b.tier and a.time < b.time))
		var victim = _l2.pop_front()
		victim.label.queue_free()
	var size := 40 + tier * 9
	var l := _make_rich(size)
	l.size = Vector2(1000, size * 1.8)
	l.pivot_offset = l.size / 2
	add_child(l)
	var e := {"label": l, "anchor": anchor, "text": text, "count": 1, "tier": tier, "time": Stats.now(),
		"offset": Vector2(randf_range(-40, 40), randf_range(-30, 10))}
	_l2.append(e)
	_set_l2_text(e)
	_pop(l, 1.5)


func _set_l2_text(e: Dictionary) -> void:
	var t: String = e.text
	if e.count > 1:
		t += " ×%d" % e.count
	var amp: int = 10 + int(e.tier) * 4
	e.label.text = "[center][rainbow freq=0.6 sat=0.9 val=1.0][wave amp=%d freq=5]%s[/wave][/rainbow][/center]" % [amp, t]


func _pop(l: Control, from_scale: float) -> void:
	l.modulate.a = 1.0
	l.scale = Vector2.ONE * from_scale
	l.rotation = deg_to_rad(randf_range(-6, 6))
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func show_l3(text: String, tier: int = 5) -> void:
	_l3.visible = true
	_l3.text = "[center][rainbow freq=1.2 sat=0.95 val=1.0][wave amp=28 freq=4]%s[/wave][/rainbow][/center]" % text
	var sz := 84 + tier * 6
	_l3.add_theme_font_size_override("normal_font_size", sz)
	_l3.add_theme_constant_override("outline_size", int(sz * 0.2))
	_l3.modulate.a = 1.0
	_l3.scale = Vector2.ONE * 2.2
	_l3.rotation = deg_to_rad(randf_range(-5, 5))
	if _l3_tween and _l3_tween.is_valid():
		_l3_tween.kill()
	_l3_tween = _l3.create_tween()
	_l3_tween.set_parallel(true)
	_l3_tween.tween_property(_l3, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_l3_tween.tween_property(_l3, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_l3_tween.chain().tween_interval(2.0)
	_l3_tween.chain().tween_property(_l3, "modulate:a", 0.0, 0.4)
	_l3_tween.chain().tween_callback(func(): _l3.visible = false)
	Juice.shake(0.35, 0.35)
	Juice.slowmo(0.25, 0.15)
	Juice.ui_sfx("powerup", -4.0)


func popup(body_text: String) -> void:
	while _popups.get_child_count() >= 3:
		_popups.get_child(0).queue_free()
		_popups.remove_child(_popups.get_child(0))
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
			e.label.queue_free()
			_l2.remove_at(i)
			continue
		var p: Vector3 = e.anchor + Vector3(0, 1.2 + age * 0.6, 0)
		if _camera.is_position_behind(p):
			e.label.visible = false
		else:
			e.label.visible = true
			var sp := _camera.unproject_position(p)
			e.label.position = sp - e.label.pivot_offset + e.offset
		if age > L2_LIFE - 0.4:
			e.label.modulate.a = (L2_LIFE - age) / 0.4
		i += 1
