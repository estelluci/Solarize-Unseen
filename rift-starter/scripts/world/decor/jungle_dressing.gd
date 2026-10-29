class_name JungleDressing
extends Node2D
## Scatters JunglePlants along the tops of every Ground in the level when the
## game starts: palms and banana plants behind the action, ferns and
## monstera in front. Seeded, so the jungle looks the same every run.
## Hand-placed JunglePlants work alongside it; set `density` to 0 to turn the
## automatic dressing off.

@export_range(0.0, 2.0) var density := 1.0
@export var seed_value := 7
## Keep plants this far from these x positions (doorways, signs, triggers).
@export var keep_clear: PackedFloat32Array = []
@export var keep_clear_radius := 60.0


func _ready() -> void:
	if density <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var back := Node2D.new()
	back.name = "Back"
	back.z_index = -2
	add_child(back)
	var front := Node2D.new()
	front.name = "Front"
	front.z_index = 4
	add_child(front)
	for ground in get_tree().get_nodes_in_group("ground"):
		if not ground.style == Ground.Style.JUNGLE:
			continue
		for e in ground.top_edges(30.0):
			var a: Vector2 = ground.to_global(e[0])
			var b: Vector2 = ground.to_global(e[1])
			var length := a.distance_to(b)
			if length < 60.0:
				continue
			var x := rng.randf_range(10.0, 90.0)
			while x < length - 20.0:
				var p := a.lerp(b, x / length) + Vector2(0, 4)
				if not _blocked(p.x):
					_place(rng, back, front, p, length)
				x += rng.randf_range(90.0, 220.0) / density


func _blocked(x: float) -> bool:
	for c in keep_clear:
		if absf(x - c) < keep_clear_radius:
			return true
	return false


func _place(rng: RandomNumberGenerator, back: Node2D, front: Node2D, at: Vector2, edge_length: float) -> void:
	var plant := JunglePlant.new()
	plant.position = at
	plant.flip = rng.randf() < 0.5
	plant.variation = rng.randi() % 10
	var roll := rng.randf()
	if roll < 0.62 or edge_length < 200.0:
		# Behind the characters.
		var options := [JunglePlant.Kind.PALM, JunglePlant.Kind.BANANA, JunglePlant.Kind.HIBISCUS,
			JunglePlant.Kind.MONSTERA, JunglePlant.Kind.BAMBOO]
		plant.kind = options[rng.randi() % options.size()]
		match plant.kind:
			JunglePlant.Kind.PALM: plant.height = rng.randf_range(170.0, 260.0)
			JunglePlant.Kind.BANANA: plant.height = rng.randf_range(110.0, 160.0)
			JunglePlant.Kind.BAMBOO: plant.height = rng.randf_range(150.0, 230.0)
			_: plant.height = rng.randf_range(50.0, 80.0)
		plant.shade = rng.randf_range(-0.35, -0.15)
		back.add_child(plant)
	else:
		# Low foreground plants that frame the scene without hiding anyone.
		plant.kind = JunglePlant.Kind.FERN if rng.randf() < 0.6 else JunglePlant.Kind.MONSTERA
		plant.height = rng.randf_range(24.0, 38.0)
		plant.shade = rng.randf_range(0.0, 0.1)
		plant.modulate.a = 0.92
		front.add_child(plant)
