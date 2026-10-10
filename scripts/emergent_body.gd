class_name EmergentBody
extends RigidBody3D
## One object in the world. Everything it can do comes from its EmergenceDef:
## emit when hit / squeezed, take part in collapses, eat, transform by recipe,
## and (for people) wander and get "enlightened".

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_OBJECTS := 3
const LAYER_WATER := 4

const HOT_TIME := 2.0
const EMIT_HOT_TIME := 1.0
const TRIGGER_COOLDOWN := 1.5
const HIT_SPEED := 6.0
const SQUEEZE_TIME := 0.9

const NPC_IDS := ["person", "worker", "boss", "netkid", "agent", "developer", "student", "netizen", "grandpa"]

var def
var built: Visuals.Built
var visual: Node3D
var hot_until := 0.0
var cooldown_until := 0.0
var spawn_time := 0.0
var absorbing := false
var squeeze := 0.0
var eaten := 0
var enlightened := false
var is_npc := false
var is_bird := false
var life_left := -1.0
var _eat_area: Area3D
var _wander_target: Vector3
var _wander_wait := 0.0
var _enlight_timer := 0.0
var _aura: MeshInstance3D
var _bubble: Label3D
var _squeeze_visual_base: Vector3 = Vector3.ONE


static func create(d) -> EmergentBody:
	var b := EmergentBody.new()
	b.def = d
	return b


func _ready() -> void:
	add_to_group("emergent")
	spawn_time = Stats.now()
	built = Visuals.build(def)
	visual = built.visual
	add_child(visual)
	_squeeze_visual_base = visual.scale
	var cs := CollisionShape3D.new()
	cs.shape = built.shape
	cs.position = built.shape_offset
	add_child(cs)

	is_npc = def.id in NPC_IDS
	is_bird = def.id == "pigeon"
	var is_water: bool = def.id in ["water", "rain"]

	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(LAYER_WATER if is_water else LAYER_OBJECTS, true)
	set_collision_mask_value(LAYER_WORLD, true)
	set_collision_mask_value(LAYER_PLAYER, true)
	set_collision_mask_value(LAYER_OBJECTS, true)

	mass = {"S": 0.4, "M": 2.0, "L": 12.0, "XL": 40.0}.get(def.size, 1.0)
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 0.15
	angular_damp = 0.8
	can_sleep = true
	body_entered.connect(_on_body_entered)

	if def.anchored:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	if is_npc:
		axis_lock_angular_x = true
		axis_lock_angular_z = true
		angular_damp = 6.0
		_pick_wander()
	if is_bird:
		gravity_scale = 0.35
		_wander_wait = randf_range(0.5, 2.0)
	if def.id == "grandpa":
		call_deferred("_enlighten", true)
	if is_water:
		life_left = randf_range(7.0, 10.0)
		linear_damp = 0.5
	if def.id == "flock":
		gravity_scale = 0.0
		linear_damp = 0.3
		_wander_wait = 0.2
	if not def.eats.is_empty():
		_make_eat_area()
	Stats.register(self)


func _exit_tree() -> void:
	Stats.unregister(self)


# ---------- state ----------

func is_hot() -> bool:
	return Stats.now() < hot_until


func set_hot(t: float = HOT_TIME) -> void:
	hot_until = Stats.now() + t
	sleeping = false


func top_position() -> Vector3:
	return global_position + Vector3(0, built.height * 0.9, 0)


func _physics_process(delta: float) -> void:
	if absorbing:
		return
	if life_left > 0.0:
		life_left -= delta
		if life_left <= 0.0:
			archive()
			return
	if squeeze > 0.0 and not _squeezing_this_frame:
		squeeze = max(squeeze - delta * 2.0, 0.0)
		_apply_squeeze_visual()
	_squeezing_this_frame = false
	if is_npc:
		_npc_tick(delta)
	elif is_bird or def.id == "flock":
		_bird_tick(delta)


var _squeezing_this_frame := false


# ---------- squeezing (player holding on an anchored object) ----------

func apply_squeeze(delta: float, from: Vector3) -> bool:
	## Returns true when the squeeze completes and the object emerges.
	if Stats.now() < cooldown_until:
		return false
	_squeezing_this_frame = true
	squeeze += delta
	_apply_squeeze_visual()
	if squeeze >= SQUEEZE_TIME:
		squeeze = 0.0
		_apply_squeeze_visual()
		var dir := (from - global_position)
		dir.y = 0.0
		dir = dir.normalized()
		trigger(null, dir, true, 1.1)
		return true
	return false


func _apply_squeeze_visual() -> void:
	var k := squeeze / SQUEEZE_TIME
	var wob := sin(Stats.now() * 40.0) * 0.06 * k
	visual.scale = _squeeze_visual_base * Vector3(1.0 + k * 0.12 + wob, 1.0 - k * 0.1, 1.0 + k * 0.12 - wob)


# ---------- the core: emergence ----------

func trigger(hitter: Node, dir: Vector3 = Vector3.UP, by_player: bool = false, power: float = 1.0) -> void:
	if absorbing or Stats.now() < cooldown_until:
		return
	cooldown_until = Stats.now() + TRIGGER_COOLDOWN
	if hitter is EmergentBody:
		# A bullet gets one hit, otherwise chains explode exponentially.
		hitter.hot_until = 0.0
	var world := get_tree().current_scene

	# Recipes: a specific hitter turns me into something else.
	if hitter is EmergentBody and def.recipes.has(hitter.def.name):
		var result: String = def.recipes[hitter.def.name]
		if not result.begins_with("("):
			var into = DB.get_def(result)
			if into != null:
				_transform_into(into, world)
				return

	if def.emits.is_empty():
		# Nothing inside, but it still reacts.
		Juice.squash(visual, 0.25, 0.3)
		Juice.sfx("impact", global_position, -4.0)
		if is_npc:
			_npc_hit()
		return

	var factor := Stats.budget_factor()
	var top := top_position()
	var total := 0
	var emitted_def = null
	for e in def.emits:
		var ed = DB.get_def(e.name)
		if ed == null:
			continue
		emitted_def = ed
		var n: int = max(1, int(round(e.count * factor)))
		for i in n:
			var spread := Vector3(randf_range(-1, 1), randf_range(0.6, 1.4), randf_range(-1, 1)).normalized()
			var d := (dir * 1.4 + spread).normalized()
			var speed := randf_range(5.0, 9.0) * power + (2.0 if ed.size == "S" else 0.0)
			var pos := top + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.6), randf_range(-0.4, 0.4))
			var delay := float(i) * (0.02 if n > 8 else 0.05)
			world.spawn_body(ed, pos, d * speed, delay, true)
			total += 1

	# Feel.
	Juice.squash(visual, 0.3 if def.anchored else 0.45, 0.35)
	Juice.burst(top, built.color, 14 + total, 6.0 + total * 0.1, 0.8 if def.size == "S" else 1.2)
	var tier_boost: int = max(emitted_def.tier if emitted_def else 1, def.tier)
	if by_player and tier_boost >= 3:
		Juice.hitstop(0.06)
		Juice.shake(0.25, 0.25)
	elif by_player:
		Juice.shake(0.12, 0.2)
	Juice.sfx("metal" if def.anchored else "impact", global_position, 0.0 if def.anchored else -3.0)
	Juice.sfx("pop", top, -6.0, 0.8, 1.3)
	if def.pattern == "reproduce" and not def.anchored:
		set_hot()
		apply_central_impulse(Vector3(randf_range(-1, 1), 1.5, randf_range(-1, 1)) * mass * 3.0)
	if is_npc:
		_npc_hit()

	Stats.record_emergence(def, emitted_def, top, total, by_player)


func _transform_into(into, world: Node) -> void:
	var pos := global_position
	Juice.burst(top_position(), Color(1, 1, 0.4), 24, 8.0, 1.3)
	Juice.sfx("powerup", pos, 0.0)
	Juice.hitstop(0.08)
	Juice.shake(0.3, 0.3)
	world.spawn_after(into, pos, 0.05)
	Stats.record_emergence(def, into, pos, 1, true)
	absorb_to(pos + Vector3(0, 1, 0), 0.15)


func _on_body_entered(body: Node) -> void:
	if absorbing or body == self:
		return
	if body is EmergentBody:
		var other := body as EmergentBody
		if other.absorbing:
			return
		var speed: float = other.linear_velocity.length() if not other.freeze else 0.0
		var mine: float = linear_velocity.length() if not freeze else 0.0
		if other.is_hot() and speed > HIT_SPEED:
			var d := (global_position - other.global_position).normalized()
			trigger(other, d, false, clamp(speed / 12.0, 0.6, 1.4))
		elif is_hot() and mine > HIT_SPEED and not other.is_hot():
			# I am the bullet; the thing I hit reacts.
			var d := (other.global_position - global_position).normalized()
			other.trigger(self, d, false, clamp(mine / 12.0, 0.6, 1.4))
	elif body is StaticBody3D or body is CharacterBody3D:
		if is_hot() and linear_velocity.length() > HIT_SPEED + 2.0 and body is StaticBody3D:
			Juice.sfx("impact", global_position, -10.0, 0.7, 1.0)


# ---------- removal ----------

func absorb_to(target: Vector3, time: float = 0.35) -> void:
	if absorbing:
		return
	absorbing = true
	Stats.unregister(self)
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "global_position", target, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(visual, "scale", Vector3.ONE * 0.05, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(queue_free)


func archive() -> void:
	if absorbing:
		return
	absorbing = true
	Stats.unregister(self)
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var t := create_tween()
	t.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


# ---------- eating ----------

func _make_eat_area() -> void:
	_eat_area = Area3D.new()
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = max(built.height, 1.5) * 0.9
	cs.shape = s
	cs.position = built.shape_offset
	_eat_area.add_child(cs)
	_eat_area.collision_layer = 0
	_eat_area.collision_mask = 0
	_eat_area.set_collision_mask_value(LAYER_OBJECTS, true)
	_eat_area.set_collision_mask_value(LAYER_WATER, true)
	add_child(_eat_area)
	_eat_area.body_entered.connect(_on_eat_area_entered)


func _on_eat_area_entered(body: Node) -> void:
	if absorbing or not (body is EmergentBody) or body == self:
		return
	var other := body as EmergentBody
	if other.absorbing or other.def.anchored:
		return
	var wanted := false
	var need := 1
	for e in def.eats:
		if e.name == "*" or e.name == other.def.name:
			wanted = true
			need = e.count
	if not wanted:
		return
	other.absorb_to(global_position + Vector3(0, built.height * 0.5, 0), 0.25)
	eaten += 1
	Juice.sfx("pop", global_position, -8.0, 0.6, 0.9)
	if eaten >= need:
		eaten = 0
		var world := get_tree().current_scene
		var top := top_position()
		var emitted = null
		for e in def.eat_emits:
			var ed = DB.get_def(e.name)
			if ed == null:
				continue
			emitted = ed
			for i in e.count:
				var d := Vector3(randf_range(-1, 1), 1.2, randf_range(-1, 1)).normalized()
				world.spawn_body(ed, top + Vector3(0, 0.3, 0), d * 7.0, i * 0.1, true)
		Juice.burst(top, Color(0.4, 0.9, 0.5), 24, 7.0, 1.2)
		Juice.sfx("fart", top, -2.0, 0.8, 1.1)
		Juice.shake(0.2, 0.25)
		if emitted != null:
			Stats.record_emergence(def, emitted, top, 1, false)


# ---------- NPC behaviour ----------

func _pick_wander() -> void:
	_wander_target = global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	_wander_wait = randf_range(1.0, 3.5)


func _npc_tick(delta: float) -> void:
	if is_hot() or linear_velocity.length() > 3.0:
		return
	# Stand back up.
	var up_rot := Vector3(0, rotation.y, 0)
	rotation.x = lerp_angle(rotation.x, 0.0, delta * 4.0)
	rotation.z = lerp_angle(rotation.z, 0.0, delta * 4.0)
	if enlightened:
		_enlight_timer -= delta
		if _enlight_timer <= 0.0:
			_enlight_timer = randf_range(6.0, 11.0)
			_npc_emerge_burst()
		if _aura:
			_aura.rotate_y(delta * 3.0)
	_wander_wait -= delta
	if _wander_wait <= 0.0:
		_pick_wander()
	var to := _wander_target - global_position
	to.y = 0.0
	if to.length() > 0.5:
		var d := to.normalized()
		var v := linear_velocity
		v.x = lerp(v.x, d.x * 1.6, delta * 3.0)
		v.z = lerp(v.z, d.z * 1.6, delta * 3.0)
		linear_velocity = v
		var target_yaw := atan2(d.x, d.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 5.0)
		sleeping = false


func _npc_hit() -> void:
	Juice.sfx("scream", global_position, -2.0, 0.9, 1.2)
	if enlightened:
		return
	var t := get_tree().create_timer(1.3)
	t.timeout.connect(_enlighten)


func _enlighten(innate: bool = false) -> void:
	if absorbing or enlightened or not is_inside_tree():
		return
	enlightened = true
	_enlight_timer = randf_range(4.0, 8.0) if not innate else randf_range(6.0, 12.0)
	if not innate:
		say("原来如此。", 1.6)
		Juice.sfx("didi", global_position, -6.0)
	_aura = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.55
	tm.rings = 16
	tm.ring_segments = 6
	_aura.mesh = tm
	_aura.material_override = Visuals.rainbow_material(2.0, 1.5)
	_aura.position = Vector3(0, built.height + 0.25, 0)
	add_child(_aura)
	var world := get_tree().current_scene
	if world.has_method("on_npc_enlightened"):
		world.on_npc_enlightened(self)


func _npc_emerge_burst() -> void:
	# A small, local version of the player's release.
	say("涌现出来了！", 1.0)
	var dir := Vector3(sin(rotation.y), 0.35, cos(rotation.y)).normalized()
	var origin := global_position + Vector3(0, 0.8, 0)
	Juice.ring(origin, Color(1, 1, 1, 0.6), 1.6, 0.3)
	Juice.sfx("whoosh", origin, -8.0, 1.0, 1.4)
	Juice.burst(origin + dir, Color(0.8, 0.95, 1.0), 10, 5.0, 0.7)
	var pushed := 0
	for b in Stats.bodies:
		if b == self or not is_instance_valid(b) or b.absorbing:
			continue
		var to: Vector3 = b.global_position - origin
		var dist := to.length()
		if dist > 4.0:
			continue
		if b.def.anchored:
			if dist < 2.5 and to.normalized().dot(dir) > 0.3:
				b.trigger(self, dir, false, 0.8)
			continue
		if to.normalized().dot(dir) < 0.2:
			continue
		var imp: Vector3 = (dir + Vector3(0, 0.3, 0)).normalized() * 9.0 * float(b.mass)
		b.apply_central_impulse(imp)
		b.set_hot(EMIT_HOT_TIME)
		pushed += 1
		if pushed >= 4:
			break


func _bird_tick(delta: float) -> void:
	_wander_wait -= delta
	if _wander_wait <= 0.0:
		_wander_wait = randf_range(0.8, 2.5)
		var hop := Vector3(randf_range(-1, 1), randf_range(1.2, 2.2), randf_range(-1, 1)) * mass * 3.0
		if def.id == "flock":
			hop = Vector3(randf_range(-1, 1), randf_range(-0.2, 0.4), randf_range(-1, 1)) * mass * 2.5
			if global_position.y < 3.0:
				hop.y += mass * 2.0
		apply_central_impulse(hop)
		sleeping = false


# ---------- speech bubble ----------

func say(text: String, time: float = 1.5) -> void:
	if _bubble and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = Label3D.new()
	_bubble.text = text
	_bubble.font = Boot.font
	_bubble.font_size = 56
	_bubble.pixel_size = 0.012
	_bubble.outline_size = 12
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.position = Vector3(0, built.height + 0.7, 0)
	_bubble.scale = Vector3.ZERO
	add_child(_bubble)
	var t := _bubble.create_tween()
	t.tween_property(_bubble, "scale", Vector3.ONE * 1.2, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_bubble, "scale", Vector3.ONE, 0.08)
	t.tween_interval(time)
	t.tween_property(_bubble, "scale", Vector3.ZERO, 0.15)
	t.tween_callback(_bubble.queue_free)
