class_name EmoteFaces
extends RefCounted
## Funny faces for online emotes, drawn by the game itself (so they look the
## same on every computer and phone, no emoji font needed). Each face is
## painted into an image once and kept.

## Emote ids look like ":laugh:" (see Net.EMOTES).
const FACES := {
	":laugh:": "Laughing",
	":silly:": "Silly",
	":cool:": "Cool",
	":shock:": "Shocked",
	":wink:": "Wink",
	":dizzy:": "Dizzy",
}

const SIZE := 256          # drawn big, then shrunk for smooth edges
const OUT := 128

const YELLOW := Color(1.0, 0.82, 0.18)
const EDGE := Color(0.62, 0.36, 0.05)
const INK := Color(0.2, 0.1, 0.05)
const MOUTH := Color(0.55, 0.08, 0.1)
const TONGUE := Color(1.0, 0.45, 0.55)
const WHITE := Color(1, 1, 1)

static var _cache: Dictionary = {}


static func is_face(emote: String) -> bool:
	return FACES.has(emote)


## The face as a picture, `px` pixels across (buttons use a smaller one).
static func texture(emote: String, px: int = OUT) -> Texture2D:
	var key := "%s@%d" % [emote, px]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(SIZE, SIZE) * 0.5
	_disc(img, c, 118, EDGE)
	_disc(img, c, 108, YELLOW)
	_disc(img, c + Vector2(-30, -40), 46, YELLOW.lightened(0.25))   # shine
	_disc(img, c + Vector2(-8, -12), 96, YELLOW)
	match emote:
		":laugh:":
			_arc(img, c + Vector2(-40, -18), 20, PI * 1.1, PI * 1.9, 7, INK)       # ^ ^ eyes
			_arc(img, c + Vector2(40, -18), 20, PI * 1.1, PI * 1.9, 7, INK)
			_half_disc(img, c + Vector2(0, 18), 58, 50, MOUTH)                     # big open mouth
			_half_disc(img, c + Vector2(0, 46), 30, 20, TONGUE)
			_drop(img, c + Vector2(-86, 10), WHITE.lerp(Color(0.35, 0.7, 1.0), 0.8))  # happy tears
			_drop(img, c + Vector2(86, 10), WHITE.lerp(Color(0.35, 0.7, 1.0), 0.8))
		":silly:":
			_disc(img, c + Vector2(-38, -24), 22, WHITE)
			_disc(img, c + Vector2(-34, -20), 11, INK)
			_disc(img, c + Vector2(40, -26), 13, WHITE)
			_disc(img, c + Vector2(42, -24), 7, INK)
			_arc(img, c + Vector2(0, 8), 52, PI * 0.15, PI * 0.85, 7, INK)        # smile
			_ellipse(img, c + Vector2(14, 66), 22, 28, TONGUE)                     # tongue out
			_line(img, c + Vector2(14, 48), c + Vector2(14, 82), 3, TONGUE.darkened(0.25))
		":cool:":
			var shade := Color(0.08, 0.08, 0.12)
			_round_rect(img, c + Vector2(-42, -20), Vector2(70, 44), shade)
			_round_rect(img, c + Vector2(42, -20), Vector2(70, 44), shade)
			_line(img, c + Vector2(-60, -30), c + Vector2(60, -30), 6, shade)
			_line(img, c + Vector2(-56, -32), c + Vector2(-40, -32), 4, Color(1, 1, 1, 0.7))  # glint
			_line(img, c + Vector2(28, -32), c + Vector2(44, -32), 4, Color(1, 1, 1, 0.7))
			_arc(img, c + Vector2(14, 30), 40, PI * 0.1, PI * 0.7, 7, INK)        # smirk
		":shock:":
			_disc(img, c + Vector2(-38, -24), 24, WHITE)
			_disc(img, c + Vector2(38, -24), 24, WHITE)
			_disc(img, c + Vector2(-38, -22), 10, INK)
			_disc(img, c + Vector2(38, -22), 10, INK)
			_arc(img, c + Vector2(-38, -62), 18, PI * 1.15, PI * 1.85, 5, INK)    # raised brows
			_arc(img, c + Vector2(38, -62), 18, PI * 1.15, PI * 1.85, 5, INK)
			_ellipse(img, c + Vector2(0, 46), 22, 30, MOUTH)                       # O mouth
		":wink:":
			_disc(img, c + Vector2(-38, -22), 14, INK)
			_arc(img, c + Vector2(40, -22), 20, PI * 0.1, PI * 0.9, 7, INK)       # winking eye
			_arc(img, c + Vector2(0, 6), 56, PI * 0.12, PI * 0.88, 8, INK)
			_disc(img, c + Vector2(-70, 22), 16, Color(1.0, 0.5, 0.45, 0.55))     # rosy cheeks
			_disc(img, c + Vector2(70, 22), 16, Color(1.0, 0.5, 0.45, 0.55))
		":dizzy:":
			for side: float in [-1.0, 1.0]:
				var e := c + Vector2(side * 40, -22)
				_arc(img, e, 22, 0, TAU * 0.8, 5, INK)                              # spiral eyes
				_arc(img, e, 13, PI, PI + TAU * 0.75, 5, INK)
				_disc(img, e, 4, INK)
			var prev := c + Vector2(-46, 48)
			for i in range(1, 25):                                                  # wobbly mouth
				var x := -46.0 + i * 4.0
				var p := c + Vector2(x, 48 + sin(i * 0.8) * 9)
				_line(img, prev, p, 6, INK)
				prev = p
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# --- tiny painting helpers (everything is solid shapes) ---

static func _blend(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	if col.a >= 0.999:
		img.set_pixel(x, y, col)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(col))


static func _disc(img: Image, at: Vector2, r: float, col: Color) -> void:
	_ellipse(img, at, r, r, col)


static func _ellipse(img: Image, at: Vector2, rx: float, ry: float, col: Color) -> void:
	for y in range(int(at.y - ry), int(at.y + ry) + 1):
		for x in range(int(at.x - rx), int(at.x + rx) + 1):
			var dx := (x - at.x) / rx
			var dy := (y - at.y) / ry
			if dx * dx + dy * dy <= 1.0:
				_blend(img, x, y, col)


## The bottom half of an ellipse (an open mouth).
static func _half_disc(img: Image, at: Vector2, rx: float, ry: float, col: Color) -> void:
	for y in range(int(at.y), int(at.y + ry) + 1):
		for x in range(int(at.x - rx), int(at.x + rx) + 1):
			var dx := (x - at.x) / rx
			var dy := (y - at.y) / ry
			if dx * dx + dy * dy <= 1.0:
				_blend(img, x, y, col)


static func _line(img: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var steps := maxi(1, int(a.distance_to(b) / 2.0))
	for i in steps + 1:
		_disc(img, a.lerp(b, float(i) / steps), w, col)


## Part of a circle's edge, angles in radians (0 = right, PI/2 = down).
static func _arc(img: Image, at: Vector2, r: float, from: float, to: float, w: float, col: Color) -> void:
	var steps := maxi(4, int(absf(to - from) * r / 3.0))
	for i in steps + 1:
		var ang := lerpf(from, to, float(i) / steps)
		_disc(img, at + Vector2(cos(ang), sin(ang)) * r, w, col)


static func _round_rect(img: Image, at: Vector2, size: Vector2, col: Color) -> void:
	var r := size.y * 0.45
	for y in range(int(at.y - size.y * 0.5), int(at.y + size.y * 0.5) + 1):
		for x in range(int(at.x - size.x * 0.5), int(at.x + size.x * 0.5) + 1):
			var qx := maxf(absf(x - at.x) - (size.x * 0.5 - r), 0.0)
			var qy := maxf(absf(y - at.y) - (size.y * 0.5 - r), 0.0)
			if qx * qx + qy * qy <= r * r:
				_blend(img, x, y, col)


## A little teardrop.
static func _drop(img: Image, at: Vector2, col: Color) -> void:
	_disc(img, at + Vector2(0, 10), 13, col)
	for i in 12:
		_disc(img, at + Vector2(0, 10 - i * 2.0), 13.0 * (1.0 - i / 12.0), col)
