class_name MawBoss
extends Area2D
## THE MAW — a giant portal boss.
##
## Its core switches between sun and moon. While the core glows gold (SOLAR)
## it can only be hurt by someone looking with a Solar eye (the Mafia's);
## while it glows silver-blue (LUNAR), only a Lunar eye (the Fairy's) reveals
## it. The Mafia does the shooting either way, so the pair must work together:
## swap characters, or let the AI partner shoot while you hold the right eye open.
##
## PHASE 1 (100-67%)  core SOLAR. Four IK tendrils reach for the party; rift orbs.
## PHASE 2 (67-33%)   core LUNAR, but shielded until two small portals it spits
##                    out are sealed. It drifts and fires telegraphed rift beams.
## PHASE 3 (33-0%)    core flips between SOLAR and LUNAR every few seconds;
##                    beams + orb spreads, and it inhales, pulling everyone in.
##
## Touching it, a beam or an orb sends you back like any portal does.
## Wake it with the cutscene command `emit maw_wake` (see boss_intro.cutscene).
## Beating it sets `defeated_flag` (saved) and plays `defeated_cutscene`.

signal fight_started
signal phase_changed(phase: int)
signal health_changed(hp: int, max_hp: int)
signal core_changed(eye: StringName, shielded: bool)
signal defeated

enum State { SLEEPING, EMERGING, FIGHT, DYING, DEAD }

@export var display_name := "The Maw"
@export var max_hp := 30
@export var radius := 120.0
@export_group("Arena")
@export var arena_left := 4800.0
@export var arena_right := 6060.0
@export var floor_y := -250.0
## How high above the floor it hovers.
@export var hover_height := 320.0
@export_group("Story")
@export var wake_event := "maw_wake"
@export var intro_flag: StringName = &"cutscene:boss_intro"
@export var defeated_flag: StringName = &"maw_defeated"
@export_file("*.cutscene") var defeated_cutscene := "res://cutscenes/boss_defeated.cutscene"
@export_group("Attacks")
@export var tendril_angles := PackedFloat32Array([55.0, 80.0, 100.0, 125.0])
@export var beam_telegraph := 1.1
@export var beam_duration := 0.5
@export var beam_half_width := 32.0
@export var orb_speed := 150.0
@export var suction_speed := 110.0
@export var adds_count := 2
@export var core_swap_time := 6.0

## Tendrils and auto-aim treat the Maw's body as visible to ANY open eye;
## what matters for damage is `core_eye`.
var for_eye: StringName = &""
var core_eye: StringName = Sight.SOLAR
var hp := 0
var phase := 0
var state: State = State.SLEEPING
var shielded := false

var _time := 0.0
var _invulnerable := 0.0
var _flash := 0.0
var _deflect := 0.0
var _emerge := 0.0
var _timers := {}
var _cooldowns := {}
var _beams: Array[Dictionary] = []   ## {x, t}
var _adds: Array[Node] = []
var _orbs: Array[Node] = []
var _tendrils: Array[PortalTendril] = []
var _swap_t := 0.0
var _suction_t := 0.0
var _drift_dir := 1.0
var _bar: BossBar
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("portals")
	add_to_group("boss")
	collision_layer = 4  # "portals": shots hit it
	collision_mask = 2   # "player": touching it hurts
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.85
	_shape.shape = circle
	add_child(_shape)
	body_entered.connect(_on_body_entered)
	Cutscenes.event_emitted.connect(_on_event)
	hp = max_hp
	_bar = BossBar.new()
	_bar.boss = self
	add_child(_bar)
	if GameState.has_flag(defeated_flag):
		_become_dead()
	else:
		monitoring = false
		visible = false


# ---------------------------------------------------------------- public
func is_sealing() -> bool:
	return state == State.DYING or state == State.DEAD


## Can a shot hurt it right now? (Also tells the AI when to fire.)
func is_targetable() -> bool:
	return state == State.FIGHT and not shielded and Sight.can_see(core_eye)


func wake() -> void:
	if state != State.SLEEPING:
		return
	state = State.EMERGING
	visible = true
	_emerge = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_emerge", 1.0, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_start_fight)


func on_shot(power := 1) -> void:
	if state != State.FIGHT:
		return
	if shielded or not Sight.can_see(core_eye):
		_deflect = 0.25   # sparks: the core is closed to this eye
		return
	hp = maxi(hp - power, 0)
	_flash = 0.12
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()
	elif phase == 1 and hp <= max_hp * 2 / 3:
		_enter_phase(2)
	elif phase == 2 and hp <= max_hp / 3:
		_enter_phase(3)


func hint() -> String:
	if state != State.FIGHT:
		return ""
	if not _adds.is_empty():
		return "Shielded! Seal the small portals first (open any eye, then shoot)."
	if _invulnerable > 0.0:
		return "..."
	if core_eye == Sight.SOLAR:
		return "Core: SOLAR - hold the Mafia's Solar eye open and shoot."
	return "Core: LUNAR - hold the Fairy's Lunar eye open; the Mafia shoots."


# ---------------------------------------------------------------- fight flow
func _on_event(event_name: String) -> void:
	if event_name == wake_event:
		wake()


func _start_fight() -> void:
	state = State.FIGHT
	monitoring = true
	hp = max_hp
	# Anyone who falls now comes back inside the arena, not outside the gate.
	for p in get_tree().get_nodes_in_group("player"):
		p.set_checkpoint(Vector2(arena_left + 90.0, floor_y - 2.0))
	_set_camera(self)
	_bar.show_bar(true)
	fight_started.emit()
	health_changed.emit(hp, max_hp)
	_enter_phase(1)


func _enter_phase(n: int) -> void:
	phase = n
	_invulnerable = 1.5
	_timers.clear()
	match n:
		1:
			_cooldowns = {"orbs": 2.8}
			_set_core(Sight.SOLAR)
			_grow_tendrils()
		2:
			_cooldowns = {"beam": 3.4}
			_set_core(Sight.LUNAR)
			_spawn_adds()
		3:
			_cooldowns = {"beam": 2.6, "orbs": 3.4}
			_set_core(Sight.SOLAR)
			_swap_t = core_swap_time
			_grow_tendrils()
	for key in _cooldowns:
		_timers[key] = 1.6
	phase_changed.emit(n)


func _set_core(eye: StringName) -> void:
	core_eye = eye
	core_changed.emit(core_eye, shielded)


func _die() -> void:
	state = State.DYING
	monitoring = false
	_beams.clear()
	for t in _tendrils:
		if is_instance_valid(t):
			t.queue_free()
	_tendrils.clear()
	for n in _adds + _orbs:
		if is_instance_valid(n):
			n.queue_free()
	_adds.clear()
	_orbs.clear()
	_bar.show_bar(false)
	_set_camera(null)
	GameState.set_flag(defeated_flag)
	defeated.emit()
	var tween := create_tween()
	tween.tween_property(self, "_emerge", 0.0, 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_death)


func _finish_death() -> void:
	_become_dead()
	if defeated_cutscene != "" and Cutscenes.enabled:
		Cutscenes.play_file(defeated_cutscene)


func _become_dead() -> void:
	state = State.DEAD
	visible = false
	monitoring = false
	set_deferred("monitorable", false)


func _set_camera(target: Node2D) -> void:
	var cam := get_tree().get_first_node_in_group("party_camera")
	if cam:
		cam.boss = target


# ---------------------------------------------------------------- per frame
func _physics_process(delta: float) -> void:
	_time += delta
	_flash -= delta
	_deflect -= delta
	match state:
		State.SLEEPING:
			# Loaded a save mid-fight (intro already seen): wake when someone enters.
			if GameState.has_flag(intro_flag) and _party_in_arena():
				wake()
		State.FIGHT:
			if not Cutscenes.is_playing:
				_fight(delta)
	queue_redraw()


func _fight(delta: float) -> void:
	_invulnerable -= delta
	# Movement: bob in place in phase 1, drift across the arena later.
	var x := global_position.x
	if phase >= 2:
		var speed := 60.0 if phase == 2 else 90.0
		x += _drift_dir * speed * delta
		if x > arena_right - 260.0:
			_drift_dir = -1.0
		elif x < arena_left + 260.0:
			_drift_dir = 1.0
	global_position = Vector2(x, floor_y - hover_height + sin(_time * 1.3) * 14.0)

	_adds = _adds.filter(func(a): return is_instance_valid(a) and not a.is_sealing())
	_orbs = _orbs.filter(func(o): return is_instance_valid(o))
	var was_shielded := shielded
	shielded = _invulnerable > 0.0 or not _adds.is_empty()
	if was_shielded != shielded:
		core_changed.emit(core_eye, shielded)

	if phase == 3:
		_swap_t -= delta
		if _swap_t <= 0.0:
			_swap_t = core_swap_time
			_set_core(Sight.LUNAR if core_eye == Sight.SOLAR else Sight.SOLAR)
		_suck(delta)

	for key in _timers.keys():
		_timers[key] -= delta
		if _timers[key] <= 0.0:
			_timers[key] = _cooldowns[key]
			_attack(key)
	_update_beams(delta)


func _attack(kind: String) -> void:
	var target := _pick_target()
	if target == null:
		return
	match kind:
		"orbs":
			var count := 3 if phase == 3 else 1
			for i in count:
				var dir := global_position.direction_to(target.global_position + Vector2(0, -50))
				_fire_orb(dir.rotated((i - (count - 1) * 0.5) * 0.35))
		"beam":
			fire_beam(target.global_position.x)


## Telegraphed rift beam at world x. Public so tests (and level scripts) can call it.
func fire_beam(x: float) -> void:
	_beams.append({"x": clampf(x, arena_left + 20.0, arena_right - 20.0), "t": 0.0})


func _update_beams(delta: float) -> void:
	for b in _beams:
		b.t += delta
		var active: bool = b.t >= beam_telegraph and b.t < beam_telegraph + beam_duration
		if active:
			for p in get_tree().get_nodes_in_group("player"):
				if absf(p.global_position.x - b.x) < beam_half_width + 10.0 and p.global_position.y > global_position.y:
					p.respawn()
	_beams = _beams.filter(func(b): return b.t < beam_telegraph + beam_duration)


func _fire_orb(dir: Vector2) -> void:
	var orb := RiftOrb.new()
	orb.velocity = dir * orb_speed
	orb.floor_y = floor_y
	get_parent().add_child(orb)
	orb.global_position = global_position + dir * radius * 0.6
	_orbs.append(orb)


func _spawn_adds() -> void:
	for i in adds_count:
		var add := Portal.new()
		add.radius = 24.0
		add.shots_to_seal = 2
		add.shard_reward = 0
		var t := (i + 1.0) / (adds_count + 1.0)
		add.position = Vector2(lerpf(arena_left + 120.0, arena_right - 120.0, t), floor_y - 150.0)
		get_parent().add_child(add)
		_adds.append(add)
	shielded = true


## Phase 3: four seconds of inhaling, three of rest.
func _suck(delta: float) -> void:
	_suction_t = fposmod(_suction_t + delta, 7.0)
	if _suction_t > 4.0:
		return
	for p in get_tree().get_nodes_in_group("player"):
		var body := p as Player
		if body.carrier or body.cargo or body.grabbed_by:
			continue
		var dx := global_position.x - body.global_position.x
		if absf(dx) > 20.0:
			body.external_velocity.x += signf(dx) * suction_speed


func is_inhaling() -> bool:
	return state == State.FIGHT and phase == 3 and _suction_t <= 4.0


func _grow_tendrils() -> void:
	for t in _tendrils:
		if is_instance_valid(t):
			t.queue_free()
	_tendrils.clear()
	for a in tendril_angles:
		var t := PortalTendril.new()
		t.angle_degrees = a
		t.segments = 10
		t.segment_length = 17.0
		t.reach_speed = 230.0
		t.pull_speed = 70.0
		add_child(t)
		_tendrils.append(t)


func _pick_target() -> Player:
	var members := get_tree().get_nodes_in_group("player")
	if members.is_empty():
		return null
	return members[randi() % members.size()]


func _party_in_arena() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		if p.global_position.x > arena_left and p.global_position.x < arena_right:
			return true
	return false


func _on_body_entered(body: Node) -> void:
	if state == State.FIGHT and body is Player and not Cutscenes.is_playing:
		body.respawn()


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var s := _emerge
	if s <= 0.01:
		return
	var seen := Sight.active
	# Even unsighted eyes glimpse something this big - but faintly.
	var a := 1.0 if seen else 0.45
	var r := radius * s
	# Beams (drawn in world space under the boss).
	for b in _beams:
		var lx: float = b.x - global_position.x
		var bottom := floor_y - global_position.y
		if b.t < beam_telegraph:
			var blink := 0.35 + 0.35 * absf(sin(b.t * 18.0))
			draw_line(Vector2(lx, r * 0.6), Vector2(lx, bottom), Color(1.0, 0.3, 0.6, blink), 2.0)
			draw_circle(Vector2(lx, bottom - 4), 10.0 + b.t * 10.0, Color(1.0, 0.3, 0.6, blink * 0.5))
		else:
			draw_rect(Rect2(lx - beam_half_width, r * 0.5, beam_half_width * 2.0, bottom - r * 0.5), Color(0.85, 0.35, 1.0, 0.55))
			draw_rect(Rect2(lx - beam_half_width * 0.35, r * 0.5, beam_half_width * 0.7, bottom - r * 0.5), Color(1, 0.9, 1, 0.9))
	# Outer swirl.
	for ring in 6:
		var rr := r * (1.0 - ring * 0.12)
		var spin := _time * (0.6 + ring * 0.35) * (1.0 if ring % 2 == 0 else -1.0)
		var col := Color(0.55 + ring * 0.06, 0.15, 0.75 - ring * 0.05, a * (0.9 - ring * 0.08))
		draw_arc(Vector2.ZERO, rr, spin, spin + TAU * 0.78, 48, col, 7.0 - ring * 0.6)
	# The maw: dark mouth ringed with teeth.
	var mouth := r * 0.5
	draw_circle(Vector2.ZERO, mouth, Color(0.04, 0.0, 0.08, a))
	var teeth := 14
	for i in teeth:
		var ang := TAU * i / teeth + sin(_time * 0.7) * 0.1
		var base_a := Vector2.RIGHT.rotated(ang - 0.18) * mouth
		var base_b := Vector2.RIGHT.rotated(ang + 0.18) * mouth
		var tip := Vector2.RIGHT.rotated(ang) * mouth * (0.7 - 0.08 * sin(_time * 3.0 + i))
		draw_colored_polygon(PackedVector2Array([base_a, tip, base_b]), Color(0.92, 0.85, 0.95, a))
	# The core: Solar gold or Lunar silver-blue; dim when shielded or hidden.
	var core_col := Color(1.0, 0.78, 0.3) if core_eye == Sight.SOLAR else Color(0.65, 0.8, 1.0)
	var open := state == State.FIGHT and not shielded and Sight.can_see(core_eye)
	if not open:
		core_col = core_col.darkened(0.55)
	if _flash > 0.0:
		core_col = Color.WHITE
	var look := _iris_offset() * mouth * 0.25
	draw_circle(look, mouth * 0.42, Color(core_col, a * 0.35))
	draw_circle(look, mouth * 0.3, Color(core_col, a))
	draw_circle(look + look.normalized() * 4.0, mouth * 0.12, Color(0.05, 0.02, 0.08, a))
	if shielded and state == State.FIGHT:
		var pulse := 0.5 + 0.3 * sin(_time * 6.0)
		draw_arc(Vector2.ZERO, mouth * 0.95, 0.0, TAU, 40, Color(0.75, 0.6, 1.0, pulse * a), 4.0)
	if _deflect > 0.0:
		for i in 6:
			var d := Vector2.RIGHT.rotated(i * 1.05 + _time * 9.0)
			draw_line(look + d * mouth * 0.3, look + d * mouth * 0.55, Color(1, 1, 1, _deflect * 3.0), 2.0)
	# Cracks spread as it weakens.
	var damage := 1.0 - float(hp) / float(max_hp)
	for i in int(damage * 8.0):
		var d := Vector2.RIGHT.rotated(i * 2.4 + 0.5)
		draw_line(d * mouth * 1.05, d * r * 0.95 + d.orthogonal() * 12.0, Color(1.0, 0.6, 0.9, a * 0.8), 2.0)


func _iris_offset() -> Vector2:
	var t := _pick_nearest()
	return global_position.direction_to(t.global_position) if t else Vector2.ZERO


func _pick_nearest() -> Node2D:
	var best: Node2D = null
	for p in get_tree().get_nodes_in_group("player"):
		if best == null or p.global_position.distance_to(global_position) < best.global_position.distance_to(global_position):
			best = p
	return best
