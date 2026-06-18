extends Node2D

const TILE_SIZE: float = 16.0
const AOE_BASE_RADIUS_TILES: float = 1.0
const AOE_ENHANCED_BONUS_TILES: float = 0.5
const PIERCE_BASE_TARGETS: int = 2
const PIERCE_ENHANCED_BONUS_TARGETS: int = 1

signal bonus_gold_earned(amount: int)

@export var socketed_materials: Array[MaterialCard] = []
@export var is_preview: bool = false

@onready var base_platform: Sprite2D = $BasePlatform
@onready var layer_1: Sprite2D = $Layer1_Bottom
@onready var layer_2: Sprite2D = $Layer2_Middle
@onready var layer_3: Sprite2D = $Layer3_Top

var current_stats: TowerStats = TowerStats.new()
var attack_timer: Timer
var flash_laser_to_targets: Array = []

func fire(targets: Array[Node]) -> void:
	flash_laser_to_targets = targets
	queue_redraw()
	
	await get_tree().create_timer(0.1).timeout
	flash_laser_to_targets = []
	queue_redraw()
	
	for enemy in targets:
		if is_instance_valid(enemy):
			enemy.take_damage(current_stats.power)
func _draw() -> void:
	if not flash_laser_to_targets.is_empty():
		for target in flash_laser_to_targets:
			if is_instance_valid(target):
				draw_line(Vector2.ZERO, to_local(target.global_position), Color(1.0, 0.2, 0.2), 2.0)
func _ready() -> void:
	attack_timer = Timer.new()
	attack_timer.one_shot = false
	add_child(attack_timer)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	update_tower()

func add_material(card: MaterialCard) -> bool:
	if socketed_materials.size() >= 3:
		return false
	socketed_materials.append(card)
	update_tower()
	return true

func update_tower() -> void:
	var layers = [layer_1, layer_2, layer_3]
	
	for i in range(layers.size()):
		if i < socketed_materials.size():
			layers[i].texture = socketed_materials[i].card_texture
			layers[i].visible = true
		else:
			layers[i].texture = null
			layers[i].visible = false
			
	current_stats = TowerFormula.compute_tower_stats(socketed_materials)
	
	if current_stats and current_stats.power > 0 and not is_preview:
		if attack_timer:
			attack_timer.wait_time = current_stats.cooldown_speed
			if attack_timer.is_stopped():
				attack_timer.start()
	else:
		if attack_timer:
			attack_timer.stop()
func _on_attack_timer_timeout() -> void:
	var targets = find_targets()
	if targets.is_empty():
		return
	fire(targets)

func find_targets() -> Array[Node]:
	var range_px = current_stats.range_tiles * TILE_SIZE
	var in_range: Array[Node] = []
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= range_px:
			in_range.append(enemy)
			
	if in_range.is_empty():
		return []
		
	in_range.sort_custom(func(a, b): return a.progress_ratio > b.progress_ratio)
	
	match current_stats.pattern:
		MaterialCard.PATTERN.SINGLE:
			return [in_range[0]]
		MaterialCard.PATTERN.PIERCE:
			var target_count = PIERCE_BASE_TARGETS
			if current_stats.is_pattern_enhanced:
				target_count += PIERCE_ENHANCED_BONUS_TARGETS
			return in_range.slice(0, mini(target_count, in_range.size()))
		MaterialCard.PATTERN.AOE:
			var radius_tiles = AOE_BASE_RADIUS_TILES
			if current_stats.is_pattern_enhanced:
				radius_tiles += AOE_ENHANCED_BONUS_TILES
			var radius_px = radius_tiles * TILE_SIZE
			var lead = in_range[0]
			var hit: Array[Node] = []
			for enemy in in_range:
				if enemy.global_position.distance_to(lead.global_position) <= radius_px:
					hit.append(enemy)
			return hit
			
	return []
