class_name PlaceholderRig
extends CharacterRig
## A procedural stand-in character, fully driven by IK, so the team can build
## and tune gameplay before the Spine art exists.
##
## What the IK does here (the same jobs the Spine rig will do):
##   * Legs  - two-bone IK to foot targets. Feet are raycast onto the ground,
##             so they plant on slopes and bumps; the hips drop so the lower
##             foot can still reach. A procedural gait moves the targets.
##   * Arm   - two-bone IK to the mouse when aiming (Mafia), idle swing otherwise.
##   * Air   - legs tuck while jumping, trail while gliding (Fairy).
##   * Carry - the Fairy reaches down and the Mafia reaches up (IK to each
##             other's hands); his legs dangle and sway. He can still aim.

@export_group("Proportions")
@export var thigh := 22.0
@export var shin := 22.0
@export var upper_arm := 17.0
@export var forearm := 16.0
@export var hip_height := 40.0
@export var torso := 36.0
@export var head_radius := 11.0
@export var foot_spread := 8.0

@export_group("Gait")
@export var stride := 16.0          ## half-length of a step
@export var step_lift := 9.0
@export var foot_sharpness := 30.0  ## how fast feet chase their targets
@export var max_hip_drop := 18.0

@export_group("Debug")
@export var show_ik_targets := false

# Pose (local space, origin = the player's feet on flat ground)
var _feet := [Vector2(-8, 0), Vector2(8, 0)]
var _foot_targets := [Vector2(-8, 0), Vector2(8, 0)]
var _knees := [Vector2.ZERO, Vector2.ZERO]
var _hands := [Vector2.ZERO, Vector2.ZERO]
var _elbows := [Vector2.ZERO, Vector2.ZERO]
var _hip := Vector2(0, -40)
var _shoulder := Vector2(0, -76)
var _gun_dir := Vector2.RIGHT
var _hip_drop := 0.0
var _lean := 0.0
var _phase := 0.0
var _aim_weight := 0.0
var _recoil := 0.0
var _wing_phase := 0.0
var _facing := 1
var _gliding := false
var _airborne := false


func update_rig(delta: float, ctx: RigContext) -> void:
	_facing = ctx.facing
	_gliding = ctx.gliding
	_airborne = not ctx.on_floor or ctx.carrying
	var grip_local := to_local(ctx.grip_point)
	var speed := absf(ctx.velocity.x)
	var move_dir := signf(ctx.velocity.x)
	var smooth := 1.0 - exp(-foot_sharpness * delta)

	# ---------------- legs ----------------
	var ground := [0.0, 0.0]
	if ctx.carried:
		# Dangling: feet hang under the hips and sway with the flight.
		var sway := sin(_wing_phase * 0.35) * 5.0 - clampf(ctx.velocity.x * 0.03, -8.0, 8.0)
		for i in 2:
			_foot_targets[i] = Vector2((i * 2 - 1) * 4.0 + sway * (1.0 + i * 0.4), -hip_height + thigh + shin - 2.0)
		_hip_drop = lerpf(_hip_drop, 0.0, smooth)
	elif ctx.on_floor and not ctx.carrying:
		var moving := speed > 12.0
		var amp := stride * clampf(speed / 140.0, 0.35, 1.0)
		if moving:
			_phase = wrapf(_phase + delta * speed / amp, 0.0, TAU)
		for i in 2:
			var rest_x := (i * 2 - 1) * foot_spread * 0.5 + _facing * 2.0
			var ph: float = _phase + PI * i
			var x := rest_x
			var lift := 0.0
			if moving:
				# Foot swings forward while lifted, pushes back while planted.
				x += sin(ph) * amp * move_dir
				lift = maxf(0.0, cos(ph)) * step_lift * (amp / stride)
			var gy := probe_ground_local_y(x)
			if is_nan(gy):
				gy = 14.0  # dangle a little over ledges
			ground[i] = gy
			_foot_targets[i] = Vector2(x, gy - lift)
		# Drop the hips so the LOWER foot can still reach the ground.
		var drop_target := clampf(maxf(ground[0], ground[1]), 0.0, max_hip_drop)
		_hip_drop = lerpf(_hip_drop, drop_target, smooth)
	else:
		for i in 2:
			var tuck: Vector2
			if ctx.gliding:
				tuck = Vector2(-_facing * (10.0 + i * 6.0), -6.0 + i * 3.0)
			else:
				tuck = Vector2(_facing * (6.0 - i * 10.0), -10.0 + i * 6.0)
			_foot_targets[i] = tuck
		_hip_drop = lerpf(_hip_drop, 0.0, smooth)

	for i in 2:
		_feet[i] = (_feet[i] as Vector2).lerp(_foot_targets[i], smooth)

	_lean = lerpf(_lean, clampf(ctx.velocity.x / maxf(ctx.run_speed, 1.0), -1.0, 1.0) * 0.14, smooth * 0.5)
	_hip = Vector2(0, -hip_height + _hip_drop)
	_shoulder = _hip + Vector2(0, -torso).rotated(_lean)

	for i in 2:
		var hip_socket: Vector2 = _hip + Vector2((i * 2 - 1) * 3.0, 0)
		var leg := TwoBoneIK.solve(hip_socket, _feet[i], thigh, shin, -_facing)
		_knees[i] = leg[0]
		_feet[i] = leg[1]

	# ---------------- arms ----------------
	_aim_weight = move_toward(_aim_weight, 1.0 if ctx.aiming else 0.0, delta * 6.0)
	_recoil = move_toward(_recoil, 0.0, delta * 8.0)
	var reach := (upper_arm + forearm) * 0.92
	var swing := sin(_phase) * clampf(speed / ctx.run_speed, 0.0, 1.0) if ctx.on_floor else 0.0
	var aim_local := to_local(ctx.aim_point)
	var aim_dir := (aim_local - _shoulder).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2(_facing, 0)
	for i in 2:
		var hand_idle: Vector2
		if ctx.gliding:
			hand_idle = _shoulder + Vector2((i * 2 - 1) * 24.0, -6.0)
		elif _airborne:
			hand_idle = _shoulder + Vector2(_facing * (4.0 + i * 8.0), 18.0 - i * 26.0)
		else:
			var s := swing * (1.0 if i == 0 else -1.0)
			hand_idle = _shoulder + Vector2(_facing * s * 12.0, reach * 0.95)
		var hand := hand_idle
		if ctx.carrying or ctx.carried:
			hand = grip_local + Vector2((i * 2 - 1) * 3.0, 0)
		if i == 1:  # front arm aims
			var hand_aim := _shoulder + aim_dir * reach * (1.0 - _recoil * 0.25)
			hand = hand.lerp(hand_aim, _aim_weight)
		var arm := TwoBoneIK.solve(_shoulder, hand, upper_arm, forearm, _facing)
		_elbows[i] = arm[0]
		_hands[i] = arm[1]

	var forearm_dir: Vector2 = (_hands[1] - _elbows[1]).normalized()
	_gun_dir = forearm_dir.lerp(aim_dir, _aim_weight).normalized()
	_wing_phase += delta * (18.0 if _airborne else 4.0)
	queue_redraw()


func on_fire() -> void:
	_recoil = 1.0


func get_hand_global_positions() -> Array:
	return [to_global(_hands[0]), to_global(_hands[1])]


func get_muzzle_global_position() -> Vector2:
	return to_global(_hands[1] + _gun_dir * 20.0)


func snap() -> void:
	for i in 2:
		_feet[i] = Vector2((i * 2 - 1) * foot_spread * 0.5, 0)
		_foot_targets[i] = _feet[i]
	_hip_drop = 0.0


## Used by the automated smoke test.
func get_debug_pose() -> Dictionary:
	return {"hip": _hip, "feet": _feet.duplicate(), "knees": _knees.duplicate(),
		"hands": _hands.duplicate(), "elbows": _elbows.duplicate(), "shoulder": _shoulder}


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if profile == null:
		return
	var body := profile.body_color
	var back_body := body.darkened(0.35)
	var skin := profile.skin_color
	var accent := profile.accent_color
	var accent2 := profile.accent_color2
	var fairy := profile.look == CharacterProfile.Look.FAIRY
	var back := 0 if _facing > 0 else 1   # the limb further from the camera
	var front := 1 - back

	if fairy:
		_draw_wings(accent)
	# Back limbs first
	_limb(_shoulder, _elbows[0], _hands[0], back_body, 6.0, skin.darkened(0.25))
	_limb(_hip + Vector2((back * 2 - 1) * 3.0, 0), _knees[back], _feet[back], back_body, 7.0, Color.BLACK.lightened(0.15))
	# Torso
	draw_line(_hip, _shoulder, body, 14.0)
	draw_circle(_hip, 7.0, body)
	draw_circle(_shoulder, 7.0, body)
	if not fairy:
		draw_line(_shoulder + Vector2(0, 2), _shoulder.lerp(_hip, 0.55), accent, 3.0)  # tie
	# Head
	var head := _shoulder + Vector2(0, -head_radius - 4.0)
	draw_circle(head, head_radius, skin)
	draw_circle(head + Vector2(_facing * 5.0, -1.0), 1.8, Color(0.1, 0.1, 0.12))
	if fairy:
		_draw_fairy_hair(head, accent2)
	else:
		_draw_fedora(head, body)
	# Front leg + arm
	_limb(_hip + Vector2((front * 2 - 1) * 3.0, 0), _knees[front], _feet[front], body, 7.0, Color.BLACK.lightened(0.1))
	if not fairy:
		var tip: Vector2 = _hands[1] + _gun_dir * 20.0
		draw_line(_hands[1], tip, Color(0.2, 0.2, 0.22), 5.0)
	_limb(_shoulder, _elbows[1], _hands[1], body.lightened(0.08), 6.0, skin)

	if show_ik_targets:
		for i in 2:
			draw_circle(_foot_targets[i], 2.5, Color.YELLOW)
			draw_circle(_knees[i], 2.0, Color.RED)


func _limb(a: Vector2, joint: Vector2, b: Vector2, color: Color, width: float, end_color: Color) -> void:
	draw_line(a, joint, color, width)
	draw_line(joint, b, color, width * 0.9)
	draw_circle(joint, width * 0.5, color)
	draw_circle(b, width * 0.55, end_color)


func _draw_fedora(head: Vector2, color: Color) -> void:
	var top := head + Vector2(0, -head_radius + 1.0)
	draw_line(top + Vector2(-15, 0), top + Vector2(15, 0), color.darkened(0.2), 3.0)
	draw_rect(Rect2(top + Vector2(-9, -11), Vector2(18, 11)), color.darkened(0.2))
	draw_line(top + Vector2(-9, -2), top + Vector2(9, -2), profile.accent_color, 2.0)


func _draw_fairy_hair(head: Vector2, color: Color) -> void:
	var hair := color.darkened(0.45)
	draw_circle(head + Vector2(-_facing * 4.0, -5.0), head_radius * 0.8, hair)
	draw_line(head + Vector2(-_facing * 8.0, -2.0), head + Vector2(-_facing * 16.0, 12.0), hair, 5.0)
	draw_circle(head + Vector2(_facing * 3.0, -head_radius - 2.0), 2.5, Color(1, 0.95, 0.6))


func _draw_wings(color: Color) -> void:
	var flap := sin(_wing_phase) * (0.6 if _airborne else 0.15)
	if _gliding:
		flap = 0.35
	var root := _shoulder.lerp(_hip, 0.2)
	var wing := color
	wing.a = 0.55
	for side in [-1.0, 1.0]:
		var rot: float = (-0.9 + flap) * side - _facing * 0.4
		var pts := PackedVector2Array()
		for k in 12:
			var t := TAU * k / 12.0
			var p := Vector2(cos(t) * 10.0, sin(t) * 22.0 - 20.0).rotated(rot)
			pts.append(root + p)
		draw_colored_polygon(pts, wing)
