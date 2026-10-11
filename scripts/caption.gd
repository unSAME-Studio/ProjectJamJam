class_name Caption
extends WordArtLine
## A HUD caption: WordArt NAME (poster gradient) + flat yellow suffix, one line,
## bent by the live wave envelope. Size follows tier; long lines shrink to fit.

const MAX_LINE_PX := 1300.0
const PALETTE_KEYS := ["热彩", "粉蓝紫", "红橙金", "绿蓝"]

var tier := 1
var fullscreen := false
var _base_name := ""
var _count := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if name_text != "":
		rebuild()


func setup(p_name: String, p_suffix: String, p_tier: int, p_fullscreen: bool = false) -> void:
	_base_name = p_name
	suffix_text = p_suffix
	tier = p_tier
	fullscreen = p_fullscreen
	palette = PALETTE_KEYS[abs(p_name.hash()) % PALETTE_KEYS.size()]
	_apply()


func set_count(n: int) -> void:
	_count = n
	_apply()


func _apply() -> void:
	name_text = _base_name + ("×%d" % _count if _count > 1 else "")
	var base := (120 + tier * 6) if fullscreen else (40 + tier * 8)
	var units := float(name_text.length()) * (1.0 + tracking) + suffix_text.length() * suffix_scale * (1.0 + tracking)
	glyph_px = int(min(base, MAX_LINE_PX / max(units, 1.0)))
	if is_inside_tree():
		rebuild()
