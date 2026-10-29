class_name RiftOrb
extends Area2D
## A slow, slightly homing orb the Maw spits out. Touching it sends you back
## like a portal. Shoot it to pop it (it's always visible: fair warning).

@export var lifetime := 7.0
@export var turn_rate := 0.7   ## radians/s it bends toward the nearest character

var velocity := Vector2.ZERO
var floor_y := 1e9
var for_eye: StringName = &""
var _age := 0.0
var _popping := false


func _ready() -> void:
	add_to_group("portals")   # so the AI's auto-aim considers it
	collision_layer = 4
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func is_sealing() -> bool:
	return _popping


func on_shot(_power := 1) -> void:
	_pop()


func _physics_process(delta: float) -> void:
	_age += delta
	var target := _nearest()
	if target:
		var want := global_position.direction_to(target.global_position + Vector2(0, -40))
		var ang := velocity.angle_to(want * velocity.length())
		velocity = velocity.rotated(clampf(ang, -turn_rate * delta, turn_rate * delta))
	global_position += velocity * delta
	if _age > lifetime or global_position.y > floor_y + 10.0:
		_pop()
	queue_redraw()


func _nearest() -> Node2D:
	var best: Node2D = null
	for p in get_tree().get_nodes_in_group("player"):
		if best == null or p.global_position.distance_to(global_position) < best.global_position.distance_to(global_position):
			best = p
	return best


func _on_body_entered(body: Node) -> void:
	if not _popping and body is Player and not Cutscenes.is_playing:
		body.respawn()
		_pop()


func _pop() -> void:
	if _popping:
		return
	_popping = true
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var pulse := 1.0 + 0.15 * sin(_age * 10.0)
	draw_circle(Vector2.ZERO, 20.0 * pulse, Color(0.8, 0.3, 1.0, 0.2))
	draw_circle(Vector2.ZERO, 12.0, Color(0.55, 0.15, 0.85))
	draw_arc(Vector2.ZERO, 9.0, _age * 6.0, _age * 6.0 + 4.0, 12, Color(1.0, 0.7, 1.0), 2.0)
	draw_circle(Vector2.ZERO, 4.0, Color(0.05, 0.0, 0.1))
