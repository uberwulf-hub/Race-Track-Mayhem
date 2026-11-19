class_name Unlocks
extends RefCounted
## Everything you can unlock: paint jobs, stickers, wheels, secret cars and Car Builder parts.
## You earn stars by finishing races (3 for 1st, 2 for 2nd, 1 for finishing),
## plus bonus stars for Grand Prix trophies. Winning a Grand Prix unlocks the
## secret car.

const ITEMS: Array[Dictionary] = [
	# --- paint ---
	{"id": "paint_original", "kind": "paint", "name": "Original", "stars": 0},
	{"id": "paint_sky", "kind": "paint", "name": "Sky Blue", "stars": 2, "color": Color(0.45, 0.75, 1.0)},
	{"id": "paint_lime", "kind": "paint", "name": "Lime Zest", "stars": 4, "color": Color(0.6, 0.95, 0.2)},
	{"id": "paint_midnight", "kind": "paint", "name": "Midnight", "stars": 7, "color": Color(0.12, 0.12, 0.22)},
	{"id": "paint_gold", "kind": "paint", "name": "Shiny Gold", "stars": 10, "color": Color(1.0, 0.78, 0.25), "metal": true},
	{"id": "paint_chrome", "kind": "paint", "name": "Chrome", "stars": 14, "color": Color(0.85, 0.88, 0.92), "metal": true},
	{"id": "paint_galaxy", "kind": "paint", "name": "Galaxy", "stars": 18, "color": Color(0.45, 0.2, 0.75), "metal": true},
	# --- stickers ---
	{"id": "sticker_none", "kind": "sticker", "name": "None", "stars": 0},
	{"id": "sticker_stripes", "kind": "sticker", "name": "Racing Stripes", "stars": 3},
	{"id": "sticker_flames", "kind": "sticker", "name": "Flames", "stars": 6},
	{"id": "sticker_stars", "kind": "sticker", "name": "Stars", "stars": 9},
	{"id": "sticker_lightning", "kind": "sticker", "name": "Lightning", "stars": 12},
	{"id": "sticker_checkers", "kind": "sticker", "name": "Checkers", "stars": 16},
	# --- wheels ---
	{"id": "wheels_classic", "kind": "wheels", "name": "Classic", "stars": 0},
	{"id": "wheels_gold", "kind": "wheels", "name": "Gold Rims", "stars": 5},
	{"id": "wheels_slicks", "kind": "wheels", "name": "Fat Slicks", "stars": 8},
	{"id": "wheels_glow", "kind": "wheels", "name": "Glow Wheels", "stars": 13},
	# --- secret car (index into CarData.CARS) ---
	{"id": "car_rocket", "kind": "car", "name": "Rocket Rascal", "stars": 25, "trophy": true},
	{"id": "car_fire", "kind": "car", "name": "Fire Engine Fred", "stars": 30},
	{"id": "car_icecream", "kind": "car", "name": "Ice Cream Dream", "stars": 40},
	# --- Car Builder parts (see CarParts). Starter parts are free. ---
	{"id": "part_body_racer", "kind": "part", "name": "Racer body", "stars": 0},
	{"id": "part_body_truck", "kind": "part", "name": "Truck body", "stars": 0},
	{"id": "part_body_buggy", "kind": "part", "name": "Buggy body", "stars": 0},
	{"id": "part_body_van", "kind": "part", "name": "Van body", "stars": 0},
	{"id": "part_front_bumper", "kind": "part", "name": "Bumper", "stars": 0},
	{"id": "part_front_nose", "kind": "part", "name": "Pointy Nose", "stars": 0},
	{"id": "part_engine_small", "kind": "part", "name": "Zippy Motor", "stars": 0},
	{"id": "part_engine_big", "kind": "part", "name": "Big Engine", "stars": 0},
	{"id": "part_wheels_small", "kind": "part", "name": "Small Wheels", "stars": 0},
	{"id": "part_wheels_big", "kind": "part", "name": "Grippy Wheels", "stars": 0},
	{"id": "part_spoiler_none", "kind": "part", "name": "No Spoiler", "stars": 0},
	{"id": "part_spoiler_wing", "kind": "part", "name": "Wing", "stars": 0},
	{"id": "part_topper_none", "kind": "part", "name": "Nothing on top", "stars": 0},
	{"id": "part_topper_driver", "kind": "part", "name": "Toy Driver", "stars": 0},
	{"id": "part_topper_flag", "kind": "part", "name": "Flag", "stars": 0},
	{"id": "part_topper_lights", "kind": "part", "name": "Light Bar", "stars": 4},
	{"id": "part_front_ram", "kind": "part", "name": "Bulldozer", "stars": 6},
	{"id": "part_spoiler_big", "kind": "part", "name": "Giant Wing", "stars": 9},
	{"id": "part_engine_electric", "kind": "part", "name": "Battery Zap", "stars": 12},
	{"id": "part_wheels_monster", "kind": "part", "name": "Monster Wheels", "stars": 15},
	{"id": "part_topper_fin", "kind": "part", "name": "Shark Fin", "stars": 18},
	{"id": "part_body_bullet", "kind": "part", "name": "Bullet body", "stars": 22},
	{"id": "part_topper_crown", "kind": "part", "name": "Golden Crown", "stars": 35, "trophy": true},
	{"id": "part_engine_jet", "kind": "part", "name": "Jet Engine", "stars": 999999, "how": "Beat a Story Mode boss",
		"stat": "bosses", "goal": 1},
	# Special unlocks: earned by doing something, not with stars (see Game.grant()).
	{"id": "car_sleigh", "kind": "car", "name": "Santa's Sleigh", "stars": 999999, "how": "Finish the holiday track (December only!)"},
	{"id": "car_pumpkin", "kind": "car", "name": "Pumpkin Rider", "stars": 999999, "how": "Finish the Halloween track (October only!)"},
	{"id": "car_surf", "kind": "car", "name": "Surf Buggy", "stars": 999999, "how": "Finish the summer beach track (June to August!)"},
]


static func get_item(item_id: String) -> Dictionary:
	for it in ITEMS:
		if it["id"] == item_id:
			return it
	return {}


static func of_kind(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in ITEMS:
		if it["kind"] == kind:
			out.append(it)
	return out


## Ids of everything unlocked with this many stars and these trophies.
## Items marked "trophy" unlock with their stars OR by winning any Grand Prix.
static func available(stars: int, trophies: Dictionary) -> Array:
	var won_cup := false
	for k in trophies:
		if int(trophies[k]) == 1:
			won_cup = true
	var out: Array = []
	for it in ITEMS:
		if stars >= int(it["stars"]) or (it.get("trophy", false) and won_cup):
			out.append(it["id"])
	return out


## A friendly line describing how to unlock an item.
static func requirement_text(it: Dictionary) -> String:
	if it.has("how"):
		return String(it["how"])
	if it.get("trophy", false):
		return "Win a Grand Prix or earn %d stars" % int(it["stars"])
	return "Earn %d stars" % int(it["stars"])
