extends PathFollow2D

signal died(enemy: PathFollow2D)

@export var speed: float = 60.0
@export var max_health: float = 20.0
@export var bounty: int = 1

var current_health: float

func _ready() -> void:
	current_health = max_health
	loop = false
	add_to_group("enemies")

func _process(delta: float) -> void:
	progress += speed * delta
	if progress_ratio >= 1.0:
		if get_tree().current_scene.has_method("damage_base"):
			get_tree().current_scene.damage_base(1)
		queue_free()

func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0:
		die()

func reached_base() -> void:
	queue_free()

func die() -> void:
	died.emit(self)
	queue_free()
