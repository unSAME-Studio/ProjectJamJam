class_name Player
extends CharacterBody3D
## 气功小人. One verb: hold to attract, release to push.
## No belly: everything stays in the world; collapses happen out there.

const SPEED := 7.0
const ACCEL := 40.0
const FIELD_RADIUS := 6.5
const CONE_COS := 0.35          # ~70° half-angle
const GATHER_DIST := 1.8
const ATTRACT_STRENGTH := 26.0
const SQUEEZE_RANGE := 4.5
const BLAST_RANGE := 3.5
const HOLD_FULL := 1.5

var holding := false
var hold_time := 0.0
var facing := Vector3.FORWARD
var yaw := 0.0
var pitch := -28.0
var cam_distance := 9.0
var _cam_kick := 0.0
var _mouse_captured := true
var _attracted: Array = []
var _hum: AudioStreamPlayer3D
var _charge_label: Label3D
var _field: Area3D
var _gas: CPUParticles3D
var _stream: CPUParticles3D
var locked := false            # cutscenes take the controls away
var k := 1.0:                  # body scale; grows between stages
	set(v):
		k = v
		scale = Vector3.ONE * v

@onready var pivot: Node3D = $Pivot
@onready var arm: SpringArm3D = $Pivot/SpringArm3D
@onready var camera: Camera3D = $Pivot/SpringArm3D/Camera3D
@onready var body_visual: Node3D = $Visual


func _ready() -> void:
	Juice.camera = camera
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(EmergentBody.LAYER_PLAYER, true)
	set_collision_mask_value(EmergentBody.LAYER_WORLD, true)
	set_collision_mask_value(EmergentBody.LAYER_OBJECTS, true)
	_build_visual()
	_build_field()
	_build_stream()
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = load("res://assets/sounds/hum.wav")
	_hum.volume_db = -14.0
	add_child(_hum)
	_charge_label = Label3D.new()
	_charge_label.font = Boot.font_brush
	_charge_label.font_size = 72
	_charge_label.pixel_size = 0.013
	_charge_label.outline_size = 16
	_charge_label.modulate = Color(1.0, 0.95, 0.6)
	_charge_label.outline_modulate = Color(0.45, 0.05, 0.05)
	_charge_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_charge_label.no_depth_test = true
	_charge_label.position = Vector3(0, 2.4, 0)
	_charge_label.visible = false
	add_child(_charge_label)
	if not Boot.autopilot and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	arm.add_excluded_object(get_rid())
	pivot.top_level = true


func _build_visual() -> void:
	# Placeholder 气功小人: capsule body, round head, two "qi" hands.
	var body := CapsuleMesh.new()
	body.radius = 0.36
	body.height = 1.25
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.95, 0.85, 0.3)
	var bmi := MeshInstance3D.new()
	bmi.mesh = body
	bmi.material_override = bm
	bmi.position = Vector3(0, 0.65, 0)
	body_visual.add_child(bmi)
	var head := SphereMesh.new()
	head.radius = 0.32
	head.height = 0.64
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.98, 0.82, 0.68)
	var hmi := MeshInstance3D.new()
	hmi.mesh = head
	hmi.material_override = hm
	hmi.position = Vector3(0, 1.55, 0)
	body_visual.add_child(hmi)
	var eye := BoxMesh.new()
	eye.size = Vector3(0.08, 0.04, 0.02)
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.05, 0.05, 0.05)
	for x in [-0.1, 0.1]:
		var e := MeshInstance3D.new()
		e.mesh = eye
		e.material_override = em
		e.position = Vector3(x, 1.6, 0.3)
		body_visual.add_child(e)
	var belt := TorusMesh.new()
	belt.inner_radius = 0.34
	belt.outer_radius = 0.42
	var btm := MeshInstance3D.new()
	btm.mesh = belt
	btm.material_override = Visuals.rainbow_material(2.0, 1.0)
	btm.position = Vector3(0, 0.75, 0)
	body_visual.add_child(btm)
	# gas burst particles at the dantian
	_gas = CPUParticles3D.new()
	_gas.one_shot = true
	_gas.explosiveness = 0.9
	_gas.amount = 40
	_gas.lifetime = 0.5
	_gas.emitting = false
	var gm := SphereMesh.new()
	gm.radius = 0.16
	gm.height = 0.32
	gm.radial_segments = 6
	gm.rings = 3
	_gas.mesh = gm
	_gas.direction = Vector3(0, 0, 1)
	_gas.spread = 25.0
	_gas.initial_velocity_min = 10.0
	_gas.initial_velocity_max = 18.0
	_gas.gravity = Vector3.ZERO
	_gas.scale_amount_min = 0.6
	_gas.scale_amount_max = 1.6
	_gas.color = Color(0.75, 0.95, 1.0, 0.9)
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.vertex_color_use_as_albedo = true
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gas.material_override = gmat
	_gas.position = Vector3(0, 0.75, 0.3)
	body_visual.add_child(_gas)


func _build_stream() -> void:
	# While holding: little streaks of qi flowing into the gather point.
	_stream = CPUParticles3D.new()
	_stream.emitting = false
	_stream.amount = 60
	_stream.lifetime = 0.45
	_stream.local_coords = false
	_stream.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	_stream.emission_sphere_radius = FIELD_RADIUS * 0.75
	_stream.direction = Vector3.ZERO
	_stream.spread = 180.0
	_stream.initial_velocity_min = 0.0
	_stream.initial_velocity_max = 0.5
	_stream.radial_accel_min = -60.0
	_stream.radial_accel_max = -40.0
	_stream.gravity = Vector3.ZERO
	_stream.scale_amount_min = 0.5
	_stream.scale_amount_max = 1.2
	var m := BoxMesh.new()
	m.size = Vector3(0.06, 0.06, 0.45)
	_stream.mesh = m
	_stream.particle_flag_align_y = true
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(0.8, 1.0, 1.0, 0.9), Color(1.0, 0.9, 0.5, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_stream.color_ramp = g
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stream.material_override = mat
	add_child(_stream)


func _build_field() -> void:
	_field = Area3D.new()
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = FIELD_RADIUS
	cs.shape = s
	cs.position = Vector3(0, 0.8, 0)
	_field.add_child(cs)
	_field.collision_layer = 0
	_field.collision_mask = 0
	_field.set_collision_mask_value(EmergentBody.LAYER_OBJECTS, true)
	_field.set_collision_mask_value(EmergentBody.LAYER_WATER, true)
	add_child(_field)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		yaw -= event.relative.x * 0.18
		pitch = clamp(pitch - event.relative.y * 0.12, -70.0, 10.0)
	if event.is_action_pressed("toggle_mouse"):
		_mouse_captured = not _mouse_captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("reset"):
		Engine.time_scale = 1.0
		Stats.reset()
		get_tree().reload_current_scene()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_distance = max(5.0 * k, cam_distance - k)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_distance = min(22.0 * k, cam_distance + k)


func _physics_process(delta: float) -> void:
	# --- camera ---
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(rx) > 0.15:
		yaw -= rx * 140.0 * delta
	if abs(ry) > 0.15:
		pitch = clamp(pitch - ry * 90.0 * delta, -70.0, 10.0)
	pivot.rotation_degrees = Vector3(pitch, yaw, 0)
	pivot.global_position = pivot.global_position.lerp(global_position + Vector3(0, 1.2 * k, 0), min(delta * 12.0, 1.0))
	var auto_zoom: float = clamp(Stats.bodies.size() * 0.012, 0.0, 5.0) * k
	var hold_zoom: float = -2.2 * k * clamp(hold_time / HOLD_FULL, 0.0, 1.0)
	_cam_kick = lerp(_cam_kick, 0.0, delta * 6.0)
	arm.spring_length = lerp(arm.spring_length, cam_distance + auto_zoom + hold_zoom + _cam_kick, delta * 8.0)

	# --- movement ---
	var input := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var dir := (cam_basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	dir = dir.normalized()
	var speed := SPEED * pow(k, 0.75) * (0.45 if holding else 1.0)
	velocity.x = move_toward(velocity.x, dir.x * speed, ACCEL * k * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, ACCEL * k * delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	# Facing: aim with camera while holding, otherwise face movement.
	var cam_forward: Vector3 = (cam_basis * Vector3(0, 0, -1)).normalized()
	if holding:
		facing = facing.slerp(cam_forward, min(delta * 10.0, 1.0))
	elif dir.length() > 0.1:
		facing = facing.slerp(dir, min(delta * 10.0, 1.0))
	body_visual.rotation.y = lerp_angle(body_visual.rotation.y, atan2(facing.x, facing.z), delta * 12.0)

	# --- the verb ---
	if locked:
		if holding:
			_release()
		return
	if Input.is_action_just_pressed("emerge"):
		_begin_hold()
	if holding:
		hold_time += delta
		_hold_tick(delta)
		if Input.is_action_just_released("emerge") or not Input.is_action_pressed("emerge"):
			_release()


func gather_point() -> Vector3:
	return global_position + (facing * GATHER_DIST + Vector3(0, 0.9, 0)) * k


func _begin_hold() -> void:
	holding = true
	hold_time = 0.0
	_attracted.clear()
	_hum.pitch_scale = 0.8
	_hum.play()
	_charge_label.text = "力量——"
	_charge_label.visible = true
	_charge_label.scale = Vector3.ONE * 0.6
	_stream.emitting = true
	var t := body_visual.create_tween()
	t.tween_property(body_visual, "scale", Vector3(1.15, 0.8, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hold_tick(delta: float) -> void:
	var k: float = clamp(hold_time / HOLD_FULL, 0.0, 1.0)
	_hum.pitch_scale = 0.8 + k * 1.1
	_charge_label.scale = Vector3.ONE * (0.6 + k * 0.9)
	_charge_label.text = "力量——" + "—".repeat(int(hold_time * 2.0))
	var gp := gather_point()
	_stream.global_position = gp
	_stream.radial_accel_min = -60.0 * k
	_stream.radial_accel_max = -40.0 * k
	var origin := global_position + Vector3(0, 0.8, 0) * k
	_restore_gravity()
	for body in _field.get_overlapping_bodies():
		if not (body is EmergentBody):
			continue
		var b := body as EmergentBody
		if b.absorbing:
			continue
		var to := b.global_position - origin
		var dist := to.length()
		var in_cone := dist < 1.5 * k or to.normalized().dot(facing) > CONE_COS
		if not in_cone:
			continue
		if b.def.anchored:
			if dist <= SQUEEZE_RANGE * k + b.built.height * 0.3:
				b.apply_squeeze(delta, origin)
			continue
		_attracted.append(b)
		var pull := gp - b.global_position
		var pd := pull.length()
		if pd < 0.05:
			continue
		var strength: float = ATTRACT_STRENGTH * sqrt(k) * clamp(pd / k, 0.3, 3.0) / 3.0
		var force: Vector3 = pull.normalized() * strength * b.mass
		# damp so they clump instead of orbiting
		force -= b.linear_velocity * 2.5 * b.mass
		b.apply_central_force(force)
		b.gravity_scale = b.default_gravity * (0.15 if pd < 2.5 * k else 0.6)
		b.sleeping = false


func _restore_gravity() -> void:
	for b in _attracted:
		if is_instance_valid(b):
			b.gravity_scale = b.default_gravity
	_attracted.clear()


func _release() -> void:
	holding = false
	var power: float = clamp(hold_time / HOLD_FULL, 0.25, 1.0)
	_hum.stop()
	_stream.emitting = false
	_charge_label.text = "涌现出来了！！！"
	_charge_label.scale = Vector3.ONE * 1.3
	var lt := _charge_label.create_tween()
	lt.tween_property(_charge_label, "scale", Vector3.ONE * 1.8, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(0.8)
	lt.tween_property(_charge_label, "scale", Vector3.ZERO, 0.15)
	lt.tween_callback(func(): _charge_label.visible = false)
	var t := body_visual.create_tween()
	t.tween_property(body_visual, "scale", Vector3(0.8, 1.3, 0.8), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(body_visual, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var origin := global_position + Vector3(0, 0.8, 0) * k
	var dir := (facing + Vector3(0, 0.22, 0)).normalized()
	var launch_speed: float = (9.0 + 20.0 * power) * sqrt(k)
	var launched := 0
	for b in _attracted:
		if not is_instance_valid(b) or b.absorbing:
			continue
		b.gravity_scale = b.default_gravity
		var spread := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)) * 0.18
		var v: Vector3 = (dir + spread).normalized() * launch_speed
		b.linear_velocity = v
		b.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * b.mass * 2.0)
		b.set_hot()
		b.player_shot_until = b.hot_until
		launched += 1
	_attracted.clear()
	# Everything loose in the cone (not necessarily gathered) also gets a shove,
	# and anchored things right in front get blasted.
	for body in _field.get_overlapping_bodies():
		if not (body is EmergentBody):
			continue
		var b := body as EmergentBody
		if b.absorbing:
			continue
		var to := b.global_position - origin
		var dist := to.length()
		if dist > (BLAST_RANGE + 1.5) * k or to.normalized().dot(facing) < CONE_COS:
			continue
		if b.def.anchored:
			if dist <= BLAST_RANGE * k + b.built.height * 0.3:
				b.trigger(null, facing, true, 0.8 + power * 0.6)
		elif not b.is_hot():
			b.apply_central_impulse((dir + to.normalized() * 0.4).normalized() * launch_speed * 0.6 * b.mass)
			b.set_hot(1.2)
			b.player_shot_until = b.hot_until

	_gas.restart()
	_gas.emitting = true
	Juice.ring(origin + facing * 0.8 * k, Color(0.8, 0.95, 1.0, 0.7), (2.0 + 2.5 * power) * k, 0.3)
	Juice.sfx("whoosh", origin, 0.0, 0.9 + power * 0.3, 1.0 + power * 0.4)
	Juice.shake(0.12 + 0.3 * power, 0.25)
	_cam_kick = (1.2 + 1.5 * power) * k
	Stats.record_release(power)
	hold_time = 0.0
