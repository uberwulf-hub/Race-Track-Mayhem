class_name TouchControls
extends CanvasLayer
## Big on-screen buttons for phones and tablets. They press the same actions
## as the keyboard and controller, so the rest of the game doesn't care.
## Multi-touch: steer with your left thumb while holding GO with your right.
## Slide your thumb between LEFT and RIGHT without lifting it.

const ALPHA := 0.42

var _buttons: Dictionary = {}   # id -> TouchScreenButton
var _prefix := ""


func setup(input_prefix: String = "") -> TouchControls:
	_prefix = input_prefix
	layer = 8
	_add("left", "<", "steer_left", 170, Color(0.3, 0.6, 1.0), true)
	_add("right", ">", "steer_right", 170, Color(0.3, 0.6, 1.0), true)
	_add("go", "GO", "accelerate", 190, Color(0.25, 0.85, 0.35), true)
	_add("brake", "BRAKE", "brake", 130, Color(0.95, 0.35, 0.3), true)
	_add("turbo", "TURBO", "turbo", 130, Color(0.2, 0.85, 0.95), true)
	_add("item", "ITEM", "use_item", 120, Color(1.0, 0.8, 0.2), false)
	_add("pause", "II", "pause", 76, Color(0.6, 0.6, 0.75), false, false)
	_add("respawn", "R", "respawn", 76, Color(0.75, 0.55, 1.0), false, false)
	return self


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


## Shows the ITEM button brighter when you're holding a power-up.
func set_item_ready(ready: bool) -> void:
	if _buttons.has("item"):
		(_buttons["item"] as TouchScreenButton).modulate.a = 1.0 if ready else 0.45


func _layout() -> void:
	var sz := get_viewport().get_visible_rect().size
	var w := sz.x
	var h := sz.y
	_place("left", Vector2(30, h - 200))
	_place("right", Vector2(215, h - 200))
	_place("go", Vector2(w - 220, h - 220))
	_place("brake", Vector2(w - 380, h - 150))
	_place("turbo", Vector2(w - 190, h - 380))
	_place("item", Vector2(w - 360, h - 300))
	_place("pause", Vector2(w * 0.5 - 86, 12))
	_place("respawn", Vector2(w * 0.5 + 10, 12))


func _place(id: String, pos: Vector2) -> void:
	if _buttons.has(id):
		(_buttons[id] as TouchScreenButton).position = pos


func _add(id: String, text: String, action: String, size: int, col: Color, passby: bool, prefixed: bool = true) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = _circle(size, col, ALPHA)
	b.texture_pressed = _circle(size, col.lightened(0.25), 0.8)
	b.action = (_prefix + action) if prefixed and _prefix != "" else action
	b.passby_press = passby
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	var shape := CircleShape2D.new()
	shape.radius = size * 0.5
	b.shape = shape
	b.shape_centered = true
	var l := RaceHud.make_label(text, int(size * 0.24) if text.length() > 2 else int(size * 0.4), Color.WHITE, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(size, size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	add_child(b)
	_buttons[id] = b


## A soft round button picture with a white ring.
static func _circle(size: int, col: Color, alpha: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	var r := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > r:
				continue
			var edge := clampf(r - d, 0.0, 1.0)   # smooth outer edge
			var px := Color(col.r, col.g, col.b, alpha * edge)
			if d > r - 5.0:
				px = Color(1, 1, 1, 0.75 * edge)   # white ring
			img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)
