class_name Story
extends RefCounted
## Story Mode: race through the house room by room. Each room has a boss
## car that thinks it's the champion of that room. Finish ahead of the boss
## to beat them and open the next room. Chapter i races on Track.TRACKS[i].

## car: index into CarData.CARS. look: Car Designer look for the boss's car.
const CHAPTERS: Array[Dictionary] = [
	{"boss": "Teddy Thunder", "car": 2, "title": "Bedtime Showdown",
		"look": {"color": "8b5a2b", "accent": "ffd21f", "sticker": "sticker_stars", "nickname": "Teddy Truck"},
		"hello": "Nobody races in MY bedroom without beating me first!",
		"won": "Grrr... fine! You're faster than a sleepy bear.",
		"lost": "Ha! Back to bed with you!"},
	{"boss": "Block Boss Bella", "car": 4, "title": "Toy Box Trouble",
		"look": {"color": "2f6fe8", "accent": "ffd21f", "sticker": "sticker_checkers", "nickname": "Block Bus"},
		"hello": "I built this whole playroom. Block by block!",
		"won": "You knocked my tower down! Well raced!",
		"lost": "Stack 'em up and knock 'em down!"},
	{"boss": "Captain Crumbs", "car": 3, "title": "Kitchen Chaos",
		"look": {"color": "ff7a1a", "accent": "8b5a2b", "sticker": "sticker_flames", "nickname": "Cookie Cruiser"},
		"hello": "This kitchen is MY cookie jar. Try and catch me!",
		"won": "You ate my crumbs! I mean... you beat me.",
		"lost": "Too slow! More cookies for me!"},
	{"boss": "Bubbles McSplash", "car": 7, "title": "Bath Time Blast",
		"look": {"color": "1fc8d8", "accent": "ffffff", "sticker": "sticker_stars", "nickname": "Soap Speeder"},
		"hello": "Splish splash, I'm going to make you crash!",
		"won": "Blub blub... you washed me right out!",
		"lost": "Splashed ya! Better dry off and try again."},
	{"boss": "Couch King Carl", "car": 1, "title": "Sofa Kingdom",
		"look": {"color": "7a3fe0", "accent": "ffd21f", "sticker": "sticker_lightning", "nickname": "Royal Remote"},
		"hello": "Bow down! I am the king of the comfy cushions!",
		"won": "My crown! You've taken the couch throne!",
		"lost": "The king stays on the couch! Ha ha!"},
	{"boss": "Gnome Gus", "car": 3, "title": "Garden Getaway",
		"look": {"color": "1fae4b", "accent": "e8241c", "sticker": "sticker_stripes", "nickname": "Mushroom Zoomer"},
		"hello": "Hmph. Nobody gets past the garden gnome.",
		"won": "Well I never! You zoomed right past me.",
		"lost": "Back to the flower beds, little racer!"},
	{"boss": "Big Wrench Wendy", "car": 6, "title": "The Final Workshop",
		"look": {"color": "1e1e26", "accent": "ff7a1a", "sticker": "sticker_flames", "nickname": "Wrench Wagon"},
		"hello": "I fixed up every car in this house. I'm the fastest of all!",
		"won": "Whoa! You're the champion of the WHOLE house!",
		"lost": "Need a tune-up? Come back and try again!"},
]

const BONUS_STARS := 5


static func count() -> int:
	return mini(CHAPTERS.size(), Track.TRACKS.size())


static func chapter(i: int) -> Dictionary:
	return CHAPTERS[clampi(i, 0, CHAPTERS.size() - 1)]


static func room_name(i: int) -> String:
	var room := String(Track.TRACKS[clampi(i, 0, Track.TRACKS.size() - 1)]["room"])
	for r in Game.ROOM_THEMES:
		if r[0] == room:
			return String(r[1])
	return room
