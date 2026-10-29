class_name StatModifier
extends Resource
## One change to one CharacterProfile stat, e.g. "pix_max ADD 40" or
## "pix_carry_drain MULTIPLY 0.75".
##
## When several upgrades touch the same stat they combine in a fixed order,
## so the result never depends on purchase order:
##   1. SET      (last one wins)
##   2. ADD      (all summed)
##   3. MULTIPLY (all multiplied)

enum Op { ADD, MULTIPLY, SET }

## Name of a CharacterProfile property (e.g. &"run_speed").
@export var stat: StringName
@export var op: Op = Op.ADD
@export var value := 0.0


func describe() -> String:
	match op:
		Op.ADD:
			return "%s %s%s" % [stat, "+" if value >= 0.0 else "", _num(value)]
		Op.MULTIPLY:
			return "%s ×%s" % [stat, _num(value)]
		_:
			return "%s = %s" % [stat, _num(value)]


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.2f" % v
