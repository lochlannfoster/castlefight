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
var building_grid
var close_button
var title_label

# External references
var economy_manager
var building_manager
var tech_tree_manager

# Ready function
func _ready() -> void:
    # Get node references
    building_grid = get_node_or_null("Panel/BuildingGrid")
    close_button = get_node_or_null("Panel/CloseButton")
    title_label = get_node_or_null("Panel/TitleLabel")
    
    # Create nodes if they don't exist
    if not building_grid:
        print("BuildingGrid not found, creating it")
        var panel = get_node_or_null("Panel")
        if not panel:
            panel = Panel.new()
            panel.name = "Panel"
            panel.rect_position = Vector2(10, 10)
            panel.rect_size = Vector2(400, 300)
            add_child(panel)
        
        building_grid = GridContainer.new()
        building_grid.name = "BuildingGrid"
        building_grid.columns = 3
        building_grid.rect_position = Vector2(10, 50)
        building_grid.rect_size = Vector2(380, 230)
        panel.add_child(building_grid)
    
    if not close_button:
        print("CloseButton not found, creating it")
        var panel = get_node_or_null("Panel")
        close_button = Button.new()
        close_button.name = "CloseButton"
        close_button.text = "X"
        close_button.rect_position = Vector2(370, 10)
        close_button.rect_size = Vector2(20, 20)
        panel.add_child(close_button)
    
    if not title_label:
        print("TitleLabel not found, creating it")
        var panel = get_node_or_null("Panel")
        title_label = Label.new()
        title_label.name = "TitleLabel"
        title_label.rect_position = Vector2(10, 10)
        title_label.rect_size = Vector2(380, 30)
        title_label.text = "Available Buildings"
        title_label.align = Label.ALIGN_CENTER
        panel.add_child(title_label)
    
    # Connect button signals
    if close_button:
        if not close_button.is_connected("pressed", self, "_on_close_button_pressed"):
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
    
    # Make sure the building grid exists
    if not building_grid:
        print("Building grid not found, creating it")
        var panel = get_node_or_null("Panel")
        if not panel:
            panel = Panel.new()
            panel.name = "Panel"
            panel.rect_position = Vector2(10, 10)
            panel.rect_size = Vector2(400, 300)
            add_child(panel)
        
        building_grid = GridContainer.new()
        building_grid.name = "BuildingGrid"
        building_grid.columns = 3
        building_grid.rect_position = Vector2(10, 50)
        building_grid.rect_size = Vector2(380, 230)
        panel.add_child(building_grid)
    
    # Make sure title label exists
    if not title_label:
        var panel = get_node_or_null("Panel")
        title_label = Label.new()
        title_label.name = "TitleLabel"
        title_label.rect_position = Vector2(10, 10)
        title_label.rect_size = Vector2(380, 30)
        title_label.text = "Available Buildings"
        title_label.align = Label.ALIGN_CENTER
        panel.add_child(title_label)
    
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
            },
            {
                "id": "hq",
                "name": "Headquarters",
                "cost": 0,
                "size": Vector2(3, 3),
                "description": "Main base structure"
            }
        ]
    
    # Create buttons for each building
    for i in range(available_buildings.size()):
        var building_data = available_buildings[i]
        visible_buildings.append(building_data)
        
        var button = Button.new()
        button.text = building_data.name
        
        # Format tooltip, handling cases where properties might be missing
        var tooltip = building_data.description if building_data.has("description") else ""
        var cost = building_data.cost if building_data.has("cost") else 0
        var size_x = building_data.size.x if building_data.has("size") else 1
        var size_y = building_data.size.y if building_data.has("size") else 1
        
        tooltip += "\nCost: " + str(cost) + " gold"
        tooltip += "\nSize: " + str(size_x) + "x" + str(size_y)
        
        button.hint_tooltip = tooltip
        
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
