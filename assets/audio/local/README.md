# Your own sounds (kept private)

Put sound files here to **replace** the built-in ones on your computer only.
This folder is ignored by git, so sounds with licenses that don't allow sharing
(like Pixabay's) never get uploaded to GitHub.

- `local/sfx/<name>.ogg` (or `.wav`/`.mp3`) replaces a sound effect. For random
  variations, number the files: `<name>_1.ogg`, `<name>_2.ogg`.
- `local/music/<name>.ogg` replaces a music track.

When a name exists here, the game uses your version instead of the built-in one.

| Sound name | When it plays | What to search for on Pixabay |
|---|---|---|
| `engine` | Your car's engine, loops and changes pitch with speed | "engine loop", "rc car loop" |
| `engine_high` | Extra engine layer at high speed (loop) | "race car engine high rpm loop" |
| `rev` | Pressing go from a standstill | "car rev", "engine rev" |
| `whoosh` | A car zooming past you | "car pass by", "whoosh fast" |
| `brake` | Braking hard (loops while braking) | "car brakes", "tire screech" |
| `skid` | Scraping a wall | "tire skid" |
| `bump` | Bumping another car | "plastic hit", "toy car crash" |
| `crash` | Falling off the track | "toy crash", "cartoon crash" |
| `boost` | Boost pads and turbo | "turbo boost", "power up whoosh" |
| `jump` / `land` | Ramp jumps | "jump cartoon" / "landing thud" |
| `beep` / `go` | Countdown tones | "race start beep" |
| `voice_ready` / `voice_set` / `voice_go` | Countdown voice | "ready set go" |
| `lap` / `final_lap` / `win` / `finish` | Race jingles | "game jingle win", "level complete" |
| `click` / `select` / `back` | Menu buttons | "soft ui click", "pop" |

| Music name | Where it plays |
|---|---|
| `menu` | Main menu (the theme song) |
| `garage` | Car picker and track picker (if missing, the menu song keeps playing) |
| `race` (or `race_1`, `race_2`...) | During races (one is picked at random) |
| `results` | Results screen |

After adding files, open the project in Godot once so it imports them.
