class_name CarParts
extends RefCounted
## The Car Builder's parts. "My Build" (the last car in CarData) is put
## together from one part per slot, and the parts decide how it drives.
##
## Fair by design: every body starts with 9 stat points and every other part
## adds 1 point overall (a big plus often comes with a minus somewhere else),
## so every build has about 13 points, like the garage's own cars. Stats stay
## between 1 and 5. Toppers are just for fun and don't change anything.
##
## Parts unlock like paint jobs (see Unlocks: kind "part"). The starter parts
## are free.

const SLOTS := ["body", "front", "engine", "wheels", "spoiler", "topper"]

const SLOT_NAMES := {
	"body": "Body", "front": "Front", "engine": "Engine",
	"wheels": "Wheels", "spoiler": "Spoiler", "topper": "On Top",
}

## Unlock ids live in Unlocks.ITEMS; their "stars" decide when they open up.
const PARTS: Array[Dictionary] = [
	# --- bodies: the base 1..5 stats (9 points each) ---
	{"id": "part_body_racer", "slot": "body", "blurb": "Fast and sleek", "name": "Racer", "stats": {"speed": 3, "accel": 2, "handling": 2, "weight": 2}},
	{"id": "part_body_truck", "slot": "body", "blurb": "Big, tough and heavy", "name": "Truck", "stats": {"speed": 2, "accel": 2, "handling": 1, "weight": 4}},
	{"id": "part_body_buggy", "slot": "body", "blurb": "Quick off the line", "name": "Buggy", "stats": {"speed": 2, "accel": 3, "handling": 2, "weight": 2}},
	{"id": "part_body_van", "slot": "body", "blurb": "Easy to steer", "name": "Van", "stats": {"speed": 1, "accel": 2, "handling": 3, "weight": 3}},
	{"id": "part_body_bullet", "slot": "body", "blurb": "Light and super speedy", "name": "Bullet", "stats": {"speed": 3, "accel": 3, "handling": 2, "weight": 1}},
	# --- fronts ---
	{"id": "part_front_bumper", "slot": "front", "name": "Bumper", "stats": {"weight": 1}},
	{"id": "part_front_nose", "slot": "front", "name": "Pointy Nose", "stats": {"speed": 1}},
	{"id": "part_front_ram", "slot": "front", "name": "Bulldozer", "stats": {"weight": 2, "handling": -1}},
	# --- engines ---
	{"id": "part_engine_small", "slot": "engine", "name": "Zippy Motor", "stats": {"accel": 1}},
	{"id": "part_engine_big", "slot": "engine", "name": "Big Engine", "stats": {"speed": 1}},
	{"id": "part_engine_electric", "slot": "engine", "name": "Battery Zap", "stats": {"accel": 2, "speed": -1}},
	{"id": "part_engine_jet", "slot": "engine", "name": "Jet Engine", "stats": {"speed": 2, "handling": -1}},
	# --- wheels ---
	{"id": "part_wheels_small", "slot": "wheels", "name": "Small Wheels", "stats": {"accel": 1}, "radius": 0.27},
	{"id": "part_wheels_big", "slot": "wheels", "name": "Grippy Wheels", "stats": {"handling": 1}, "radius": 0.34},
	{"id": "part_wheels_monster", "slot": "wheels", "name": "Monster Wheels", "stats": {"weight": 2, "accel": -1}, "radius": 0.56},
	# --- spoilers ---
	{"id": "part_spoiler_none", "slot": "spoiler", "name": "No Spoiler", "stats": {"accel": 1}},
	{"id": "part_spoiler_wing", "slot": "spoiler", "name": "Wing", "stats": {"handling": 1}},
	{"id": "part_spoiler_big", "slot": "spoiler", "name": "Giant Wing", "stats": {"handling": 2, "speed": -1}},
	# --- toppers (just for looks) ---
	{"id": "part_topper_none", "slot": "topper", "name": "Nothing", "stats": {}},
	{"id": "part_topper_driver", "slot": "topper", "name": "Toy Driver", "stats": {}},
	{"id": "part_topper_flag", "slot": "topper", "name": "Flag", "stats": {}},
	{"id": "part_topper_lights", "slot": "topper", "name": "Light Bar", "stats": {}},
	{"id": "part_topper_fin", "slot": "topper", "name": "Shark Fin", "stats": {}},
	{"id": "part_topper_crown", "slot": "topper", "name": "Golden Crown", "stats": {}},
]

const DEFAULT_BUILD := {
	"body": "part_body_racer", "front": "part_front_nose", "engine": "part_engine_small",
	"wheels": "part_wheels_big", "spoiler": "part_spoiler_wing", "topper": "part_topper_driver",
}

const STAT_KEYS := ["speed", "accel", "handling", "weight"]


static func get_part(part_id: String) -> Dictionary:
	for p in PARTS:
		if p["id"] == part_id:
			return p
	return {}


static func of_slot(slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in PARTS:
		if p["slot"] == slot:
			out.append(p)
	return out


## A build with every slot filled by a real part of that slot. Online, builds
## come from other people's games, so anything odd falls back to the default.
static func clean(build: Variant) -> Dictionary:
	var out := DEFAULT_BUILD.duplicate()
	if build is Dictionary:
		for slot in SLOTS:
			var id := String((build as Dictionary).get(slot, ""))
			var p := get_part(id)
			if not p.is_empty() and p["slot"] == slot:
				out[slot] = id
	return out


## The build's 1..5 stats.
static func stats_for(build: Variant) -> Dictionary:
	var b := clean(build)
	var s: Dictionary = (get_part(b["body"])["stats"] as Dictionary).duplicate()
	for slot in SLOTS:
		if slot == "body":
			continue
		var d: Dictionary = get_part(b[slot])["stats"]
		for k in d:
			s[k] = int(s[k]) + int(d[k])
	for k in STAT_KEYS:
		s[k] = clampi(int(s[k]), 1, 5)
	return s


## "+1 Top Speed, -1 Handling" (or "Just for looks"; bodies get a short description).
static func effect_text(part: Dictionary) -> String:
	var d: Dictionary = part.get("stats", {})
	if part.get("slot", "") == "body":
		return String(part.get("blurb", ""))
	if d.is_empty():
		return "Just for looks"
	var bits: Array = []
	for k in STAT_KEYS:
		if d.has(k):
			bits.append("%s%d %s" % ["+" if int(d[k]) > 0 else "", int(d[k]), CarData.STAT_LABELS[k]])
	return ", ".join(bits)


## The wheel size for this build.
static func wheel_radius(build: Variant) -> float:
	return float(get_part(clean(build)["wheels"]).get("radius", 0.3))
