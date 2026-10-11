extends Node
## Event ledger + world bookkeeping: body registry, combo window, collapse
## detection, physics-body budget (archiving). Everything that happens in the
## world reports here; the HUD and (later) ActDirector listen to the signals.

signal emerged(def, emitted_def, pos: Vector3, count: int, by_player: bool, crit: bool, first: bool)
signal collapsed(into_def, pos: Vector3, n: int, source_def)
signal combo_changed(combo: int)
signal released(power: float)
signal body_count_changed(n: int)
signal archived(def)
signal first_release
signal progress_changed(value: float, goal: float, gained: float)
signal discovered(def, count: int)
signal stage_goal_reached(stage: int)

const MAX_BODIES := 320
const COMBO_WINDOW := 1.5
const COLLAPSE_TICK := 0.25
const COLLAPSE_RADIUS_BASE := 3.5
const COLLAPSE_SETTLE := 3.0
# 涌现度 needed to leave each stage (index = stage - 1).
const STAGE_GOALS := [260.0, 420.0, 999999.0]
const STAGE_NAMES := ["街道", "城市", "地球"]

var bodies: Array = []           # alive EmergentBody
var buckets: Dictionary = {}     # name -> Array[EmergentBody]
var combo := 0
var combo_timer := 0.0
var emerge_count := 0
var collapse_count := 0
var release_count := 0
var recycled := 0
var has_released := false
var stage := 1
var progress := 0.0
var goal_reached := false
var seen: Dictionary = {}         # name -> true, every def that has emerged
var _recent: Array = []           # timestamps of emergences in the last second
const CHAIN_RATE_CAP := 18        # passive chain reactions per second before they fizzle
var _collapse_timer := 0.0
var _world: Node3D


func reset() -> void:
	bodies.clear()
	buckets.clear()
	combo = 0
	combo_timer = 0.0
	emerge_count = 0
	collapse_count = 0
	release_count = 0
	recycled = 0
	has_released = false
	stage = 1
	progress = 0.0
	goal_reached = false
	seen.clear()


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func set_world(w: Node3D) -> void:
	_world = w


func register(b) -> void:
	bodies.append(b)
	var key: String = b.def.name
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(b)
	body_count_changed.emit(bodies.size())
	_enforce_budget()


func unregister(b) -> void:
	bodies.erase(b)
	if buckets.has(b.def.name):
		buckets[b.def.name].erase(b)
	body_count_changed.emit(bodies.size())


func loose_count() -> int:
	## Rooted scenery (houses, towers, trees…) doesn't count against the budget.
	var n := 0
	for b in bodies:
		if is_instance_valid(b) and not b.def.anchored:
			n += 1
	return n


func budget_factor() -> float:
	## 1.0 when the world is roomy, shrinking toward 0.25 near the cap.
	var fill := float(loose_count()) / MAX_BODIES
	return clamp(1.3 - fill, 0.25, 1.0)


func record_emergence(def, emitted_def, pos: Vector3, count: int, by_player: bool, crit: bool = false) -> void:
	emerge_count += 1
	_recent.append(now())
	combo += 1
	combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)
	var key = emitted_def if emitted_def else def
	var is_new := _discover(key)
	emerged.emit(def, emitted_def, pos, count, by_player, crit, is_new)
	add_progress(1.0 + key.tier + (6.0 if is_new else 0.0) + (3.0 if crit else 0.0) + min(combo, 20) * 0.1)


func emergence_rate() -> int:
	var t := now() - 1.0
	while not _recent.is_empty() and _recent[0] < t:
		_recent.pop_front()
	return _recent.size()


func chain_saturated() -> bool:
	return emergence_rate() >= CHAIN_RATE_CAP


func is_seen(def) -> bool:
	return seen.has(def.name)


func _discover(def) -> bool:
	if seen.has(def.name):
		return false
	seen[def.name] = true
	discovered.emit(def, seen.size())
	return true


func add_progress(amount: float) -> void:
	progress += amount
	var goal: float = STAGE_GOALS[min(stage - 1, STAGE_GOALS.size() - 1)]
	progress_changed.emit(progress, goal, amount)
	if not goal_reached and progress >= goal:
		goal_reached = true
		stage_goal_reached.emit(stage)


func enter_stage(n: int) -> void:
	stage = n
	progress = 0.0
	goal_reached = false
	progress_changed.emit(0.0, STAGE_GOALS[min(stage - 1, STAGE_GOALS.size() - 1)], 0.0)


func record_release(power: float) -> void:
	release_count += 1
	released.emit(power)
	if not has_released:
		has_released = true
		first_release.emit()


func _process(delta: float) -> void:
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			combo_changed.emit(0)
	_collapse_timer -= delta
	if _collapse_timer <= 0.0:
		_collapse_timer = COLLAPSE_TICK
		_check_collapses()


func _check_collapses() -> void:
	for key in buckets.keys():
		var list: Array = buckets[key]
		if list.is_empty():
			continue
		var def = list[0].def
		if def.collapse_n <= 0 or def.collapse_into == "":
			continue
		if list.size() < def.collapse_n:
			continue
		var into = DB.get_def(def.collapse_into)
		if into == null:
			continue
		var base_radius: float = COLLAPSE_RADIUS_BASE + float(def.tier) * 0.75
		# Fresh spawns need to settle before they count; otherwise a collapse
		# product that emits its own ingredients re-collapses every tick.
		var t := now()
		var candidates := list.filter(func(b): return is_instance_valid(b) and not b.absorbing and t - b.spawn_time > COLLAPSE_SETTLE)
		for seed in candidates:
			var radius: float = base_radius * seed.size_mult
			var near := []
			for other in candidates:
				if other.size_mult == seed.size_mult and other.global_position.distance_to(seed.global_position) <= radius:
					near.append(other)
			if near.size() >= def.collapse_n:
				near.sort_custom(func(a, b):
					return a.global_position.distance_to(seed.global_position) < b.global_position.distance_to(seed.global_position))
				_collapse(near.slice(0, def.collapse_n), into)
				break


func _collapse(group: Array, into) -> void:
	var center := Vector3.ZERO
	for b in group:
		center += b.global_position
	center /= group.size()
	center.y += 0.5
	for b in group:
		b.absorb_to(center)
	collapse_count += 1
	combo += 1
	combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)
	collapsed.emit(into, center, group.size(), group[0].def)
	_discover(into)
	add_progress(4.0 * into.tier)
	if _world:
		_world.spawn_after(into, center, 0.35, group[0].size_mult)


func _enforce_budget() -> void:
	var loose := loose_count()
	if loose <= MAX_BODIES:
		return
	# Archive the oldest small, cold, loose things first.
	var victims := bodies.filter(func(b):
		return is_instance_valid(b) and not b.def.anchored and not b.is_hot() and not b.absorbing and b.def.size == "S")
	if victims.is_empty():
		victims = bodies.filter(func(b):
			return is_instance_valid(b) and not b.def.anchored and not b.absorbing)
	var excess := loose - MAX_BODIES + 12
	for i in min(excess, victims.size()):
		var b = victims[i]
		recycled += 1
		archived.emit(b.def)
		b.archive()


func summary() -> String:
	return "bodies=%d emerged=%d collapsed=%d released=%d recycled=%d" % [
		bodies.size(), emerge_count, collapse_count, release_count, recycled]
