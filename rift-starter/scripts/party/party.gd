class_name Party
extends Node
## Owns the two protagonists and decides who controls whom.
##
## SOLO: player 1 controls the leader and the other character follows as an
##       AI companion. Tab swaps which character you play.
## COOP: player 2 controls the other character. Player 2 joins by pressing
##       any of their keys or buttons (drop-in). F2 switches back to the AI.
##
## CARRY: either player presses carry (P1: F, P2: .) near the partner and the
##       Fairy picks the Mafia up. Whoever steers the Fairy flies the pair; the
##       hold lasts as long as her Pix energy. In solo, if you play the Mafia,
##       you "call for a lift" and steer the AI Fairy yourself while carried.

signal changed

enum Mode { SOLO, COOP }

@export var first_path: NodePath    ## starts as player 1's character
@export var second_path: NodePath   ## starts as the companion
@export var camera_path: NodePath
## In co-op, player 2 is pulled back to player 1 beyond this distance.
@export var coop_tether_distance := 1100.0

var mode := Mode.SOLO
var leader: Player    ## controlled by player 1
var partner: Player   ## AI companion (SOLO) or player 2 (COOP)

var _p1 := HumanInput.new("", true, "P1")
var _p2 := HumanInput.new("p2_", false, "P2")
var _ai := CompanionAI.new()
var _camera: PartyCamera
var _tether: CarryTether

const P2_JOIN_ACTIONS := ["p2_jump", "p2_move_left", "p2_move_right", "p2_sight", "p2_shoot", "p2_carry"]


func _ready() -> void:
	add_to_group("party")
	leader = get_node(first_path)
	partner = get_node(second_path)
	_camera = get_node_or_null(camera_path)
	for member in [leader, partner]:
		member.respawn_override = _on_member_died
		member.carry_started.connect(_on_carry_started.bind(member))
		member.carry_ended.connect(_on_carry_ended.bind(member))
	_tether = CarryTether.new()
	_tether.name = "CarryTether"
	add_child(_tether)
	_assign()


func _unhandled_input(event: InputEvent) -> void:
	if Cutscenes.is_playing:
		return
	if event.is_action_pressed("swap"):
		swap()
	elif event.is_action_pressed("coop_toggle"):
		set_mode(Mode.SOLO if mode == Mode.COOP else Mode.COOP)


func _physics_process(_delta: float) -> void:
	if Cutscenes.is_playing:
		return
	_handle_carry_input()
	if mode == Mode.SOLO:
		for action in P2_JOIN_ACTIONS:
			if Input.is_action_just_pressed(action):
				set_mode(Mode.COOP)
				break
	elif leader.global_position.distance_to(partner.global_position) > coop_tether_distance:
		partner.warp_near(leader)


## Swap which character player 1 controls (in co-op, the players trade characters).
func swap() -> void:
	carrier_of_party().end_carry()
	var previous := leader
	leader = partner
	partner = previous
	_assign()


func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	_assign()


## Re-apply who controls whom (used after cutscenes hand control back).
func reassign() -> void:
	_assign()


func _assign() -> void:
	if Cutscenes.is_playing:
		return  # the cutscene director owns the inputs right now
	leader.set_input(_p1)
	if mode == Mode.SOLO:
		_ai.leader = leader
		partner.set_input(_ai)
		# In solo, the sight eye always belongs to the character you're playing.
		Sight.set_eye(leader.profile.sight_eye)
	else:
		partner.set_input(_p2)
	if _camera:
		_camera.targets = [leader, partner]
		_camera.frame_everyone = mode == Mode.COOP
	changed.emit()


# ---------------------------------------------------------------- carrying
## The party member who can carry (the Fairy).
func carrier_of_party() -> Player:
	return leader if leader.profile.can_carry else partner


func _handle_carry_input() -> void:
	# Both bodies may share one input (solo lift), so count each source once.
	var pressed := false
	var seen := {}
	for member in [leader, partner]:
		if member.input.carry_pressed and not seen.has(member.input):
			seen[member.input] = true
			pressed = true
	if not pressed:
		return
	var fairy := carrier_of_party()
	var other := partner if fairy == leader else leader
	if fairy.cargo:
		fairy.end_carry()
	elif fairy.can_grab(other):
		fairy.start_carry(other)


func _on_carry_started(_cargo: Player, carrier: Player) -> void:
	_tether.carrier = carrier
	# Solo, playing the Mafia: player 1 steers the AI Fairy during the lift.
	if carrier.input is CompanionAI:
		carrier.set_input(_p1)


func _on_carry_ended(_cargo: Player, _carrier: Player) -> void:
	_assign()


## Respawn rules: a fallen partner reappears next to the other character when
## that character is safely on the ground. The solo leader uses checkpoints.
func _on_member_died(member: Player) -> bool:
	var other := partner if member == leader else leader
	if mode == Mode.SOLO and member == leader:
		return false
	if other.is_on_floor():
		member.warp_near(other)
		return true
	return false
