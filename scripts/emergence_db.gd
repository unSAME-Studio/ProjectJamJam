extends Node
## Loads content/emergence_table.csv into EmergenceDef objects.
## The CSV is the single source of truth; nothing here is hand-authored.

const TABLE_PATH := "res://content/emergence_table.csv"

class EmergenceDef:
	var id: String
	var name: String
	var act: String
	var tier: int
	var pattern: String
	var size: String       # S M L XL or "-"
	var anchored: bool
	var emits: Array = []  # [{name, count}]
	var collapse_n: int = 0
	var collapse_into: String = ""
	var eats: Array = []   # [{name, count}]  name "*" = anything
	var eat_emits: Array = []
	var recipes: Dictionary = {}  # hitter name -> result name or "(effect)"
	var line: String
	var status: String
	var notes: String

	func is_entity() -> bool:
		return size != "-"

	func caption_for(emitted_name: String) -> String:
		if line != "":
			return line
		return "%s涌现出来了。" % emitted_name


var defs: Dictionary = {}     # name -> EmergenceDef
var by_id: Dictionary = {}    # id -> EmergenceDef


func _ready() -> void:
	_load()


func get_def(name_or_id: String) -> EmergenceDef:
	if defs.has(name_or_id):
		return defs[name_or_id]
	if by_id.has(name_or_id):
		return by_id[name_or_id]
	return null


func _load() -> void:
	var f := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if f == null:
		push_error("cannot open %s" % TABLE_PATH)
		return
	var header := f.get_csv_line()
	var col := {}
	for i in header.size():
		col[header[i].strip_edges()] = i
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < header.size() or row[0].strip_edges() == "":
			continue
		var d := EmergenceDef.new()
		d.id = _cell(row, col, "id")
		d.name = _cell(row, col, "name")
		d.act = _cell(row, col, "act")
		d.tier = int(_cell(row, col, "tier"))
		d.pattern = _cell(row, col, "pattern")
		d.size = _cell(row, col, "size")
		d.anchored = _cell(row, col, "anchored") == "y"
		d.emits = _parse_list(_cell(row, col, "emits"), ";")
		var cn := _cell(row, col, "collapse_n")
		d.collapse_n = int(cn) if cn != "" else 0
		d.collapse_into = _cell(row, col, "collapse_into")
		d.eats = _parse_list(_cell(row, col, "eats"), "|")
		d.eat_emits = _parse_list(_cell(row, col, "eat_emits"), ";")
		d.recipes = _parse_recipes(_cell(row, col, "recipes"))
		d.line = _cell(row, col, "line")
		d.status = _cell(row, col, "status")
		d.notes = _cell(row, col, "notes")
		defs[d.name] = d
		by_id[d.id] = d
	print("[DB] loaded %d defs" % defs.size())


func _cell(row: PackedStringArray, col: Dictionary, key: String) -> String:
	if not col.has(key):
		return ""
	return row[col[key]].strip_edges()


func _parse_list(cell: String, sep: String) -> Array:
	var out := []
	for part in cell.split(sep, false):
		var p: String = part.strip_edges()
		if p == "":
			continue
		var n := 1
		var nm := p
		var x := p.find("×")
		if x >= 0:
			nm = p.substr(0, x).strip_edges()
			n = int(p.substr(x + 1).strip_edges())
		out.append({"name": nm, "count": max(n, 1)})
	return out


func _parse_recipes(cell: String) -> Dictionary:
	var out := {}
	for part in cell.split(";", false):
		var p: String = part.strip_edges()
		var arrow := p.find("→")
		if arrow < 0:
			continue
		out[p.substr(0, arrow).strip_edges()] = p.substr(arrow + 1).strip_edges()
	return out
