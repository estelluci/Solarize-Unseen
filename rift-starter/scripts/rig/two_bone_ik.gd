class_name TwoBoneIK
extends RefCounted
## Analytic two-bone IK (law of cosines). Used for legs and arms.
##
## Given a root (hip / shoulder), a target (foot / hand) and two bone lengths,
## returns [joint, end] where joint is the knee/elbow. If the target is out of
## reach the limb stretches straight toward it.
##
## bend = +1 or -1 picks which side the joint bends to. In Godot's y-down
## space, for a character facing right: knees use -1, elbows use +1.
## Multiply by the facing direction when the character turns around.


static func solve(root: Vector2, target: Vector2, len_a: float, len_b: float, bend: float) -> PackedVector2Array:
	var to_target := target - root
	var dist := to_target.length()
	var dir := to_target / dist if dist > 0.0001 else Vector2.DOWN
	# Keep the triangle valid: never fully straight, never fully folded.
	dist = clampf(dist, absf(len_a - len_b) + 0.01, len_a + len_b - 0.01)
	var end := root + dir * dist
	var cos_root := (len_a * len_a + dist * dist - len_b * len_b) / (2.0 * len_a * dist)
	var angle := acos(clampf(cos_root, -1.0, 1.0))
	var joint := root + dir.rotated(angle * signf(bend)) * len_a
	return PackedVector2Array([joint, end])
