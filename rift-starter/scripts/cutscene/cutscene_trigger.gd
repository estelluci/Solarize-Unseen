@tool
class_name CutsceneTrigger
extends Area2D
## Plays a cutscene when a party member walks in (or as soon as the level
## starts, with `autoplay`). Place it with its origin on the ground.
##
## Logic: `require_flag` must be set, `skip_if_flag` must not be. With `once`,
## it remembers it played via the flag "cutscene:<file name>" (saved).

@export_file("*.cutscene") var cutscene := ""
@export var size := Vector2(80, 220):
	set(value):
		size = value
		queue_redraw()
@export var once := true
@export var autoplay := false
@export var require_flag: StringName = &""
@export var skip_if_flag: StringName = &""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = 2  # player
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y * 0.5)
	add_child(shape)
	body_entered.connect(func(_b): try_play())
	if autoplay:
		# Let the party and camera finish setting up first.
		await get_tree().process_frame
		await get_tree().process_frame
		try_play()


func played_flag() -> StringName:
	return StringName("cutscene:" + cutscene.get_file().get_basename())


func can_play() -> bool:
	if cutscene == "" or not Cutscenes.enabled or Cutscenes.is_playing:
		return false
	if once and GameState.has_flag(played_flag()):
		return false
	if require_flag != &"" and not GameState.has_flag(require_flag):
		return false
	if skip_if_flag != &"" and GameState.has_flag(skip_if_flag):
		return false
	return true


func try_play() -> void:
	if not can_play():
		return
	GameState.set_flag(played_flag())
	Cutscenes.play_file(cutscene)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	draw_rect(r, Color(1.0, 0.6, 0.9, 0.12))
	draw_rect(r, Color(1.0, 0.6, 0.9, 0.8), false, 2.0)
