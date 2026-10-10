extends Node
## Hit feel: slow motion, hitstop, camera shake, squash, particle bursts, SFX.
## Everything here is fire-and-forget so gameplay code stays one-liners.

const SFX := {
	"impact": ["Impact1", "Impact2", "Impact3", "Impact4", "Impact5", "Impact6", "Impact7"],
	"metal": ["metal_hit", "metal_hit2"],
	"pop": ["pop", "Bubble_Pop", "PopExplode"],
	"whoosh": ["whoosh", "Swing"],
	"didi": ["didi"],
	"error": ["error"],
	"chime": ["chime"],
	"hum": ["hum"],
	"startup": ["startup"],
	"dialup": ["dialup"],
	"explosion": ["explosion", "GlassExplode"],
	"honk": ["Honk1", "Honk2"],
	"powerup": ["powerup"],
	"fart": ["Fart"],
	"scream": ["people/man_scream", "people/man_scream2", "people/man_scream3",
		"people/women_scream", "people/women_scream2", "people/kid_scream"],
}

var camera: Camera3D
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _shake_strength := 0.0
var _shake_time := 0.0
var _slowmo_tween: Tween
var _hitstop_until := 0.0
var _burst_mesh: SphereMesh
var _burst_mats: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 24:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 60.0
		p.unit_size = 6.0
		p.attenuation_filter_cutoff_hz = 12000
		add_child(p)
		_pool.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_ui_pool.append(p)
	_burst_mesh = SphereMesh.new()
	_burst_mesh.radius = 0.12
	_burst_mesh.height = 0.24
	_burst_mesh.radial_segments = 6
	_burst_mesh.rings = 3


func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := "res://assets/sounds/%s.wav" % name
	if not ResourceLoader.exists(path):
		path = "res://assets/sounds/%s.ogg" % name
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[name] = s
	return s


func sfx(kind: String, pos: Vector3, volume_db: float = 0.0, pitch_min: float = 0.9, pitch_max: float = 1.15) -> void:
	var names: Array = SFX.get(kind, [kind])
	var s := _stream(names.pick_random())
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.global_position = pos
			p.volume_db = volume_db
			p.pitch_scale = randf_range(pitch_min, pitch_max)
			p.play()
			return


func ui_sfx(kind: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var names: Array = SFX.get(kind, [kind])
	var s := _stream(names.pick_random())
	if s == null:
		return null
	for p in _ui_pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return p
	return null


func slowmo(duration: float = 0.3, scale: float = 0.08) -> void:
	if _slowmo_tween and _slowmo_tween.is_valid():
		_slowmo_tween.kill()
	_slowmo_tween = create_tween()
	_slowmo_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_slowmo_tween.tween_property(Engine, "time_scale", scale, 0.03)
	_slowmo_tween.tween_interval(duration * scale)
	_slowmo_tween.tween_property(Engine, "time_scale", 1.0, 0.25)


func hitstop(seconds: float = 0.05) -> void:
	# Short freeze; measured in real time, so the interval is scaled.
	if _slowmo_tween and _slowmo_tween.is_valid() and Engine.time_scale < 0.5:
		return
	if _slowmo_tween and _slowmo_tween.is_valid():
		_slowmo_tween.kill()
	_slowmo_tween = create_tween()
	_slowmo_tween.tween_property(Engine, "time_scale", 0.02, 0.0)
	_slowmo_tween.tween_interval(seconds * 0.02)
	_slowmo_tween.tween_property(Engine, "time_scale", 1.0, 0.08)


func shake(strength: float = 0.4, time: float = 0.3) -> void:
	_shake_strength = max(_shake_strength, strength)
	_shake_time = max(_shake_time, time)


func _process(delta: float) -> void:
	if camera == null:
		return
	if _shake_time > 0.0:
		_shake_time -= delta / max(Engine.time_scale, 0.01)
		var s: float = _shake_strength * clamp(_shake_time / 0.3, 0.0, 1.0)
		camera.h_offset = randf_range(-s, s)
		camera.v_offset = randf_range(-s, s)
		camera.rotation.z = randf_range(-s, s) * 0.05
	else:
		camera.h_offset = lerp(camera.h_offset, 0.0, 0.3)
		camera.v_offset = lerp(camera.v_offset, 0.0, 0.3)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, 0.3)
		_shake_strength = 0.0


func squash(node: Node3D, amount: float = 0.35, time: float = 0.25) -> void:
	if not is_instance_valid(node):
		return
	if not node.has_meta("base_scale"):
		node.set_meta("base_scale", node.scale)
	var base: Vector3 = node.get_meta("base_scale")
	var t := node.create_tween()
	t.tween_property(node, "scale", base * Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount), time * 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", base, time * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func burst(pos: Vector3, color: Color = Color.WHITE, count: int = 18, speed: float = 7.0, size: float = 1.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = 0.7
	p.mesh = _burst_mesh
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 1.4 * size
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.color = color
	var key := color.to_html()
	if not _burst_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.albedo_color = color
		_burst_mats[key] = m
	p.material_override = _burst_mats[key]
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


func ring(pos: Vector3, color: Color = Color(1, 1, 1, 0.8), radius: float = 2.5, time: float = 0.35) -> void:
	# Expanding flat torus: the "shockwave" of a release.
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 6
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	mi.material_override = m
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.3, 0.3, 0.3)
	var t := mi.create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3(radius, 0.4, radius), time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, time)
	t.chain().tween_callback(mi.queue_free)
