# 🏎️ Race Track Mayhem

A toy-car racing game for kids, made with **Godot 4**.

![Racing through the loop-de-loop](docs/screenshot-loop.png)

Pick a toy car, then race four computer cars around **Bedroom Speedway**: a classic
orange plastic track on a kid's bedroom floor, with a loop-de-loop, a ramp jump, banked turns,
a wiggly chicane, a big hill and glowing boost pads. Each race starts with the camera looking at
the whole bedroom, then it swoops down to your car for **3… 2… 1… GO!**

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
- **Race**: intro zoom, countdown, laps, places, timer, speedometer, turbo meter, mini-map, pause menu
- Computer drivers that keep the race close (Easy / Normal / Hard)
- Bumping between cars, where heavy cars push light ones around
- Results screen, with best times saved between plays
- Sound effects made by the game itself, including a toy-motor engine sound

## Code map (for tinkering)

| File | What it does |
|---|---|
| `scripts/track.gd` | Builds the track. **Edit `_layout()` to design new tracks.** It is a list of pieces like `_straight(10)`, `_turn(90, 15, 20)`, `_loop(8.5, 10)` and `_jump()`. The circuit closes itself automatically. |
| `scripts/car_data.gd` | The cars, their colors and stats. Add a new car here. |
| `scripts/toy_car_model.gd` | Builds each car's 3D model from simple shapes. |
| `scripts/racer.gd` | Driving: speed, steering, boosts, jumps, falling off the loop, bumping, and the computer driver. |
| `scripts/race.gd` | Race flow: intro, countdown, camera, places, pause menu, results. |
| `scripts/race_hud.gd` | On-screen display and mini-map. |
| `scripts/bedroom.gd` | The bedroom: floor, rug, bed, teddy, blocks, crayons, beach ball, window. |
| `scripts/main_menu.gd`, `scripts/vehicle_select.gd` | Menu screens. |
| `scripts/game_state.gd`, `scripts/sfx.gd` | Settings and saving, controls, UI theme, sound effects. |

Ideas for next time: more tracks (a kitchen-table track, a bathtub track), unlockable cars,
a split-screen two-player mode, music, and a ghost car of your best lap.
