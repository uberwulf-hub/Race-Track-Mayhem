class_name Daily
extends RefCounted
## Daily challenges: three little goals every day, the same for everyone (they
## come from the date). Each one is worth stars; finish all three for a bonus.
## Doing at least one every day builds up a streak.
##
## A race reports what happened (see Game.daily_race()) and each goal counts
## the bit it cares about.

const STARS_EACH := 2
const ALL_BONUS := 3

## kind: what's counted. goal: how many. Some goals name a track or a car,
## filled in from the day's numbers.
const POOL: Array[Dictionary] = [
	{"kind": "wins", "goal": 1, "text": "Win a race"},
	{"kind": "wins", "goal": 2, "text": "Win 2 races"},
	{"kind": "jumps", "goal": 5, "text": "Land 5 jumps"},
	{"kind": "jumps", "goal": 10, "text": "Land 10 jumps"},
	{"kind": "items", "goal": 5, "text": "Use 5 power-ups"},
	{"kind": "hits", "goal": 3, "text": "Hit other cars with power-ups 3 times"},
	{"kind": "laps", "goal": 10, "text": "Drive 10 laps"},
	{"kind": "clean", "goal": 1, "text": "Finish a race without bumping a wall"},
	{"kind": "podium", "goal": 2, "text": "Finish in the top 3 twice"},
	{"kind": "track", "goal": 1, "text": "Finish a race on %s"},
	{"kind": "car", "goal": 1, "text": "Finish a race driving %s"},
	{"kind": "boss", "goal": 1, "text": "Race a Story Mode boss"},
]


## Today's day number (local date), counting from 1970.
static func today() -> int:
	var d := Time.get_date_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict({"year": d["year"], "month": d["month"], "day": d["day"]}) / 86400)


## The three goals for a day: [{"id", "kind", "goal", "text", "track"?, "car"?}].
static func goals_for(day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919 + 13
	var picks: Array = []
	var kinds_used := {}
	var tries := 0
	while picks.size() < 3 and tries < 50:
		tries += 1
		var g: Dictionary = POOL[rng.randi() % POOL.size()].duplicate()
		if kinds_used.has(g["kind"]):
			continue
		kinds_used[g["kind"]] = true
		if g["kind"] == "track":
			var ti := rng.randi() % Track.TRACKS.size()
			g["track"] = Track.TRACKS[ti]["id"]
			g["text"] = String(g["text"]) % Track.TRACKS[ti]["name"]
		elif g["kind"] == "car":
			var cars: Array = []
			for i in CarData.count():
				if CarData.is_regular(i):
					cars.append(i)
			var ci: int = cars[rng.randi() % cars.size()]
			g["car"] = CarData.get_car(ci)["id"]
			g["text"] = String(g["text"]) % CarData.get_car(ci)["name"]
		g["id"] = "%d_%d" % [day, picks.size()]
		picks.append(g)
	return picks


## How much a finished race counts toward a goal.
static func amount(g: Dictionary, race: Dictionary) -> int:
	if not race.get("finished", false):
		return 0
	match String(g["kind"]):
		"wins":
			return 1 if int(race.get("place", 9)) == 1 else 0
		"jumps":
			return int(race.get("jumps", 0))
		"items":
			return int(race.get("items", 0))
		"hits":
			return int(race.get("hits", 0))
		"laps":
			return int(race.get("laps", 0))
		"clean":
			return 1 if int(race.get("wall_bumps", 1)) == 0 else 0
		"podium":
			return 1 if int(race.get("place", 9)) <= 3 else 0
		"track":
			return 1 if race.get("track", "") == g.get("track", "-") else 0
		"car":
			return 1 if race.get("car", "") == g.get("car", "-") else 0
		"boss":
			return 1 if race.get("boss", false) else 0
	return 0
