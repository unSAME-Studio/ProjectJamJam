extends Node
## Headless smoke test: walks to anchored objects, holds, releases, repeats,
## then prints the ledger and quits. Run with:
##   godot --headless --path . -- --autopilot

var run_time := 40.0
const HOLD_TIME := 1.3

var _world: Node3D
var _player: Player
var _t := 0.0
var _phase := "seek"
var _target: EmergentBody
var _phase_t := 0.0
var _used: Array = []
var _report_t := 0.0
var _shots: Array = [2.0, 6.5, 12.0, 18.0, 26.0, 34.0]
var _showcased := false
var _stage_times: Array = []


func _ready() -> void:
	_world = get_parent()
	_player = _world.player
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--run="):
			run_time = float(a.substr(6))
		if a.begins_with("--shots-at="):
			_shots = Array(a.substr(11).split(",")).map(func(x): return float(x))
		if a.begins_with("--stages-at="):
			_stage_times = Array(a.substr(12).split(",")).map(func(x): return float(x))
	print("[autopilot] start")


func _physics_process(delta: float) -> void:
	_t += delta
	_phase_t += delta
	_report_t += delta
	if _report_t > 5.0:
		_report_t = 0.0
		print("[autopilot] t=%.1f %s combo=%d" % [_t, Stats.summary(), Stats.combo])
	if _t > run_time:
		_finish()
		return
	if not _shots.is_empty() and _t >= _shots[0]:
		_shots.pop_front()
		_screenshot()
	if not _showcased and _t >= 1.2:
		_showcased = true
		_showcase_captions()
	if not _stage_times.is_empty() and _t >= _stage_times[0]:
		_stage_times.pop_front()
		print("[autopilot] advance_stage at t=%.1f (stage %d)" % [_t, Stats.stage])
		_world.advance_stage()
	match _phase:
		"seek":
			if _target == null or not is_instance_valid(_target):
				_target = _pick_target()
				if _target == null:
					_set_phase("hold")
					return
			var to := _target.global_position - _player.global_position
			to.y = 0.0
			if to.length() < 3.0 * _player.k + _target.built.height * 0.3 or _phase_t > 8.0:
				Input.action_release("move_forward")
				_set_phase("hold")
				Input.action_press("emerge")
				return
			_player.yaw = rad_to_deg(atan2(-to.x, -to.z))
			Input.action_press("move_forward")
		"hold":
			if _phase_t >= HOLD_TIME:
				Input.action_release("emerge")
				_set_phase("rest")
		"rest":
			if _phase_t > 1.2:
				_used.append(_target)
				_target = null
				_set_phase("seek")


func _showcase_captions() -> void:
	# Only meaningful with a display; exercises every caption style once.
	if Boot.shots_dir == "":
		return
	var hud = _world.hud
	var p: Vector3 = _player.global_position
	var f: Vector3 = _player.facing
	hud.show_l2("钱", "涌现出来了。", p + f * 4.0 + Vector3(-3, 0, 0), 1)
	hud.show_l2("资本", "涌现出来了。", p + f * 6.0 + Vector3(3, 1, 0), 3)
	hud.show_l2("两个杀毒软件打起来了", "。", p + f * 8.0 + Vector3(0, 2, 0), 4)
	hud.show_l3("游戏", "涌现出来了。", 4)
	Stats.combo = 23
	Stats.combo_timer = 3.0
	Stats.combo_changed.emit(23)


func _screenshot() -> void:
	if Boot.shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/shot_%05.1f.png" % [Boot.shots_dir, _t]
	img.save_png(path)
	print("[autopilot] screenshot %s" % path)


func _set_phase(p: String) -> void:
	_phase = p
	_phase_t = 0.0


func _pick_target() -> EmergentBody:
	var best: EmergentBody = null
	var best_d := INF
	for b in Stats.bodies:
		if not is_instance_valid(b) or not b.def.anchored or b.def.emits.is_empty():
			continue
		if b in _used:
			continue
		var d: float = b.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = b
	if best == null:
		_used.clear()
	return best


func _finish() -> void:
	Input.action_release("emerge")
	Input.action_release("move_forward")
	print("[autopilot] DONE %s" % Stats.summary())
	var names := {}
	for b in Stats.bodies:
		if is_instance_valid(b):
			names[b.def.name] = names.get(b.def.name, 0) + 1
	print("[autopilot] world: %s" % str(names))
	get_tree().quit()
