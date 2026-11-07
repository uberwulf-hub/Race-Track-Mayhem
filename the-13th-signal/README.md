# THE 13TH SIGNAL

*You were never supposed to hear it.*

A first-person horror escape game made with **Godot 4.3**. It plays like DOORS meets an escape room, with Doom Eternal intensity.
You win with your ears and your brain, not a gun. Scares come from **sound, darkness, timing and surprise**.
There is no blood, no gore and no graphic deaths. When a monster gets you, the screen fills with TV static and
you go back to the last checkpoint.

This first playable version is **Sector 1: Intake**. You wake up alone in an underground research facility.
The facility AI, MERIDIAN, talks to you over the intercom. Sometimes it tells the truth. Sometimes it's not
MERIDIAN at all.

## Parent guide (the safeguard)

| Mode | What it's like |
|---|---|
| **Explorer** | **No jump scares.** Slower, gentler monsters. The Listener never learns to check lockers, and the mannequin creeps closer but never catches you. When a voice lies, the game hints that it's lying. Quiet ambient sounds. |
| **Survivor** | Jump scares (a short sting sound and a quick glimpse of the mannequin), suspense and hiding. The monsters learn your habits. |
| **Nightmare** | More frequent, unpredictable scares, darker halls, faster learning. Mistakes like a wrong elevator code set off an alarm the monster can hear. |

- **The game starts in Explorer every time it's opened.** It never remembers a scary mode.
- **Survivor and Nightmare need the Parent PIN**, once each time the game is opened.
- **Set the PIN first:** Main menu → **PARENT SETTINGS** → choose 4 digits, then type them again.
  Until a PIN exists, the scary modes stay locked.
- In Parent Settings you can also **LOCK SCARY MODES NOW**, change the PIN, or remove it (which keeps the scary modes locked).
- Only a salted hash of the PIN is saved, never the digits themselves.
- **Forgot the PIN?** Delete the settings file and make a new one:
  `%APPDATA%\Godot\app_userdata\The 13th Signal\the_13th_signal.cfg` on Windows.

## How to play

**Goal:** get out of Sector 1 through the service elevator.

| Control | Keyboard / mouse | Controller |
|---|---|---|
| Move / look | WASD / mouse | Left stick / right stick |
| Run (loud!) | Shift | Left trigger or click the left stick |
| Crouch (quiet) | Ctrl or C (hold) | B (hold) |
| Use / open / hide | E | A |
| Flashlight | F | Y |
| Hold your breath (in a locker) | Space (hold) | X (hold) |
| Journal (clues) | Tab or J (hold) | Back/View |
| Pause | Esc | Start |

**The monsters**

- **THE LISTENER** is blind and hears everything. Listen for its clicking: the faster it clicks, the closer it is to finding you.
  The **NOISE** bar shows how far your sound carries. Walking is quiet, running is loud, the orange metal
  grates are LOUD, and crouching is almost silent. Doors make noise when you open them.
  **It learns.** If you hide in lockers a lot, it starts checking them, so hold your breath when it stops at yours.
  If you run a lot, it strings tripwires across the halls you run through. Crouch to step over them.
- **THE REPLACEMENT** is a scientist mannequin that only moves when you can't see it. It wakes up when the power comes back on.
  Keep your light on it.
- **ECHO** copies MERIDIAN's voice and gives you bad advice. Check what it says against the notes you find.

**Puzzles** (the colour code is different every game):
1. Find the maintenance note. It tells you the breaker order.
2. Find the security keycard and open SECURITY, the orange door off the main hall.
3. Flip the three breakers in the right order. In the wrong order they trip with a loud alarm.
4. The elevator door shows a colour order. Find the four painted numbers (red, blue, green, yellow) around the sector.
   Look at them with your light and they go in your journal.
5. Type the code at the elevator and step in.

**Secrets:** 3 signal fragments are hidden in Sector 1. One is behind a low vent you have to crouch through.

## Run it from the source code

1. Install **Godot 4.3** (standard version) from <https://godotengine.org/download>.
2. Open Godot, click **Import**, choose this folder's `project.godot`, then press **F5** to play.

Everything is built in code (`scripts/`). The map is a text drawing at the top of `scripts/sector.gd`,
so you can redesign Sector 1 by editing the characters. The legend is right above it.
All sounds are synthesized in `scripts/sound.gd`, so there are no audio files to license.

**Automated test:** this plays through the sector and checks the Parent Lock, the puzzles, getting caught,
the checkpoints, and the monster's learning:
```
godot --headless --path . res://tests/smoke_test.tscn
```

## Publishing to SauceStore

This works the same way as Race Track Mayhem: `saucestore.json` is the store listing, and
`.github/workflows/release.yml` builds `The13thSignal-windows.zip` and publishes a GitHub release
when you push a version tag (`git tag v0.1.0 && git push origin v0.1.0`).

### Moving to its own repository

GitHub only runs workflows from a repository's top-level `.github` folder, so the release workflow starts
working once this folder becomes its own repository:

1. On GitHub, create a new empty repository, for example `uberwulf-hub/The-13th-Signal`.
2. Copy the contents of this `the-13th-signal/` folder (including the hidden `.github` and `.gitignore`) into it, then commit and push.
3. Push a tag such as `v0.1.0`, or run **Actions → Release → Run workflow**, to make the first release.

## Where it goes next

- **Sectors 2 to 12**, each with its own puzzle style and a new trick for the monsters.
- **ECHO as a full monster.** It copies other characters' voices, and even repeats your own choices back at you.
- **SUBJECT 13**, the final boss. You only see the whole thing at the end, and you beat it with puzzle mechanics, not firepower.
- **13 signal fragments** across the game that unlock the true ending.
- Voice acting for MERIDIAN and ECHO, real recorded sound effects, more rooms and props.
