class_name Shop
extends Control

signal purchase_requested(card: Resource, cost: int)
signal reroll_requested(cost: int)
signal closed

const MATERIAL_PATHS: Array[String] = [
	"res://Data/BaseMaterials/wood.tres",
	"res://Data/BaseMaterials/stone.tres",
	"res://Data/BaseMaterials/iron.tres",
	"res://Data/BaseMaterials/silver.tres",
	"res://Data/BaseMaterials/glass.tres",
	"res://Data/BaseMaterials/bone.tres",
	"res://Data/BaseMaterials/tar.tres",
	"res://Data/BaseMaterials/gold.tres",
	"res://Data/BaseMaterials/obsidian.tres"
]

const TROOP_PATHS: Array[String] = [
	"res://Data/Troops/archer.tres",
	"res://Data/Troops/Berserker.tres",
	"res://Data/Troops/Paladin.tres",
	"res://Data/Troops/Cleric.tres",
	"res://Data/Troops/Knight.tres"
]

const MATERIAL_COSTS := {
	MaterialCard.RARITY.COMMON: 3,
	MaterialCard.RARITY.RARE: 6,
	MaterialCard.RARITY.LEGENDARY: 12
}

const LEGENDARY_UNLOCK_WAVE: int = 6
const COMMON_COLOR := Color(0.62, 0.65, 0.7)
const RARE_COLOR := Color(0.35, 0.55, 0.95)
const LEGENDARY_COLOR := Color(0.95, 0.72, 0.25)
const DISABLED_COLOR := Color(0.35, 0.35, 0.38)

var current_wave: int = 1
var available_gold: int = 0
var reroll_cost: int = 1
var offered_cards: Array[Resource] = []
var card_pool: Array[Resource] = []

var gold_label: Label
var title_label: Label
var card_buttons: Array[Button] = []
var reroll_button: Button
var continue_button: Button

func _ready() -> void:
	_build_ui()
	visible = false

func open(start_gold: int, wave_number: int) -> void:
	current_wave = wave_number
	reroll_cost = 1
	_load_card_pool()
	_refresh_offers()
	refresh(start_gold)
	visible = true

func refresh(gold: int) -> void:
	available_gold = gold
	_update_labels()

func _load_card_pool() -> void:
	card_pool.clear()
	for path in MATERIAL_PATHS:
		if ResourceLoader.exists(path):
			var card: MaterialCard = load(path)
			if card and (card.rarity != MaterialCard.RARITY.LEGENDARY or current_wave >= LEGENDARY_UNLOCK_WAVE):
				card_pool.append(card)
		else:
			print("Missing resource: ", path)

	if card_pool.is_empty():
		var emergency_wood = MaterialCard.new()
		emergency_wood.card_name = "Wood (Backup)"
		emergency_wood.rarity = MaterialCard.RARITY.COMMON
		emergency_wood.power = 3
		card_pool.append(emergency_wood)

func _build_ui() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.anchor_left = 0.0
	backdrop.anchor_top = 0.0
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	
	var panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.1, 0.97)
	panel_style.border_color = Color(0.55, 0.42, 0.2)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(14)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	
	title_label = Label.new()
	title_label.text = "SHOP"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	vbox.add_child(title_label) 
	
	gold_label = Label.new()
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	vbox.add_child(gold_label)
	
	var card_row = HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 16)
	vbox.add_child(card_row)
	
	for i in range(4):
		var button = Button.new()
		button.custom_minimum_size = Vector2(150, 150)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_constant_override("icon_max_width", 64)
		button.pressed.connect(_on_card_button_pressed.bind(i))
		card_row.add_child(button)
		card_buttons.append(button)
		
	var bottom_row = HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 24)
	vbox.add_child(bottom_row)
	
	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(140, 44)
	reroll_button.add_theme_font_size_override("font_size", 16)
	reroll_button.pressed.connect(_on_reroll_pressed)
	bottom_row.add_child(reroll_button)
	
	continue_button = Button.new()
	continue_button.text = "Start Wave"
	continue_button.custom_minimum_size = Vector2(140, 44)
	continue_button.add_theme_font_size_override("font_size", 16)
	continue_button.pressed.connect(_on_continue_pressed)
	bottom_row.add_child(continue_button)

func _refresh_offers() -> void:
	offered_cards.clear()
	var pool_copy = card_pool.duplicate()
	pool_copy.shuffle()
	for i in range(card_buttons.size()):
		if i < pool_copy.size():
			offered_cards.append(pool_copy[i])
		else:
			offered_cards.append(null)
	_update_labels()

func _update_labels() -> void:
	if gold_label == null: return
	gold_label.text = "Gold: %d" % available_gold
	for i in range(card_buttons.size()):
		var card = offered_cards[i]
		var button = card_buttons[i]
		if card == null:
			button.text = "—"
			button.icon = null
			button.disabled = true
			_apply_card_style(button, DISABLED_COLOR)
			continue
		var cost = _get_cost(card)
		var card_label = card.card_name
		var texture = card.card_texture
		button.icon = texture
		button.text = "%s\n%dg" % [card_label, cost]
		button.disabled = available_gold < cost
		_apply_card_style(button, _rarity_color(card.rarity))
	reroll_button.text = "Reroll (%dg)" % reroll_cost
	reroll_button.disabled = available_gold < reroll_cost

func _rarity_color(rarity: int) -> Color:
	match rarity:
		1: return RARE_COLOR
		2: return LEGENDARY_COLOR
	return COMMON_COLOR

func _apply_card_style(button: Button, border_color: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_card_style(border_color, 0.95))
	button.add_theme_stylebox_override("hover", _make_card_style(border_color, 1.0))
	button.add_theme_stylebox_override("pressed", _make_card_style(border_color, 0.75))
	button.add_theme_stylebox_override("disabled", _make_card_style(DISABLED_COLOR, 0.5))

func _make_card_style(border_color: Color, alpha: float) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.14, 0.18, alpha)
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8)
	return style

func _get_cost(card: Resource) -> int:
	return MATERIAL_COSTS[card.rarity]

func _on_card_button_pressed(index: int) -> void:
	var card = offered_cards[index]
	if card == null:
		return
	var cost = _get_cost(card)
	if available_gold < cost:
		return
	purchase_requested.emit(card, cost)
	offered_cards[index] = null
	_update_labels()

func _on_reroll_pressed() -> void:
	if available_gold < reroll_cost:
		return
	reroll_requested.emit(reroll_cost)
	reroll_cost += 1
	_refresh_offers()

func _on_continue_pressed() -> void:
	visible = false
	closed.emit()
