class_name Ocean
extends Node2D
## Animated sea water for the bottom of a chasm (one node per chasm, set
## `from_x` / `to_x` to its edges). It sits behind the ground, so only the
## part inside the gap shows. Purely visual: falling in counts as a fall once
## you pass Player.kill_y.

@export var surface_y := -40.0
@export var from_x := -1200.0
@export var to_x := 5600.0

const SHALLOW := Color(0.15, 0.55, 0.62)
const DEEP := Color(0.05, 0.2, 0.3)

var _time := 0.0


func _ready() -> void:
	z_index = -1


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := to_x - from_x
	draw_rect(Rect2(from_x, surface_y, w, 60.0), SHALLOW)
	draw_rect(Rect2(from_x, surface_y + 60.0, w, 900.0), DEEP)
	var wave := PackedVector2Array()
	var steps := int(w / 24.0)
	for i in steps + 1:
		var x := from_x + i * 24.0
		wave.append(Vector2(x, surface_y + sin(x * 0.03 + _time * 2.0) * 4.0))
	draw_polyline(wave, Color(0.85, 0.97, 1.0, 0.85), 3.0)
	for i in 40:
		var x := from_x + fposmod(i * 173.0 + _time * 14.0, w)
		var y := surface_y + 18.0 + (i % 5) * 9.0
		draw_line(Vector2(x, y), Vector2(x + 26.0, y), Color(0.7, 0.95, 1.0, 0.35), 2.0)
