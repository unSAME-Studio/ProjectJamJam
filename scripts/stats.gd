extends Node
## Event ledger + world bookkeeping: body registry, combo window, collapse
## detection, physics-body budget (archiving). Everything that happens in the
## world reports here; the HUD and (later) ActDirector listen to the signals.

signal emerged(def, emitted_def, pos: Vector3, count: int, by_player: bool)
signal collapsed(into_def, pos: Vector3, n: int, source_def)
signal combo_changed(combo: int)
signal released(power: float)
signal body_count_changed(n: int)
signal archived(def)
signal first_release

const MAX_BODIES := 320
const COMBO_WINDOW := 1.5
const COLLAPSE_TICK := 0.25
const COLLAPSE_RADIUS_BASE := 3.5
const COLLAPSE_SETTLE := 3.0

var bodies: Array = []           # alive EmergentBody
var buckets: Dictionary = {}     # name -> Array[EmergentBody]
var combo := 0
var combo_timer := 0.0
var emerge_count := 0
var collapse_count := 0
var release_count := 0
var recycled := 0
var has_released := false
var _collapse_timer := 0.0
var _world: Node3D


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


func budget_factor() -> float:
	## 1.0 when the world is roomy, shrinking toward 0.25 near the cap.
	var fill := float(bodies.size()) / MAX_BODIES
	return clamp(1.3 - fill, 0.25, 1.0)


func record_emergence(def, emitted_def, pos: Vector3, count: int, by_player: bool) -> void:
	emerge_count += 1
	combo += 1
	combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)
	emerged.emit(def, emitted_def, pos, count, by_player)


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
		var radius: float = COLLAPSE_RADIUS_BASE + float(def.tier) * 0.75
		# Fresh spawns need to settle before they count; otherwise a collapse
		# product that emits its own ingredients re-collapses every tick.
		var t := now()
		var candidates := list.filter(func(b): return is_instance_valid(b) and not b.absorbing and t - b.spawn_time > COLLAPSE_SETTLE)
		for seed in candidates:
			var near := []
			for other in candidates:
				if other.global_position.distance_to(seed.global_position) <= radius:
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
	if _world:
		_world.spawn_after(into, center, 0.35)


func _enforce_budget() -> void:
	if bodies.size() <= MAX_BODIES:
		return
	# Archive the oldest small, cold, loose things first.
	var victims := bodies.filter(func(b):
		return is_instance_valid(b) and not b.def.anchored and not b.is_hot() and not b.absorbing and b.def.size == "S")
	if victims.is_empty():
		victims = bodies.filter(func(b):
			return is_instance_valid(b) and not b.def.anchored and not b.absorbing)
	var excess := bodies.size() - MAX_BODIES + 12
	for i in min(excess, victims.size()):
		var b = victims[i]
		recycled += 1
		archived.emit(b.def)
		b.archive()


func summary() -> String:
	return "bodies=%d emerged=%d collapsed=%d released=%d recycled=%d" % [
		bodies.size(), emerge_count, collapse_count, release_count, recycled]
