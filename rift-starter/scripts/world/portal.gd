class_name Portal
extends Area2D
## An enemy portal. Always dangerous, but only visible with sight open —
## and only shootable while you can see it ("you can only fight what you see").

@export var radius := 30.0
@export var for_eye: StringName = &""
@export var shots_to_seal := 3
## Lumen Shards awarded for sealing this portal.
@export var shard_reward := 1

var _time := 0.0
var _hp := 0
var _sealing := false


func _ready() -> void:
	add_to_group("portals")
	collision_layer = 4  # "portals"
	collision_mask = 2   # "player"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	_hp = shots_to_seal
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not _sealing and body.has_method("respawn"):
		body.respawn()


func is_sealing() -> bool:
	return _sealing


func on_shot(power := 1) -> void:
	if _sealing or not Sight.can_see(for_eye):
		return
	_hp -= power
	if _hp <= 0:
		_sealing = true
		GameState.add_shards(shard_reward)
		set_deferred("monitoring", false)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)


func _draw() -> void:
	var seen := Sight.can_see(for_eye)
	# A faint shimmer even without sight, so observant players get a hint.
	var alpha := 1.0 if seen else 0.05
	var hurt := 1.0 - float(_hp) / float(maxi(shots_to_seal, 1))
	for ring in 4:
		var r := radius * (1.0 - ring * 0.22)
		var start := _time * (2.0 + ring) * (1.0 if ring % 2 == 0 else -1.0)
		var col := Color(0.55 + hurt * 0.4, 0.2, 0.85 - ring * 0.1, alpha * (0.9 - ring * 0.15))
		draw_arc(Vector2.ZERO, r, start, start + TAU * 0.7, 24, col, 3.0)
	draw_circle(Vector2.ZERO, radius * 0.18, Color(0.05, 0.0, 0.1, alpha))
