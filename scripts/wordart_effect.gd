@tool
class_name WordArtEffect
extends RichTextEffect
## [wordart n=4 amp=10 freq=2.5 bulge=0.3 speed=0.5 hue=0.0 sat=0.9]
## Rainbow sweep along the word, sine wave on the baseline, chars near the
## middle bigger (the WordArt "inflate" arch), a little rocking rotation.
## `n` is the char count so the hue sweep can span the word exactly.

var bbcode := "wordart"


func _process_custom_fx(c: CharFXTransform) -> bool:
	var amp: float = c.env.get("amp", 10.0)
	var freq: float = c.env.get("freq", 2.5)
	var bulge: float = c.env.get("bulge", 0.3)
	var speed: float = c.env.get("speed", 0.5)
	var sat: float = c.env.get("sat", 0.9)
	var hue0: float = c.env.get("hue", 0.0)
	var n: float = max(float(c.env.get("n", 4)), 1.0)
	var t: float = c.elapsed_time
	var i: float = float(c.relative_index)
	var u: float = i / max(n - 1.0, 1.0)

	var phase: float = t * freq * TAU - i * 0.85
	c.offset.y += sin(phase) * amp
	var s: float = 1.0 + bulge * (1.0 - abs(u - 0.5) * 2.0)
	var rot: float = sin(phase) * 0.07
	c.transform = Transform2D(rot, Vector2.ONE * s, 0.0, Vector2.ZERO)

	if not c.outline:
		var hue: float = fmod(hue0 + u * 0.8 + t * speed, 1.0)
		c.color = Color.from_hsv(hue, sat, 1.0, c.color.a)
	return true
