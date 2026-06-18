extends Node2D

@onready var towers_container: Node2D = $TowersContainer
@onready var map_grid: TileMapLayer = $MapGrid
@onready var dialogue_label: Label = $TutorialCanvas/TutorialUI/DialogueLabel
@onready var action_button: Button = $TutorialCanvas/TutorialUI/ActionButton

var tower_scene = preload("res://Scenes/tower.tscn")
var enemy_scene = preload("res://Scenes/enemy.tscn")
var placement_preview: Node2D = null

enum TutorialState { BUILD_BASE, ACQUIRE_CARD, SOCKET_TOWER, TEST_RUN, COMPLETE }
var current_state: TutorialState = TutorialState.BUILD_BASE

var tutorial_inventory: Array[MaterialCard] = []
var spawned_tutorial_tower: Node2D = null

func _ready() -> void:
	placement_preview = tower_scene.instantiate()
	placement_preview.is_preview = true
	add_child(placement_preview)
	placement_preview.modulate.a = 0.5
	
	action_button.pressed.connect(_on_action_button_pressed)
	update_tutorial_flow()

func _process(_delta: float) -> void:
	if placement_preview and placement_preview.visible:
		var mouse_pos = map_grid.get_global_mouse_position()
		var snapped_pos = get_snapped_position(mouse_pos)
		placement_preview.global_position = snapped_pos
		
		if can_place_tower(mouse_pos):
			placement_preview.modulate = Color(0.3, 1.0, 0.3, 0.6)
		else:
			placement_preview.modulate = Color(1.0, 0.3, 0.3, 0.6)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = map_grid.get_global_mouse_position()
		var target_pos = get_snapped_position(mouse_pos)
		
		if current_state == TutorialState.BUILD_BASE:
			if can_place_tower(mouse_pos):
				spawned_tutorial_tower = tower_scene.instantiate()
				spawned_tutorial_tower.is_preview = false
				towers_container.add_child(spawned_tutorial_tower)
				spawned_tutorial_tower.global_position = target_pos
				
				placement_preview.visible = false
				current_state = TutorialState.ACQUIRE_CARD
				update_tutorial_flow()
				get_viewport().set_input_as_handled()
				
		elif current_state == TutorialState.SOCKET_TOWER:
			if spawned_tutorial_tower:
				if not tutorial_inventory.is_empty():
					var card = tutorial_inventory.pop_back()
					var success = spawned_tutorial_tower.add_material(card)
					if success:
						current_state = TutorialState.TEST_RUN
						update_tutorial_flow()
						get_viewport().set_input_as_handled()

func update_tutorial_flow() -> void:
	match current_state:
		TutorialState.BUILD_BASE:
			dialogue_label.text = "Welcome Commander. Click on a grass tile to build an Empty Tower Base."
			action_button.visible = false
			placement_preview.visible = true
		TutorialState.ACQUIRE_CARD:
			dialogue_label.text = "Bases do nothing on their own. We need to draft raw elements."
			action_button.text = "Take Free Wood Card"
			action_button.visible = true
			placement_preview.visible = false
		TutorialState.SOCKET_TOWER:
			dialogue_label.text = "Click directly on your Empty Base to socket the Wood card into Layer 1!"
			action_button.visible = false
			placement_preview.visible = false
		TutorialState.TEST_RUN:
			dialogue_label.text = "Excellent! Your module is active. Let's test its structural output."
			action_button.text = "Spawn Test Target"
			action_button.visible = true
			placement_preview.visible = false
		TutorialState.COMPLETE:
			dialogue_label.text = "System validation complete. Transitioning your constructed platform to the frontlines..."
			action_button.text = "Deploy to Level 1"
			action_button.visible = true
			placement_preview.visible = false

func _on_action_button_pressed() -> void:
	if current_state == TutorialState.ACQUIRE_CARD:
		var wood_card = load("res://Data/BaseMaterials/wood.tres")
		if wood_card:
			tutorial_inventory.append(wood_card)
		current_state = TutorialState.SOCKET_TOWER
		update_tutorial_flow()
		
	elif current_state == TutorialState.TEST_RUN:
		action_button.visible = false
		var enemy = enemy_scene.instantiate()
		enemy.max_health = 10.0
		enemy.speed = 40.0
		enemy.died.connect(func(_e): 
			current_state = TutorialState.COMPLETE
			update_tutorial_flow()
		)
		$LanePath.add_child(enemy)
		
	elif current_state == TutorialState.COMPLETE:
		if spawned_tutorial_tower:
			GlobalCarryover.starting_tower_materials = spawned_tutorial_tower.socketed_materials
		get_tree().change_scene_to_file("res://Scenes/main.tscn")

func get_snapped_position(raw_pos: Vector2) -> Vector2:
	var tile_coords = map_grid.local_to_map(raw_pos)
	return map_grid.map_to_local(tile_coords)

func can_place_tower(raw_mouse_pos: Vector2) -> bool:
	var tile_coords = map_grid.local_to_map(raw_mouse_pos)
	var tile_data = map_grid.get_cell_tile_data(tile_coords)
	if not tile_data:
		return false
	var is_buildable = tile_data.get_custom_data("buildable")
	if not is_buildable:
		return false
	var target_global_pos = map_grid.map_to_local(tile_coords)
	if spawned_tutorial_tower and spawned_tutorial_tower.global_position.distance_to(target_global_pos) < 4.0:
		return false
	return true
