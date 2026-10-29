extends Node
## The cutscene director (autoload `Cutscenes`).
##
##   await Cutscenes.play_file("res://cutscenes/intro.cutscene")
##
## While a cutscene runs:
##   * both characters are driven by ScriptedInput (players can't move them),
##   * the camera can be pointed anywhere, dialogue shows in a letterboxed box,
##   * Esc skips. Skipping is SAFE: every command that changes the game
##     (flags, shards, upgrades, sight, positions) still applies instantly;
##     only waits, dialogue and animation are dropped.
##
## Commands are registered in CutsceneCommands. To add one:
##   Cutscenes.register("shake", func(args): ..., 0, 1, "shake [seconds]")
## and it can be used in any .cutscene file — the parser checks names and
## argument counts and reports mistakes with file:line.

signal started(cutscene_name: String)
signal finished(cutscene_name: String, skipped: bool)
## Raised by the `emit <event>` command. Level objects (bosses, gates, doors)
## listen for their own event names - cutscenes never need to know about them.
signal event_emitted(event_name: String)

## Turn off to suppress all cutscenes (automated tests, level-design runs).
var enabled := true
## >= 0: dialogue advances by itself after this many seconds (tests, demos).
var auto_advance := -1.0
var chars_per_second := 45.0

var is_playing := false
var skipping := false
var current_name := ""
var ui: CutsceneUI

var _commands := {}
var _scripted := {}   ## Player -> ScriptedInput


func _ready() -> void:
	ui = CutsceneUI.new()
	ui.name = "CutsceneUI"
	add_child(ui)
	CutsceneCommands.register_all(self)


func _process(_delta: float) -> void:
	if is_playing and not skipping and Input.is_action_just_pressed("cutscene_skip"):
		skip()


# ---------------------------------------------------------------- registry
## Register a command.
##   run:      func(args: Array) - may `await`; does the full, animated version
##   skip:     func(args: Array) - instant version used while skipping; leave
##             empty for purely presentational commands (dialogue, waits)
##   validate: func(args: Array) -> String - "" if OK, else an error message
func register(command: String, run: Callable, min_args := 0, max_args := 0, usage := "",
		skip_fn := Callable(), validate := Callable()) -> void:
	_commands[command] = {"run": run, "skip": skip_fn, "min_args": min_args,
		"max_args": max_args, "usage": usage if usage != "" else command, "validate": validate}


func registry() -> Dictionary:
	return _commands


func load_script(path: String) -> CutsceneScript:
	return CutsceneScript.load_file(path, _commands)


func parse(text: String, script_name := "<inline>") -> CutsceneScript:
	return CutsceneScript.parse(text, script_name, _commands)


# ---------------------------------------------------------------- playback
func play_file(path: String) -> bool:
	return await play(load_script(path))


## Runs a parsed script. Returns false if it couldn't start.
func play(script: CutsceneScript) -> bool:
	if not enabled or is_playing:
		return false
	if not script.is_valid():
		for e in script.errors:
			push_error(e)
		return false
	is_playing = true
	skipping = false
	current_name = script.source_name
	_take_control()
	started.emit(current_name)

	var pc := 0
	var cmds := script.commands
	while pc < cmds.size():
		var c: Dictionary = cmds[pc]
		match c.cmd:
			"if":
				if not evaluate(c.cond):
					pc = (c.else_index + 1) if c.else_index >= 0 else (c.end_index + 1)
					continue
			"else":
				pc = c.end_index + 1   # end of the true branch: jump past `end`
				continue
			"end":
				pass
			_:
				var spec: Dictionary = _commands[c.cmd]
				if skipping:
					if spec.skip.is_valid():
						spec.skip.call(c.args)
				else:
					await spec.run.call(c.args)
		pc += 1

	var was_skipped := skipping
	_release_control()
	finished.emit(current_name, was_skipped)
	return true


func skip() -> void:
	if is_playing:
		skipping = true
		ui.hide_line()


## Conditions used by `if`.
func evaluate(cond: Dictionary) -> bool:
	var result := false
	match cond.kind:
		"flag":
			result = GameState.has_flag(StringName(cond.name))
		"upgrade":
			result = Upgrades.is_owned(StringName(cond.name))
		"eye":
			result = Sight.active and String(Sight.eye).to_lower() == String(cond.name).to_lower()
		"sight":
			result = Sight.active
	return result != cond.negate


# ---------------------------------------------------------------- helpers for commands
## Wait that ends early when the cutscene is skipped.
func wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not skipping:
		await get_tree().process_frame
		t += get_process_delta_time()


func advance_pressed() -> bool:
	return Input.is_action_just_pressed("cutscene_advance")


func party() -> Party:
	return get_tree().get_first_node_in_group("party") as Party


func camera() -> PartyCamera:
	return get_tree().get_first_node_in_group("party_camera") as PartyCamera


## Finds a character by profile id or display name ("mafia", "Fairy"),
## or by role: "leader" / "p1" (player 1's character) and "partner".
func actor(actor_name: String) -> Player:
	var key := actor_name.to_lower()
	var p := party()
	if p:
		if key in ["leader", "p1"]:
			return p.leader
		if key == "partner":
			return p.partner
	for member in get_tree().get_nodes_in_group("player"):
		var body := member as Player
		if String(body.base_profile.id).to_lower() == key or body.profile.display_name.to_lower() == key:
			return body
	return null


func scripted(body: Player) -> ScriptedInput:
	if not _scripted.has(body):
		_scripted[body] = ScriptedInput.new()
		body.set_input(_scripted[body])
	return _scripted[body]


func _take_control() -> void:
	for member in get_tree().get_nodes_in_group("player"):
		var body := member as Player
		body.end_carry()
		if body.grabbed_by:
			body.grabbed_by.release(false)
	_scripted.clear()
	for member in get_tree().get_nodes_in_group("player"):
		scripted(member)
	ui.set_letterbox(true)


func _release_control() -> void:
	is_playing = false
	skipping = false
	_scripted.clear()
	ui.hide_line()
	ui.set_letterbox(false)
	ui.set_fade(0.0)
	var cam := camera()
	if cam:
		cam.clear_focus()
	var p := party()
	if p:
		p.reassign()
