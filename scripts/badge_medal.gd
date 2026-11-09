class_name BadgeMedal
extends Control
## A round medal on a ribbon with the badge's symbol. Grey with a lock look
## when it isn't earned yet.

var badge: Dictionary = {}
var earned := true
var _shine := 0.0


static func make(b: Dictionary, is_earned: bool, size_px: float) -> BadgeMedal:
	var m := BadgeMedal.new()
	m.badge = b
	m.earned = is_earned
	m.custom_minimum_size = Vector2(size_px, size_px * 1.15)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


func _process(delta: float) -> void:
	if earned:
		_shine = fmod(_shine + delta * 0.35, 1.6)
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var col: Color = badge.get("color", Color(0.8, 0.8, 0.8))
	if not earned:
		col = Color(0.42, 0.42, 0.48)
	var r := w * 0.4
	var c := Vector2(w * 0.5, size.y - r - 2.0)
	# Ribbon tails behind the medal.
	var rib := col.darkened(0.25) if earned else Color(0.3, 0.3, 0.35)
	var rib2 := Color(1, 1, 1, 0.9) if earned else Color(0.45, 0.45, 0.5)
	for side: float in [-1.0, 1.0]:
		var top := Vector2(w * 0.5 + side * r * 0.55, 0.0)
		var pts := PackedVector2Array([top + Vector2(-r * 0.28, 0), top + Vector2(r * 0.28, 0),
			c + Vector2(side * r * 0.15 + r * 0.2, -r * 0.4), c + Vector2(side * r * 0.15 - r * 0.2, -r * 0.4)])
		draw_colored_polygon(pts, rib)
		draw_line(top, c + Vector2(side * r * 0.15, -r * 0.4), rib2, maxf(2.0, r * 0.08))
	# The medal: dark rim, colored face, lighter inner ring.
	draw_circle(c, r + 3.0, Color(0.1, 0.06, 0.15))
	draw_circle(c, r, col.darkened(0.2))
	draw_circle(c, r * 0.84, col)
	draw_arc(c, r * 0.72, 0, TAU, 40, col.lightened(0.35), maxf(1.5, r * 0.05), true)
	# A sweep of shine.
	if earned and _shine < 1.0:
		var a := -PI * 0.75 + _shine * PI * 0.6
		draw_arc(c, r * 0.6, a, a + 0.5, 12, Color(1, 1, 1, 0.45), r * 0.12, true)
	# The symbol in the middle.
	var font := get_theme_default_font()
	var sym: String = badge.get("symbol", "?") if earned else "?"
	var fs := int(r * (0.95 if sym.length() <= 1 else (0.75 if sym.length() == 2 else 0.55)))
	var ts := font.get_string_size(sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := c + Vector2(-ts.x * 0.5, fs * 0.36)
	draw_string_outline(font, pos, sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(r * 0.12)), Color(0.1, 0.06, 0.15))
	draw_string(font, pos, sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if earned else Color(0.75, 0.75, 0.8))
