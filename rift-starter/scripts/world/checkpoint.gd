class_name Checkpoint
extends Area2D
## Walk past it to set your respawn point. Place it with its origin on the ground.

var _lit := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 120)
	shape.shape = rect
	shape.position = Vector2(0, -60)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.has_method("set_checkpoint"):
		# Checkpoints are shared by the whole party.
		for member in get_tree().get_nodes_in_group("player"):
			member.set_checkpoint(global_position + Vector2(0, -2))
		_lit = true
		queue_redraw()


func _draw() -> void:
	# Bamboo pole with a paper lantern.
	draw_line(Vector2.ZERO, Vector2(0, -70), Color(0.55, 0.62, 0.3), 5.0)
	for k in 3:
		draw_line(Vector2(-3, -18 - k * 20), Vector2(3, -18 - k * 20), Color(0.35, 0.42, 0.2), 2.0)
	var flame := Color(1.0, 0.8, 0.4) if _lit else Color(0.3, 0.28, 0.38)
	if _lit:
		draw_circle(Vector2(0, -78), 14.0, Color(flame, 0.25))
	draw_circle(Vector2(0, -78), 7.0, flame)
