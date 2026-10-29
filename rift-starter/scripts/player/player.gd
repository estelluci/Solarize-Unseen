class_name Player
extends CharacterBody2D
## Platformer controller shared by both protagonists.
##
## Feel features: acceleration/friction, coyote time, jump buffering,
## variable jump height, faster falling, air jumps and gliding (fairy),
## aiming + hitscan shot (mafia), and carrying the partner (fairy),
## limited by her Pix energy.
##
## The body never reads the keyboard itself: it asks its `input`
## (a PlayerInput). The Party gives it HumanInput for player 1 / player 2 or
## CompanionAI when it's the AI partner, and can swap them at any time.

signal respawned
signal warped
signal carry_started(cargo: Player)
signal carry_ended(cargo: Player)

## The character's BASE stats. At runtime `profile` becomes a copy with all
## owned upgrades applied (see the Upgrades autoload).
@export var profile: CharacterProfile
## Falling below this Y counts as a death.
@export var kill_y := 200.0
@export var shot_range := 900.0
## What shots can hit: world (1) + portals (3).
@export_flags_2d_physics var shot_mask := 1 | 4

@onready var rig: CharacterRig = $Rig
@onready var tracer: Line2D = $Tracer
@onready var tag_label: Label = $Tag
@onready var collision: CollisionShape2D = $CollisionShape2D

var input: PlayerInput = HumanInput.new()
var facing := 1
## Optional: called instead of the normal checkpoint respawn (the Party uses
## this to bring a fallen partner back next to the other character).
var respawn_override: Callable

## Carrying: the Fairy holds `cargo`; the Mafia being held has `carrier`.
var cargo: Player = null
var carrier: Player = null
## Pix energy (only meaningful for characters with profile.can_carry).
var pix := 0.0
## The portal tendril holding this character, if any.
var grabbed_by: PortalTendril = null
## Seconds of safety from tendrils after getting free (so another one
## doesn't snatch you instantly).
var grab_immunity := 0.0
## Outside push for this frame (wind, a boss's suction...). Add to it from
## anywhere; it's applied on the next move and then cleared.
var external_velocity := Vector2.ZERO

const HISTORY_SIZE := 64
const BASE_HEIGHT := 100.0
const BASE_RADIUS := 14.0
## Partner must be within this horizontal distance to be picked up.
const GRAB_RANGE_X := 80.0
## The carried partner is knocked loose if dragged this far from the hang point.
const CARRY_BREAK_DISTANCE := 70.0

var _history: Array[Dictionary] = []
var _coyote := 0.0
var _jump_buffer := 0.0
var _air_jumps_left := 0
var _gliding := false
var _spawn_point := Vector2.ZERO
var _tracer_time := 0.0
var _pix_regen_wait := 0.0
var _ctx := RigContext.new()
var _wall_jump_lock := 0.0
var base_profile: CharacterProfile


func _ready() -> void:
	add_to_group("player")
	_spawn_point = global_position
	rig.setup(self)
	base_profile = profile
	profile = Upgrades.build_profile(base_profile)
	_apply_profile()
	pix = profile.pix_max
	Upgrades.changed.connect(refresh_profile)
	tracer.visible = false
	tracer.top_level = true  # tracer points are in world space


## Size, collision, rig look and Pix meter all come from the profile.
func _apply_profile() -> void:
	var s := profile.body_scale
	rig.scale = Vector2(s, s)
	rig.apply_profile(profile)
	# Each body gets its own capsule so the Fairy's can be smaller.
	var capsule := CapsuleShape2D.new()
	capsule.radius = BASE_RADIUS * s
	capsule.height = BASE_HEIGHT * s
	collision.shape = capsule
	collision.position = Vector2(0, -BASE_HEIGHT * s * 0.5)
	tag_label.position = Vector2(-30, -body_height() - 40.0)
	pix = minf(pix, profile.pix_max)
	if profile.can_carry and not has_node("PixMeter"):
		var meter := PixMeter.new()
		meter.name = "PixMeter"
		add_child(meter)


## Re-apply upgrades (called whenever an upgrade is bought or granted).
func refresh_profile() -> void:
	profile = Upgrades.build_profile(base_profile)
	_apply_profile()


func has_ability(ability: StringName) -> bool:
	return profile.abilities.has(ability)


func body_height() -> float:
	return BASE_HEIGHT * profile.body_scale


func set_input(source: PlayerInput) -> void:
	input = source
	tag_label.text = source.tag
	tag_label.modulate = Color(0.75, 0.75, 0.85, 0.7) if source is CompanionAI else Color(1, 0.9, 0.55)


func _physics_process(delta: float) -> void:
	input.poll(self, delta)
	grab_immunity -= delta
	# Solo lift: P1 (playing the Mafia) steers the AI Fairy, so both bodies
	# share one input. The sight key still belongs to P1's own character — the
	# Mafia being carried — so the Fairy ignores it (no double toggle, and the
	# Solar eye opens, not the Lunar one).
	var shares_input := cargo != null and cargo.input == input

	# --- one-shot actions -------------------------------------------------
	if input.sight_pressed and not shares_input:
		Sight.toggle_eye(profile.sight_eye)
	if input.shoot_pressed and profile.can_aim:
		shoot(input.aim_point)

	if grabbed_by:
		_move_grabbed(delta)
	elif carrier:
		_move_carried(delta)
	elif cargo:
		_move_carrying(delta)
	else:
		_move_normal(delta)
	_update_pix(delta)
	external_velocity = Vector2.ZERO  # pushes only apply to normal movement

	# --- facing -----------------------------------------------------------
	var aiming := profile.can_aim and input.aim_controls_facing
	if aiming:
		var dx := input.aim_point.x - global_position.x
		if absf(dx) > 4.0:
			facing = 1 if dx > 0.0 else -1
	elif carrier:
		facing = carrier.facing
	elif grabbed_by:
		pass
	elif not is_zero_approx(input.move_x):
		facing = 1 if input.move_x > 0.0 else -1

	_record_history()

	if global_position.y > kill_y:
		respawn()

	# --- feed the rig -----------------------------------------------------
	_ctx.velocity = velocity
	_ctx.on_floor = is_on_floor() and carrier == null and grabbed_by == null
	_ctx.facing = facing
	_ctx.run_speed = profile.run_speed
	_ctx.aiming = aiming
	_ctx.aim_point = input.aim_point
	_ctx.gliding = _gliding
	_ctx.carrying = cargo != null
	_ctx.carried = carrier != null or grabbed_by != null
	if grabbed_by:
		_ctx.grip_point = grabbed_by.tip()
	elif cargo:
		_ctx.grip_point = _midpoint(cargo.rig.get_hand_global_positions())
	elif carrier:
		_ctx.grip_point = _midpoint(carrier.rig.get_hand_global_positions())
	rig.update_rig(delta, _ctx)

	_update_tracer(delta)


# ------------------------------------------------------------ movement
func _move_normal(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = profile.coyote_time
		_air_jumps_left = profile.air_jumps
	else:
		_coyote -= delta
	if input.jump_pressed:
		_jump_buffer = profile.jump_buffer_time
	else:
		_jump_buffer -= delta

	var accel := profile.ground_accel if on_floor else profile.air_accel
	if on_floor and is_zero_approx(input.move_x):
		accel = profile.ground_friction
	if _wall_jump_lock > 0.0:
		_wall_jump_lock -= delta  # brief lock so the kick-off isn't cancelled
	else:
		velocity.x = move_toward(velocity.x, input.move_x * profile.run_speed * input.speed_scale, accel * delta)

	var on_wall := not on_floor and is_on_wall_only() and has_ability(&"wall_jump")
	if _jump_buffer > 0.0:
		if _coyote > 0.0:
			_jump()
		elif on_wall:
			_wall_jump()
		elif _air_jumps_left > 0:
			_air_jumps_left -= 1
			_jump()

	var g := profile.gravity
	if velocity.y > 0.0:
		g *= profile.fall_gravity_multiplier
	elif not input.jump_held:
		g *= profile.jump_cut_gravity_multiplier  # short hop
	if not on_floor:
		velocity.y += g * delta

	_gliding = profile.can_glide and not on_floor and velocity.y > 0.0 and input.jump_held
	if _gliding:
		velocity.y = minf(velocity.y, profile.glide_fall_speed)
	# Wall slide: pressing into a wall slows the fall.
	if on_wall and velocity.y > 0.0 and input.move_x * get_wall_normal().x < 0.0:
		velocity.y = minf(velocity.y, profile.wall_slide_speed)
	velocity.y = minf(velocity.y, profile.max_fall_speed)
	# Pushes move you without becoming part of your own momentum.
	velocity += external_velocity
	move_and_slide()
	velocity -= external_velocity


func _jump() -> void:
	velocity.y = -profile.jump_velocity
	_jump_buffer = 0.0
	_coyote = 0.0


## Wall jump ability (from the "Wall Jump" upgrade): kick away from the wall.
func _wall_jump() -> void:
	var away := signf(get_wall_normal().x)
	velocity = Vector2(away * profile.wall_jump_push, -profile.jump_velocity * 0.92)
	facing = int(away)
	_wall_jump_lock = 0.16
	_jump_buffer = 0.0


## Fairy flying with the Mafia: hold jump to climb (costs extra Pix),
## let go to sink slowly. Horizontal speed is reduced by the weight.
func _move_carrying(delta: float) -> void:
	var p := profile
	_gliding = false
	velocity.x = move_toward(velocity.x, input.move_x * p.run_speed * p.carry_speed_multiplier, p.air_accel * delta)
	var lifting := input.jump_held
	var target_vy := -p.carry_rise_speed if lifting else p.carry_sink_speed
	velocity.y = move_toward(velocity.y, target_vy, p.carry_vertical_accel * delta)
	# Once the partner's feet touch the ground, don't sink any lower into him.
	if cargo.is_on_floor() and velocity.y > 0.0 \
			and global_position.y >= cargo.global_position.y - p.carry_hang_distance:
		velocity.y = 0.0
	move_and_slide()

	pix -= (p.pix_carry_drain + (p.pix_lift_drain if lifting else 0.0)) * delta
	if pix <= 0.0:
		pix = 0.0
		end_carry()  # out of Pix: she has to let go


## Being carried: follow the hang point under the carrier. Snagging on the
## level (e.g. flying into a wall) knocks you loose.
func _move_carried(delta: float) -> void:
	_gliding = false
	var hang := carrier.global_position + Vector2(0, carrier.profile.carry_hang_distance)
	velocity = ((hang - global_position) / delta).limit_length(1400.0)
	move_and_slide()
	if carrier != null and global_position.distance_to(hang) > CARRY_BREAK_DISTANCE:
		carrier.end_carry()


## Held by a portal tendril: dragged toward the portal. Every jump press
## weakens its grip.
func _move_grabbed(_delta: float) -> void:
	_gliding = false
	if input.jump_pressed:
		grabbed_by.struggle(profile.struggle_strength)
	if grabbed_by == null:
		return  # broke free; the tendril already flung us clear
	velocity = grabbed_by.pull_velocity()
	move_and_slide()


## Called by a PortalTendril when it catches this character.
func grab_by(tendril: PortalTendril) -> void:
	end_carry()
	if carrier:
		carrier.end_carry()
	grabbed_by = tendril


# ------------------------------------------------------------ carrying + Pix
func can_grab(other: Player) -> bool:
	if not profile.can_carry or other == self:
		return false
	if cargo or carrier or other.cargo or other.carrier:
		return false
	if pix < profile.pix_min_to_grab:
		return false
	var d := other.global_position - global_position
	# Partner must be beside or below us, not way above.
	return absf(d.x) < GRAB_RANGE_X and d.y > -60.0 and d.y < profile.carry_hang_distance + 80.0


func start_carry(other: Player) -> void:
	cargo = other
	other.carrier = self
	# Rise (or line up) so the partner hangs right below.
	var want := other.global_position - Vector2(0, profile.carry_hang_distance)
	move_and_collide(want - global_position)
	velocity = Vector2(velocity.x * 0.5, 0.0)
	other.velocity = Vector2.ZERO
	carry_started.emit(other)


func end_carry() -> void:
	if cargo == null:
		return
	var dropped := cargo
	cargo = null
	dropped.carrier = null
	dropped.velocity = velocity  # keep the momentum
	_pix_regen_wait = profile.pix_regen_delay
	carry_ended.emit(dropped)


func pix_ratio() -> float:
	return pix / profile.pix_max if profile.pix_max > 0.0 else 0.0


func _update_pix(delta: float) -> void:
	if not profile.can_carry or cargo:
		return
	if _pix_regen_wait > 0.0:
		_pix_regen_wait -= delta
	else:
		pix = minf(profile.pix_max, pix + profile.pix_regen * delta)


static func _midpoint(points: Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / maxf(points.size(), 1)


# ------------------------------------------------------------ history
## A short record of recent frames, used by the AI companion to follow.
func _record_history() -> void:
	_history.append({
		"pos": global_position,
		"jump_pressed": input.jump_pressed,
		"jump_held": input.jump_held,
		"on_floor": is_on_floor(),
	})
	if _history.size() > HISTORY_SIZE:
		_history.pop_front()


## The frame recorded `frames_ago` physics frames back (clamped to the oldest).
func get_history_frame(frames_ago: int) -> Dictionary:
	if _history.is_empty():
		return {}
	return _history[maxi(0, _history.size() - 1 - frames_ago)]


func clear_history() -> void:
	_history.clear()


# ------------------------------------------------------------ combat
## Hitscan shot. Anything hit with an `on_shot()` method gets notified.
func shoot(target: Vector2) -> void:
	var from := rig.get_muzzle_global_position()
	var dir := (target - from).normalized()
	if dir == Vector2.ZERO:
		return
	var query := PhysicsRayQueryParameters2D.create(from, from + dir * shot_range, shot_mask, [get_rid()])
	query.collide_with_areas = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var end: Vector2 = hit.position if not hit.is_empty() else from + dir * shot_range
	# Tendrils aren't physics bodies: test the shot line against each visible one.
	# A shot aimed at an open boss core slips past tendrils, unless a tendril
	# is holding someone (then saving your partner comes first).
	var at_open_core: bool = not hit.is_empty() and hit.collider.has_method("is_targetable") and hit.collider.is_targetable()
	var nearest_tendril: PortalTendril = null
	var nearest_d := from.distance_to(end)
	for t in get_tree().get_nodes_in_group("tendrils"):
		if at_open_core and t.state != PortalTendril.State.GRABBING:
			continue
		var d: float = t.hit_distance(from, end)
		if d >= 0.0 and d < nearest_d:
			nearest_d = d
			nearest_tendril = t
	if nearest_tendril:
		nearest_tendril.sever()
		end = from + dir * nearest_d
	elif not hit.is_empty() and hit.collider.has_method("on_shot"):
		hit.collider.on_shot(profile.shot_power)
	tracer.points = PackedVector2Array([from, end])
	tracer.visible = true
	_tracer_time = 0.06
	rig.on_fire()


func _update_tracer(delta: float) -> void:
	if _tracer_time > 0.0:
		_tracer_time -= delta
		if _tracer_time <= 0.0:
			tracer.visible = false


# ------------------------------------------------------------ spawning
func set_checkpoint(point: Vector2) -> void:
	_spawn_point = point


func respawn() -> void:
	if respawn_override.is_valid() and respawn_override.call(self):
		return
	teleport(_spawn_point)
	respawned.emit()


## Appear just behind `other` (used for catch-up and partner respawns).
func warp_near(other: Player) -> void:
	teleport(other.global_position + Vector2(-other.facing * 40.0, -4.0))
	warped.emit()


func teleport(point: Vector2) -> void:
	# Teleporting always breaks a carry or a tendril's grip.
	if grabbed_by:
		grabbed_by.release(false)
	end_carry()
	if carrier:
		carrier.end_carry()
	global_position = point
	velocity = Vector2.ZERO
	_history.clear()
	rig.snap()
