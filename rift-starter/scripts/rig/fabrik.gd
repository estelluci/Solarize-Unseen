class_name Fabrik
extends RefCounted
## FABRIK ("Forward And Backward Reaching Inverse Kinematics") for chains of
## any length — tendrils, tails, ropes, long arms. TwoBoneIK is exact for two
## bones; FABRIK handles many by iterating:
##   1. backward pass: pin the tip on the target, walk toward the base
##   2. forward pass:  pin the base back in place, walk toward the tip
## Each pass only re-places joints at their bone length, so lengths are kept.
##
## Optional joint limits: `max_bend` (radians) caps how sharply each joint may
## turn relative to the bone before it. The first bone is measured against
## `root_dir`. Limits make chains curl smoothly instead of kinking; the price
## is that very tight targets may not be reached exactly.


## `points` are the current joint positions (base first). Returns new joints.
## The base stays at `base`; the tip gets as close to `target` as it can.
static func solve(points: PackedVector2Array, base: Vector2, target: Vector2,
		iterations := 8, tolerance := 0.5, max_bend := PI, root_dir := Vector2.ZERO) -> PackedVector2Array:
	var n := points.size()
	if n < 2:
		return points
	var lengths := PackedFloat32Array()
	var total := 0.0
	for i in n - 1:
		var l := points[i].distance_to(points[i + 1])
		lengths.append(l)
		total += l
	var out := points.duplicate()
	var limited := max_bend < PI

	# Out of reach and unconstrained: stretch straight toward the target.
	if base.distance_to(target) >= total and not limited:
		var dir := base.direction_to(target)
		out[0] = base
		for i in n - 1:
			out[i + 1] = out[i] + dir * lengths[i]
		return out

	for _iter in iterations:
		# Backward: tip to target.
		out[n - 1] = target
		for i in range(n - 2, -1, -1):
			out[i] = out[i + 1] + _dir_or(out[i + 1], out[i], Vector2.UP) * lengths[i]
		# Forward: base back home, applying joint limits on the way out.
		out[0] = base
		var prev_dir := root_dir.normalized() if root_dir != Vector2.ZERO else Vector2.ZERO
		for i in n - 1:
			var dir := _dir_or(out[i], out[i + 1], prev_dir if prev_dir != Vector2.ZERO else Vector2.DOWN)
			if limited and prev_dir != Vector2.ZERO:
				var bend := clampf(prev_dir.angle_to(dir), -max_bend, max_bend)
				dir = prev_dir.rotated(bend)
			out[i + 1] = out[i] + dir * lengths[i]
			prev_dir = dir
		if out[n - 1].distance_to(target) <= tolerance:
			break
	return out


static func _dir_or(from: Vector2, to: Vector2, fallback: Vector2) -> Vector2:
	var d := from.direction_to(to)
	return d if d != Vector2.ZERO else fallback
