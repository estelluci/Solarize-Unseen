class_name CompanionAI
extends PlayerInput
## Drives the character you are NOT playing so it tags along as a partner.
##
## Core idea (the "Tails" trick from Sonic 2): the leader records a short
## history of where it was and when it jumped. The companion walks toward
## where the leader was a few frames ago and replays those jumps, so it
## naturally takes the same route. A few heuristics patch the gaps:
##   * jump when blocked by a wall, at a gap, or when the trail goes up
##   * fairy: glide across gaps, use the air jump to climb
##   * warp to the leader when too far behind or stuck (standard "catch up")
##   * mafia: shoots portals the party can currently see

## How far behind the leader's trail the companion walks (physics frames).
var trail_delay := 14
## Don't crowd the leader when it stands still.
var personal_space := 60.0
## Beyond this distance the companion warps to the leader.
var catch_up_distance := 650.0
var stuck_warp_time := 1.6
var shoot_interval := 0.55
## How fast the AI mashes jump when a tendril grabs it.
var mash_interval := 0.22

var leader: Player

var _stuck_time := 0.0
var _unreachable_time := 0.0
var _hold_jump_time := 0.0
var _jump_cooldown := 0.0
var _shoot_cooldown := 0.0
var _air_jump_used := false
var _mash_time := 0.0


func _init(leader_body: Player = null) -> void:
	leader = leader_body
	tag = "AI"


func poll(player: Player, delta: float) -> void:
	move_x = 0.0
	jump_pressed = false
	jump_held = false
	shoot_pressed = false
	sight_pressed = false
	carry_pressed = false
	aim_controls_facing = false
	_jump_cooldown -= delta
	_shoot_cooldown -= delta
	_hold_jump_time -= delta

	if leader == null or not is_instance_valid(leader):
		aim_point = player.global_position + Vector2(player.facing * 200.0, -60.0)
		return

	# Grabbed by a tendril: struggle (mash jump) and shoot back if possible.
	if player.grabbed_by != null:
		_mash_time -= delta
		if _mash_time <= 0.0:
			jump_pressed = true
			_mash_time = mash_interval
		_shoot_at_portals(player)
		return

	# While being carried, just help out: aim and shoot at visible portals.
	if player.carrier != null:
		move_x = 0.0
		_shoot_at_portals(player)
		return

	var pos := player.global_position
	var on_floor := player.is_on_floor()
	if on_floor:
		_air_jump_used = false
	var dist := pos.distance_to(leader.global_position)
	# Rubber-band: run a bit faster when falling behind (the fairy is slower).
	speed_scale = 1.2 if dist > 140.0 else 1.0

	# ---- catch up --------------------------------------------------------
	if dist > catch_up_distance:
		player.warp_near(leader)
		return

	# ---- where to go: the leader's position a few frames ago -------------
	var frame := leader.get_history_frame(trail_delay)
	var target: Vector2 = frame.get("pos", leader.global_position)
	var dx := target.x - pos.x
	var leader_dx := leader.global_position.x - pos.x
	var leader_idle := absf(leader.velocity.x) < 10.0 and leader.is_on_floor()

	if leader_idle and absf(leader_dx) < personal_space:
		move_x = 0.0
	elif absf(dx) > 8.0:
		move_x = signf(dx)
	elif absf(leader_dx) > personal_space:
		move_x = signf(leader_dx)

	# ---- jumping ---------------------------------------------------------
	var want_jump := false
	# 1. Replay the leader's jumps from the trail.
	if frame.get("jump_pressed", false) and absf(dx) < 90.0:
		want_jump = true
	if on_floor and _jump_cooldown <= 0.0 and move_x != 0.0:
		# 2. Blocked by a wall.
		if player.is_on_wall():
			want_jump = true
		# 3. Gap ahead while the trail continues past it.
		elif absf(dx) > 40.0 and not _ground_ahead(player, move_x):
			want_jump = true
	# 4. Trail goes clearly upward (ledges, platforms) - only toward places the
	#    leader actually stood on, not toward a leader who is flying.
	if on_floor and _jump_cooldown <= 0.0 and target.y < pos.y - 50.0 and absf(dx) < 140.0 \
			and frame.get("on_floor", true):
		want_jump = true

	if want_jump and on_floor:
		jump_pressed = true
		_hold_jump_time = 0.3
		_jump_cooldown = 0.35
	elif not on_floor:
		var profile := player.profile
		# Fairy: air jump to climb toward a higher trail point, once per airtime.
		if profile.air_jumps > 0 and not _air_jump_used and player.velocity.y > 0.0 \
				and target.y < pos.y - 30.0:
			jump_pressed = true
			_air_jump_used = true
			_hold_jump_time = 0.3
		# Fairy: glide while there is still distance to cover.
		if profile.can_glide and player.velocity.y > 0.0 and absf(dx) > 40.0:
			_hold_jump_time = 0.1
	jump_held = _hold_jump_time > 0.0 or bool(frame.get("jump_held", false))

	# ---- stuck detection -------------------------------------------------
	if move_x != 0.0 and absf(player.velocity.x) < 5.0 and dist > 150.0:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	# Leader is standing somewhere this character can't reach (e.g. the fairy ledge).
	if on_floor and leader.is_on_floor() and leader.global_position.y < pos.y - 60.0:
		_unreachable_time += delta
	else:
		_unreachable_time = 0.0
	if _stuck_time > stuck_warp_time or _unreachable_time > stuck_warp_time * 1.5:
		_stuck_time = 0.0
		_unreachable_time = 0.0
		player.warp_near(leader)
		return

	_shoot_at_portals(player)


func _shoot_at_portals(player: Player) -> void:
	var aim := PlayerInput.auto_aim(player, 900.0, true)
	aim_point = aim[0]
	if player.profile.can_aim and aim[1]:
		aim_controls_facing = true
		if _shoot_cooldown <= 0.0:
			shoot_pressed = true
			_shoot_cooldown = shoot_interval


func _ground_ahead(player: Player, dir: float) -> bool:
	var from := player.global_position + Vector2(dir * 34.0, -10.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 90), 1, [player.get_rid()])
	return not player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
