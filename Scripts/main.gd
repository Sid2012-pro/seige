extends Node2D

@onready var towers_container: Node2D = $TowersContainer  
@onready var lane_path: Path2D = $LanePath  
@onready var map_grid: TileMapLayer = $MapGrid  
@onready var wave_label: Label = $GameUI/WaveLabel 

var current_wave_index :int = 0
var total_waves_in_level = 10
var tower_scene = preload("res://Scenes/tower.tscn")  
var enemy_scene = preload("res://Scenes/enemy.tscn")  
var placement_preview: Node2D = null  

var gold: int = 25  
var current_wave: int = 1  
var shop: Shop  

var held_cards_for_upgrade: Array[MaterialCard] = []  
var selected_card_index: int = -1  

var inventory_container: VBoxContainer
var slot_panels: Array[Panel] = []

var type_colors := {
	0: Color(0.5, 0.5, 0.55),
	1: Color(0.95, 0.8, 0.3),
	2: Color(0.3, 0.65, 0.9),
	3: Color(0.25, 0.7, 0.3),
	4: Color(0.55, 0.25, 0.7),
	5: Color(0.9, 0.35, 0.2)
}
var base_health: int = 20

func damage_base(amount: int) -> void:
	base_health -= amount
	print("Base Health Remaining: ", base_health)
	
	if base_health <= 0:
		trigger_game_over()

func trigger_game_over() -> void:
	Engine.time_scale = 0.0
	$CanvasLayer/GameOverPanel.show() 
func _ready() -> void:
	placement_preview = tower_scene.instantiate()  
	placement_preview.is_preview = true  
	add_child(placement_preview)  
	placement_preview.modulate.a = 0.5  
	
	var shop_layer = CanvasLayer.new()  
	add_child(shop_layer)  
	
	shop = Shop.new()  
	shop_layer.add_child(shop)  
	shop.visible = false  
	
	shop.purchase_requested.connect(_on_purchase_requested)  
	shop.reroll_requested.connect(_on_reroll_requested)  
	shop.closed.connect(_on_shop_closed)  

	var inv_layer = CanvasLayer.new()
	add_child(inv_layer)

	inventory_container = VBoxContainer.new()
	inventory_container.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	inventory_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	inventory_container.add_theme_constant_override("separation", 10)
	inventory_container.offset_right = -20
	inv_layer.add_child(inventory_container)

	for i in range(5):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(56, 56)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var tex = TextureRect.new()
		tex.name = "CardTexture"
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex)
		
		var fallback_lbl = Label.new()
		fallback_lbl.name = "FallbackLabel"
		fallback_lbl.set_anchors_preset(Control.PRESET_CENTER)
		fallback_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
		fallback_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
		fallback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback_lbl.add_theme_font_size_override("font_size", 13)
		fallback_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		fallback_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(fallback_lbl)
		
		var bind_lbl = Label.new()
		bind_lbl.name = "HotkeyLabel"
		bind_lbl.text = str(i + 1)
		bind_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bind_lbl.offset_left = 5
		bind_lbl.offset_top = 2
		bind_lbl.add_theme_font_size_override("font_size", 11)
		bind_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		bind_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(bind_lbl)
		
		inventory_container.add_child(slot)
		slot_panels.append(slot)

	_update_inventory_ui()

	if not GlobalCarryover.starting_tower_materials.is_empty():  
		var spawn_pos = map_grid.to_global(map_grid.map_to_local(Vector2i(8, 5)))  
		var carryover_tower = tower_scene.instantiate()  
		carryover_tower.is_preview = false  
		towers_container.add_child(carryover_tower)  
		carryover_tower.global_position = spawn_pos  
		carryover_tower.bonus_gold_earned.connect(_on_bonus_gold_earned)  
		
		for mat in GlobalCarryover.starting_tower_materials:  
			carryover_tower.add_material(mat)  

	start_wave(5)  

func _process(_delta: float) -> void:
	if placement_preview:  
		var mouse_pos = map_grid.get_local_mouse_position()
		var snapped_pos = get_snapped_position(mouse_pos)
		placement_preview.global_position = snapped_pos  
		
		if selected_card_index != -1:  
			placement_preview.visible = false  
			return  
		else:
			placement_preview.visible = true  
			
		if can_place_tower(mouse_pos):  
			placement_preview.modulate = Color(0.3, 1.0, 0.3, 0.6)  
		else:
			placement_preview.modulate = Color(1.0, 0.3, 0.3, 0.6)  

func _unhandled_input(event: InputEvent) -> void:
	if shop and shop.visible:  
		return  
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:  
		var mouse_pos = map_grid.get_local_mouse_position()
		var target_pos = get_snapped_position(mouse_pos)
		
		var clicked_tower = get_tower_at_position(target_pos)  
		
		if clicked_tower != null:  
			if selected_card_index != -1 and selected_card_index < held_cards_for_upgrade.size():  
				var card_to_apply = held_cards_for_upgrade[selected_card_index]  
				var success = clicked_tower.add_material(card_to_apply)  
				if success:  
					print("Upgraded tower with: ", card_to_apply.card_name)  
					held_cards_for_upgrade.remove_at(selected_card_index)  
					selected_card_index = -1  
					_update_inventory_ui()
					SoundManager.play("upgrade")
			return  
			
		if clicked_tower == null and can_place_tower(mouse_pos):  
			spawn_empty_base_tower(target_pos)  
			
	if event is InputEventKey and event.pressed:  
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:  
			var target_idx = event.keycode - KEY_1  
			if target_idx < held_cards_for_upgrade.size():  
				selected_card_index = target_idx  
				print("Selected card index: ", selected_card_index, " (", held_cards_for_upgrade[selected_card_index].card_name, ")")  
				_update_inventory_ui()
			else:
				print("No card in inventory slot ", target_idx + 1)

func get_snapped_position(raw_pos: Vector2) -> Vector2:
	var tile_coords = map_grid.local_to_map(raw_pos)  
	return map_grid.to_global(map_grid.map_to_local(tile_coords))  

func get_tower_at_position(target_global_pos: Vector2) -> Node2D:
	for active_tower in towers_container.get_children():  
		if active_tower.global_position.distance_to(target_global_pos) < 4.0:  
			return active_tower  
	return null  

func can_place_tower(raw_mouse_pos: Vector2) -> bool:
	var tile_coords = map_grid.local_to_map(raw_mouse_pos)  
	var tile_data = map_grid.get_cell_tile_data(tile_coords)  
	if not tile_data:  
		return false  
	var is_buildable = tile_data.get_custom_data("buildable")  
	if not is_buildable:  
		return false  
	var target_global_pos = map_grid.to_global(map_grid.map_to_local(tile_coords))  
	if get_tower_at_position(target_global_pos) != null:  
		return false  
	return true  

func spawn_empty_base_tower(target_pos: Vector2) -> void:
	var new_tower = tower_scene.instantiate()
	new_tower.is_preview = false
	towers_container.add_child(new_tower)
	new_tower.global_position = target_pos
	new_tower.bonus_gold_earned.connect(_on_bonus_gold_earned)
	SoundManager.play("place_tower")
func _on_purchase_requested(card: Resource, cost: int) -> void:
	if gold >= cost:  
		if card is MaterialCard:  
			if held_cards_for_upgrade.size() >= 5:  
				print("Inventory full! Cannot hold more than 5 cards.")
				return  
				
			gold -= cost  
			shop.refresh(gold)  
			SoundManager.play("purchase")
			
			held_cards_for_upgrade.append(card)  
			selected_card_index = held_cards_for_upgrade.size() - 1  
			print("Purchased ", card.card_name, ". Hand Slot: ", held_cards_for_upgrade.size())  
			_update_inventory_ui()

func _on_reroll_requested(cost: int) -> void:
	if gold >= cost:  
		gold -= cost  
		shop.refresh(gold)  

func _on_shop_closed() -> void:
	current_wave += 1  
	start_wave(5 + (current_wave * 2))  

func _on_bonus_gold_earned(amount: int) -> void:
	gold += amount  
	if shop.visible:  
		shop.refresh(gold)  

func start_wave(count: int) -> void:
	current_wave_index += 1 
	for i in range(count):  
		wave_label.text = "Wave: " + str(current_wave_index) + " / " + str(total_waves_in_level)
		var enemy = enemy_scene.instantiate()  
		enemy.max_health = 18.0 * pow(1.16, current_wave - 1)  
		enemy.died.connect(_on_enemy_died)  
		lane_path.add_child(enemy)  
		await get_tree().create_timer(2.5).timeout  
	
	watch_for_wave_clear()  

func watch_for_wave_clear() -> void:
	while lane_path.get_child_count() > 0:  
		await get_tree().create_timer(0.5).timeout  
	_on_wave_cleared()  

func _on_wave_cleared() -> void:
	if current_wave_index < total_waves_in_level:
		var interest = mini(gold / 5, 5)  
		gold += 4 + interest  
		shop.open(gold, current_wave)  
		SoundManager.play("enemy_die")
	else:
		get_tree().change_scene_to_file("res://Scenes/victory.tscn")
func _on_enemy_died(enemy: Node) -> void:
	gold += enemy.bounty  
	if shop.visible:  
		shop.refresh(gold)  

func _update_inventory_ui() -> void:
	for i in range(5):
		var slot = slot_panels[i]
		var tex = slot.get_node("CardTexture") as TextureRect
		var fallback_lbl = slot.get_node("FallbackLabel") as Label
		var bind_lbl = slot.get_node("HotkeyLabel") as Label
		
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		
		if i < held_cards_for_upgrade.size():
			var card = held_cards_for_upgrade[i]
			var element_color = type_colors.get(int(card.card_type), Color(0.4, 0.4, 0.4))
			
			if card.card_texture != null:
				tex.texture = card.card_texture
				tex.visible = true
				fallback_lbl.visible = false
				style.bg_color = Color(0.12, 0.12, 0.14, 0.85)
			else:
				tex.texture = null
				tex.visible = false
				fallback_lbl.visible = true
				fallback_lbl.text = card.card_name.substr(0, 3).to_upper()
				style.bg_color = element_color.darkened(0.5)
				style.bg_color.a = 0.85
			
			if i == selected_card_index:
				style.set_border_width_all(2)
				style.border_color = Color(0.98, 0.86, 0.36)
				bind_lbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.36))
			else:
				style.set_border_width_all(1)
				style.border_color = element_color
				bind_lbl.add_theme_color_override("font_color", Color.WHITE)
		else:
			tex.texture = null
			tex.visible = false
			fallback_lbl.visible = false
			
			style.bg_color = Color(0.06, 0.06, 0.08, 0.35)
			style.set_border_width_all(1)
			style.border_color = Color(0.16, 0.16, 0.2)
			bind_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			
		slot.add_theme_stylebox_override("panel", style)
