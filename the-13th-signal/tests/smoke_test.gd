extends Node
## Plays through Sector 1 automatically and checks the important parts work.
## Run:  godot --headless --path . res://tests/smoke_test.tscn
## Exits with code 0 if everything passed, 1 if anything failed.

var failures := 0
var s: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	# --- Parent Lock ---
	Game.lock_scary_modes()
	check(Game.mode == Game.Mode.EXPLORER, "the game starts in Explorer")
	check(not Game.mode_allowed(Game.Mode.SURVIVOR), "Survivor is locked without the Parent PIN")
	check(not Game.mode_allowed(Game.Mode.NIGHTMARE), "Nightmare is locked without the Parent PIN")

	# --- Explorer playthrough ---
	s = load("res://scenes/sector.tscn").instantiate()
	add_child(s)
	await wait(1.0)
	check(s.exit_code.length() == 4, "an exit code was made")
	s.player.global_position = s.cell_to_world(Vector2i(4, 7))
	await wait(0.5)
	check(s.listener.is_physics_processing(), "the Listener wakes up in the main hall")
	var levers: Array = []
	for c in s.get_children():
		if c.get("prompt_text") != null and String(c.prompt_text).begins_with("Flip"):
			levers.append(c)
	check(levers.size() == 3, "there are 3 breakers")
	s._flip_breaker("MIDDLE", levers[1])
	await wait(0.6)
	check(s.breaker_seq.is_empty() and not s.power_on, "the wrong breaker order trips and resets")
	s.listener.reset_to(s.cell_to_world(Vector2i(1, 7)))
	for side in ["RIGHT", "MIDDLE", "LEFT"]:
		s._flip_breaker(side, levers[0])
	check(s.power_on, "the right breaker order turns the power on")
	check(s.replacement.active, "the Replacement wakes up when the power comes on")
	s.listener.reset_to(s.player.global_position + Vector3(0.5, 0, 0))
	await wait(0.3)
	check(s.catching and s.catches == 1, "the Listener catches you when it reaches you")
	await wait(4.0)
	check(not s.catching and not s.player.frozen, "you respawn at the checkpoint")
	s._on_code("0000" if s.exit_code != "0000" else "1111")
	check(not s.exit_open, "a wrong code keeps the elevator shut")
	s._on_code(s.exit_code)
	check(s.exit_open, "the right code opens the elevator")
	s.player.global_position = s.cell_to_world(Vector2i(25, 16))
	await wait(1.0)
	check(s.ended, "stepping into the elevator finishes the sector")
	check(not Game.learned_lockers, "in Explorer the Listener never learns to check lockers")
	s.queue_free()
	await wait(0.3)

	# --- Survivor: the Listener learns ---
	Game.scary_unlocked = true
	Game.mode = Game.Mode.SURVIVOR
	s = load("res://scenes/sector.tscn").instantiate()
	add_child(s)
	await wait(1.0)
	s.listener.set_physics_process(true)
	for i in 3:
		s._hid_recently = 0.0
		s.on_player_hid(s.lockers[0])
	check(Game.learned_lockers, "in Survivor, hiding 3 times teaches it to check lockers")
	var lk: Node = s.lockers[3]
	s.player.enter_locker(lk)
	s.listener.reset_to(lk.front_pos() + Vector3(4, 0, 0))
	s.listener.state = s.listener.State.LISTEN
	s.listener._wait = 0.01
	Input.action_press("hold_breath")
	await wait(4.5)
	Input.action_release("hold_breath")
	check(s.catches == 0, "holding your breath in a checked locker keeps you safe")
	s.player.leave_locker()
	s.player.enter_locker(lk)
	s.listener.reset_to(lk.front_pos() + Vector3(4, 0, 0))
	s.listener.state = s.listener.State.LISTEN
	s.listener._wait = 0.01
	await wait(4.5)
	check(s.catches == 1, "breathing in a checked locker gets you caught")
	await wait(4.0)
	Game.sprint_cells = {Vector2i(2, 7): 5.0, Vector2i(12, 7): 4.0, Vector2i(24, 7): 3.0, Vector2i(15, 16): 2.0}
	s.player.global_position = s.cell_to_world(Vector2i(3, 2))
	Game.sprint_time = 100.0
	s.note_sprint(s.player.global_position, 0.1)
	check(Game.learned_traps and s.traps.size() == 3, "running a lot makes it set 3 tripwires")

	Game.lock_scary_modes()
	print("\n%s (%d failed)" % ["ALL PASSED" if failures == 0 else "SOME TESTS FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)
