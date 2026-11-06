# 🏎️ Race Track Mayhem

A toy-car racing game for kids, made with **Godot 4**.

![Racing through the loop-de-loop](docs/screenshot-loop.png)

Pick a toy car and a track, then race four computer cars around an orange plastic toy track on a
kid's bedroom floor. Each race starts with the camera looking at the whole bedroom, then it swoops
down to your car for **3… 2… 1… GO!**

**5 tracks, each in its own room**

| Track | Room | Trickiness | Highlights |
|---|---|---|---|
| Bedroom Speedway | Bedroom: bed, teddy bear, rainbow rug | ★☆☆ | loop-de-loop, ramp jump, hill, chicane |
| Toy Box Twister | Playroom: foam mat, rainbow, ball pit, toy chest | ★★☆ | figure-8 bridge over itself, corkscrew, loop |
| Kitchen Kerfuffle | Kitchen: checker tiles, fridge, table, giant fruit | ★★☆ | spiral climb, big drop, double jump, S-bends |
| Bubble Bath Bash | Bathroom: bubbly tub, GIANT rubber duck | ★★☆ | double loop, wavy bumps, zig-zags, jump |
| Sofa Slalom | Living room at sunset: sofa, TV, sleeping cat | ★★★ | slalom, spiral, corkscrew, loop, jump |

![The five rooms](docs/screenshot-rooms.png)


## How to play it on your computer

1. Install **Godot 4.3 or newer** (the standard version, not .NET) from <https://godotengine.org/download>.
2. Get the code:
   ```
   git clone https://github.com/uberwulf-hub/Race-Track-Mayhem.git
   ```
3. Open Godot, click **Import**, choose the `project.godot` file in that folder, then press **F5** (▶ Play).

There are no art or sound files. The cars, track, bedroom and sound effects are all built in code.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Go | W / ↑ | A or right trigger |
| Steer | A D / ← → | Left stick / D-pad |
| Brake / reverse | S / ↓ | X or left trigger |
| **Turbo** (blue bar) | Space / Shift | B or right bumper |
| Back on track | R | Y |
| Change camera | C | Left bumper |
| Pause | Esc / P | Start |

Tips: drive over the glowing striped pads for a **BOOST**. Keep your speed up in the loop.
If you go too slowly upside down, you fall off. **MAYHEM!**

## What's in the game

- **Main menu** with a live race in the background, plus Options (laps, difficulty, volume) and How to Play
- **Garage**: five toy cars on a spinning turntable, each with Top Speed / Acceleration / Handling / Weight stats
  - Red Rocket · Blue Bolt · Monster Max · Sunny Buggy · Bubblegum Van
- **Track select**: mini-map of each track (brighter = higher), features, best time, lap count
- **Race**: intro zoom, start lights with a "3, 2, 1, GO!" voice countdown, laps, places, timer,
  speedometer, turbo meter, mini-map, pause menu, camera shake, speed lines, sparks on the walls
- Computer drivers that keep the race close (Easy / Normal / Hard)
- Bumping between cars, where heavy cars push light ones around
- Results screen, with best times saved between plays
- Real sound effects and chiptune music (all CC0, see [assets/audio/CREDITS.md](assets/audio/CREDITS.md)),
  with separate Music and Sound volume sliders. If an audio file is missing, the game falls back to its own beeps.

## Code map (for tinkering)

| File | What it does |
|---|---|
| `scripts/track.gd` | Builds the tracks. **Each track is a `_layout_...()` function**, a list of pieces like `_straight(10)`, `_turn(90, 15, 20)`, `_loop(8.5, 10)`, `_corkscrew(62, 5.5)`, `_helix(360, 13, 7.5)`, `_slalom(5, 34, 13)`, `_waves(3)`, `_bridge()` and `_jump()`. The circuit closes itself automatically. Add an entry to `TRACKS` (with its `room`) and a layout function to make a new track. |
| `scripts/mesh_kit.gd` | Rounded "toy" box meshes and soft blob shadows. |
| `scripts/track_select.gd` | Track-picking screen. |
| `scripts/car_data.gd` | The cars, their colors and stats. Add a new car here. |
| `scripts/toy_car_model.gd` | Builds each car's 3D model from simple shapes. |
| `scripts/racer.gd` | Driving: speed, steering, boosts, jumps, falling off the loop, bumping, and the computer driver. |
| `scripts/race.gd` | Race flow: intro, countdown, camera, places, pause menu, results. |
| `scripts/race_hud.gd` | On-screen display and mini-map. |
| `scripts/rooms/room.gd` | Base class for the rooms: lighting, floor, walls, window, door and shape helpers. |
| `scripts/rooms/*_room.gd` | One file per room theme (bedroom, playroom, kitchen, bathroom, living room). Each one sets its colours and builds its furniture. |
| `scripts/main_menu.gd`, `scripts/vehicle_select.gd` | Menu screens. |
| `scripts/game_state.gd`, `scripts/sfx.gd` | Settings and saving, controls, UI theme, sound effects and music. |

Ideas for next time: an outdoor garden track, unlockable cars,
a split-screen two-player mode, and a ghost car of your best lap.
