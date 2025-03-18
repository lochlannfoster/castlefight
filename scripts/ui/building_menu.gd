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

# Debug mode flags
var ui_debug_mode: bool = false

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
            panel.rect_size = Vector2(200, 250)
            panel.rect_position = Vector2(10, get_viewport_rect().size.y - 260) # Bottom left
            add_child(panel)
        
        building_grid = GridContainer.new()
        building_grid.name = "BuildingGrid"
        building_grid.columns = 3
        building_grid.rect_position = Vector2(10, 50)
        building_grid.rect_size = Vector2(180, 180)
        panel.add_child(building_grid)
    
    if not close_button:
        print("CloseButton not found, creating it")
        var panel = get_node_or_null("Panel")
        close_button = Button.new()
        close_button.name = "CloseButton"
        close_button.text = "X"
        close_button.rect_position = Vector2(180, 10)
        close_button.rect_size = Vector2(20, 20)
        panel.add_child(close_button)
    
    if not title_label:
        print("TitleLabel not found, creating it")
        var panel = get_node_or_null("Panel")
        title_label = Label.new()
        title_label.name = "TitleLabel"
        title_label.rect_position = Vector2(10, 10)
        title_label.rect_size = Vector2(170, 30)
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
    
    # Check for debug mode
    var network_manager = get_node_or_null("/root/GameManager/NetworkManager")
    if network_manager:
        ui_debug_mode = network_manager.debug_mode
    
    # Hide the menu initially
    visible = false

# Show the menu
func show_menu(team: int) -> void:
    populate_buildings(team)
    visible = true
    title_label.text = "Available Buildings"

# Hide the menu
func hide_menu() -> void:
    visible = false
    emit_signal("menu_closed")

# Populate the menu with available buildings
func populate_buildings(team: int) -> void:
    current_team = team
    
    # Clear existing buttons
    for child in building_grid.get_children():
        child.queue_free()
    
    visible_buildings.clear()
    
    # Get available buildings from building manager
    var available_buildings = building_manager.get_available_buildings(team)
    
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
        
        # Add cost indicator
        var can_afford = economy_manager.can_afford_building(team, building_data.id)
        if not can_afford:
            button.modulate = Color(1, 0.5, 0.5) # Red tint if can't afford
        
        # Debug mode handling
        if ui_debug_mode:
            button.modulate = Color(1, 1, 1) # Full color in debug mode
        
        # Connect button press
        button.connect("pressed", self, "_on_building_button_pressed", [i])
        
        building_grid.add_child(button)

# Populate building menu with available upgrades
func populate_upgrades(team: int) -> void:
    current_team = team
    
    # Clear existing buttons
    for child in building_grid.get_children():
        child.queue_free()
    
    visible_buildings.clear()
    
    # Get available upgrades
    var available_upgrades = tech_tree_manager.get_available_upgrades(team)
    
    # Create buttons for each upgrade
    for i in range(available_upgrades.size()):
        var upgrade_data = available_upgrades[i]
        visible_buildings.append(upgrade_data)
        
        var button = Button.new()
        button.text = upgrade_data.name
        
        # Format tooltip
        var tooltip = upgrade_data.description if upgrade_data.has("description") else ""
        tooltip += "\nBuilding: " + upgrade_data.building
        
        button.hint_tooltip = tooltip
        
        # Add indicator for research status
        var is_researchable = tech_tree_manager.can_research_upgrade(team, upgrade_data.id)
        if not is_researchable:
            button.modulate = Color(0.5, 0.5, 0.5) # Gray out if not researchable
        
        # Connect button press
        button.connect("pressed", self, "_on_upgrade_button_pressed", [i])
        
        building_grid.add_child(button)

# Button press handlers
func _on_building_button_pressed(index: int) -> void:
    if index >= 0 and index < visible_buildings.size():
        var building_data = visible_buildings[index]
        emit_signal("building_selected", building_data.id)
        hide_menu()

func _on_upgrade_button_pressed(index: int) -> void:
    if index >= 0 and index < visible_buildings.size():
        var upgrade_data = visible_buildings[index]
        # Attempt to research the upgrade
        var success = tech_tree_manager.research_upgrade(current_team, upgrade_data.id)
        if success:
            hide_menu()

func _on_close_button_pressed() -> void:
    hide_menu()

# Input handling
func _input(event: InputEvent) -> void:
    if visible and event is InputEventKey:
        if event.pressed and event.scancode == KEY_ESCAPE:
            hide_menu()

# Additional input handlers
func _unhandled_input(event: InputEvent) -> void:
    # Right-click to close menu
    if visible and event is InputEventMouseButton:
        if event.button_index == BUTTON_RIGHT and event.pressed:
            hide_menu()

# Debugging and error handling
func _get_configuration_warning() -> String:
    if not building_manager:
        return "No BuildingManager found. Menu may not function correctly."
    return ""

# Custom debug logging
func _print_debug(message: String) -> void:
    if ui_debug_mode:
        print("[BuildingMenu Debug] ", message)
