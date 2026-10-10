class_name Starburst
extends Control
## The 爆炸贴 / 我的妈呀 backdrop: a spiky ellipse, two-tone fill, fat outline.

@export var points := 16
@export var fill := Color(1.0, 0.92, 0.15)
@export var fill2 := Color(1.0, 0.55, 0.1)
@export var outline := Color(0.85, 0.08, 0.1)
@export var inner := 0.74
@export var line_width := 6.0
@export var spin_speed := 0.25

var _spin := 0.0


func _process(delta: float) -> void:
	_spin += delta * spin_speed
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var pts := PackedVector2Array()
	var total := points * 2
	for i in total:
		var a := TAU * float(i) / total + _spin
		var r := 1.0 if i % 2 == 0 else inner
		# jitter the spikes a little so it looks hand-cut
		if i % 2 == 0:
			r += 0.06 * sin(float(i) * 2.3 + _spin * 3.0)
		pts.append(c + Vector2(cos(a) * c.x * r, sin(a) * c.y * r))
	draw_colored_polygon(pts, fill)
	# inner lighter wedge for a two-tone print feel
	var inner_pts := PackedVector2Array()
	for p in pts:
		inner_pts.append(c + (p - c) * 0.78)
	draw_colored_polygon(inner_pts, fill2)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, outline, line_width, true)
