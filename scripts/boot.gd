extends Node
## First autoload. Registers input actions in code so the project does not
## depend on hand-edited project.godot input entries.

const FONT_PATH := "res://assets/fonts/wqy-zenhei.ttf"

var font: Font
var autopilot := false


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
	autopilot = "--autopilot" in OS.get_cmdline_user_args()


func _ready() -> void:
	font = load(FONT_PATH)


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
