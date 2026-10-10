extends Node3D
## Builds the street block, spawns objects from the content table, and owns
## the spawn API used by everything else.

const CITY := "res://assets/models/city/"

# name, position, yaw (deg)
const LAYOUT := [
	["ATM", Vector3(6, 0, -8), 0], ["ATM", Vector3(8.4, 0, -8), 0],
	["自动售货机", Vector3(-7, 0, -8), 0],
	["小卖部", Vector3(-12, 0, -9), 0],
	["报刊亭", Vector3(14, 0, -9), 0],
	["网吧", Vector3(0, 0, -22), 0],
	["消防栓", Vector3(4, 0, 4), 0], ["消防栓", Vector3(-16, 0, 12), 0],
	["下水道", Vector3(7, 0, 6), 0], ["下水道", Vector3(-13, 0, 14), 0],
	["垃圾桶", Vector3(-4, 0, 4), 0], ["垃圾桶", Vector3(11, 0, 11), 0], ["垃圾桶", Vector3(-9, 0, -6), 0],
	["树", Vector3(-14, 0, 2), 0], ["树", Vector3(-18, 0, -3), 0], ["树", Vector3(16, 0, 3), 0], ["树", Vector3(20, 0, -2), 0],
	["树", Vector3(-20, 0, 8), 0], ["树", Vector3(18, 0, 9), 0],
	["电线杆", Vector3(10, 0, -4), 0], ["电线杆", Vector3(-10, 0, -4), 0], ["电线杆", Vector3(10, 0, 16), 0], ["电线杆", Vector3(-10, 0, 16), 0],
	["大喇叭", Vector3(-6, 0, 8), 0],
	["汽车", Vector3(-2, 0, 10), 90], ["汽车", Vector3(5, 0, 12), 90], ["汽车", Vector3(-9, 0, 12), 90], ["汽车", Vector3(14, 0, -2), 0],
	["公交车", Vector3(0, 0, 16), 90],
]

var player: Player
var hud: CanvasLayer
var _desat_mat: ShaderMaterial
var _desat_rect: ColorRect
var _bodies_root: Node3D
var _ambient: AudioStreamPlayer


func _ready() -> void:
	Stats.set_world(self)
	_bodies_root = Node3D.new()
	_bodies_root.name = "Bodies"
	add_child(_bodies_root)
	_build_ground()
	_build_props()
	player = $Player
	hud = $HUD
	hud.set_camera(player.camera)
	_spawn_layout()
	_spawn_people(12)
	_spawn_pigeons(14)
	_build_desaturate()
	Stats.first_release.connect(_on_first_release)
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = load("res://assets/sounds/CityAmbience.ogg")
	_ambient.volume_db = -16.0
	add_child(_ambient)
	_ambient.play()
	Juice.ui_sfx("dialup", -8.0)
	if Boot.autopilot:
		var ap: Node = load("res://scripts/autopilot.gd").new()
		add_child(ap)
	print("[world] ready: %s" % Stats.summary())


# ---------- spawning API ----------

func spawn_body(def, pos: Vector3, velocity: Vector3 = Vector3.ZERO, delay: float = 0.0, hot: bool = false) -> void:
	if delay > 0.0:
		var t := get_tree().create_timer(delay)
		t.timeout.connect(func(): _do_spawn(def, pos, velocity, hot))
	else:
		_do_spawn(def, pos, velocity, hot)


func _do_spawn(def, pos: Vector3, velocity: Vector3, hot: bool) -> EmergentBody:
	if def == null or not def.is_entity():
		return null
	var b := EmergentBody.create(def)
	_bodies_root.add_child(b)
	if def.anchored:
		# Fixed things grow out of the ground where they land.
		pos.y = 0.0
		velocity = Vector3.ZERO
		pos += Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	b.global_position = pos
	b.rotation.y = randf_range(0, TAU)
	if velocity != Vector3.ZERO:
		b.linear_velocity = velocity
		b.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	if hot and not def.anchored:
		# Only some shrapnel stays "live"; otherwise chains run away.
		var chance := 0.25 if def.pattern == "reproduce" else 0.5
		if randf() < chance:
			b.set_hot(EmergentBody.EMIT_HOT_TIME)
	# pop in
	var base: Vector3 = b.visual.scale
	b.visual.scale = base * 0.1
	var t := b.create_tween()
	t.tween_property(b.visual, "scale", base, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return b


func spawn_after(def, pos: Vector3, delay: float) -> void:
	var t := get_tree().create_timer(delay)
	t.timeout.connect(func():
		var b := _do_spawn(def, pos, Vector3.ZERO, false)
		if b:
			Juice.burst(pos, Color(1, 1, 0.5), 30, 9.0, 1.5)
			Juice.ring(pos, Color(1, 0.9, 0.3, 0.8), 4.0, 0.45)
			Juice.sfx("explosion" if def.tier >= 4 else "powerup", pos, -2.0)
			Juice.shake(0.3 + def.tier * 0.08, 0.35)
			if def.tier >= 3:
				Juice.slowmo(0.3, 0.12)
			if def.tier >= 3:
				_drop_name_chars(def.name, pos + Vector3(0, 2.5, 0))
	)


func _drop_name_chars(name: String, pos: Vector3) -> void:
	# The caption's characters fall into the world as rainbow blocks.
	var n := name.length()
	for i in n:
		var ch := name.substr(i, 1)
		var b := RigidBody3D.new()
		b.add_to_group("char")
		var mi := MeshInstance3D.new()
		mi.mesh = Visuals.char_body_mesh(ch, 1.1)
		mi.material_override = Visuals.rainbow_material(2.0, 1.0)
		b.add_child(mi)
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(1.0, 1.1, 0.35)
		cs.shape = s
		b.add_child(cs)
		b.mass = 1.5
		b.collision_layer = 1 << (EmergentBody.LAYER_OBJECTS - 1)
		b.collision_mask = (1 << (EmergentBody.LAYER_WORLD - 1)) | (1 << (EmergentBody.LAYER_OBJECTS - 1)) | (1 << (EmergentBody.LAYER_PLAYER - 1))
		_bodies_root.add_child(b)
		b.global_position = pos + Vector3((i - n * 0.5 + 0.5) * 1.2, 0, 0)
		b.linear_velocity = Vector3(randf_range(-2, 2), randf_range(2, 5), randf_range(-2, 2))
		b.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
		var t := get_tree().create_timer(12.0 + i)
		t.timeout.connect(func():
			if is_instance_valid(b):
				var tw := b.create_tween()
				tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.4)
				tw.tween_callback(b.queue_free))


func on_npc_enlightened(_npc: EmergentBody) -> void:
	pass


# ---------- world building ----------

func _spawn_layout() -> void:
	for entry in LAYOUT:
		var def = DB.get_def(entry[0])
		if def == null:
			push_warning("no def for %s" % entry[0])
			continue
		var b := _do_spawn(def, entry[1], Vector3.ZERO, false)
		if b:
			b.rotation.y = deg_to_rad(entry[2])


func _spawn_people(n: int) -> void:
	var def = DB.get_def("路人")
	for i in n:
		var p := Vector3(randf_range(-18, 18), 0.2, randf_range(-14, 18))
		_do_spawn(def, p, Vector3.ZERO, false)
	var g = DB.get_def("大爷")
	if g:
		_do_spawn(g, Vector3(-16, 0.2, 5), Vector3.ZERO, false)


func _spawn_pigeons(n: int) -> void:
	var def = DB.get_def("鸽子")
	for i in n:
		var p := Vector3(randf_range(-10, 10), 0.4, randf_range(-6, 10))
		_do_spawn(def, p, Vector3.ZERO, false)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(140, 2, 140)
	cs.shape = s
	cs.position = Vector3(0, -1, 0)
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(140, 140)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.68, 0.4)
	m.roughness = 1.0
	mi.material_override = m
	ground.add_child(mi)
	add_child(ground)
	# roads: a cross
	for r in [[Vector3(0, 0.01, 2), Vector3(70, 0.02, 7)], [Vector3(0, 0.01, 0), Vector3(7, 0.02, 70)]]:
		var road := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = r[1]
		road.mesh = bm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.28, 0.28, 0.3)
		road.material_override = rm
		road.position = r[0]
		add_child(road)
	for i in range(-6, 7):
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(2.0, 0.03, 0.25)
		dash.mesh = dm
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.95, 0.95, 0.8)
		dash.material_override = dmat
		dash.position = Vector3(i * 5.0, 0.03, 2)
		add_child(dash)
	# sidewalk strips
	for z in [-2.0, 6.0]:
		var sw := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(70, 0.08, 1.5)
		sw.mesh = sm
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.8, 0.78, 0.72)
		sw.material_override = smat
		sw.position = Vector3(0, 0.04, z)
		add_child(sw)


func _build_props() -> void:
	# Borrowed low-poly city pieces as static scenery with box collisions.
	var houses := ["house2.obj", "house3.obj", "small_buildingB.obj"]
	var spots := [
		[Vector3(-22, 0, -18), 0.0], [Vector3(-10, 0, -20), 0.0], [Vector3(12, 0, -20), 0.0], [Vector3(24, 0, -18), 0.0],
		[Vector3(-26, 0, 0), 90.0], [Vector3(28, 0, 2), -90.0], [Vector3(-24, 0, 22), 180.0], [Vector3(26, 0, 22), 180.0],
		[Vector3(-8, 0, 26), 180.0], [Vector3(10, 0, 26), 180.0],
	]
	for i in spots.size():
		_place_static(CITY + houses[i % houses.size()], spots[i][0], spots[i][1], 7.0 + (i % 3) * 1.5)
	for i in 4:
		_place_static(CITY + "Bench.obj", Vector3(-6 + i * 4, 0, -5.5), 0.0, 0.9)
	_place_static(CITY + "busstop.obj", Vector3(6, 0, 7.5), 180.0, 3.0)
	_place_static(CITY + "trafficlight.obj", Vector3(-4.5, 0, 6.5), 0.0, 4.0)


func _place_static(path: String, pos: Vector3, yaw_deg: float, height: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var mesh: Mesh = load(path)
	if mesh == null:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var aabb := mesh.get_aabb()
	var s: float = height / max(aabb.size.y, 0.001)
	mi.scale = Vector3.ONE * s
	mi.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s, -aabb.get_center().z * s)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size * s
	cs.shape = box
	cs.position = Vector3(0, aabb.size.y * s * 0.5, 0)
	body.add_child(cs)
	add_child(body)
	body.global_position = pos
	body.rotation.y = deg_to_rad(yaw_deg)


func _build_desaturate() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	_desat_rect = ColorRect.new()
	_desat_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desat_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desat_mat = ShaderMaterial.new()
	_desat_mat.shader = load("res://assets/shaders/desaturate.gdshader")
	_desat_mat.set_shader_parameter("radius", 0.0)
	_desat_mat.set_shader_parameter("aspect", 16.0 / 9.0)
	_desat_rect.material = _desat_mat
	layer.add_child(_desat_rect)
	add_child(layer)


func _on_first_release() -> void:
	# 插曲 A：游戏涌现出来了。Logo gets spat out; colour spreads from where it lands.
	var origin := player.global_position + player.facing * 2.0 + Vector3(0, 1.5, 0)
	_drop_name_chars("涌现出来了！", origin)
	var center := player.camera.unproject_position(origin) / Vector2(get_viewport().get_visible_rect().size)
	_desat_mat.set_shader_parameter("center", center)
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_method(func(v): _desat_mat.set_shader_parameter("radius", v), 0.0, 2.6, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): _desat_rect.get_parent().queue_free())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn"):
		var names := ["鸽子", "钱", "路人", "苹果", "汽车"]
		var def = DB.get_def(names.pick_random())
		spawn_body(def, player.global_position + player.facing * 3.0 + Vector3(0, 3, 0), Vector3.ZERO)
