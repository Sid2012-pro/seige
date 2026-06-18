class_name MaterialCard
extends Resource
enum TYPE{
	PHYSICAL,
	HOLY,
	FROST,
	POISON,
	BLIGHT,
	FIRE
}
enum PATTERN {
	SINGLE,
	PIERCE,
	AOE
}
enum RARITY{
	COMMON,
	RARE,
	LEGENDARY
}
@export var card_name: String = ""
@export var card_type: TYPE = TYPE.PHYSICAL
@export var card_pattern: PATTERN = PATTERN.SINGLE
@export var rarity: RARITY = RARITY.COMMON

@export var power:int = 0
@export var weight:int = 0

@export var is_enhanced_pattern:bool = false
@export var status_effects:Array[String] = []
@export var signature_id : String = ""

@export var card_texture: Texture2D
