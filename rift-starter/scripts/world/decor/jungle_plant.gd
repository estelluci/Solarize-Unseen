@tool
class_name JunglePlant
extends Node2D
## One piece of procedural jungle scenery. Place it with its origin on the
## ground. Purely decorative (no collision). Placed automatically by
## JungleDressing, or by hand anywhere.

enum Kind { PALM, MONSTERA, FERN, BANANA, HIBISCUS, BAMBOO }

@export var kind: Kind = Kind.PALM:
	set(value):
		kind = value
		queue_redraw()
@export var height := 200.0:
	set(value):
		height = value
		queue_redraw()
@export var flip := false:
	set(value):
		flip = value
		queue_redraw()
@export var variation := 0:
	set(value):
		variation = value
		queue_redraw()
## Darken for plants placed behind the action, lighten for foreground.
@export_range(-0.6, 0.4) var shade := 0.0:
	set(value):
		shade = value
		queue_redraw()

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	if kind in [Kind.PALM, Kind.BANANA, Kind.BAMBOO]:
		queue_redraw()  # gentle sway


func _c(c: Color) -> Color:
	return c.darkened(-shade) if shade < 0.0 else c.lightened(shade)


func _draw() -> void:
	var s := -1.0 if flip else 1.0
	var sway := sin(_time * 0.9 + variation) * 0.04
	match kind:
		Kind.PALM: _palm(s, sway)
		Kind.MONSTERA: _monstera(s)
		Kind.FERN: _fern(s)
		Kind.BANANA: _banana(s, sway)
		Kind.HIBISCUS: _hibiscus(s)
		Kind.BAMBOO: _bamboo(s, sway)


func _palm(s: float, sway: float) -> void:
	var trunk := _c(Color(0.45, 0.33, 0.22))
	var leaf := _c(Color(0.2, 0.52, 0.25))
	var bend := 40.0 * s
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(Vector2(bend * t * t + sway * height * t * t, -height * t))
	for i in pts.size() - 1:
		draw_line(pts[i], pts[i + 1], trunk, lerpf(11.0, 7.0, i / 12.0))
		if i % 2 == 0:
			draw_line(pts[i] + Vector2(-5, 0), pts[i] + Vector2(5, -2), trunk.darkened(0.25), 2.0)
	var top := pts[pts.size() - 1]
	draw_circle(top + Vector2(4 * s, 6), 6.0, _c(Color(0.35, 0.25, 0.12)))  # coconuts
	draw_circle(top + Vector2(-4 * s, 8), 5.0, _c(Color(0.3, 0.22, 0.1)))
	for f in 8:
		var ang := -PI * 0.5 + (f - 3.5) * 0.42 + sway * 3.0
		var dir := Vector2.RIGHT.rotated(ang)
		var length := height * (0.38 + 0.06 * sin(f * 2.3 + variation))
		var mid := top + dir * length * 0.5 + Vector2(0, -length * 0.05)
		var tip := top + dir * length + Vector2(0, length * 0.32)
		var frond := PackedVector2Array([top, mid, tip])
		draw_polyline(frond, leaf.darkened(0.15), 4.0)
		for k in 7:
			var t := (k + 1) / 8.0
			var p := top.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(tip, (t - 0.5) * 2.0)
			var side := (tip - top).orthogonal().normalized()
			draw_line(p, p + side * 9.0 + Vector2(0, 6), leaf, 3.0)
			draw_line(p, p - side * 9.0 + Vector2(0, 6), leaf, 3.0)


func _monstera(s: float) -> void:
	var leaf := _c(Color(0.16, 0.45, 0.24))
	var vein := _c(Color(0.3, 0.6, 0.32))
	for i in 5:
		var ang := -PI * 0.5 + (i - 2) * 0.55 * s
		var stem_end := Vector2.RIGHT.rotated(ang) * height * 0.55
		draw_line(Vector2.ZERO, stem_end, vein, 3.0)
		var r := height * (0.24 + 0.04 * sin(i + variation))
		draw_circle(stem_end, r, leaf)
		# The famous splits
		for k in 3:
			var cut_dir := Vector2.RIGHT.rotated(ang + (k - 1) * 0.9)
			draw_line(stem_end + cut_dir * r * 0.35, stem_end + cut_dir * r * 1.05, leaf.darkened(0.45), 2.5)
		draw_line(stem_end - Vector2.RIGHT.rotated(ang) * r * 0.8, stem_end + Vector2.RIGHT.rotated(ang) * r * 0.8, vein, 1.5)


func _fern(s: float) -> void:
	var leaf := _c(Color(0.28, 0.6, 0.28))
	for i in 7:
		var ang := -PI * 0.5 + (i - 3) * 0.32 * s
		var tip := Vector2.RIGHT.rotated(ang) * height + Vector2(0, height * 0.25 * absf(i - 3) / 3.0)
		draw_line(Vector2.ZERO, tip, leaf.darkened(0.1), 2.0)
		for k in 6:
			var p := Vector2.ZERO.lerp(tip, (k + 1) / 7.0)
			var side := tip.orthogonal().normalized() * (6.0 - k * 0.7)
			draw_line(p, p + side, leaf, 2.0)
			draw_line(p, p - side, leaf, 2.0)


func _banana(s: float, sway: float) -> void:
	var stem := _c(Color(0.35, 0.5, 0.25))
	var leaf := _c(Color(0.32, 0.62, 0.26))
	draw_line(Vector2.ZERO, Vector2(0, -height * 0.55), stem, 9.0)
	var top := Vector2(0, -height * 0.55)
	for i in 5:
		var ang := -PI * 0.5 + (i - 2) * 0.6 * s + sway * 2.0
		var dir := Vector2.RIGHT.rotated(ang)
		var tip := top + dir * height * 0.5 + Vector2(0, height * 0.12)
		var side := (tip - top).orthogonal().normalized() * height * 0.09
		draw_colored_polygon(PackedVector2Array([top, top.lerp(tip, 0.5) + side, tip, top.lerp(tip, 0.5) - side]), leaf)
		draw_line(top, tip, leaf.lightened(0.2), 1.5)


func _hibiscus(s: float) -> void:
	var leaf := _c(Color(0.18, 0.46, 0.22))
	for i in 6:
		var c := Vector2((i - 2.5) * height * 0.22 * s, -height * (0.3 + 0.25 * absf(sin(i * 1.7 + variation))))
		draw_circle(c, height * 0.28, leaf)
	var colors := [Color(0.93, 0.18, 0.3), Color(1.0, 0.5, 0.65), Color(1.0, 0.75, 0.2)]
	for i in 4:
		var c := Vector2((i - 1.5) * height * 0.28 * s, -height * (0.45 + 0.2 * sin(i * 2.1 + variation)))
		var col: Color = _c(colors[(i + variation) % colors.size()])
		for p in 5:
			draw_circle(c + Vector2.RIGHT.rotated(TAU * p / 5.0 + i) * 5.0, 4.5, col)
		draw_circle(c, 2.5, Color(1.0, 0.9, 0.4))


func _bamboo(s: float, sway: float) -> void:
	var col := _c(Color(0.5, 0.62, 0.3))
	for stalk in 3:
		var x := (stalk - 1) * 12.0 * s
		var h := height * (0.8 + 0.1 * stalk)
		var top := Vector2(x + sway * h * 2.0, -h)
		draw_line(Vector2(x, 0), top, col, 6.0)
		for k in int(h / 34.0):
			var p := Vector2(x, 0).lerp(top, (k + 1) * 34.0 / h)
			draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), col.darkened(0.3), 2.0)
			if k % 2 == 1:
				draw_line(p, p + Vector2(16 * s, -8), col.lightened(0.1), 2.0)
