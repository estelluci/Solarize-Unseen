class_name CarryTether
extends Node2D
## The glowing strand of Pix light between the Fairy's hands and the Mafia's
## while she carries him. It dims and flickers as her Pix runs out.

var carrier: Player
var _time := 0.0


func _ready() -> void:
	top_level = true
	z_index = 5


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if carrier == null or carrier.cargo == null:
		return
	var a: Vector2 = Player._midpoint(carrier.rig.get_hand_global_positions())
	var b: Vector2 = Player._midpoint(carrier.cargo.rig.get_hand_global_positions())
	var ratio := carrier.pix_ratio()
	var alpha := 0.35 + 0.65 * ratio
	if ratio < 0.25:
		alpha *= 0.5 + 0.5 * absf(sin(_time * 18.0))  # about to give out
	var glow := Color(1.0, 0.85, 0.5, alpha * 0.35)
	var core := Color(1.0, 0.95, 0.8, alpha)
	draw_line(a, b, glow, 6.0)
	draw_line(a, b, core, 2.0)
	# Sparkles drifting down the strand.
	for i in 4:
		var t := fmod(_time * 0.9 + i * 0.25, 1.0)
		var p := a.lerp(b, t) + Vector2(sin(_time * 7.0 + i) * 3.0, 0)
		draw_circle(p, 1.8, Color(1, 1, 0.85, alpha))
