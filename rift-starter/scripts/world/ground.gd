@tool
class_name Ground
extends StaticBody2D
## Solid terrain from a polygon. Edit `points` in the Inspector — it draws
## itself in the editor too, so levels can be blocked out before real art.
##
## Jungle style: volcanic soil, a grassy top on every upward-facing edge with
## tufts and the odd hibiscus / plumeria flower, moss on walls. Decoration is
## seeded from the polygon, so it looks the same every run.

enum Style { JUNGLE, BASALT, PLAIN }

@export var points := PackedVector2Array([Vector2(-200, 0), Vector2(200, 0), Vector2(200, 100), Vector2(-200, 100)]):
	set(value):
		points = value
		_sync()
@export var style: Style = Style.JUNGLE:
	set(value):
		style = value
		queue_redraw()
@export var fill_color := Color(0.23, 0.15, 0.13):
	set(value):
		fill_color = value
		queue_redraw()
@export var edge_color := Color(0.42, 0.3, 0.24):
	set(value):
		edge_color = value
		queue_redraw()
## Draw flowers in the grass (turn off for cliffs, caves...).
@export var flowers := true:
	set(value):
		flowers = value
		queue_redraw()

const GRASS_DARK := Color(0.2, 0.5, 0.22)
const GRASS := Color(0.33, 0.68, 0.27)
const GRASS_LIGHT := Color(0.56, 0.84, 0.36)
const MOSS := Color(0.25, 0.45, 0.22, 0.9)
const FLOWER_COLORS := [Color(0.93, 0.2, 0.3), Color(1.0, 0.45, 0.6), Color(1.0, 0.8, 0.25), Color(0.98, 0.95, 0.9)]

var _shape: CollisionPolygon2D


func _ready() -> void:
	add_to_group("ground")
	_sync()


func _sync() -> void:
	queue_redraw()
	if not is_inside_tree() or Engine.is_editor_hint():
		return
	if _shape == null:
		_shape = CollisionPolygon2D.new()
		add_child(_shape)
	_shape.polygon = points


## Upward-facing edges (the walkable tops), in local space: [[a, b], ...].
## Polygons are drawn clockwise, so tops run left-to-right.
func top_edges(max_slope_degrees := 50.0) -> Array:
	var out := []
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		if b.x - a.x > 1.0 and absf(rad_to_deg((b - a).angle())) <= max_slope_degrees:
			out.append([a, b])
	return out


func _draw() -> void:
	if points.size() < 3:
		return
	draw_colored_polygon(points, fill_color)
	if style == Style.PLAIN:
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, edge_color, 3.0)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(points)
	# Rock speckles in the soil.
	var bounds := _bounds()
	for i in int(bounds.get_area() / 9000.0):
		var p := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y + 24.0, bounds.end.y))
		if Geometry2D.is_point_in_polygon(p, points):
			draw_circle(p, rng.randf_range(2.0, 6.0), fill_color.darkened(rng.randf_range(0.1, 0.3)))
	# Walls and undersides.
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, edge_color, 3.0)
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		if style == Style.JUNGLE and absf(b.x - a.x) < 2.0 and absf(b.y - a.y) > 30.0:
			# Hanging moss on vertical faces.
			var top := minf(a.y, b.y)
			for k in int(absf(b.y - a.y) / 28.0):
				var y := top + 10.0 + k * 28.0
				draw_line(Vector2(a.x, y), Vector2(a.x + rng.randf_range(-3, 3), y + rng.randf_range(8, 18)), MOSS, 3.0)
	if style != Style.JUNGLE:
		return
	# Grass on top edges.
	for e in top_edges():
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n := (b - a).orthogonal().normalized()   # points down-ish for left-to-right edges
		if n.y < 0.0:
			n = -n
		draw_line(a + n * 5.0, b + n * 5.0, GRASS_DARK, 10.0)
		draw_line(a + n * 1.5, b + n * 1.5, GRASS, 5.0)
		draw_line(a, b, GRASS_LIGHT, 2.0)
		var length := a.distance_to(b)
		var steps := int(length / 9.0)
		for k in steps:
			var t := (k + rng.randf()) / maxf(steps, 1)
			var p := a.lerp(b, t)
			var h := rng.randf_range(4.0, 11.0)
			var lean := rng.randf_range(-4.0, 4.0)
			draw_line(p, p + Vector2(lean, -h), GRASS if rng.randf() < 0.6 else GRASS_LIGHT, 2.0)
		if flowers:
			var count := int(length / 120.0)
			for k in count:
				if rng.randf() < 0.55:
					var p := a.lerp(b, rng.randf()) + Vector2(0, -rng.randf_range(4.0, 9.0))
					_flower(p, FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()], rng.randf_range(3.0, 5.0), rng.randf() * TAU)


## Five-petal flower (hibiscus / plumeria style).
func _flower(at: Vector2, color: Color, size: float, spin: float) -> void:
	for i in 5:
		var dir := Vector2.RIGHT.rotated(spin + TAU * i / 5.0)
		draw_circle(at + dir * size, size * 0.75, color)
	draw_circle(at, size * 0.5, Color(1.0, 0.85, 0.3) if color.r > 0.9 and color.g > 0.9 else Color(1.0, 0.95, 0.6))


func _bounds() -> Rect2:
	var r := Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	return r
