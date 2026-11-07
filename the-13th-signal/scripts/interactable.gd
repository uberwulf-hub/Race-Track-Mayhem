extends StaticBody3D
## Something the player can look at and press E on (notes, keycards, switches).
## The player's look-ray hits collision layer 2.

var prompt_text := ""
var on_use: Callable
var enabled := true


func _init() -> void:
	collision_layer = 2
	collision_mask = 0


func prompt() -> String:
	return prompt_text if enabled else ""


func interact(_player: Node) -> void:
	if enabled and on_use.is_valid():
		on_use.call()
