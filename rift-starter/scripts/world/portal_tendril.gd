class_name PortalTendril
extends Node2D
## A tendril growing out of a Portal (make it a child of one).
##
## It's a FABRIK chain: the base is pinned to the portal's rim and the tip
## chases a target. It sways while idle, reaches for anyone who comes close,
## grabs them and drags them toward the portal.
##
## Getting free:
##   * mash jump (each press weakens its grip), or
##   * your partner shoots it — only while it can be SEEN (sight open),
##     which is the game's rule: you can only fight what you can see.
## Like its portal, it's nearly invisible with sight closed, but still dangerous.

enum State { IDLE, REACHING, GRABBING, SEVERED }

## Direction the tendril grows from the portal, in degrees (90 = straight down).
@export var angle_degrees := 90.0
@export var segments := 9
@export var segment_length := 17.0
## Joint limit: how sharply each joint may bend (degrees). Lower = smoother
## curls; 180 = no limit (it can kink).
@export_range(5.0, 180.0) var max_bend_degrees := 35.0
## How fast the tip moves (px/s) - slow enough to dodge.
@export var reach_speed := 240.0
## How fast a grabbed victim is dragged toward the portal.
@export var pull_speed := 55.0
## Jump presses needed to break free.
@export var grip_strength := 5
## Seconds before a severed / shaken-off tendril can grab again.
@export var regrow_time := 3.0
@export var recoil_time := 1.5

var state: State = State.IDLE
var victim: Player = null

var _points := PackedVector2Array()   # global joint positions
var _tip := Vector2.ZERO               # global position the tip is chasing
var _grip := 0
var _cooldown := 0.0
var _growth := 1.0                     # 0..1, shrinks when severed
var _time := 0.0
var _portal: Node2D


func _ready() -> void:
	add_to_group("tendrils")
	_portal = get_parent() as Node2D
	_time = randf() * 10.0
	var dir := _rest_dir()
	var base := _base()
	for i in segments + 1:
		_points.append(base + dir * segment_length * i)
	_tip = _points[_points.size() - 1]


func _exit_tree() -> void:
	release(false)


func reach() -> float:
	return segments * segment_length


func tip() -> Vector2:
	return _points[_points.size() - 1] if _points.size() > 0 else global_position


## Visible (and therefore shootable) right now?
func can_be_seen() -> bool:
	var eye: StringName = _portal.for_eye if _portal and "for_eye" in _portal else &""
	return Sight.can_see(eye) and state != State.SEVERED


func _base() -> Vector2:
	var radius: float = _portal.radius if _portal and "radius" in _portal else 0.0
	return global_position + _rest_dir() * radius * 0.9


func _rest_dir() -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(angle_degrees))


static func _chest(p: Player) -> Vector2:
	return p.global_position + Vector2(0, -p.body_height() * 0.55)


func _physics_process(delta: float) -> void:
	_time += delta
	_cooldown -= delta
	var base := _base()
	# The portal is being sealed: let go and wither.
	if _portal and _portal.has_method("is_sealing") and _portal.is_sealing() and state != State.SEVERED:
		sever()

	match state:
		State.SEVERED:
			_growth = move_toward(_growth, 0.0, delta * 4.0)
			if _cooldown <= 0.0:
				state = State.IDLE
		State.IDLE, State.REACHING:
			_growth = move_toward(_growth, 1.0, delta * 1.5)
			var prey := _find_prey(base) if _cooldown <= 0.0 else null
			if prey:
				state = State.REACHING
				_tip = _tip.move_toward(_chest(prey), reach_speed * delta)
				if tip().distance_to(_chest(prey)) < 16.0:
					_grab(prey)
			else:
				state = State.IDLE
				var sway := Vector2(sin(_time * 1.7), cos(_time * 1.3)) * segment_length * 1.5
				var idle := base + _rest_dir() * reach() * 0.75 + sway
				_tip = _tip.move_toward(idle, reach_speed * 0.4 * delta)
		State.GRABBING:
			if victim == null or not is_instance_valid(victim):
				release(false)
			else:
				_tip = _chest(victim)
				# Snapped: the victim got further than the tendril can stretch.
				if base.distance_to(_tip) > reach() * 1.15:
					release(false)

	# Solve the chain toward the tip, scaled by growth (severed ones shrink away).
	var target := base + (_tip - base) * _growth
	_points = Fabrik.solve(_scaled_chain(base), base, target, 8, 0.5,
		deg_to_rad(max_bend_degrees), _rest_dir())
	queue_redraw()


# Shrink the rest chain when severed so FABRIK works with shorter bones.
func _scaled_chain(base: Vector2) -> PackedVector2Array:
	var chain := PackedVector2Array()
	var dir := _rest_dir()
	var bone_len := segment_length * maxf(_growth, 0.05)
	# Start from the previous pose but re-space it to the current bone length.
	var prev := base
	chain.append(base)
	for i in range(1, _points.size()):
		var d := prev.direction_to(_points[i])
		if d == Vector2.ZERO:
			d = dir
		prev = prev + d * bone_len
		chain.append(prev)
	return chain


func _find_prey(base: Vector2) -> Player:
	if Cutscenes.is_playing:
		return null  # no ambushes mid-conversation
	var best: Player = null
	var best_d := reach() + 10.0
	for p in get_tree().get_nodes_in_group("player"):
		var body := p as Player
		if body.grabbed_by != null or body.grab_immunity > 0.0:
			continue
		var d := base.distance_to(_chest(body))
		if d < best_d:
			best_d = d
			best = body
	return best


func _grab(prey: Player) -> void:
	victim = prey
	_grip = grip_strength
	state = State.GRABBING
	prey.grab_by(self)


## Velocity the victim should move with this frame (toward the portal).
func pull_velocity() -> Vector2:
	if victim == null:
		return Vector2.ZERO
	return _chest(victim).direction_to(global_position) * pull_speed


## Called by the victim on each jump press.
func struggle(strength := 1) -> void:
	_grip -= strength
	if _grip <= 0:
		release(true)


## Shot by the Mafia.
func sever() -> void:
	release(false)
	state = State.SEVERED
	_cooldown = regrow_time


func release(shaken_off: bool) -> void:
	if victim and is_instance_valid(victim) and victim.grabbed_by == self:
		victim.grabbed_by = null
		victim.grab_immunity = 1.2
		if shaken_off:
			victim.velocity = global_position.direction_to(victim.global_position) * 260.0 + Vector2(0, -200)
	victim = null
	if state == State.GRABBING:
		state = State.IDLE
		_cooldown = recoil_time


## For shots: distance along the shot where it crosses this tendril, or -1.
func hit_distance(from: Vector2, to: Vector2) -> float:
	if not can_be_seen():
		return -1.0
	var best := -1.0
	for i in _points.size() - 1:
		var closest := Geometry2D.get_closest_points_between_segments(from, to, _points[i], _points[i + 1])
		if closest[0].distance_to(closest[1]) < 7.0:
			var d := from.distance_to(closest[0])
			if best < 0.0 or d < best:
				best = d
	return best


func _draw() -> void:
	if _points.size() < 2:
		return
	var alpha := 1.0 if can_be_seen() else 0.07
	if state == State.SEVERED:
		alpha *= _growth
	var n := _points.size()
	for i in n - 1:
		var t := float(i) / float(n - 1)
		var width := lerpf(9.0, 2.5, t)
		var col := Color(0.5 + 0.3 * t, 0.18, 0.75 - 0.2 * t, alpha)
		if state == State.GRABBING:
			col = col.lerp(Color(0.95, 0.3, 0.55, alpha), 0.5)
		draw_line(to_local(_points[i]), to_local(_points[i + 1]), col, width)
		draw_circle(to_local(_points[i + 1]), width * 0.5, col)
	# Little hooked tip
	var tip_local := to_local(_points[n - 1])
	var tip_dir := (_points[n - 1] - _points[n - 2]).normalized()
	draw_line(tip_local, tip_local + tip_dir.rotated(1.2) * 7.0, Color(0.9, 0.5, 1.0, alpha), 2.0)
	draw_line(tip_local, tip_local + tip_dir.rotated(-1.2) * 7.0, Color(0.9, 0.5, 1.0, alpha), 2.0)
