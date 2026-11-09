class_name Badges
extends RefCounted
## Badges you earn for doing things: winning, jumping, building tracks,
## racing your cousins online... Each player has their own (see Game.stats
## and Game.badges). The Badges room shows them all.
##
## "stat" + "goal": earned once Game.stats[stat] reaches goal.
## "tracks": earned once you've finished every built-in track.

const LIST: Array[Dictionary] = [
	{"id": "first_race", "name": "Off We Go!", "desc": "Finish your first race", "stat": "races", "goal": 1, "symbol": "1", "color": Color(0.4, 0.75, 1.0)},
	{"id": "first_win", "name": "Winner!", "desc": "Win a race", "stat": "wins", "goal": 1, "symbol": "★", "color": Color(1.0, 0.8, 0.2)},
	{"id": "wins_10", "name": "Champion", "desc": "Win 10 races", "stat": "wins", "goal": 10, "symbol": "10", "color": Color(1.0, 0.6, 0.15)},
	{"id": "wins_50", "name": "Legend", "desc": "Win 50 races", "stat": "wins", "goal": 50, "symbol": "50", "color": Color(0.95, 0.3, 0.25)},
	{"id": "races_25", "name": "Road Tripper", "desc": "Finish 25 races", "stat": "races", "goal": 25, "symbol": "25", "color": Color(0.35, 0.8, 0.5)},
	{"id": "tourist", "name": "Tourist", "desc": "Finish a race on every track", "tracks": true, "symbol": "ALL", "color": Color(0.3, 0.7, 0.9)},
	{"id": "hard_win", "name": "Tough Cookie", "desc": "Win a race on Hard", "stat": "hard_wins", "goal": 1, "symbol": "H", "color": Color(0.85, 0.25, 0.3)},
	{"id": "gp_gold", "name": "Golden Cup", "desc": "Win a Grand Prix", "stat": "gp_wins", "goal": 1, "symbol": "GP", "color": Color(1.0, 0.82, 0.25)},
	{"id": "record", "name": "Record Breaker", "desc": "Beat your best time", "stat": "records", "goal": 1, "symbol": "PB", "color": Color(0.55, 0.9, 0.6)},
	{"id": "smooth", "name": "Smooth Driver", "desc": "Finish a race without bumping a wall", "stat": "clean_races", "goal": 1, "symbol": "OK", "color": Color(0.5, 0.85, 0.95)},
	{"id": "big_air", "name": "Big Air", "desc": "Land 25 jumps", "stat": "jumps", "goal": 25, "symbol": "UP", "color": Color(0.65, 0.5, 1.0)},
	{"id": "power_player", "name": "Power Player", "desc": "Use 50 power-ups", "stat": "items", "goal": 50, "symbol": "?!", "color": Color(1.0, 0.75, 0.3)},
	{"id": "stars_100", "name": "Star Collector", "desc": "Collect 100 stars", "stat": "stars", "goal": 100, "symbol": "★", "color": Color(0.95, 0.85, 0.35)},
	{"id": "designer", "name": "Track Designer", "desc": "Save a track in the Track Builder", "stat": "tracks_built", "goal": 1, "symbol": "DIY", "color": Color(0.95, 0.55, 0.8)},
	{"id": "sharer", "name": "Sharing is Caring", "desc": "Share a track code", "stat": "shared", "goal": 1, "symbol": "<3", "color": Color(1.0, 0.45, 0.6)},
	{"id": "online", "name": "Cousin Racer", "desc": "Finish an online race", "stat": "online_races", "goal": 1, "symbol": "NET", "color": Color(0.35, 0.6, 1.0)},
	{"id": "online_win", "name": "Internet Champ", "desc": "Win an online race", "stat": "online_wins", "goal": 1, "symbol": "#1", "color": Color(0.2, 0.45, 0.95)},
	{"id": "weekly", "name": "Weekly Warrior", "desc": "Finish a Weekly Challenge", "stat": "weekly", "goal": 1, "symbol": "W", "color": Color(0.9, 0.5, 0.2)},
	{"id": "photo", "name": "Shutterbug", "desc": "Snap a photo in a replay", "stat": "photos", "goal": 1, "symbol": "PIC", "color": Color(0.95, 0.65, 0.9)},
	{"id": "boss", "name": "Boss Buster", "desc": "Beat a Story Mode boss", "stat": "bosses", "goal": 1, "symbol": "KO", "color": Color(0.75, 0.3, 0.9)},
	{"id": "story_done", "name": "Toy Box Hero", "desc": "Beat every Story Mode boss", "stat": "bosses", "goal": 7, "symbol": "!!", "color": Color(0.95, 0.45, 0.2)},
	{"id": "halloween", "name": "Trick or Treat", "desc": "Finish Pumpkin Patch Panic", "stat": "halloween", "goal": 1, "symbol": "BOO", "color": Color(1.0, 0.55, 0.15)},
	{"id": "summer", "name": "Beach Bum", "desc": "Finish Sandy Shores Splash", "stat": "summer", "goal": 1, "symbol": "SUN", "color": Color(1.0, 0.85, 0.3)},
	{"id": "holiday", "name": "Holiday Spirit", "desc": "Finish Frosty Backyard", "stat": "holiday", "goal": 1, "symbol": "JOY", "color": Color(0.7, 0.88, 1.0)},
]


static func get_badge(badge_id: String) -> Dictionary:
	for b in LIST:
		if b["id"] == badge_id:
			return b
	return {}


## How far along a badge is: [have, goal].
static func progress(b: Dictionary, stats: Dictionary) -> Array:
	if b.get("tracks", false):
		var done: Array = stats.get("tracks", [])
		var have := 0
		for t in Track.TRACKS:
			if done.has(t["id"]):
				have += 1
		return [have, Track.TRACKS.size()]
	return [mini(int(stats.get(b["stat"], 0)), int(b["goal"])), int(b["goal"])]


## Badges the stats have reached that aren't in `have` yet.
static func newly_earned(stats: Dictionary, have: Array) -> Array:
	var out: Array = []
	for b in LIST:
		if have.has(b["id"]):
			continue
		var p := progress(b, stats)
		if int(p[0]) >= int(p[1]):
			out.append(b["id"])
	return out
