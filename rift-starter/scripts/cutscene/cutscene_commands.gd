class_name CutsceneCommands
extends RefCounted
## Every command a .cutscene file can use. Add new ones in register_all().
##
## COMMAND                         WHAT IT DOES
## say <speaker> "text"            dialogue line (speaker = actor or any name)
## narrate "text"                  dialogue line with no speaker
## wait <seconds>                  pause
## move <actor> <x> [speed]        walk to x (speed 0.2-1.0, default 0.6)
## face <actor> <left|right|actor> turn around
## jump <actor>                    jump
## teleport <actor> <x> <y>        place instantly
## emote <actor> "text" [seconds]  floating bubble over the head ("!", "?", "...")
## camera <actor> [zoom]           point the camera at a character
## camera <x> <y> [zoom]           ...or at a spot in the level
## camera_reset                    hand the camera back to the game
## letterbox <on|off>              cinematic bars
## fade_out [seconds]              fade to black
## fade_in [seconds]               fade back in
## sight <on|off> [Solar|Lunar]    open/close sight
## set_flag <name>                 remember something (saved)
## clear_flag <name>               forget it
## give_shards <amount>            award Lumen Shards
## give_upgrade <id>               award an upgrade for free
## emit <event>                    tell the level something happened
##                                 (e.g. "emit maw_wake" wakes the boss)
##
## Actors: mafia, fairy, leader (player 1's character), partner.

const ACTORS := ["mafia", "fairy", "leader", "p1", "partner"]
const DEFAULT_SPEAKER_COLOR := Color(1.0, 0.85, 0.55)


static func register_all(d) -> void:
	d.register("say", func(a): await say(d, a[0], a[1]), 2, 2, 'say <speaker> "text"')
	d.register("narrate", func(a): await say(d, "", a[0]), 1, 1, 'narrate "text"')
	d.register("wait", func(a): await d.wait(float(a[0])), 1, 1, "wait <seconds>",
		Callable(), func(a): return _need_numbers(a, [0]))

	d.register("move", func(a): await move(d, a), 2, 3, "move <actor> <x> [speed]",
		func(a): _move_instant(d, a),
		func(a): return _need_actor(a[0]) + _need_numbers(a, range(1, a.size())))
	d.register("face", func(a): face(d, a), 2, 2, "face <actor> <left|right|actor>",
		func(a): face(d, a), func(a): return _need_actor(a[0]))
	d.register("jump", func(a): d.scripted(d.actor(a[0])).queue_jump(), 1, 1, "jump <actor>",
		Callable(), func(a): return _need_actor(a[0]))
	d.register("teleport", func(a): teleport(d, a), 3, 3, "teleport <actor> <x> <y>",
		func(a): teleport(d, a), func(a): return _need_actor(a[0]) + _need_numbers(a, [1, 2]))
	d.register("emote", func(a): emote(d, a), 2, 3, 'emote <actor> "text" [seconds]',
		Callable(), func(a): return _need_actor(a[0]) + _need_numbers(a, range(2, a.size())))

	d.register("camera", func(a): camera(d, a), 1, 3, "camera <actor> [zoom] | camera <x> <y> [zoom]",
		Callable(), func(a): return _validate_camera(a))
	d.register("camera_reset", func(_a): d.camera().clear_focus(), 0, 0, "camera_reset",
		func(_a): d.camera().clear_focus())
	d.register("letterbox", func(a): d.ui.set_letterbox(a[0].to_lower() == "on"), 1, 1, "letterbox <on|off>",
		Callable(), func(a): return _need_choice(a[0], ["on", "off"]))
	d.register("fade_out", func(a): await fade(d, 1.0, a), 0, 1, "fade_out [seconds]",
		Callable(), func(a): return _need_numbers(a, range(a.size())))
	d.register("fade_in", func(a): await fade(d, 0.0, a), 0, 1, "fade_in [seconds]",
		func(_a): d.ui.set_fade(0.0), func(a): return _need_numbers(a, range(a.size())))

	# Commands that change the game: they run the same way when skipping.
	var sight_fn := func(a): sight(a)
	d.register("sight", sight_fn, 1, 2, "sight <on|off> [Solar|Lunar]", sight_fn,
		func(a): return _need_choice(a[0], ["on", "off"]) + (_need_choice(a[1], ["solar", "lunar"]) if a.size() > 1 else ""))
	var set_flag_fn := func(a): GameState.set_flag(StringName(a[0]))
	d.register("set_flag", set_flag_fn, 1, 1, "set_flag <name>", set_flag_fn)
	var clear_flag_fn := func(a): GameState.clear_flag(StringName(a[0]))
	d.register("clear_flag", clear_flag_fn, 1, 1, "clear_flag <name>", clear_flag_fn)
	var shards_fn := func(a): GameState.add_shards(int(a[0]))
	d.register("give_shards", shards_fn, 1, 1, "give_shards <amount>", shards_fn,
		func(a): return _need_numbers(a, [0]))
	var emit_fn := func(a): d.event_emitted.emit(a[0])
	d.register("emit", emit_fn, 1, 1, "emit <event>", emit_fn)
	var upgrade_fn := func(a): Upgrades.grant(StringName(a[0]))
	d.register("give_upgrade", upgrade_fn, 1, 1, "give_upgrade <id>", upgrade_fn,
		func(a): return "" if Upgrades.get_upgrade(StringName(a[0])) else "unknown upgrade '%s'" % a[0])


# ---------------------------------------------------------------- implementations
static func say(d, speaker: String, text: String) -> void:
	var body: Player = d.actor(speaker) if speaker != "" else null
	var shown_name := body.profile.display_name if body else speaker
	var color: Color = body.profile.accent_color.lightened(0.2) if body else DEFAULT_SPEAKER_COLOR
	d.ui.show_line(shown_name, color, text)
	var total: int = d.ui.line_length()
	var shown := 0.0
	# Typewriter: a press finishes the line instantly.
	while shown < total and not d.skipping:
		await d.get_tree().process_frame
		if d.advance_pressed():
			break
		shown += d.chars_per_second * d.get_process_delta_time()
		d.ui.set_visible_chars(int(shown))
	d.ui.set_visible_chars(-1)
	# Then wait for the next press (or the auto-advance timer).
	var t := 0.0
	while not d.skipping:
		await d.get_tree().process_frame
		t += d.get_process_delta_time()
		if d.advance_pressed() or (d.auto_advance >= 0.0 and t >= d.auto_advance):
			break
	d.ui.hide_line()


static func move(d, a: Array) -> void:
	var body: Player = d.actor(a[0])
	var x := float(a[1])
	var speed := clampf(float(a[2]) if a.size() > 2 else 0.6, 0.2, 1.0)
	var input: ScriptedInput = d.scripted(body)
	var limit := absf(x - body.global_position.x) / maxf(body.profile.run_speed * speed, 1.0) * 2.0 + 1.0
	var t := 0.0
	while not d.skipping and t < limit:
		var dx := x - body.global_position.x
		if absf(dx) < 6.0:
			break
		input.move_x = signf(dx)
		input.speed_scale = speed
		await d.get_tree().physics_frame
		t += d.get_physics_process_delta_time()
	input.move_x = 0.0
	input.speed_scale = 1.0
	if d.skipping or absf(x - body.global_position.x) >= 6.0:
		_move_instant(d, a)   # skipped or blocked: just put them there


static func _move_instant(d, a: Array) -> void:
	var body: Player = d.actor(a[0])
	if body:
		body.teleport(Vector2(float(a[1]), body.global_position.y - 30.0))


static func face(d, a: Array) -> void:
	var body: Player = d.actor(a[0])
	match a[1].to_lower():
		"left":
			body.facing = -1
		"right":
			body.facing = 1
		_:
			var other: Player = d.actor(a[1])
			if other:
				body.facing = 1 if other.global_position.x >= body.global_position.x else -1


static func teleport(d, a: Array) -> void:
	d.actor(a[0]).teleport(Vector2(float(a[1]), float(a[2])))


static func emote(d, a: Array) -> void:
	var body: Player = d.actor(a[0])
	var label := Label.new()
	label.text = a[1]
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(-20, -body.body_height() - 70.0)
	body.add_child(label)
	var seconds := float(a[2]) if a.size() > 2 else 1.2
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 18.0, seconds)
	tween.parallel().tween_property(label, "modulate:a", 0.0, seconds).set_delay(seconds * 0.5)
	tween.tween_callback(label.queue_free)


static func camera(d, a: Array) -> void:
	var cam: PartyCamera = d.camera()
	if a[0].is_valid_float():
		var zoom := float(a[2]) if a.size() > 2 else -1.0
		cam.focus_on_point(Vector2(float(a[0]), float(a[1])), zoom)
	else:
		var zoom := float(a[1]) if a.size() > 1 else -1.0
		cam.focus_on_node(d.actor(a[0]), zoom)


static func fade(d, target: float, a: Array) -> void:
	var seconds := float(a[0]) if a.size() > 0 else 0.6
	var start: float = d.ui.get_fade()
	var t := 0.0
	while t < seconds and not d.skipping:
		await d.get_tree().process_frame
		t += d.get_process_delta_time()
		d.ui.set_fade(lerpf(start, target, clampf(t / seconds, 0.0, 1.0)))
	d.ui.set_fade(target)


static func sight(a: Array) -> void:
	if a[0].to_lower() == "off":
		Sight.set_active(false)
		return
	if a.size() > 1:
		Sight.set_eye(Sight.SOLAR if a[1].to_lower() == "solar" else Sight.LUNAR)
	Sight.set_active(true)


# ---------------------------------------------------------------- validation helpers
static func _need_actor(word: String) -> String:
	return "" if ACTORS.has(word.to_lower()) else "unknown actor '%s' (use %s)" % [word, ", ".join(ACTORS)]


static func _need_numbers(a: Array, indices) -> String:
	for i in indices:
		if i < a.size() and not String(a[i]).is_valid_float():
			return "'%s' should be a number" % a[i]
	return ""


static func _need_choice(word: String, choices: Array) -> String:
	return "" if choices.has(word.to_lower()) else "'%s' should be one of: %s" % [word, ", ".join(choices)]


static func _validate_camera(a: Array) -> String:
	if a[0].is_valid_float():
		if a.size() < 2:
			return "camera <x> <y> needs both coordinates"
		return _need_numbers(a, range(a.size()))
	return _need_actor(a[0]) + _need_numbers(a, range(1, a.size()))
