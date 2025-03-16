extends GameService

# Building signals
signal building_placed(building_type, position, team)
signal building_constructed(building_reference)
signal building_destroyed(building_reference)
signal building_selected(building_reference)
signal building_deselected(building_reference)

# Building data
var building_data: Dictionary = {} # Stores building configurations
var buildings: Dictionary = {} # Tracks all active buildings
var selected_building = null # Currently selected building

# References to other systems
var grid_system
var economy_manager
var game_manager

func debug_log(message: String, level: String = "info", context: String = "") -> void:
    var logger = get_node_or_null("/root/UnifiedLogger")
    if logger:
        match level.to_lower():
            "error":
                logger.error(message, context if context else service_name)
            "warning":
                logger.warning(message, context if context else service_name)
            "debug":
                logger.debug(message, context if context else service_name)
            "verbose":
                logger.verbose(message, context if context else service_name)
            _:
                logger.info(message, context if context else service_name)
    else:
        # Fallback to print
        var prefix = "[" + level.to_upper() + "]"
        if context:
            prefix += "[" + context + "]"
        elif service_name:
            prefix += "[" + service_name + "]"
        print(prefix + " " + message)

func _init() -> void:
    service_name = "BuildingManager"
    required_services = ["GridSystem", "EconomyManager"]

func _initialize_impl() -> void:
    var logger = get_node("/root/UnifiedLogger")
    
    # References initialization with logging
    grid_system = get_dependency("GridSystem")
    economy_manager = get_dependency("EconomyManager")
    game_manager = get_dependency("GameManager")
    
    # Load building data with comprehensive logging
    _load_building_data()
    
    logger.info("Building manager initialized", "BuildingManager", {
        "total_building_types": building_data.size()
    })

func get_node_or_null(path):
    if has_node(path):
        return get_node(path)
    return null

# Process function
func _process(_delta: float) -> void:
    # Check for building selection via input
    if Input.is_action_just_pressed("ui_select"):
        _handle_selection()

# Load building configurations from data files
func _load_building_data() -> void:
    # Path to building data directory
    var data_path = "res://data/buildings/"
    
    # Use Directory to list all files
    var dir = Directory.new()
    if dir.open(data_path) == OK:
        dir.list_dir_begin(true, true)
        var file_name = dir.get_next()
        
        while file_name != "":
            if file_name.ends_with(".json"):
                var building_id = file_name.get_basename()
                var file_path = data_path + file_name
                _load_building_file(building_id, file_path)
            file_name = dir.get_next()
    else:
        push_error("Error: Could not open building data directory")

# Load a single building configuration file
func _load_building_file(building_id: String, file_path: String) -> void:
    var file = File.new()
    if file.open(file_path, File.READ) == OK:
        var text = file.get_as_text()
        file.close()
        
        var parse_result = JSON.parse(text)
        if parse_result.error == OK:
            var data = parse_result.result
            building_data[building_id] = data
            print("Loaded building data: ", building_id)
        else:
            push_error("Error parsing building data: " + file_path)
    else:
        push_error("Error opening building file: " + file_path)

# Create and configure a building instance
func _create_building_instance(building_type: String, position: Vector2, team: int) -> Building:
    # Get building data
    var data = building_data.get(building_type, {})
    if data.empty():
        debug_log("Unknown building type: " + building_type, "error", "BuildingManager")
        return null
    
    # Check if we can afford it
    if economy_manager and economy_manager.has_method("can_afford_building"):
        if not economy_manager.can_afford_building(team, building_type):
            debug_log("Cannot afford building: " + building_type, "warning", "BuildingManager")
            return null
    
    # Check if position is valid for placement
    if grid_system:
        # Extract size from data
        var size = Vector2.ONE
        if data.has("size_x") and data.has("size_y"):
            size = Vector2(data.size_x, data.size_y)
        
        # Convert world position to grid position
        var grid_pos = grid_system.world_to_grid(position)
        
        # Check if position is valid for placement
        if not grid_system.can_place_building(grid_pos, size, team):
            debug_log("Invalid position for building: " + building_type, "warning", "BuildingManager")
            return null
        
        # Deduct resources
        if economy_manager and economy_manager.has_method("purchase_building"):
            if not economy_manager.purchase_building(team, building_type):
                debug_log("Failed to purchase building: " + building_type, "warning", "BuildingManager")
                return null
    
    # Load building scene
    var scene_path = "res://scenes/buildings/base_building.tscn"
    if data.has("scene_path"):
        scene_path = data.scene_path
    
    var building_scene = load(scene_path)
    if not building_scene:
        debug_log("Failed to load building scene: " + scene_path, "error", "BuildingManager")
        return null
    
    # Create building instance
    var building = building_scene.instance()
    
    # Configure the building
    _configure_building(building, building_type, data, team)
    
    # Set position
    building.position = position
    
    # Set grid position
    if grid_system:
        var grid_pos = grid_system.world_to_grid(position)
        if building.has_method("set_grid_position"):
            building.set_grid_position(grid_pos)
        
        # Occupy grid cells
        var size = Vector2(data.size_x, data.size_y) if data.has("size_x") and data.has("size_y") else Vector2.ONE
        for x in range(size.x):
            for y in range(size.y):
                var cell_pos = grid_pos + Vector2(x, y)
                grid_system.occupy_cell(cell_pos, building)
    
    # Add to scene
    var current_scene = get_tree().current_scene
    if current_scene:
        current_scene.add_child(building)
    else:
        add_child(building)
    
    # Connect signals
    if not building.is_connected("building_destroyed", self, "_on_building_destroyed"):
        building.connect("building_destroyed", self, "_on_building_destroyed")
    
    if not building.is_connected("construction_completed", self, "_on_building_construction_completed"):
        building.connect("construction_completed", self, "_on_building_construction_completed")
    
    # Start construction
    if building.has_method("start_construction"):
        building.start_construction()
    
    # Add to building tracking
    var building_id = building.get_instance_id()
    buildings[building_id] = building
    
    # Emit signal
    emit_signal("building_placed", building_type, position, team)
    
    return building

func place_building(building_type: String, position: Vector2, team: int) -> Building:
    debug_log("Attempting to place building: " + building_type + " at position " + str(position) + " for team " + str(team), "debug", "BuildingManager")
    
    # Validate building type
    if not building_data.has(building_type):
        debug_log("Unknown building type attempted", "error", "BuildingManager")
        return null
    
    # Existing placement logic with added logging
    var building = _create_building_instance(building_type, position, team)
    
    if building:
        debug_log("Building successfully placed", "info", "BuildingManager")
        return building
    else:
        debug_log("Building placement failed", "warning", "BuildingManager")
        return null

# Configure a building instance with data
func _configure_building(building, building_type: String, data: Dictionary, team: int) -> void:
    # This function configures a building instance with its data
    if not is_instance_valid(building):
        return
        
    # Set basic properties
    building.building_id = building_type
    building.display_name = data.display_name if data.has("display_name") else building_type
    building.team = team
    
    # Set stats
    if data.has("health"):
        building.health = data.health
        building.max_health = data.health
    
    if data.has("armor"):
        building.armor = data.armor
    
    if data.has("armor_type"):
        building.armor_type = data.armor_type
    
    if data.has("size_x") and data.has("size_y"):
        building.size = Vector2(data.size_x, data.size_y)
    
    # Set unit spawning properties if applicable
    if data.has("can_spawn_units"):
        building.can_spawn_units = data.can_spawn_units
        
        if building.can_spawn_units:
            if data.has("spawn_interval"):
                building.spawn_interval = data.spawn_interval
            
            if data.has("spawn_offset_x") and data.has("spawn_offset_y"):
                building.spawn_point_offset = Vector2(data.spawn_offset_x, data.spawn_offset_y)
            
            if data.has("unit_types") and data.unit_types is Array:
                building.unit_types = data.unit_types

func _handle_selection() -> void:
    # Deselect current building if any
    if selected_building != null:
        selected_building.deselect()
        emit_signal("building_deselected", selected_building)
        selected_building = null
    
    # Get mouse position using viewport
    var viewport = get_viewport()
    var mouse_pos = viewport.get_mouse_position()
    
    # Cast a ray to select a building
    var space_state = viewport.get_world_2d().direct_space_state
    var result = space_state.intersect_point(mouse_pos, 1, [], 2) # Layer 2 for buildings
    
    if not result.empty():
        var selected = result[0].collider
        if selected is Building:
            selected_building = selected
            selected_building.select()
            emit_signal("building_selected", selected_building)

# Handle building construction completion
func _on_building_construction_completed(building: Building) -> void:
    emit_signal("building_constructed", building)
    
    # If this is a HQ building, register it with the game manager
    if building.building_id == "hq" or building.building_id == "headquarters":
        game_manager.register_headquarters(building, building.team)
    
    # Apply income bonus (10% of building cost)
    var building_cost = _get_building_cost(building.building_id)
    var income_bonus = building_cost * 0.1
    economy_manager.add_income(building.team, income_bonus)

# Handle building destruction
func _on_building_destroyed(building: Building) -> void:
    debug_log("Building destroyed: " + building.display_name + " (Team " + str(building.team) + ")", "info", "BuildingManager")
    
    # Remove from tracking
    var building_id_to_remove = null
    for id in buildings.keys():
        if buildings[id] == building:
            building_id_to_remove = id
            break
    
    if building_id_to_remove:
        var _result = buildings.erase(building_id_to_remove)
    
    # Free up grid cells
    if grid_system and building.has_method("get_grid_position") and building.has_method("get_size"):
        var grid_pos = building.get_grid_position()
        var size = building.get_size()
        
        for x in range(size.x):
            for y in range(size.y):
                var cell_pos = grid_pos + Vector2(x, y)
                grid_system.free_cell(cell_pos)
    
    # Handle economy effects if applicable
    if economy_manager and building.building_id == "bank_vault":
        # Special handling for economy buildings like bank vault
        var income_reduction = economy_manager.get_building_gold_cost(building.building_id) * 0.1
        economy_manager.add_income(building.team, -income_reduction)
    
    # If this is an HQ building, tell game manager
    if building.building_id == "headquarters" or building.building_id == "hq":
        if game_manager and game_manager.has_method("headquarters_destroyed"):
            game_manager.headquarters_destroyed(building.team)
    
    # Emit signal for other systems to respond
    emit_signal("building_destroyed", building)

# Get the cost of a building
func _get_building_cost(building_type: String) -> float:
    if not building_data.has(building_type):
        return 0.0
        
    var data = building_data[building_type]
    return data.cost if data.has("cost") else 0.0

# Get available building types for a team
func get_available_buildings(team: int) -> Array:
    var available = []
    
    for building_id in building_data.keys():
        var data = building_data[building_id]
        
        # Check if this building is available for the given team
        var team_valid = true
        if data.has("team_restriction"):
            team_valid = data.team_restriction == team
        
        if team_valid:
            available.append({
                "id": building_id,
                "name": data.display_name if data.has("display_name") else building_id,
                "cost": data.cost if data.has("cost") else 0,
                "size": Vector2(data.size_x, data.size_y) if data.has("size_x") and data.has("size_y") else Vector2.ONE,
                "description": data.description if data.has("description") else ""
            })
    
    return available

# Get a reference to a specific building by ID
func get_building_by_id(building_id: String) -> Building:
    if buildings.has(building_id):
        return buildings[building_id]
    return null

# Get all buildings for a specific team
func get_team_buildings(team: int) -> Array:
    var team_buildings = []
    
    for building in buildings.values():
        if building.team == team:
            team_buildings.append(building)
    
    return team_buildings

# Get the count of a specific building type for a team
func get_building_count(team: int, building_type: String) -> int:
    var count = 0
    
    for building in buildings.values():
        if building.team == team and building.building_id == building_type:
            count += 1
    
    return count

# Check if a team has a specific building type
func has_building_type(team: int, building_type: String) -> bool:
    return get_building_count(team, building_type) > 0

# Get data for a specific building type
func get_building_data(building_type: String) -> Dictionary:
    if building_data.has(building_type):
        return building_data[building_type]
    return {}

# Track statistics for destroyed buildings
var buildings_destroyed_by_team: Dictionary = {0: 0, 1: 0}
var buildings_constructed_by_player: Dictionary = {}

func initialize() -> void:
    # If we're not in the scene tree yet, defer initialization
    if not is_inside_tree():
        # Call deferred will wait until we're properly in the tree
        call_deferred("initialize")
        return
    
    print("BuildingManager: Initializing...")
    
    # NOW it's safe to get references using get_node
    # Get references to required systems
    grid_system = get_node_or_null("/root/GridSystem")
    if not grid_system:
        # Local search for GridSystem - only after we're in the tree
        grid_system = get_node_or_null("../GridSystem")
        if not grid_system:
            debug_log("Error: GridSystem not found", "error", "BuildingManager")
    
    economy_manager = get_node_or_null("/root/EconomyManager")
    if not economy_manager:
        economy_manager = get_node_or_null("../EconomyManager")
        if not economy_manager:
            debug_log("Error: EconomyManager not found", "error", "BuildingManager")
    
    game_manager = get_node_or_null("/root/GameManager")
    if not game_manager:
        game_manager = get_node_or_null("..")
        if not game_manager:
            debug_log("Error: GameManager not found", "error", "BuildingManager")
    
    # Clear building tracking
    buildings.clear()
    selected_building = null
    
    # Load building data
    _load_building_data()
    
    print("BuildingManager: Initialization complete with " + str(building_data.size()) + " building types loaded")
