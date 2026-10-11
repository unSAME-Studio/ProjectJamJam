extends Control
## 字体样张. Open scenes/wordart_specimen.tscn and press F6 to see the WordArt
## captions moving. With `-- --shots=DIR` it saves a burst of frames and quits.

const ROWS := [
	# [glyph px, name, suffix, palette]
	[118, "城市", "涌现出来了。", "热彩"],
	[72, "两个杀毒软件打起来了", "。", "热彩"],
	[72, "资本", "涌现出来了。", "粉蓝紫"],
	[72, "鸽子", "涌现出来了。", "红橙金"],
	[72, "钱", "涌现出来了。", "绿蓝"],
]

var _shots_dir := ""
var _t := 0.0
var _frame := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
	# left half sky, right half grass: captions must read on both
	var vp := get_viewport().get_visible_rect().size
	var sky := ColorRect.new()
	sky.color = Color(0.7, 0.84, 1.0)
	sky.size = Vector2(vp.x * 0.5, vp.y)
	add_child(sky)
	var grass := ColorRect.new()
	grass.color = Color(0.47, 0.69, 0.37)
	grass.position = Vector2(vp.x * 0.5, 0)
	grass.size = Vector2(vp.x * 0.5, vp.y)
	add_child(grass)
	var y := 0.0
	for row in ROWS:
		var w := WordArtLine.make(row[1], row[2], row[0], {"palette": row[3]})
		add_child(w)
		w.position = Vector2((vp.x - w.size.x) * 0.5, y)
		y += w.size.y * 0.78


func _process(delta: float) -> void:
	if _shots_dir == "":
		return
	_t += delta
	if _t < 0.5:
		return
	if _frame >= 24:
		get_tree().quit()
		return
	_frame += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/f_%03d.png" % [_shots_dir, _frame])
