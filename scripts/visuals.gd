class_name Visuals
extends RefCounted
## Builds the look + collision shape of an emergent object from its def.
## Priority: hand-made primitive / borrowed low-poly model → rainbow 3D text
## of the object's name (the fallback that lets anything in the CSV exist).

const SIZE_HEIGHT := {"S": 0.45, "M": 1.3, "L": 3.2, "XL": 6.0}
const TEXT_HEIGHT := {"S": 0.5, "M": 0.85, "L": 1.4, "XL": 2.2}
const CITY := "res://assets/models/city/"
const NPC_MODELS := {
	"Michiru": "FAMILY02_D", "Mizue": "FAMILY04_D", "Mutsuo": "FAMILY01_D", "Tomino": "FAMILY03_D",
}

static var _rainbow_shader: Shader
static var _mat_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


class Built:
	var visual: Node3D
	var shape: Shape3D
	var shape_offset: Vector3 = Vector3.ZERO
	var height: float = 1.0
	var color: Color = Color.WHITE


static func build(def) -> Built:
	var b := Built.new()
	b.height = SIZE_HEIGHT.get(def.size, 1.0)
	match def.id:
		"person", "worker", "boss", "netkid", "agent", "developer", "student", "netizen":
			_build_person(def, b)
		"grandpa":
			_build_person(def, b, Color(0.85, 0.85, 0.8))
		"pigeon":
			_build_pigeon(b)
		"tree":
			_build_tree(b)
		"apple":
			_sphere(b, 0.22, Color(0.9, 0.15, 0.15))
		"money":
			_box(b, Vector3(0.5, 0.03, 0.25), Color(0.25, 0.65, 0.3))
		"hydrant":
			_build_hydrant(b)
		"water", "rain":
			_sphere(b, 0.2, Color(0.3, 0.6, 1.0, 0.85), true)
		"drain":
			_cylinder(b, 0.55, 0.12, Color(0.25, 0.25, 0.27))
		"trashcan":
			_model(b, "garbage_bin.obj", 1.2)
		"trash":
			_box(b, Vector3(0.3, 0.3, 0.3), Color(0.45, 0.4, 0.3))
		"car":
			_model(b, ["car1.obj", "car2.obj", "car3.obj", "SUV.obj", "SportsCar.obj", "NormalCar1.obj"].pick_random(), 1.5)
		"bus":
			_model(b, "bus.obj", 3.0)
		"pole":
			_model(b, "streetlamp.obj", 4.5)
		"atm":
			_build_atm(b)
		"vending":
			_build_vending(b)
		"kiosk":
			_build_signbox(b, Vector3(2.2, 2.4, 1.8), Color(0.2, 0.55, 0.3), "小卖部")
		"newsstand":
			_build_signbox(b, Vector3(2.0, 2.3, 1.6), Color(0.2, 0.45, 0.7), "报刊亭")
		"netbar":
			_build_signbox(b, Vector3(7.0, 5.0, 6.0), Color(0.15, 0.15, 0.2), "网吧", Color(0.2, 1.0, 1.0))
		"speaker":
			_build_speaker(b)
		"disc":
			_cylinder(b, 0.25, 0.03, Color(0.85, 0.85, 0.95))
		"drink":
			_cylinder(b, 0.12, 0.4, Color(0.85, 0.1, 0.1))
		"latiao":
			_box(b, Vector3(0.35, 0.08, 0.18), Color(0.8, 0.2, 0.1))
		"flyer":
			_box(b, Vector3(0.3, 0.01, 0.4), Color(1, 1, 1))
		"croc":
			_build_croc(b)
		"flood":
			_build_flood(b)
		"house":
			_model(b, ["house2.obj", "house3.obj", "small_buildingB.obj"].pick_random(), randf_range(7.0, 9.5))
		"bench":
			_model(b, "Bench.obj", 0.9)
		"busstop":
			_model(b, "busstop.obj", 3.0)
		"trafficlight":
			_model(b, "trafficlight.obj", 4.0)
		"tower":
			var tw := randf_range(14.0, 24.0)
			_build_tower(b, Vector3(tw, randf_range(24.0, 60.0), tw * randf_range(0.7, 1.2)),
				Color.from_hsv(randf(), randf_range(0.1, 0.35), randf_range(0.7, 0.95)),
				["宾馆", "发廊", "KTV", "超市", "移动", "药房", "大酒店", "电器城", "足浴", "彩票", "影楼"].pick_random())
		"building":
			_build_tower(b, Vector3(2.4, 3.4, 2.4), _hash_color(def.name, 0.35, 0.85), "楼")
		"company":
			_build_tower(b, Vector3(4.0, 7.0, 4.0), Color(0.55, 0.7, 0.85), "公司")
		"bank":
			_build_tower(b, Vector3(5.0, 4.5, 4.0), Color(0.85, 0.82, 0.7), "银行", Color(0.85, 0.1, 0.1))
		"school":
			_build_tower(b, Vector3(7.0, 4.0, 4.0), Color(0.9, 0.75, 0.55), "学校", Color(0.9, 0.1, 0.1))
		"tvstation":
			_build_tower(b, Vector3(3.5, 9.0, 3.5), Color(0.75, 0.75, 0.8), "电视台", Color(0.1, 0.3, 0.9))
		"pcmall":
			_build_tower(b, Vector3(6.0, 4.5, 5.0), Color(0.3, 0.35, 0.45), "电脑城", Color(0.2, 1.0, 1.0))
		"site":
			_build_tower(b, Vector3(5.0, 2.0, 5.0), Color(0.95, 0.75, 0.2), "工地", Color(0.1, 0.1, 0.1))
		"danwei":
			_build_tower(b, Vector3(5.0, 5.0, 4.0), Color(0.85, 0.85, 0.8), "单位", Color(0.8, 0.1, 0.1))
		_:
			if def.anchored:
				_build_tower(b, Vector3(4.0, 4.0, 4.0), _hash_color(def.name, 0.4, 0.85), def.name)
			else:
				_build_text(def, b)
	if b.shape == null:
		var box := BoxShape3D.new()
		box.size = Vector3.ONE * b.height * 0.6
		b.shape = box
	return b


# ---------- builders ----------

static func _mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var key := color.to_html() + ("u" if unshaded else "")
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cache[key] = m
	return m


static func rainbow_material(speed := 1.2, scale := 0.6) -> ShaderMaterial:
	if _rainbow_shader == null:
		_rainbow_shader = load("res://assets/shaders/rainbow.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _rainbow_shader
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("scale", scale)
	return m


static func _mi(mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi


static func _sphere(b: Built, r: float, color: Color, unshaded := false) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2
	m.radial_segments = 10
	m.rings = 5
	b.visual = _mi(m, _mat(color, unshaded))
	var s := SphereShape3D.new()
	s.radius = r
	b.shape = s
	b.height = r * 2
	b.color = color


static func _box(b: Built, size: Vector3, color: Color) -> void:
	var m := BoxMesh.new()
	m.size = size
	b.visual = _mi(m, _mat(color))
	var s := BoxShape3D.new()
	s.size = size
	b.shape = s
	b.height = size.y
	b.color = color


static func _cylinder(b: Built, r: float, h: float, color: Color) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 12
	b.visual = _mi(m, _mat(color))
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	b.shape = s
	b.height = h
	b.color = color


static func _build_person(def, b: Built, tint := Color(-1, 0, 0)) -> void:
	var root := Node3D.new()
	var npc := _try_npc_model()
	var h := 1.7 if def.id != "boss" else 2.1
	var shirt := tint if tint.r >= 0.0 else Color.from_hsv(randf(), 0.55, 0.9)
	if def.id == "boss":
		shirt = Color(0.1, 0.1, 0.12)
	elif def.id == "worker":
		shirt = Color(0.95, 0.95, 0.95)
	elif def.id == "netkid":
		shirt = Color(0.2, 0.2, 0.25)
	if npc != null:
		root.add_child(npc)
		_fit(npc, h)
	else:
		var body := CapsuleMesh.new()
		body.radius = 0.32
		body.height = 1.2
		root.add_child(_mi(body, _mat(shirt), Vector3(0, 0.6, 0)))
		var head := SphereMesh.new()
		head.radius = 0.28
		head.height = 0.56
		root.add_child(_mi(head, _mat(Color(0.95, 0.8, 0.65)), Vector3(0, 1.45, 0)))
		if def.id == "boss":
			var hat := CylinderMesh.new()
			hat.top_radius = 0.2
			hat.bottom_radius = 0.2
			hat.height = 0.3
			root.add_child(_mi(hat, _mat(Color(0.05, 0.05, 0.05)), Vector3(0, 1.85, 0)))
	b.visual = root
	var s := CapsuleShape3D.new()
	s.radius = 0.35
	s.height = h
	b.shape = s
	b.shape_offset = Vector3(0, h * 0.5, 0)
	b.height = h
	b.color = shirt


static func _try_npc_model() -> Node3D:
	var name: String = NPC_MODELS.keys().pick_random()
	var path := "res://assets/models/npc/%s.fbx" % name
	if not ResourceLoader.exists(path):
		return null
	var scene = load(path)
	if scene == null or not (scene is PackedScene):
		return null
	var inst: Node3D = scene.instantiate()
	var tex_path := "res://assets/models/npc/%s.png" % NPC_MODELS[name]
	if ResourceLoader.exists(tex_path):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(tex_path)
		m.roughness = 0.9
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = m
	return inst


static func _fit(node: Node3D, target_height: float) -> void:
	# Scale a model so its vertical AABB extent equals target_height and its
	# base sits on y=0.
	var aabb := _aabb_of(node)
	if aabb.size.y <= 0.0001:
		return
	var s := target_height / aabb.size.y
	node.scale = Vector3.ONE * s
	node.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s, -aabb.get_center().z * s)


static func _aabb_of(node: Node3D) -> AABB:
	var total := AABB()
	var first := true
	var list := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		list.append(node)
	for mi in list:
		if mi.mesh == null:
			continue
		var xf: Transform3D = node.global_transform.affine_inverse() * mi.global_transform if node.is_inside_tree() else _rel_xf(node, mi)
		var a: AABB = xf * mi.mesh.get_aabb()
		if first:
			total = a
			first = false
		else:
			total = total.merge(a)
	return total


static func _rel_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = cur.transform * xf
		cur = cur.get_parent()
	return xf


static func _model(b: Built, file: String, target_height: float) -> void:
	var path := CITY + file
	var mesh: Mesh = null
	if _mesh_cache.has(path):
		mesh = _mesh_cache[path]
	elif ResourceLoader.exists(path):
		mesh = load(path)
		_mesh_cache[path] = mesh
	if mesh == null:
		_box(b, Vector3(1, target_height, 1), Color(0.6, 0.6, 0.6))
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var aabb := mesh.get_aabb()
	var s: float = target_height / max(aabb.size.y, 0.001)
	mi.scale = Vector3.ONE * s
	mi.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s, -aabb.get_center().z * s)
	b.visual = mi
	var box := BoxShape3D.new()
	box.size = aabb.size * s * 0.9
	b.shape = box
	b.shape_offset = Vector3(0, aabb.size.y * s * 0.5, 0)
	b.height = aabb.size.y * s
	b.color = Color(0.8, 0.8, 0.8)


static func _build_pigeon(b: Built) -> void:
	var root := Node3D.new()
	var body := SphereMesh.new()
	body.radius = 0.18
	body.height = 0.3
	body.radial_segments = 8
	body.rings = 4
	root.add_child(_mi(body, _mat(Color(0.55, 0.55, 0.6))))
	var head := SphereMesh.new()
	head.radius = 0.09
	head.height = 0.18
	head.radial_segments = 6
	head.rings = 3
	root.add_child(_mi(head, _mat(Color(0.35, 0.4, 0.5)), Vector3(0, 0.12, 0.17)))
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.035
	beak.height = 0.1
	beak.radial_segments = 4
	var bk := _mi(beak, _mat(Color(1.0, 0.6, 0.1)), Vector3(0, 0.1, 0.28))
	bk.rotation_degrees.x = 90
	root.add_child(bk)
	b.visual = root
	var s := SphereShape3D.new()
	s.radius = 0.2
	b.shape = s
	b.height = 0.4
	b.color = Color(0.6, 0.6, 0.65)


static func _build_tree(b: Built) -> void:
	var root := Node3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.25
	trunk.height = 1.4
	trunk.radial_segments = 8
	root.add_child(_mi(trunk, _mat(Color(0.45, 0.3, 0.18)), Vector3(0, 0.7, 0)))
	var crown := SphereMesh.new()
	crown.radius = 1.3
	crown.height = 2.4
	crown.radial_segments = 10
	crown.rings = 6
	root.add_child(_mi(crown, _mat(Color(0.25, 0.6, 0.25)), Vector3(0, 2.3, 0)))
	b.visual = root
	var s := CylinderShape3D.new()
	s.radius = 0.4
	s.height = 3.4
	b.shape = s
	b.shape_offset = Vector3(0, 1.7, 0)
	b.height = 3.5
	b.color = Color(0.3, 0.7, 0.3)


static func _build_hydrant(b: Built) -> void:
	var root := Node3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.18
	body.bottom_radius = 0.22
	body.height = 0.8
	body.radial_segments = 10
	root.add_child(_mi(body, _mat(Color(0.85, 0.1, 0.1)), Vector3(0, 0.4, 0)))
	var cap := SphereMesh.new()
	cap.radius = 0.2
	cap.height = 0.4
	root.add_child(_mi(cap, _mat(Color(0.85, 0.1, 0.1)), Vector3(0, 0.82, 0)))
	var side := BoxMesh.new()
	side.size = Vector3(0.6, 0.14, 0.14)
	root.add_child(_mi(side, _mat(Color(0.9, 0.2, 0.2)), Vector3(0, 0.55, 0)))
	b.visual = root
	var s := CylinderShape3D.new()
	s.radius = 0.25
	s.height = 1.0
	b.shape = s
	b.shape_offset = Vector3(0, 0.5, 0)
	b.height = 1.0
	b.color = Color(0.9, 0.2, 0.2)


static func _build_atm(b: Built) -> void:
	var root := Node3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(1.0, 1.9, 0.7)
	root.add_child(_mi(body, _mat(Color(0.75, 0.78, 0.8)), Vector3(0, 0.95, 0)))
	var screen := BoxMesh.new()
	screen.size = Vector3(0.6, 0.4, 0.05)
	root.add_child(_mi(screen, _mat(Color(0.2, 0.5, 1.0), true), Vector3(0, 1.3, 0.36)))
	var slot := BoxMesh.new()
	slot.size = Vector3(0.5, 0.06, 0.05)
	root.add_child(_mi(slot, _mat(Color(0.1, 0.1, 0.1)), Vector3(0, 0.8, 0.36)))
	root.add_child(_label("ATM", Vector3(0, 1.7, 0.37), 0.3, Color(0.1, 0.3, 0.6)))
	b.visual = root
	var s := BoxShape3D.new()
	s.size = Vector3(1.0, 1.9, 0.7)
	b.shape = s
	b.shape_offset = Vector3(0, 0.95, 0)
	b.height = 1.9
	b.color = Color(0.3, 0.8, 0.4)


static func _build_vending(b: Built) -> void:
	var root := Node3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(1.1, 2.0, 0.8)
	root.add_child(_mi(body, _mat(Color(0.85, 0.12, 0.12)), Vector3(0, 1.0, 0)))
	var glass := BoxMesh.new()
	glass.size = Vector3(0.7, 1.3, 0.05)
	root.add_child(_mi(glass, _mat(Color(0.7, 0.9, 1.0, 0.8)), Vector3(-0.1, 1.15, 0.41)))
	b.visual = root
	var s := BoxShape3D.new()
	s.size = Vector3(1.1, 2.0, 0.8)
	b.shape = s
	b.shape_offset = Vector3(0, 1.0, 0)
	b.height = 2.0
	b.color = Color(0.9, 0.2, 0.2)


static func _build_signbox(b: Built, size: Vector3, color: Color, sign: String, sign_color := Color(1, 0.9, 0.2)) -> void:
	var root := Node3D.new()
	var body := BoxMesh.new()
	body.size = size
	root.add_child(_mi(body, _mat(color), Vector3(0, size.y * 0.5, 0)))
	var board := BoxMesh.new()
	board.size = Vector3(size.x * 0.9, size.y * 0.22, 0.1)
	root.add_child(_mi(board, _mat(Color(0.8, 0.1, 0.1)), Vector3(0, size.y * 0.85, size.z * 0.5 + 0.05)))
	root.add_child(_label(sign, Vector3(0, size.y * 0.85, size.z * 0.5 + 0.12), size.y * 0.16, sign_color))
	b.visual = root
	var s := BoxShape3D.new()
	s.size = size
	b.shape = s
	b.shape_offset = Vector3(0, size.y * 0.5, 0)
	b.height = size.y
	b.color = color.lightened(0.3)


static func _build_speaker(b: Built) -> void:
	var root := Node3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.05
	pole.height = 2.4
	root.add_child(_mi(pole, _mat(Color(0.4, 0.4, 0.4)), Vector3(0, 1.2, 0)))
	var horn := CylinderMesh.new()
	horn.top_radius = 0.35
	horn.bottom_radius = 0.1
	horn.height = 0.5
	var h := _mi(horn, _mat(Color(0.75, 0.75, 0.75)), Vector3(0, 2.5, 0.25))
	h.rotation_degrees.x = -70
	root.add_child(h)
	b.visual = root
	var s := CylinderShape3D.new()
	s.radius = 0.2
	s.height = 2.8
	b.shape = s
	b.shape_offset = Vector3(0, 1.4, 0)
	b.height = 2.8
	b.color = Color(0.9, 0.9, 0.9)


static func _build_croc(b: Built) -> void:
	var root := Node3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(0.6, 0.35, 2.2)
	root.add_child(_mi(body, _mat(Color(0.2, 0.5, 0.2)), Vector3(0, 0.18, 0)))
	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.4, 0.2, 0.9)
	root.add_child(_mi(jaw, _mat(Color(0.25, 0.55, 0.25)), Vector3(0, 0.25, 1.4)))
	for i in 4:
		var tooth := BoxMesh.new()
		tooth.size = Vector3(0.06, 0.12, 0.06)
		root.add_child(_mi(tooth, _mat(Color.WHITE), Vector3(-0.15 + i * 0.1, 0.12, 1.75)))
	b.visual = root
	var s := BoxShape3D.new()
	s.size = Vector3(0.6, 0.35, 3.0)
	b.shape = s
	b.shape_offset = Vector3(0, 0.18, 0.3)
	b.height = 0.4
	b.color = Color(0.3, 0.7, 0.3)


static func _label(text: String, pos: Vector3, size: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Boot.font_display
	l.font_size = 64
	l.pixel_size = size / 64.0
	l.modulate = color
	l.outline_size = 8
	l.position = pos
	l.no_depth_test = false
	return l


static func _hash_color(text: String, sat: float, val: float) -> Color:
	return Color.from_hsv(float(abs(text.hash()) % 1000) / 1000.0, sat, val)


static func _build_tower(b: Built, size: Vector3, color: Color, sign: String, sign_color := Color(1, 0.95, 0.2)) -> void:
	# A city block building: body, window stripes, rooftop sign facing +Z.
	var root := Node3D.new()
	var body := BoxMesh.new()
	body.size = size
	root.add_child(_mi(body, _mat(color), Vector3(0, size.y * 0.5, 0)))
	var floors := int(max(size.y / 1.1, 1.0))
	var win_mat := _mat(Color(0.55, 0.8, 1.0), true)
	for f in floors:
		var strip := BoxMesh.new()
		strip.size = Vector3(size.x * 0.82, 0.35, size.z * 1.02)
		root.add_child(_mi(strip, win_mat, Vector3(0, 0.75 + f * (size.y - 0.8) / floors, 0)))
	var board := BoxMesh.new()
	var ls: float = max(0.75, size.x * 0.11)
	var bw: float = max(size.x * 0.9, sign.length() * ls * 1.2)
	board.size = Vector3(bw, ls * 1.2, 0.15 * ls / 0.75)
	root.add_child(_mi(board, _mat(Color(0.8, 0.1, 0.1)), Vector3(0, size.y + ls * 0.66, size.z * 0.3)))
	root.add_child(_label(sign, Vector3(0, size.y + ls * 0.66, size.z * 0.3 + 0.1 * ls / 0.75 + 0.02), ls, sign_color))
	b.visual = root
	var s := BoxShape3D.new()
	s.size = size
	b.shape = s
	b.shape_offset = Vector3(0, size.y * 0.5, 0)
	b.height = size.y
	b.color = color.lightened(0.3)


static func scaled_shape(shape: Shape3D, k: float) -> Shape3D:
	var s: Shape3D = shape.duplicate()
	if s is BoxShape3D:
		s.size *= k
	elif s is SphereShape3D:
		s.radius *= k
	elif s is CapsuleShape3D:
		s.radius *= k
		s.height *= k
	elif s is CylinderShape3D:
		s.radius *= k
		s.height *= k
	return s


static func _build_flood(b: Built) -> void:
	var m := CylinderMesh.new()
	m.top_radius = 2.4
	m.bottom_radius = 2.6
	m.height = 0.22
	m.radial_segments = 16
	b.visual = _mi(m, _mat(Color(0.25, 0.55, 1.0, 0.8)), Vector3(0, 0.11, 0))
	var s := CylinderShape3D.new()
	s.radius = 2.4
	s.height = 0.22
	b.shape = s
	b.shape_offset = Vector3(0, 0.11, 0)
	b.height = 0.25
	b.color = Color(0.3, 0.6, 1.0)


static func _build_text(def, b: Built) -> void:
	# Fallback: the object's name as a chunky rainbow 3D word.
	b.height = TEXT_HEIGHT.get(def.size, 0.9)
	var tm := TextMesh.new()
	tm.text = def.name
	tm.font = Boot.font_display
	tm.font_size = 64
	tm.pixel_size = b.height / 64.0
	tm.depth = 0.35 * b.height
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mi := _mi(tm, rainbow_material(1.5, 0.8 / max(b.height, 0.3)))
	mi.position.y = b.height * 0.5
	b.visual = mi
	var chars: int = max(int(def.name.length()), 1)
	var s := BoxShape3D.new()
	s.size = Vector3(b.height * chars * 0.95, b.height, max(tm.depth, 0.2))
	b.shape = s
	b.shape_offset = Vector3(0, b.height * 0.5, 0)
	b.color = Color.from_hsv(randf(), 0.9, 1.0)


static func char_body_mesh(ch: String, height: float) -> Mesh:
	var tm := TextMesh.new()
	tm.text = ch
	tm.font = Boot.font_display
	tm.font_size = 64
	tm.pixel_size = height / 64.0
	tm.depth = 0.3 * height
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return tm
