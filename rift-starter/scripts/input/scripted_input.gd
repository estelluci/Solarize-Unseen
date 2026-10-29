class_name ScriptedInput
extends PlayerInput
## Input driven by a cutscene. The director sets `move_x`, queues jumps, etc.
## Everything else stays idle, so characters stand still unless told to move.

var _jump_queued := false
var _hold_jump := 0.0


func _init() -> void:
	tag = ""


func queue_jump(hold_seconds := 0.25) -> void:
	_jump_queued = true
	_hold_jump = hold_seconds


func poll(player: Player, delta: float) -> void:
	jump_pressed = _jump_queued
	_jump_queued = false
	_hold_jump -= delta
	jump_held = _hold_jump > 0.0
	shoot_pressed = false
	sight_pressed = false
	carry_pressed = false
	aim_controls_facing = false
	aim_point = player.global_position + Vector2(player.facing * 200.0, -60.0)
