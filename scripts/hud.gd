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
var _bar_root: Control
var _bar_label: Label
var _bar_fill: TextureRect
var _bar_width := 0.0
var _found: Label
var _fever_rect: ColorRect
var _fever_mat: ShaderMaterial
var _fever_tween: Tween


func _ready() -> void:
	layer = 10
	_build()
	Stats.emerged.connect(_on_emerged)
	Stats.collapsed.connect(_on_collapsed)
	Stats.combo_changed.connect(_on_combo)
	Stats.archived.connect(_on_archived)
	Stats.body_count_changed.connect(func(n): _body_count.text = "物体 %d / %d" % [n, Stats.MAX_BODIES])
	Stats.first_release.connect(_on_first_release)
	Stats.progress_changed.connect(_on_progress)
	Stats.discovered.connect(_on_discovered)
	Stats.stage_goal_reached.connect(_on_goal)
	Stats.fever_changed.connect(_on_fever)
	_set_started(false)
	_on_progress(0.0, Stats.STAGE_GOALS[0], 0.0)


func _build() -> void:
	_combo = RichTextLabel.new()
	_combo.bbcode_enabled = true
	_combo.scroll_active = false
	_combo.autowrap_mode = TextServer.AUTOWRAP_OFF
	_combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo.add_theme_font_override("normal_font", WordArtLine.heavy_font(54, 0.45, 0.04))
	_combo.add_theme_font_size_override("normal_font_size", 54)
	_combo.add_theme_constant_override("outline_size", 12)
	_combo.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.28))
	_combo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_combo.add_theme_constant_override("shadow_offset_x", 4)
	_combo.add_theme_constant_override("shadow_offset_y", 4)
	_combo.install_effect(WordArtEffect.new())
	_combo.clip_contents = false
	_combo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combo.size = Vector2(560, 130)
	_combo.position = Vector2(-580, 34)
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
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.text = "按住 空格 / 鼠标左键 ……然后松开"
	add_child(_hint)

	_found = _small_label(Vector2(20, -86), 22, Color(1.0, 0.95, 0.5))
	_found.text = "已发现 0 种涌现"
	add_child(_found)

	_bar_root = Control.new()
	_bar_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bar_root.size = Vector2(560, 60)
	_bar_root.position = Vector2(-280, 12)
	_bar_root.pivot_offset = _bar_root.size * 0.5
	_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_root)
	_bar_label = Label.new()
	_bar_label.size = Vector2(560, 30)
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_label.add_theme_font_override("font", Boot.font_display)
	_bar_label.add_theme_font_size_override("font_size", 26)
	_bar_label.add_theme_color_override("font_color", Color.WHITE)
	_bar_label.add_theme_constant_override("outline_size", 8)
	_bar_label.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.28))
	_bar_root.add_child(_bar_label)
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.05, 0.2, 0.7)
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(9)
	bg.add_theme_stylebox_override("panel", sb)
	bg.position = Vector2(0, 34)
	bg.size = Vector2(560, 20)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.add_child(bg)
	_bar_fill = TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.2, 0.3), Color(1, 0.8, 0.1), Color(0.3, 1, 0.3), Color(0.2, 0.7, 1), Color(0.8, 0.3, 1)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	_bar_fill.texture = gt
	_bar_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bar_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_bar_fill.position = Vector2(4, 38)
	_bar_fill.size = Vector2(0, 12)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.add_child(_bar_fill)

	_fever_rect = ColorRect.new()
	_fever_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fever_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fever_mat = ShaderMaterial.new()
	_fever_mat.shader = load("res://assets/shaders/fever_rainbow.gdshader")
	_fever_rect.material = _fever_mat
	_fever_rect.visible = false
	add_child(_fever_rect)
	move_child(_fever_rect, 0)

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
	_found.visible = v
	_bar_root.visible = v


func _on_first_release() -> void:
	_set_started(true)
	var t := _hint.create_tween()
	t.tween_property(_hint, "modulate:a", 0.0, 1.5)
	_queue_hints()
	show_l3("游戏", SUFFIX_DEFAULT, 4)
	Juice.ui_sfx("startup", -4.0)


# ---------- onboarding: a few deadpan one-liners, each shown once ----------

var _hint_done: Dictionary = {}


func _queue_hints() -> void:
	get_tree().create_timer(5.0).timeout.connect(func():
		if Stats.emerge_count == 0:
			hint("squeeze", "对着 ATM、消防栓、树 按住不放。"))
	Stats.emerged.connect(func(_a, _b, _c, _d, _e, _f, _g):
		if Stats.emerge_count >= 3:
			get_tree().create_timer(2.5).timeout.connect(func():
				if Stats.collapse_count == 0:
					hint("gather", "同样的东西吸到一起，按住别松。")))
	Stats.collapsed.connect(func(_a, _b, _c, _d):
		get_tree().create_timer(3.0).timeout.connect(func():
			hint("chain", "松开，把它们砸向别的东西。")))
	Stats.stage_goal_reached.connect(func(_s): _hint.modulate.a = 0.0)


func hint(id: String, text: String) -> void:
	if _hint_done.has(id) or not is_inside_tree():
		return
	_hint_done[id] = true
	_hint.text = text
	_hint.modulate.a = 0.0
	var t := _hint.create_tween()
	t.tween_property(_hint, "modulate:a", 1.0, 0.4)
	t.tween_interval(4.0)
	t.tween_property(_hint, "modulate:a", 0.0, 0.8)


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

func _on_emerged(def, emitted_def, pos: Vector3, _count: int, _by_player: bool, crit: bool, first: bool) -> void:
	var emitted_name: String = emitted_def.name if emitted_def else def.name
	var parts := split_line(def.line, emitted_name)
	var tier: int = max(emitted_def.tier if emitted_def else 1, 1)
	var kind := "crit" if crit else ("first" if first else "normal")
	show_l2(parts[0], parts[1], pos, tier, kind)
	if crit:
		popup("暴击！%s ×2" % emitted_name)
		Juice.ui_sfx("powerup", -3.0, 1.3)
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
	var txt := ("狂热 连涌 ×%d！" if Stats.fever else "连涌 ×%d！") % c
	_combo.text = "[right][wordart n=%d amp=%d freq=3 bulge=0.15 speed=0.6]%s[/wordart][/right]" % [txt.length(), int(sz * 0.12), txt]
	var t := _combo.create_tween()
	_combo.scale = Vector2.ONE * 1.25
	t.tween_property(_combo, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if c in [10, 50, 100, 200]:
		show_l3("连涌 ×%d" % c, "！！！", 4)


func _on_progress(value: float, goal: float, gained: float) -> void:
	var st: int = Stats.stage
	var names: Array = Stats.STAGE_NAMES
	if st >= names.size():
		_bar_label.text = "%s　　第三幕 未完待续" % names[names.size() - 1]
		_bar_fill.size.x = 552.0
		return
	var next_name: String = names[st]
	_bar_label.text = "%s  ▸  %s　　涌现度 %d / %d" % [names[st - 1], next_name, int(value), int(goal)]
	var target: float = 552.0 * clamp(value / goal, 0.0, 1.0)
	var t := _bar_fill.create_tween()
	t.tween_property(_bar_fill, "size:x", target, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if gained >= 4.0:
		_bar_root.scale = Vector2.ONE * 1.08
		var p := _bar_root.create_tween()
		p.tween_property(_bar_root, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_fever(on: bool) -> void:
	# 涌现狂热: like Love Spinnin's fever — rainbow ring, wider FOV, faster
	# player, more crits, and no more slow-mo while it lasts.
	if _fever_tween and _fever_tween.is_valid():
		_fever_tween.kill()
	_fever_tween = create_tween()
	_fever_tween.set_parallel(true)
	var cam: Camera3D = _camera
	if on:
		_fever_rect.visible = true
		_fever_tween.tween_method(func(v): _fever_mat.set_shader_parameter("opacity", v), 0.0, 0.55, 0.3)
		if cam:
			_fever_tween.tween_property(cam, "fov", 72.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		show_l3("涌现狂热", "！！！", 5)
		Juice.ui_sfx("rainbow", -4.0)
		Juice.flash(Color(1, 0.9, 1, 0.35))
	else:
		_fever_tween.tween_method(func(v): _fever_mat.set_shader_parameter("opacity", v), 0.55, 0.0, 0.6)
		if cam:
			_fever_tween.tween_property(cam, "fov", 60.0, 0.6)
		_fever_tween.chain().tween_callback(func(): _fever_rect.visible = false)
		Juice.ui_sfx("Correct", -6.0)


func _on_goal(_stage: int) -> void:
	_bar_label.text = "涌现度满了！"
	Juice.ui_sfx("powerup", -2.0, 1.2)


func _on_discovered(def, count: int) -> void:
	_found.text = "已发现 %d 种涌现" % count
	if count > 1:
		popup("发现新的涌现：%s（第 %d 种）" % [def.name, count])
	_found.scale = Vector2.ONE * 1.3
	var t := _found.create_tween()
	t.tween_property(_found, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_archived(_def) -> void:
	_recycle.text = "回收站 %d" % Stats.recycled


# ---------- captions ----------

func show_l2(name_text: String, suffix_text: String, anchor: Vector3, tier: int = 2, kind: String = "normal") -> void:
	if kind != "normal":
		suffix_text = exclaim(suffix_text)
	var key := name_text + "|" + suffix_text + "|" + kind
	for e in _l2:
		if kind == "normal" and e.key == key and Stats.now() - e.time < MERGE_WINDOW + L2_LIFE:
			e.count += 1
			e.time = Stats.now()
			e.anchor = anchor
			e.cap.set_count(e.count)
			e.cap.pop_in(1.2)
			return
	if _l2.size() >= L2_MAX:
		_l2.sort_custom(func(a, b): return a.tier < b.tier or (a.tier == b.tier and a.time < b.time))
		var victim = _l2.pop_front()
		victim.cap.queue_free()
	var cap := ObjectCaption.new()
	add_child(cap)
	cap.setup(name_text, suffix_text, tier, kind)
	var rank: int = tier + (3 if kind == "crit" else (2 if kind == "first" else 0))
	_l2.append({"cap": cap, "anchor": anchor, "key": key, "count": 1, "tier": rank, "time": Stats.now(),
		"offset": Vector2(randf_range(-40, 40), randf_range(-30, 10))})
	cap.pop_in(1.6)


static func exclaim(suffix: String) -> String:
	## 「涌现出来了。」→「涌现出来了！」
	if suffix.ends_with("。"):
		return suffix.substr(0, suffix.length() - 1) + "！"
	if suffix.ends_with("！"):
		return suffix
	return suffix + "！"


func show_l3(name_text: String, suffix_text: String, tier: int = 5) -> void:
	if _l3 and is_instance_valid(_l3):
		_l3.queue_free()
	_l3 = Caption.new()
	add_child(_l3)
	_l3.setup(name_text, suffix_text, tier, true)
	var vp := get_viewport().get_visible_rect().size
	_l3.position = (vp - _l3.size) * 0.5 - Vector2(0, vp.y * 0.08)
	_l3.pop_in(1.6)
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
