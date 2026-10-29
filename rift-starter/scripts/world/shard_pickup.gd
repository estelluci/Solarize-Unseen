@tool
class_name ShardPickup
extends Area2D
## A Lumen Shard: the currency for upgrades. Collected once per save — its
## `shard_id` is stored as a flag so it stays gone after loading.

## Unique per shard (e.g. "start_chimney"). Leave empty to use the node path.
@export var shard_id := ""
@export var amount := 1

var _time := 0.0
var _taken := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("shards")
	collision_layer = 0
	collision_mask = 2  # player
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_time = randf() * TAU
	GameState.changed.connect(_sync)
	_sync()


func flag_name() -> StringName:
	return StringName("shard:" + (shard_id if shard_id != "" else String(get_path())))


func _sync() -> void:
	_taken = GameState.has_flag(flag_name())
	set_deferred("monitoring", not _taken)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _taken or not body is Player:
		return
	GameState.set_flag(flag_name())
	GameState.add_shards(amount)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _taken and not Engine.is_editor_hint():
		return
	var bob := Vector2(0, sin(_time * 2.0) * 5.0)
	var glow := Color(0.35, 1.0, 0.85, 0.18 + 0.08 * sin(_time * 3.0))
	draw_circle(bob, 22.0, glow)
	# A faceted crystal: teal body, gold heart.
	var pts := PackedVector2Array([Vector2(0, -16), Vector2(9, -2), Vector2(5, 13), Vector2(-5, 13), Vector2(-9, -2)])
	for i in pts.size():
		pts[i] = pts[i].rotated(sin(_time * 1.3) * 0.15) + bob
	draw_colored_polygon(pts, Color(0.3, 0.9, 0.8))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.85, 1.0, 0.95), 1.5)
	draw_line(pts[0], pts[3], Color(0.7, 1, 0.95, 0.6), 1.0)
	draw_circle(bob + Vector2(0, 2), 3.0, Color(1.0, 0.85, 0.4))
