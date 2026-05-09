extends Node2D

@onready var path: Path2D = $Path2D
@onready var enemy: PathFollow2D = $Path2D/Enemy

func _ready() -> void:
	var curve := Curve2D.new()
	curve.add_point(Vector2(80, 240))
	curve.add_point(Vector2(640, 240))
	path.curve = curve

	enemy.setup({
		"id": "swarm",
		"name": "Swarm",
		"visual_type": "swarm",
		"hp": 30,
		"max_hp": 30,
		"speed": 60,
		"reward_gold": 5,
		"base_damage": 1,
		"tags": ["swarm"]
	})
	
	
