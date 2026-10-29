class_name PixMeter
extends Node2D
## Little Pix energy bar that floats over the Fairy.
## Bright while carrying or refilling, fades out when full and idle.
## Flashes when Pix is too low to pick the partner up.

const WIDTH := 38.0
const HEIGHT := 5.0
const FULL_COLOR := Color(1.0, 0.82, 0.45)
const LOW_COLOR := Color(1.0, 0.4, 0.55)

var _alpha := 0.0
var _time := 0.0


func _process(delta: float) -> void:
	var body := get_parent() as Player
	if body == null:
		return
	_time += delta
	var busy := body.cargo != null or body.pix < body.profile.pix_max - 0.5
	_alpha = move_toward(_alpha, 1.0 if busy else 0.2, delta * (6.0 if busy else 1.0))
	position = Vector2(0, -body.body_height() - 18.0)
	queue_redraw()


func _draw() -> void:
	var body := get_parent() as Player
	if body == null:
		return
	var ratio := clampf(body.pix_ratio(), 0.0, 1.0)
	var low := body.pix < body.profile.pix_min_to_grab
	var color := FULL_COLOR.lerp(LOW_COLOR, 1.0 - ratio)
	var a := _alpha
	if low and body.cargo == null:
		a *= 0.55 + 0.45 * absf(sin(_time * 8.0))
	var rect := Rect2(-WIDTH * 0.5, 0, WIDTH, HEIGHT)
	draw_rect(rect.grow(1.5), Color(0.05, 0.03, 0.1, 0.7 * a))
	draw_rect(Rect2(rect.position, Vector2(WIDTH * ratio, HEIGHT)), Color(color, a))
	# Tick showing the minimum Pix needed to grab.
	var tick_x := -WIDTH * 0.5 + WIDTH * body.profile.pix_min_to_grab / body.profile.pix_max
	draw_line(Vector2(tick_x, -1), Vector2(tick_x, HEIGHT + 1), Color(1, 1, 1, 0.5 * a), 1.0)
