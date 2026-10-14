extends Node3D
## Builds the street block, spawns objects from the content table, owns the
## spawn API, and runs the stage transitions:
##   街道 (k=1) → 城市 (k=3.5, player grows, buildings rise) → 地球 (preview:
##   camera pulls out to orbit, then comes back down).

const CITY_K := 3.5
const GROUND_SIZE := 1800.0

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

# The city ring: emergent (anchored, triggerable) buildings closest to the street.
const CITY_BUILDINGS := [
	["银行", Vector3(0, 0, -70)], ["公司", Vector3(60, 0, -60)], ["学校", Vector3(-65, 0, -55)],
	["工地", Vector3(70, 0, 5)], ["电视台", Vector3(-72, 0, 5)], ["电脑城", Vector3(55, 0, 65)],
	["公司", Vector3(-55, 0, 65)], ["网吧", Vector3(0, 0, 75)], ["银行", Vector3(115, 0, -20)],
	["公司", Vector3(-115, 0, -25)], ["学校", Vector3(110, 0, 60)], ["工地", Vector3(-110, 0, 55)],
]

var player: Player
var hud: CanvasLayer
var k := 1.0                    # scale of things spawned by the level itself
var transitioning := false
var _desat_mat: ShaderMaterial
var _desat_rect: ColorRect
var _bodies_root: Node3D
var _ambient: AudioStreamPlayer
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sky_colors: Array = []
var _earth_root: Node3D


func _ready() -> void:
	Stats.set_world(self)
	_bodies_root = Node3D.new()
	_bodies_root.name = "Bodies"
	add_child(_bodies_root)
	_env = $WorldEnvironment.environment
	_sky = _env.sky.sky_material
	_sky_colors = [_sky.sky_top_color, _sky.sky_horizon_color, _sky.ground_horizon_color, _sky.ground_bottom_color]
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
	Stats.stage_goal_reached.connect(func(st):
		if st < 3:
			advance_stage())
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

func spawn_body(def, pos: Vector3, velocity: Vector3 = Vector3.ZERO, delay: float = 0.0, hot: bool = false, scale_k: float = -1.0) -> void:
	var sk := k if scale_k <= 0.0 else scale_k
	if delay > 0.0:
		var t := get_tree().create_timer(delay)
		t.timeout.connect(func(): _do_spawn(def, pos, velocity, hot, sk))
	else:
		_do_spawn(def, pos, velocity, hot, sk)


func _do_spawn(def, pos: Vector3, velocity: Vector3, hot: bool, scale_k: float = -1.0, pop: bool = true) -> EmergentBody:
	if def == null or not def.is_entity():
		return null
	var sk := k if scale_k <= 0.0 else scale_k
	var b := EmergentBody.create(def, sk)
	_bodies_root.add_child(b)
	if def.anchored:
		# Rooted things grow out of the ground where they land.
		if velocity != Vector3.ZERO:
			pos += Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)) * sk
		pos.y = 0.0
		velocity = Vector3.ZERO
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
	if not pop:
		return b
	var base: Vector3 = b.visual.scale
	b.visual.scale = base * 0.1
	var t := b.create_tween()
	t.tween_property(b.visual, "scale", base, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return b


func spawn_after(def, pos: Vector3, delay: float, scale_k: float = -1.0) -> void:
	var sk := k if scale_k <= 0.0 else scale_k
	var t := get_tree().create_timer(delay)
	t.timeout.connect(func():
		var b := _do_spawn(def, pos, Vector3.ZERO, false, sk)
		if b:
			Juice.burst(pos, Color(1, 1, 0.5), 30, 9.0 * sqrt(sk), 1.5 * sk)
			Juice.ring(pos, Color(1, 0.9, 0.3, 0.8), 4.0 * sk, 0.45)
			Juice.sfx("explosion" if def.tier >= 4 else "powerup", pos, -2.0)
			Juice.shake(0.3 + def.tier * 0.08, 0.35)
			if def.tier >= 3:
				Juice.slowmo(0.3, 0.12)
				_drop_name_chars(def.name, pos + Vector3(0, 2.5, 0) * sk, sk)
	)


func _drop_name_chars(name: String, pos: Vector3, sk: float = 1.0) -> void:
	# The caption's characters fall into the world as rainbow blocks.
	var n := name.length()
	for i in n:
		var ch := name.substr(i, 1)
		var b := RigidBody3D.new()
		b.add_to_group("char")
		var mi := MeshInstance3D.new()
		mi.mesh = Visuals.char_body_mesh(ch, 1.1 * sk)
		mi.material_override = Visuals.rainbow_material(2.0, 1.0 / sk)
		b.add_child(mi)
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(1.0, 1.1, 0.35) * sk
		cs.shape = s
		b.add_child(cs)
		b.mass = 1.5 * sk * sk
		b.collision_layer = 1 << (EmergentBody.LAYER_OBJECTS - 1)
		b.collision_mask = (1 << (EmergentBody.LAYER_WORLD - 1)) | (1 << (EmergentBody.LAYER_OBJECTS - 1)) | (1 << (EmergentBody.LAYER_PLAYER - 1))
		_bodies_root.add_child(b)
		b.global_position = pos + Vector3((i - n * 0.5 + 0.5) * 1.2 * sk, 0, 0)
		b.linear_velocity = Vector3(randf_range(-2, 2), randf_range(2, 5), randf_range(-2, 2)) * sqrt(sk)
		b.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
		var t := get_tree().create_timer(12.0 + i)
		t.timeout.connect(func():
			if is_instance_valid(b):
				var tw := b.create_tween()
				tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.4)
				tw.tween_callback(b.queue_free))


func on_npc_enlightened(_npc: EmergentBody) -> void:
	pass


# ---------- stages ----------

func advance_stage() -> void:
	if transitioning:
		return
	if Stats.stage == 1:
		_to_city()
	else:
		# 2 → Earth (once, automatically). At 3 only the debug key replays it.
		_earth_preview()


func _begin_cutscene() -> void:
	transitioning = true
	player.locked = true
	Juice.reset_time()
	Juice.cinematic = true


func _end_cutscene() -> void:
	transitioning = false
	player.locked = false
	Juice.cinematic = false


func _to_city() -> void:
	# 街道 → 城市: camera pulls way out, the street freezes into a diorama,
	# a city grows out of the ground around it, the player grows to match,
	# and the camera settles at the new scale.
	_begin_cutscene()
	k = CITY_K
	Juice.ui_sfx("startup", -2.0, 0.8)
	Juice.shake(0.4, 0.5)
	_bake_street()
	var city := _build_city()
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.set_parallel(true)
	t.tween_property(player, "cam_distance", 85.0, 2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(player, "pitch", -58.0, 2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): _rise(city, 2.6)).set_delay(0.7)
	t.tween_callback(func():
		hud.show_l3("城市", "涌现出来了。", 5)
		Juice.ui_sfx("chime", -2.0, 0.8)).set_delay(1.6)
	t.tween_property(player, "k", CITY_K, 1.4).set_delay(1.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		# the new body is the thing that just emerged
		player.set_body("excavator")
		hud.show_l2("挖掘机", "涌现出来了。", player.global_position + Vector3(0, 2, 0) * CITY_K, 4, "first")).set_delay(2.2)
	t.tween_property(player, "cam_distance", 9.0 * CITY_K, 1.6).set_delay(3.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(player, "pitch", -30.0, 1.6).set_delay(3.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func():
		_spawn_city_life()
		Stats.enter_stage(2)
		_end_cutscene()).set_delay(5.3)


func _bake_street() -> void:
	# Loose stage-1 things stop where they are: the old chaos becomes scenery.
	for b in Stats.bodies.duplicate():
		if not is_instance_valid(b) or b.def.anchored or b.size_mult != 1.0:
			continue
		b.absorbing = true
		Stats.unregister(b)
		b.freeze = true
		b.collision_layer = 0
		b.collision_mask = 0


func _build_city() -> Array:
	## Returns [{node, visual, delay}] for the rise animation.
	var items: Array = []
	# roads
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.28, 0.28, 0.3)
	for off in [-205.0, -140.0, -90.0, -38.0, 38.0, 90.0, 140.0, 205.0]:
		for along_x in [true, false]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(900, 0.05, 16) if along_x else Vector3(16, 0.05, 900)
			mi.mesh = bm
			mi.material_override = road_mat
			mi.position = Vector3(0, 0.02, off) if along_x else Vector3(off, 0.02, 0)
			add_child(mi)
			mi.scale = Vector3(1, 1, 0.01) if along_x else Vector3(0.01, 1, 1)
			items.append({"node": mi, "visual": mi, "delay": abs(off) / 450.0, "kind": "road", "along_x": along_x})
	# emergent buildings
	for entry in CITY_BUILDINGS:
		var def = DB.get_def(entry[0])
		if def == null:
			continue
		var b := _do_spawn(def, entry[1], Vector3.ZERO, false, CITY_K, false)
		if b:
			b.rotation.y = atan2(-entry[1].x, -entry[1].z)  # sign faces the street
			var base: Vector3 = b.visual.scale
			b.visual.scale = Vector3(base.x, base.y * 0.01, base.z)
			items.append({"node": b, "visual": b.visual, "delay": entry[1].length() / 180.0, "kind": "body", "base": base})
	# skyline: physical, squeezable towers
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for ring in [[165.0, 22], [250.0, 30], [360.0, 40]]:
		var r: float = ring[0]
		var n: int = ring[1]
		for i in n:
			var a := TAU * float(i) / n + rng.randf_range(-0.05, 0.05)
			var pos := Vector3(cos(a) * r, 0, sin(a) * r) + Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15))
			var t := _spawn_prop("高楼", pos, rad_to_deg(atan2(-pos.x, -pos.z)), r / 165.0)
			if t:
				var base: Vector3 = t.visual.scale
				t.visual.scale = Vector3(base.x, base.y * 0.01, base.z)
				items.append({"node": t, "visual": t.visual, "delay": r / 180.0 + rng.randf_range(0.0, 0.3), "kind": "body", "base": base})
	return items



func _rise(items: Array, total: float) -> void:
	for it in items:
		var vis: Node3D = it.visual
		if not is_instance_valid(vis):
			continue
		var t := vis.create_tween()
		t.set_ignore_time_scale(true)
		var d: float = min(it.delay, 1.0) * total * 0.7
		if it.kind == "road":
			var target := Vector3.ONE
			t.tween_property(vis, "scale", target, 0.6).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			continue
		var base: Vector3 = it.get("base", Vector3.ONE)
		t.tween_property(vis, "scale", base, 0.7).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var node: Node3D = it.node
		t.parallel().tween_callback(func():
			if is_instance_valid(node):
				Juice.burst(node.global_position + Vector3(0, 2, 0), Color(0.85, 0.8, 0.7), 12, 14.0, 4.0)).set_delay(d)
	var rumble := create_tween()
	rumble.set_ignore_time_scale(true)
	for i in 6:
		rumble.tween_callback(func():
			Juice.sfx("explosion", player.global_position + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)), -6.0, 0.4, 0.6)
			Juice.shake(0.25, 0.3))
		rumble.tween_interval(total / 6.0)


func _spawn_city_life() -> void:
	var worker = DB.get_def("上班族")
	var car = DB.get_def("汽车")
	var bus = DB.get_def("公交车")
	var money = DB.get_def("钱")
	for i in 12:
		var a := randf() * TAU
		var r := randf_range(45.0, 120.0)
		_do_spawn(worker, Vector3(cos(a) * r, 1, sin(a) * r), Vector3.ZERO, false, CITY_K)
	for i in 10:
		var along := randf_range(-160, 160)
		var lane: float = [-90.0, 90.0, -140.0, 140.0].pick_random()
		var p := Vector3(along, 1, lane) if randf() < 0.5 else Vector3(lane, 1, along)
		_do_spawn(car if randf() < 0.75 else bus, p, Vector3.ZERO, false, CITY_K)
	for i in 8:
		_do_spawn(money, player.global_position + Vector3(randf_range(-20, 20), 8, randf_range(-20, 20)), Vector3.ZERO, false, CITY_K)


func _earth_preview() -> void:
	# 城市 → 地球 (preview): powers-of-ten pull-out to orbit, hold, come back.
	_begin_cutscene()
	_build_earth()
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 300000.0
	add_child(cam)
	var start_xf: Transform3D = player.camera.global_transform
	cam.global_transform = start_xf
	cam.make_current()
	var focus: Vector3 = player.global_position
	var h0: float = max(start_xf.origin.y, 10.0)
	var h1 := 26000.0
	var place := func(u: float) -> void:
		var e: float = u * u * (3.0 - 2.0 * u)
		var h: float = h0 * pow(h1 / h0, e)
		var top := focus + Vector3(0, h, h * 0.35)
		var blend: float = clamp(u / 0.2, 0.0, 1.0)
		var pos: Vector3 = start_xf.origin.lerp(top, blend)
		cam.global_position = pos
		cam.near = max(0.05, h * 0.002)
		var look: Vector3 = (start_xf.origin + -start_xf.basis.z * 10.0).lerp(focus, blend)
		if pos.distance_to(look) > 0.01:
			cam.look_at(look, Vector3.UP)
		_set_space(clamp((u - 0.25) / 0.5, 0.0, 1.0))
	var t := create_tween()
	t.set_ignore_time_scale(true)
	Juice.ui_sfx("powerup", -2.0, 0.6)
	t.tween_method(place, 0.0, 1.0, 5.0)
	t.tween_callback(func():
		hud.show_l3("地球", "涌现出来了。", 6)
		Juice.ui_sfx("chime", 0.0, 0.7))
	t.tween_interval(2.8)
	t.tween_callback(func(): hud.show_l3("第三幕", "未完待续。", 6))
	t.tween_interval(2.6)
	t.tween_method(place, 1.0, 0.0, 3.2)
	t.tween_callback(func():
		player.camera.make_current()
		cam.queue_free()
		_set_space(0.0)
		_earth_root.visible = false
		Stats.enter_stage(3)   # 地球: to be continued — the bar stops here
		_end_cutscene())


func _set_space(v: float) -> void:
	var space := Color(0.01, 0.01, 0.04)
	_sky.sky_top_color = _sky_colors[0].lerp(space, v)
	_sky.sky_horizon_color = _sky_colors[1].lerp(space, v)
	_sky.ground_horizon_color = _sky_colors[2].lerp(space, v)
	_sky.ground_bottom_color = _sky_colors[3].lerp(space, v)


func _build_earth() -> void:
	if _earth_root:
		_earth_root.visible = true
		return
	_earth_root = Node3D.new()
	add_child(_earth_root)
	var r := 4200.0
	var earth := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 96
	sm.rings = 48
	earth.mesh = sm
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	var tex := NoiseTexture2D.new()
	tex.width = 1024
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.53, 0.6, 0.75, 1.0])
	g.colors = PackedColorArray([Color(0.05, 0.15, 0.5), Color(0.1, 0.35, 0.75), Color(0.85, 0.8, 0.55),
		Color(0.25, 0.6, 0.25), Color(0.2, 0.45, 0.2), Color(0.95, 0.95, 0.95)])
	tex.color_ramp = g
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.9
	earth.material_override = mat
	earth.position = Vector3(0, -r - 3.0, 0)
	_earth_root.add_child(earth)
	# a rainbow ring, because of course
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 1.35
	tm.outer_radius = r * 1.45
	tm.rings = 96
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = Visuals.rainbow_material(0.5, 0.0004)
	ring.position = earth.position
	ring.rotation_degrees = Vector3(18, 0, 10)
	_earth_root.add_child(ring)
	# moon
	var moon := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 1100.0
	mm.height = 2200.0
	moon.mesh = mm
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_color = Color(0.8, 0.8, 0.78)
	moon.material_override = moon_mat
	moon.position = Vector3(9000, 4000, -7000)
	_earth_root.add_child(moon)
	# stars
	var mmi := MultiMeshInstance3D.new()
	var mmesh := MultiMesh.new()
	mmesh.transform_format = MultiMesh.TRANSFORM_3D
	var star := SphereMesh.new()
	star.radius = 90.0
	star.height = 180.0
	star.radial_segments = 4
	star.rings = 2
	mmesh.mesh = star
	mmesh.instance_count = 700
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in mmesh.instance_count:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
		mmesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.5, 2.0)), d * 120000.0))
	mmi.multimesh = mmesh
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color = Color(1, 1, 0.9)
	mmi.material_override = star_mat
	_earth_root.add_child(mmi)


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
	s.size = Vector3(GROUND_SIZE, 2, GROUND_SIZE)
	cs.shape = s
	cs.position = Vector3(0, -1, 0)
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(GROUND_SIZE, GROUND_SIZE)
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
	# Borrowed low-poly city pieces — as physical, emergent objects too.
	var spots := [
		[Vector3(-22, 0, -18), 0.0], [Vector3(-10, 0, -20), 0.0], [Vector3(12, 0, -20), 0.0], [Vector3(24, 0, -18), 0.0],
		[Vector3(-26, 0, 0), 90.0], [Vector3(28, 0, 2), -90.0], [Vector3(-24, 0, 22), 180.0], [Vector3(26, 0, 22), 180.0],
		[Vector3(-8, 0, 26), 180.0], [Vector3(10, 0, 26), 180.0],
	]
	for sp in spots:
		_spawn_prop("房子", sp[0], sp[1])
	for i in 4:
		_spawn_prop("长椅", Vector3(-6 + i * 4, 0, -5.5), 0.0)
	_spawn_prop("公交站", Vector3(6, 0, 7.5), 180.0)
	_spawn_prop("红绿灯", Vector3(-4.5, 0, 6.5), 0.0)


func _spawn_prop(def_name: String, pos: Vector3, yaw_deg: float, sk: float = 1.0) -> EmergentBody:
	var def = DB.get_def(def_name)
	if def == null:
		push_warning("no def for %s" % def_name)
		return null
	var b := _do_spawn(def, pos, Vector3.ZERO, false, sk, false)
	if b:
		b.rotation.y = deg_to_rad(yaw_deg)
	return b



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
		spawn_body(def, player.global_position + player.facing * 3.0 * player.k + Vector3(0, 3, 0) * player.k, Vector3.ZERO)
	if event.is_action_pressed("next_stage"):
		if not Stats.has_released:
			Stats.record_release(0.0)
		advance_stage()
