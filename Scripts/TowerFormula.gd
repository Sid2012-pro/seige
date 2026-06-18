class_name TowerFormula
extends Node

static func compute_tower_stats(sockets: Array[MaterialCard]) -> TowerStats:
	var stats = TowerStats.new()
	if sockets.is_empty():
		return stats
		
	var raw_power: float = 0.0
	var total_weight: int = 0
	var types_present: Array[MaterialCard.TYPE] = []
	var statuses: Array[String] = []
	
	for card in sockets:
		raw_power += card.power
		total_weight += card.weight
		
		if not types_present.has(card.card_type):
			types_present.append(card.card_type)
			
		for status in card.status_effects:
			if not statuses.has(status):
				statuses.append(status)
				
	stats.weight = total_weight

	var multiplier = 1.0 + (0.1 * sockets.size())
	stats.power = raw_power * multiplier
	stats.active_statuses = statuses
	stats.range_tiles = maxi(3, 7 - (total_weight / 2))
	stats.cooldown_speed = snapping_round(0.8 + (0.12 * total_weight))
	calculate_pattern(sockets, stats)
	
	return stats

static func calculate_pattern(sockets: Array[MaterialCard], stats: TowerStats) -> void:
	if sockets.size() == 1:
		stats.pattern = sockets[0].card_pattern
		stats.is_pattern_enhanced = sockets[0].is_enhanced_pattern
		return
		
	var all_match: bool = true
	var first_pattern = sockets[0].card_pattern
	for card in sockets:
		if card.card_pattern != first_pattern:
			all_match = false
			break
			
	if all_match:
		stats.pattern = first_pattern
		stats.is_pattern_enhanced = true
		return
		
	var highest_priority: MaterialCard.PATTERN = MaterialCard.PATTERN.SINGLE
	var winning_card: MaterialCard = sockets[0]
	
	for card in sockets:
		if card.card_pattern == MaterialCard.PATTERN.AOE:
			highest_priority = MaterialCard.PATTERN.AOE
			winning_card = card
			break
		elif card.card_pattern == MaterialCard.PATTERN.PIERCE:
			highest_priority = MaterialCard.PATTERN.PIERCE
			winning_card = card
			
	stats.pattern = highest_priority
	stats.is_pattern_enhanced = winning_card.is_enhanced_pattern

static func snapping_round(val: float) -> float:
	return round(val * 100.0) / 100.0
