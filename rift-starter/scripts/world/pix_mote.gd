class_name PixMote
extends Area2D
## A floating mote of Pix light. When anyone in the party touches it, the
## Fairy's Pix is topped up — even mid-flight, even if it's the Mafia dangling
## below her who brushes it. Comes back after `respawn_time`.

@export var amount := 35.0
@export var respawn_time := 8.0
@export var radius := 12.0

var _time := 0.0
var _hidden_for := 0.0
var _home := Vector2.ZERO


func _ready() -> void:
	add_to_group("pix_motes")
	collision_layer = 0
	collision_mask = 2  # player
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_time = randf() * TAU
	_home = global_position


func is_available() -> bool:
	return _hidden_for <= 0.0


func _process(delta: float) -> void:
	_time += delta
	if _hidden_for > 0.0:
		_hidden_for -= delta
		if _hidden_for <= 0.0:
			global_position = _home
			set_deferred("monitoring", true)
	else:
		_drift_to_party(delta)
	queue_redraw()


## "Mote Magnet" upgrade: drift toward the nearest party member in range.
func _drift_to_party(delta: float) -> void:
	var magnet := 0.0
	for member in get_tree().get_nodes_in_group("player"):
		magnet = maxf(magnet, member.profile.mote_magnet_radius)
	if magnet <= 0.0:
		return
	var best: Vector2 = Vector2.INF
	for member in get_tree().get_nodes_in_group("player"):
		var chest: Vector2 = member.global_position + Vector2(0, -member.body_height() * 0.5)
		if chest.distance_to(global_position) < magnet and chest.distance_to(global_position) < best.distance_to(global_position):
			best = chest
	if best != Vector2.INF:
		global_position = global_position.move_toward(best, 320.0 * delta)


func _on_body_entered(body: Node) -> void:
	if not is_available() or not body is Player:
		return
	# Find whoever in the party can carry (holds the Pix) and fill them up.
	for member in get_tree().get_nodes_in_group("player"):
		if member.profile.can_carry:
			member.pix = minf(member.profile.pix_max, member.pix + amount)
	_hidden_for = respawn_time
	set_deferred("monitoring", false)


func _draw() -> void:
	if not is_available():
		# A faint ring shows where it will come back.
		var t := 1.0 - _hidden_for / respawn_time
		draw_arc(Vector2.ZERO, radius * t, 0.0, TAU, 20, Color(1, 0.85, 0.5, 0.2), 1.5)
		return
	var bob := Vector2(0, sin(_time * 2.5) * 4.0)
	draw_circle(bob, radius * 1.6, Color(1.0, 0.85, 0.5, 0.15))
	draw_circle(bob, radius * 0.7, Color(1.0, 0.9, 0.6, 0.9))
	draw_circle(bob, radius * 0.35, Color(1, 1, 0.95, 1))
	for i in 3:
		var a := _time * 1.5 + TAU * i / 3.0
		draw_circle(bob + Vector2(cos(a), sin(a)) * radius * 1.3, 1.8, Color(1, 0.95, 0.8, 0.8))
