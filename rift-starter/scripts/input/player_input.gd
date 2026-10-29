class_name PlayerInput
extends RefCounted
## Where a Player's "intent" comes from each physics frame.
##
## The Player never reads the keyboard directly - it asks its PlayerInput.
## That lets the same body be driven by player 1, player 2 or the AI
## companion, and lets the Party hand bodies between them at any time.

var move_x := 0.0
## Multiplies top speed. The AI uses it to rubber-band back to the leader.
var speed_scale := 1.0
var jump_pressed := false  ## true only on the frame jump was pressed
var jump_held := false
var shoot_pressed := false
var sight_pressed := false
var carry_pressed := false  ## grab / let go of the partner
var aim_point := Vector2.ZERO
## True if this source wants aim to override facing (mouse / stick).
var aim_controls_facing := false

## Short label shown above the character ("P1", "P2", "AI").
var tag := ""


## Fill in the fields above. Called by the Player at the start of each physics frame.
func poll(_player: Player, _delta: float) -> void:
	pass


## Aim helper: the nearest *visible* portal in front of the player within
## `max_range`, or the player's forward direction if there is none.
## Returns [aim_point: Vector2, found_target: bool].
## `look_behind`: also consider targets behind (the AI turns around to shoot).
static func auto_aim(player: Player, max_range := 450.0, look_behind := false) -> Array:
	var chest := player.global_position + Vector2(0, -60)
	# First priority: a visible tendril holding someone in the party.
	for tendril in player.get_tree().get_nodes_in_group("tendrils"):
		if tendril.victim != null and tendril.can_be_seen() \
				and chest.distance_to(tendril.tip()) < max_range:
			return [tendril.global_position.lerp(tendril.tip(), 0.6), true]
	var best: Node2D = null
	var best_d := max_range
	for portal in player.get_tree().get_nodes_in_group("portals"):
		if not Sight.can_see(portal.for_eye) or portal.is_sealing():
			continue
		# Bosses (and anything else) can say "not right now" — e.g. a shielded core.
		if portal.has_method("is_targetable") and not portal.is_targetable():
			continue
		var dx: float = portal.global_position.x - player.global_position.x
		if not look_behind and dx * player.facing < -20.0:
			continue  # behind us
		var d := chest.distance_to(portal.global_position)
		if d < best_d:
			best_d = d
			best = portal
	if best:
		return [best.global_position, true]
	return [chest + Vector2(player.facing * 200.0, 0.0), false]
