extends Node
## First autoload. Registers input actions in code so the project does not
## depend on hand-edited project.godot input entries.

const FONT_PATH := "res://assets/fonts/wqy-zenhei.ttf"
const FONT_DISPLAY_PATH := "res://assets/fonts/ZCOOLQingKeHuangYou-Regular.ttf"
const FONT_HAPPY_PATH := "res://assets/fonts/ZCOOLKuaiLe-Regular.ttf"
const FONT_BRUSH_PATH := "res://assets/fonts/ZhiMangXing-Regular.ttf"
const FONT_KAI_PATH := "res://assets/fonts/MaShanZheng-Regular.ttf"

var font: Font          # 文泉驿正黑：UI 正文、兜底
var font_display: Font  # 站酷庆科黄油体：物体名字（WordArt）、实体字
var font_happy: Font    # 站酷快乐体：「涌现出来了。」后缀、气泡
var font_brush: Font    # 志莽行书：「力量——」、气功味
var font_kai: Font      # 马善政楷书：备用
var autopilot := false
var shots_dir := ""


func _init() -> void:
	_add_key("move_forward", KEY_W, JOY_AXIS_LEFT_Y, -1.0)
	_add_key("move_back", KEY_S, JOY_AXIS_LEFT_Y, 1.0)
	_add_key("move_left", KEY_A, JOY_AXIS_LEFT_X, -1.0)
	_add_key("move_right", KEY_D, JOY_AXIS_LEFT_X, 1.0)
	_add_key("emerge", KEY_SPACE)
	_add_mouse("emerge", MOUSE_BUTTON_LEFT)
	_add_joy_button("emerge", JOY_BUTTON_A)
	_add_joy_axis("emerge", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_key("reset", KEY_R)
	_add_key("toggle_mouse", KEY_ESCAPE)
	_add_key("debug_spawn", KEY_T)
	_add_key("next_stage", KEY_N)
	autopilot = "--autopilot" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)


func _ready() -> void:
	font = load(FONT_PATH)
	font_display = _load_font(FONT_DISPLAY_PATH)
	font_happy = _load_font(FONT_HAPPY_PATH)
	font_brush = _load_font(FONT_BRUSH_PATH)
	font_kai = _load_font(FONT_KAI_PATH)


func _load_font(path: String) -> Font:
	var f: Font = load(path) if ResourceLoader.exists(path) else null
	if f == null:
		return font
	# Fall back to the full CJK font for glyphs the display font lacks.
	if f is FontFile and font is FontFile:
		f.fallbacks = [font]
	return f


func _add_key(action: String, key: Key, axis: JoyAxis = JOY_AXIS_INVALID, axis_value: float = 0.0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
	if axis != JOY_AXIS_INVALID:
		_add_joy_axis(action, axis, axis_value)


func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
