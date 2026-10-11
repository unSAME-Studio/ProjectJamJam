@tool
class_name WaveFx
extends RichTextEffect
## [wa n=8 amp=10 freq=2.4 arch=0.3]
## Geometry only: every char bobs on a travelling sine wave and the middle of
## the line rides a little higher (the WordArt arch). Colour is left alone so
## every layer of a WordArtLine moves in lockstep.

var bbcode := "wa"


func _process_custom_fx(c: CharFXTransform) -> bool:
	var amp: float = c.env.get("amp", 10.0)
	var freq: float = c.env.get("freq", 2.4)
	var arch: float = c.env.get("arch", 0.3)
	var n: float = max(float(c.env.get("n", 4)), 1.0)
	var i: float = float(c.relative_index)
	var u: float = i / max(n - 1.0, 1.0)
	var phase: float = c.elapsed_time * freq * TAU - i * 0.75
	c.offset.y += sin(phase) * amp - (1.0 - abs(u - 0.5) * 2.0) * arch * amp * 2.5
	return true
