class_name HumanInput
extends PlayerInput
## Reads one player's actions from the InputMap.
##
## Player 1 uses the unprefixed actions (move_left, jump, ...) plus mouse or
## right-stick aiming. Player 2 uses the "p2_" actions and auto-aims at the
## nearest visible portal, since there is only one mouse.

var prefix := ""
var use_mouse_aim := true


func _init(action_prefix := "", mouse_aim := true, label := "P1") -> void:
	prefix = action_prefix
	use_mouse_aim = mouse_aim
	tag = label


func poll(player: Player, _delta: float) -> void:
	move_x = Input.get_axis(prefix + "move_left", prefix + "move_right")
	jump_pressed = Input.is_action_just_pressed(prefix + "jump")
	jump_held = Input.is_action_pressed(prefix + "jump")
	shoot_pressed = Input.is_action_just_pressed(prefix + "shoot")
	sight_pressed = Input.is_action_just_pressed(prefix + "sight")
	carry_pressed = Input.is_action_just_pressed(prefix + "carry")

	if use_mouse_aim:
		aim_controls_facing = true
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.3:
			aim_point = player.global_position + Vector2(0, -60) + stick.normalized() * 220.0
		else:
			aim_point = player.get_global_mouse_position()
	else:
		aim_controls_facing = false
		aim_point = PlayerInput.auto_aim(player)[0]
