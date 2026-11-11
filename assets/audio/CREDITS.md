# Audio credits

The sound effects are **CC0 (public domain)**, so you can use, change and share them freely,
and no attribution is required. We credit the creators anyway because they deserve it.

The **music is not CC0**: it's our own Mesa Mayhem soundtrack (see below). Please don't reuse it
outside this game.

| Files | Creator | Source | License |
|---|---|---|---|
| `sfx/engine.ogg`, `sfx/engine_high.ogg`, `sfx/bump_1.ogg` | Kenney | [Starter Kit Racing](https://github.com/KenneyNL/Starter-Kit-Racing) | CC0 |
| `sfx/skid.ogg`, `sfx/brake.ogg` | Landeplage | [Starter Kit Racing](https://github.com/KenneyNL/Starter-Kit-Racing) | CC0 |
| `sfx/jump.ogg`, `sfx/land.ogg` | Kenney | [Starter Kit 3D Platformer](https://github.com/KenneyNL/Starter-Kit-3D-Platformer) | CC0 |
| `sfx/bump_2-3.ogg`, `sfx/crash_*.ogg` | Kenney | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | CC0 |
| `sfx/boost_*.ogg` | Kenney | [Digital Audio](https://kenney.nl/assets/digital-audio) | CC0 |
| `sfx/voice_*.ogg` | Kenney | [Voiceover Pack](https://kenney.nl/assets/voiceover-pack) | CC0 |
| `sfx/lap.ogg`, `sfx/final_lap.ogg`, `sfx/win.ogg`, `sfx/finish.ogg` | Kenney | [Music Jingles](https://kenney.nl/assets/music-jingles) | CC0 |
| `sfx/click.wav`, `sfx/select.wav`, `sfx/back.wav` | Kenney | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | CC0 |

## Music: the Mesa Mayhem soundtrack

Made by Andrew Saulls with Suno. All rights reserved; included here for Race Track Mayhem only.

| File | Song | Where it plays |
|---|---|---|
| `music/menu.ogg` | Game Menu (Mesa Mayhem) | Main menu, car picker, track picker and Track Builder |
| `music/race_bedroom.ogg` | Pebblemoon | Bedroom Speedway (and Track Builder tracks in the bedroom) |
| `music/race_playroom.ogg` | The Lab | Toy Box Twister (and builder tracks in the playroom) |
| `music/race_kitchen.ogg` | Copper Pit | Kitchen Kerfuffle (and builder tracks in the kitchen) |
| `music/race_bathroom.ogg` | Pebblemoon (second take) | Bubble Bath Bash (and builder tracks in the bathroom) |
| `music/race_living_room.ogg` | Server Room | Sofa Slalom (and builder tracks in the living room) |
| `music/race_garden.ogg` | Sonoran Mesa | Backyard Blast (and builder tracks in the garden) |
| `music/race_garage.ogg` | Server Room (second take) | Workshop Wheelie (and builder tracks in the garage) |
| `music/race_snowyard.ogg` | Sonoran Mesa (second take) | Frosty Backyard, the holiday track |
| `music/race_spooky.ogg` | Copper Pit (second take) | Pumpkin Patch Panic, the Halloween track |
| `music/race_beach.ogg` | The Lab (second take) | Sandy Shores Splash, the summer beach track |
| `music/race_attic.ogg` | Game Menu (first take) | Attic Antics (and builder tracks in the attic) |
| `music/results.ogg` | Triumphant Fanfare | Results and podium (plays once, then the menu song returns) |

The songs were converted from MP3 to Ogg Vorbis and their loudness was evened out (-16 LUFS).

## Swapping sounds

Drop a file named after the sound into `sfx/` (`.ogg`, `.wav` or `.mp3`), for example `boost.ogg`.
For random variations, number them: `boost_1.ogg`, `boost_2.ogg` and so on. Music files go in
`music/`. Each room has its own race song, `race_<room>` (bedroom, playroom, kitchen, bathroom,
living_room, garden). Without one, the game uses `race` (or `race_1`, `race_2`... picked at random).
If there's no `garage` song, the pickers keep the menu song playing.
If a file is missing, the game falls back to its own synthesized beeps.

The countdown beeps, whoosh and rev sounds are made by the game itself (in `scripts/sfx.gd`).
To use your own sounds without uploading them, put them in `local/` (see `local/README.md`).

Sound names: engine, engine_high, rev, whoosh, brake, skid, bump, crash, boost, jump, land, beep, go,
voice_ready, voice_set, voice_go, voice_win, lap, final_lap, win, finish, click, select, back.

## Other good free sources (checked November 2026)

- **Kenney.nl:** CC0, no account needed. The best all-round source for game sounds.
- **OpenGameArt.org:** license varies per file. Filter for CC0 or CC-BY (CC-BY needs a credit line).
- **freesound.org:** license varies per sound; needs a free account. Avoid "NonCommercial" sounds.
- **Incompetech (Kevin MacLeod):** great music, CC-BY 4.0, so it needs a credit line.
- Avoid putting raw files from Pixabay, Mixkit, Zapsplat or Sonniss bundles in a public repo.
  Their licenses allow using them in a game but not sharing the raw files.
