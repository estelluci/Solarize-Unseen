@tool
class_name ArenaGate
extends StaticBody2D
## A wall of thorny rift-vines that seals a boss arena while the fight is on.
## Open (walk-through) otherwise. Place its origin on the ground.

@export var boss_path: NodePath
@export var size := Vector2(40, 460):
	set(value):
		size = value
		queue_redraw()

var closed := false
var _shape: CollisionShape2D
var _time := 0.0
var _boss: MawBoss


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = Vector2(0, -size.y * 0.5)
	_shape.disabled = true
	add_child(_shape)
	_boss = get_node_or_null(boss_path) as MawBoss


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var should_close := _boss != null and _boss.state in [MawBoss.State.EMERGING, MawBoss.State.FIGHT]
	if should_close != closed:
		closed = should_close
		_shape.set_deferred("disabled", not closed)
	queue_redraw()


func _draw() -> void:
	var half := size.x * 0.5
	# Stone posts either side.
	for x in [-half - 8.0, half + 8.0]:
		draw_rect(Rect2(x - 7.0, -size.y, 14.0, size.y), Color(0.3, 0.26, 0.28))
		draw_circle(Vector2(x, -size.y), 9.0, Color(0.42, 0.36, 0.38))
	if not closed and not Engine.is_editor_hint():
		return
	# Thorny vines, glowing with rift light.
	for i in 5:
		var x := -half + size.x * (i + 0.5) / 5.0
		var pts := PackedVector2Array()
		for k in 24:
			var y := -size.y * k / 23.0
			pts.append(Vector2(x + sin(y * 0.05 + _time * 2.0 + i) * 5.0, y))
		draw_polyline(pts, Color(0.55, 0.2, 0.8, 0.9), 4.0)
		for k in range(2, 23, 3):
			draw_line(pts[k], pts[k] + Vector2(7 if k % 2 == 0 else -7, -4), Color(0.85, 0.5, 1.0), 2.0)
	draw_rect(Rect2(-half, -size.y, size.x, size.y), Color(0.7, 0.3, 1.0, 0.12 + 0.05 * sin(_time * 4.0)))
