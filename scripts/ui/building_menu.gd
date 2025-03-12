# Building Menu UI - Simple implementation for testing
# Path: scripts/ui/building_menu.gd
extends Control

# Signals
signal building_selected(building_type)
signal menu_closed

# Properties
var visible_buildings: Array = []
var current_team: int = 0

# Node references
onready var building_grid = $Panel/BuildingGrid
onready var close_button = $Panel/CloseButton
onready var title_label = $Panel/TitleLabel

# External references
var economy_manager
var building_manager
var tech_tree_manager

# Ready function
func _ready() -> void:
	# Connect button signals
	close_button.connect("pressed", self, "_on_close_button_pressed")
	
	# Get references to managers
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		economy_manager = game_manager.economy_manager
		building_manager = game_manager.building_manager
		tech_tree_manager = game_manager.get_node_or_null("TechTreeManager")
	
	# Hide the menu initially
	visible = false

# Populate the menu with available buildings
func populate_buildings(team: int) -> void:
	current_team = team
	
	# Clear existing buttons
	for child in building_grid.get_children():
		child.queue_free()
	
	visible_buildings.clear()
	
	# Get available buildings
	var available_buildings = []
	
	if building_manager:
		available_buildings = building_manager.get_available_buildings(team)
	else:
		# Fallback - provide some test buildings if building manager isn't available
		available_buildings = [
			{
				"id": "barracks",
				"name": "Barracks",
				"cost": 100,
				"size": Vector2(2, 2),
				"description": "Trains basic infantry units"
			},
			{
				"id": "lumber_mill",
				"name": "Lumber Mill",
				"cost": 80,
				"size": Vector2(2, 2),
				"description": "Increases wood income"
			},
			{
				"id": "farm",
				"name": "Farm",
				"cost": 50,
				"size": Vector2(1, 1),
				"description": "Increases supply limit"
			}
		]
	
	# Create buttons for each building
	for i in range(available_buildings.size()):
		var building_data = available_buildings[i]
		visible_buildings.append(building_data)
		
		var button = Button.new()
		button.text = building_data.name
		button.hint_tooltip = "%s\nCost: %d gold\nSize: %dx%d" % [
			building_data.description, 
			building_data.cost,
			building_data.size.x, 
			building_data.size.y
		]
		
		# Add cost indicator if economy manager is available
		if economy_manager:
			var can_afford = economy_manager.can_afford_building(team, building_data.id)
			if not can_afford:
				button.modulate = Color(1, 0.5, 0.5)  # Red tint if can't afford
		
		# Connect button press
		button.connect("pressed", self, "_on_building_button_pressed", [i])
		
		building_grid.add_child(button)

# Show the menu
func show_menu(team: int) -> void:
	populate_buildings(team)
	visible = true
	title_label.text = "Available Buildings"

# Hide the menu
func hide_menu() -> void:
	visible = false
	emit_signal("menu_closed")

# Button press handlers
func _on_building_button_pressed(index: int) -> void:
	if index >= 0 and index < visible_buildings.size():
		var building_data = visible_buildings[index]
		emit_signal("building_selected", building_data.id)
		hide_menu()

func _on_close_button_pressed() -> void:
	hide_menu()

# Input handling
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.scancode == KEY_ESCAPE:
			hide_menu()