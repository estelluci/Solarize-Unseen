class_name SpineRig
extends CharacterRig
## Drives a SpineSprite (official spine-godot runtime) from the same RigContext
## the placeholder uses. Drop-in replacement for PlaceholderRig.
##
## Setup (see README "Swapping in Spine"):
##   Player
##   └─ Rig (Node2D, this script)
##      └─ SpineSprite   <- your skeleton data resource, positioned so the
##                          character's feet sit at the Rig origin
##
## This script creates the SpineBoneNodes it needs at runtime, so your Spine
## file only has to follow the naming contract below.
##
## RIGGING CONTRACT (Spine editor):
##   * Animations: idle, run, jump, fall, glide, aim (arm-only overlay), shoot.
##   * Aim:  bone "aim-target" (child of root) + IK constraint "aim-ik" on the
##           front upper/lower arm. Setup-pose mix = 0; code raises it to 1.
##   * Feet: bones "foot-l-target" / "foot-r-target" + IK constraints
##           "foot-l-ik" / "foot-r-ik" on each thigh/shin. Setup-pose mix = 0.
##           Animate legs with normal FK - code only blends IK in to plant
##           the feet when the character is standing still on uneven ground.
##   * Muzzle: bone "muzzle" at the gun tip (optional).
##   * Skins: one per character ("mafia", "fairy") if both share a skeleton.
##
## Everything Spine-specific is called dynamically, so this file still parses
## when the spine-godot runtime is not installed.

@export var sprite_path: NodePath = ^"SpineSprite"

@export_group("Animations")
@export var anim_idle := "idle"
@export var anim_run := "run"
@export var anim_jump := "jump"
@export var anim_fall := "fall"
@export var anim_glide := "glide"
@export var anim_aim := "aim"
@export var anim_shoot := "shoot"
## Horizontal speed at which the run animation plays at 1x.
@export var run_anim_speed := 260.0
@export var mix_time := 0.12

@export_group("Bones and constraints")
@export var aim_target_bone := "aim-target"
@export var aim_ik := "aim-ik"
@export var muzzle_bone := "muzzle"
@export var foot_l_target_bone := "foot-l-target"
@export var foot_r_target_bone := "foot-r-target"
@export var foot_l_ik := "foot-l-ik"
@export var foot_r_ik := "foot-r-ik"
## Horizontal distance from the rig origin to each foot in the idle pose (pixels).
@export var foot_rest_offset_x := 10.0
@export var max_hip_drop := 18.0

const TRACK_LOCO := 0
const TRACK_AIM := 1
const TRACK_SHOT := 2
const BONE_MODE_FOLLOW := 0
const BONE_MODE_DRIVE := 1

var _ok := false
var _sprite: Node2D
var _sprite_base_pos := Vector2.ZERO
var _sprite_base_scale := Vector2.ONE
var _aim_node: Node2D
var _muzzle_node: Node2D
var _foot_nodes: Array[Node2D] = []
var _loco := ""
var _aim_playing := false
var _aim_mix := 0.0
var _foot_mix := 0.0
var _hip_drop := 0.0


func _ready() -> void:
	if not ClassDB.class_exists("SpineSprite"):
		push_error("SpineRig: the spine-godot runtime is not installed. Use PlaceholderRig, or install spine-godot (see README).")
		return
	_sprite = get_node_or_null(sprite_path) as Node2D
	if _sprite == null:
		push_error("SpineRig: no SpineSprite found at '%s'." % sprite_path)
		return
	_sprite_base_pos = _sprite.position
	_sprite_base_scale = _sprite.scale
	_aim_node = _make_bone_node(aim_target_bone, BONE_MODE_DRIVE)
	_muzzle_node = _make_bone_node(muzzle_bone, BONE_MODE_FOLLOW)
	for bone in [foot_l_target_bone, foot_r_target_bone]:
		var n := _make_bone_node(bone, BONE_MODE_DRIVE)
		if n:
			_foot_nodes.append(n)
	_ok = true
	_play_loco(anim_idle)
	if profile:
		apply_profile(profile)


func _make_bone_node(bone: String, mode: int) -> Node2D:
	if bone.is_empty() or _find_bone(bone) == null:
		push_warning("SpineRig: bone '%s' not found in skeleton - feature disabled." % bone)
		return null
	var n := ClassDB.instantiate("SpineBoneNode") as Node2D
	n.name = bone.to_pascal_case()
	n.set("bone_name", bone)
	n.set("bone_mode", mode)
	_sprite.add_child(n)
	return n


func apply_profile(p: CharacterProfile) -> void:
	super(p)
	if not _ok or p.spine_skin.is_empty():
		return
	var skeleton = _sprite.call("get_skeleton")
	skeleton.call("set_skin_by_name", p.spine_skin)
	skeleton.call("set_slots_to_setup_pose")


func update_rig(delta: float, ctx: RigContext) -> void:
	if not _ok:
		return
	_sprite.scale = Vector2(absf(_sprite_base_scale.x) * ctx.facing, _sprite_base_scale.y)

	# ---- locomotion (track 0) -------------------------------------------
	var loco := anim_idle
	if not ctx.on_floor:
		if ctx.gliding:
			loco = anim_glide
		else:
			loco = anim_jump if ctx.velocity.y < 0.0 else anim_fall
	elif absf(ctx.velocity.x) > 12.0:
		loco = anim_run
	_play_loco(loco)
	var state = _sprite.call("get_animation_state")
	var entry = state.call("get_current", TRACK_LOCO)
	if entry != null and _loco == anim_run:
		entry.call("set_time_scale", maxf(0.3, absf(ctx.velocity.x) / run_anim_speed))

	# ---- aiming (track 1 overlay + aim IK) ------------------------------
	if ctx.aiming != _aim_playing and _has_anim(anim_aim):
		if ctx.aiming:
			state.call("set_animation", anim_aim, true, TRACK_AIM)
		else:
			state.call("set_empty_animation", TRACK_AIM, mix_time)
		_aim_playing = ctx.aiming
	_aim_mix = move_toward(_aim_mix, 1.0 if ctx.aiming else 0.0, delta * 8.0)
	_set_ik_mix(aim_ik, _aim_mix)
	if _aim_node:
		_aim_node.global_position = ctx.aim_point

	# ---- foot planting (IK blended in only when standing) --------------
	var plant := ctx.on_floor and absf(ctx.velocity.x) < 30.0
	_foot_mix = move_toward(_foot_mix, 1.0 if plant else 0.0, delta * 6.0)
	var deepest := 0.0
	for i in _foot_nodes.size():
		var x := (i * 2 - 1) * foot_rest_offset_x * ctx.facing
		var gy := probe_ground_local_y(x)
		if is_nan(gy):
			gy = 0.0
		deepest = maxf(deepest, gy)
		_foot_nodes[i].global_position = to_global(Vector2(x, gy))
	_set_ik_mix(foot_l_ik, _foot_mix)
	_set_ik_mix(foot_r_ik, _foot_mix)
	var drop_target := clampf(deepest, 0.0, max_hip_drop) * _foot_mix
	_hip_drop = lerpf(_hip_drop, drop_target, 1.0 - exp(-20.0 * delta))
	_sprite.position = _sprite_base_pos + Vector2(0, _hip_drop)


func on_fire() -> void:
	if _ok and _has_anim(anim_shoot):
		var state = _sprite.call("get_animation_state")
		state.call("set_animation", anim_shoot, false, TRACK_SHOT)
		state.call("add_empty_animation", TRACK_SHOT, mix_time, 0.0)


func get_muzzle_global_position() -> Vector2:
	if _muzzle_node:
		return _muzzle_node.global_position
	return super()


func snap() -> void:
	_hip_drop = 0.0
	_foot_mix = 0.0


# ---------------------------------------------------------------- helpers
func _play_loco(anim_name: String) -> void:
	if anim_name == _loco or not _has_anim(anim_name):
		return
	var state = _sprite.call("get_animation_state")
	var looping := anim_name != anim_jump
	state.call("set_animation", anim_name, looping, TRACK_LOCO)
	_loco = anim_name


func _has_anim(anim_name: String) -> bool:
	var data = _sprite.get("skeleton_data_res")
	if data == null or not data.has_method("find_animation"):
		return true
	return data.call("find_animation", anim_name) != null


func _find_bone(bone: String):
	var skeleton = _sprite.call("get_skeleton")
	return skeleton.call("find_bone", bone) if skeleton != null else null


func _set_ik_mix(constraint_name: String, value: float) -> void:
	var c = _sprite.call("get_skeleton").call("find_ik_constraint", constraint_name)
	if c != null:
		c.call("set_mix", value)
