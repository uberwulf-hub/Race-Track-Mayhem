class_name CarData
extends RefCounted
## All the toy cars you can pick. Stats are 1..5 (shown as bars in the garage)
## and get turned into real driving numbers by `physics_for()`.

const NICKNAME_LENGTH := 14

const CARS: Array[Dictionary] = [
	{
		"id": "red_rocket",
		"name": "Red Rocket",
		"blurb": "Super fast on the straights, but a bit slippery in the turns!",
		"style": "sport",
		"body": Color(0.90, 0.12, 0.10),
		"accent": Color(1.0, 0.85, 0.15),
		"number": 7,
		"stats": {"speed": 5, "accel": 3, "handling": 2, "weight": 3},
	},
	{
		"id": "blue_bolt",
		"name": "Blue Bolt",
		"blurb": "Zooms off the start line like lightning. Light and nimble.",
		"style": "sport",
		"body": Color(0.10, 0.38, 0.95),
		"accent": Color(0.95, 0.95, 0.95),
		"number": 3,
		"stats": {"speed": 3, "accel": 5, "handling": 4, "weight": 2},
	},
	{
		"id": "monster_max",
		"name": "Monster Max",
		"blurb": "Giant wheels! Bumps everyone else out of the way.",
		"style": "monster",
		"body": Color(0.20, 0.70, 0.18),
		"accent": Color(0.15, 0.15, 0.15),
		"number": 9,
		"stats": {"speed": 3, "accel": 3, "handling": 3, "weight": 5},
	},
	{
		"id": "sunny_buggy",
		"name": "Sunny Buggy",
		"blurb": "A happy little dune buggy. Good at everything!",
		"style": "buggy",
		"body": Color(1.0, 0.80, 0.05),
		"accent": Color(0.95, 0.35, 0.05),
		"number": 1,
		"stats": {"speed": 4, "accel": 4, "handling": 3, "weight": 2},
	},
	{
		"id": "bubblegum_van",
		"name": "Bubblegum Van",
		"blurb": "Turns on a dime and is hard to push around.",
		"style": "van",
		"body": Color(1.0, 0.42, 0.72),
		"accent": Color(0.55, 0.95, 1.0),
		"number": 5,
		"stats": {"speed": 2, "accel": 4, "handling": 5, "weight": 4},
	},
	{
		"id": "rocket_rascal",
		"name": "Rocket Rascal",
		"blurb": "The SECRET car! A tiny rocket on wheels. Super fast AND easy to steer.",
		"style": "rocket",
		"body": Color(0.92, 0.92, 0.96),
		"accent": Color(0.95, 0.2, 0.25),
		"number": 0,
		"stats": {"speed": 5, "accel": 5, "handling": 4, "weight": 2},
		"secret": true,
		"unlock": "car_rocket",
	},
	{
		"id": "fire_fred",
		"name": "Fire Engine Fred",
		"blurb": "Nee-naw! A big red fire engine with a ladder and flashing lights.",
		"style": "fire",
		"body": Color(0.88, 0.1, 0.08),
		"accent": Color(0.96, 0.96, 0.96),
		"number": 11,
		"stats": {"speed": 3, "accel": 3, "handling": 3, "weight": 5},
		"secret": true,
		"unlock": "car_fire",
	},
	{
		"id": "ice_cream_dream",
		"name": "Ice Cream Dream",
		"blurb": "Ding-a-ling! The ice cream truck, with a giant cone on the roof.",
		"style": "icecream",
		"body": Color(1.0, 0.8, 0.9),
		"accent": Color(0.5, 0.85, 1.0),
		"number": 8,
		"stats": {"speed": 3, "accel": 4, "handling": 4, "weight": 3},
		"secret": true,
		"unlock": "car_icecream",
	},
	{
		"id": "santa_sleigh",
		"name": "Santa's Sleigh",
		"blurb": "Ho ho ho! Santa's sleigh, pulled by a reindeer with a glowing red nose.",
		"style": "sleigh",
		"body": Color(0.85, 0.08, 0.1),
		"accent": Color(1.0, 0.82, 0.25),
		"number": 25,
		"stats": {"speed": 4, "accel": 4, "handling": 4, "weight": 3},
		"secret": true,
		"unlock": "car_sleigh",
	},
]

const STAT_LABELS := {
	"speed": "Top Speed",
	"accel": "Acceleration",
	"handling": "Handling",
	"weight": "Weight",
}


static func count() -> int:
	return CARS.size()


## Can the player drive this car yet? (The secret car has to be unlocked.)
static func is_available(index: int) -> bool:
	var c := get_car(index)
	return not c.get("secret", false) or Game.is_unlocked(String(c.get("unlock", "")))


static func get_car(index: int) -> Dictionary:
	return CARS[wrapi(index, 0, CARS.size())]


## Converts the 1..5 kid-friendly stats into numbers the driving code uses.
static func physics_for(car: Dictionary) -> Dictionary:
	var s: Dictionary = car["stats"]
	return {
		"top_speed": 27.0 + float(s["speed"]) * 3.2,     # units / second
		"accel": 9.0 + float(s["accel"]) * 3.2,          # units / second^2
		"steer": 7.5 + float(s["handling"]) * 1.6,       # sideways units / second
		"grip": 0.55 + float(s["handling"]) * 0.09,      # resists sliding out in turns
		"mass": 0.8 + float(s["weight"]) * 0.35,         # used for bumping
	}


## The name given to a car in the Car Designer ("" if none). Cleaned up,
## since online it comes from someone else's game.
static func nickname(look: Variant) -> String:
	if not look is Dictionary:
		return ""
	var n := String((look as Dictionary).get("nickname", "")).strip_edges().replace("\n", " ")
	return n.substr(0, NICKNAME_LENGTH)
