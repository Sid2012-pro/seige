class_name TowerStats
extends RefCounted

var power: float = 0.0
var weight: int = 0
var range_tiles: int = 3
var cooldown_speed: float = 1.0
var pattern: MaterialCard.PATTERN = MaterialCard.PATTERN.SINGLE
var is_pattern_enhanced: bool = false
var active_statuses: Array[String] = []
