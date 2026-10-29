class_name CharacterRig
extends Node2D
## Base class for anything that *draws* the character.
##
## The player controller talks only to this interface, so you can swap the
## built-in PlaceholderRig for a SpineRig (or anything else) without touching
## gameplay code. Put the rig as a child of the Player, at the player's feet.

## Physics layers the feet raycast against when planting on the ground.
@export_flags_2d_physics var ground_mask := 1

var profile: CharacterProfile
var _body_rid: RID


## Called once by the player.
func setup(body: CollisionObject2D) -> void:
	_body_rid = body.get_rid()


## Called when the active character changes (Mafia <-> Fairy).
func apply_profile(p: CharacterProfile) -> void:
	profile = p


## Called every physics frame with fresh movement data.
func update_rig(_delta: float, _ctx: RigContext) -> void:
	pass


## Called when the character fires (recoil / shoot animation).
func on_fire() -> void:
	pass


## Where bullets / tracers start.
func get_muzzle_global_position() -> Vector2:
	return global_position + Vector2(0, -60)


## Reset any smoothed state (e.g. after a respawn teleport).
func snap() -> void:
	pass


## Where the hands are, in world space (used to draw the carry tether).
func get_hand_global_positions() -> Array:
	return [global_position + Vector2(0, -60), global_position + Vector2(0, -60)]


## Raycasts straight down at `local_x` (in this rig's local space) and returns
## the ground height in LOCAL space (0 = level with the player's feet,
## positive = lower), or NAN if nothing was hit. Works with scaled rigs.
func probe_ground_local_y(local_x: float, look_up := 36.0, look_down := 48.0) -> float:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		to_global(Vector2(local_x, -look_up)),
		to_global(Vector2(local_x, look_down)),
		ground_mask)
	if _body_rid.is_valid():
		query.exclude = [_body_rid]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	return to_local(hit.position).y
