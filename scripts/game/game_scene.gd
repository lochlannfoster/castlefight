extends Node2D
var service_name: String = "GameScene"

# Import required scripts for system initialization
var GridSystemScript = load("res://scripts/core/grid_system.gd")
var CombatSystemScript = load("res://scripts/combat/combat_system.gd")
var EconomyManagerScript = load("res://scripts/economy/economy_manager.gd")
var BuildingManagerScript = load("res://scripts/building/building_manager.gd")
var MapManagerScript = load("res://scripts/core/map_manager.gd")

# Declare initialization tracking variable
var is_initialized: bool = false

# Declare references to potential game systems with explicit types
var game_manager_ref: Node = null
var map_manager: Node = null
var grid_system: Node = null
var combat_system: Node = null
var economy_manager: Node = null
var building_manager: Node = null
var network_manager: Node = null
var ui_manager: Node = null
var fog_of_war_manager: Node = null
var tech_tree_manager: Node = null

export var debug_mode: bool = false


func debug_log(message: String, level: String = "info", context: String = "") -> void:
    var logger = get_node_or_null("/root/Logger")
    if logger:
        match level.to_lower():
            "error":
                logger.error(message, context if context else service_name)
            "warning":
                logger.warning(message, context if context else service_name)
            "debug":
                logger.debug(message, context if context else service_name)
            "verbose":
                logger.debug(message, context if context else service_name)
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


func initialize_game_systems() -> void:
    debug_log("Initializing all game systems...", "info", "GameManager")
    
    # Initialize all services through ServiceLocator
    var service_locator = get_node("/root/ServiceLocator")
    if service_locator:
        service_locator.initialize_all_services()
    
    # Get references to services
    grid_system = service_locator.get_service("GridSystem")
    combat_system = service_locator.get_service("CombatSystem")
    economy_manager = service_locator.get_service("EconomyManager")
    building_manager = service_locator.get_service("BuildingManager")
    network_manager = service_locator.get_service("NetworkManager")
    ui_manager = service_locator.get_service("UIManager")
    map_manager = service_locator.get_service("MapManager")
    fog_of_war_manager = service_locator.get_service("FogOfWarManager")
    tech_tree_manager = service_locator.get_service("TechTreeManager")

    if map_manager:
            map_manager.generate_map()
    # Wait a frame for all systems to finish initializing
    yield (get_tree(), "idle_frame")
    
    # Connect signals after all systems are initialized
    _connect_signals()
    
    debug_log("All game systems initialized successfully", "info", "GameManager")

# Primary initialization entry point
# Then call this from _ready or initialize:
func _ready() -> void:
    debug_log("Game scene initialization STARTED", "info")
    
    # Attempt to get ServiceLocator
    var service_locator = get_node_or_null("/root/ServiceLocator")
    if not service_locator:
        debug_log("CRITICAL: ServiceLocator not found! Check Project Settings.", "error")
        return
    
    # Initialize services
    service_locator.initialize_all_services()
    
    # Retrieve services with precise logging
    var services_to_retrieve = {
        "grid_system": "GridSystem",
        "combat_system": "CombatSystem",
        "economy_manager": "EconomyManager",
        "building_manager": "BuildingManager",
        "network_manager": "NetworkManager",
        "ui_manager": "UIManager",
        "map_manager": "MapManager",
        "fog_of_war_manager": "FogOfWarManager",
        "tech_tree_manager": "TechTreeManager"
    }
    
    for local_var_name in services_to_retrieve:
        var current_service_name = services_to_retrieve[local_var_name]
        var service = service_locator.get_service(current_service_name)
        
        if service:
            set(local_var_name, service)
            debug_log("Successfully retrieved " + current_service_name, "info")
        else:
            debug_log("FAILED to retrieve " + current_service_name + ". Verify ServiceLocator configuration.", "error")
    
    # Proceed only if critical systems are available
    if map_manager and grid_system and economy_manager and building_manager:
        # Map generation
        map_manager.generate_map()
        
        # Camera setup
        _setup_safe_camera()
        
        # Prepare game state
        _create_initial_game_state()
        
        debug_log("Game scene initialization COMPLETE", "info")
    else:
        debug_log("CRITICAL: One or more critical systems missing. Cannot initialize game.", "error")

        _ensure_rendering_structure()
    
    # Debug log the scene hierarchy
    print("Game scene loaded - printing hierarchy:")
    _print_scene_tree(self, 0)

func _ensure_rendering_structure():
    # Make sure we have a world container node
    var world = get_node_or_null("GameWorld")
    if not world:
        world = Node2D.new()
        world.name = "GameWorld"
        add_child(world)
        world.owner = self
        print("Created missing GameWorld node")
    
    # Make sure we have a ground layer for background
    var ground = world.get_node_or_null("Ground")
    if not ground:
        ground = Node2D.new()
        ground.name = "Ground"
        world.add_child(ground)
        ground.owner = self
        print("Created missing Ground node")
        
        # Add a background color to make it visible
        var background = ColorRect.new()
        background.name = "Background"
        background.rect_min_size = Vector2(4000, 3000)
        background.rect_position = Vector2(-2000, -1500)
        background.color = Color(0.2, 0.3, 0.2) # Dark green background
        ground.add_child(background)
        background.owner = self
        print("Added background color to Ground")
    
    # Make sure Units and Buildings containers exist
    for container_name in ["Units", "Buildings"]:
        var container = world.get_node_or_null(container_name)
        if not container:
            container = Node2D.new()
            container.name = container_name
            world.add_child(container)
            container.owner = self
            print("Created missing " + container_name + " node")

# Create a method to create initial game state
func _create_initial_game_state() -> void:
    debug_log("Creating initial game state...", "info")
    
    # Ensure we have a reference to the game manager
    var game_manager = get_node_or_null("/root/GameManager")
    if not game_manager:
        debug_log("Game Manager not found!", "error")
        return
    
    # Create player workers
    debug_log("Creating player workers...", "debug")
    if game_manager.has_method("_create_player_workers"):
        game_manager._create_player_workers()
    else:
        debug_log("Game Manager lacks _create_player_workers method!", "error")
    
    # Create starting buildings
    debug_log("Creating starting buildings...", "debug")
    if game_manager.has_method("_create_starting_buildings"):
        game_manager._create_starting_buildings()
    else:
        debug_log("Game Manager lacks _create_starting_buildings method!", "error")
    
    # Optional: Configure network systems
    _configure_network_systems()

func _setup_safe_camera() -> void:
    debug_log("Setting up game camera...")
    
    var camera = Camera2D.new()
    camera.name = "GameCamera"
    
    # Use a more dynamic positioning strategy
    if map_manager:
        # If map manager exists, center camera on map
        var map_center = Vector2(
            map_manager.map_width * map_manager.grid_system.cell_size.x / 2,
            map_manager.map_height * map_manager.grid_system.cell_size.y / 2
        )
        camera.position = map_center
    else:
        # Fallback to a default position
        camera.position = Vector2(400, 300)
    
    camera.current = true
    
    var camera_script = load("res://scripts/core/camera_controller.gd")
    if camera_script:
        camera.set_script(camera_script)
        debug_log("Camera controller script successfully loaded", "debug")
    else:
        debug_log("Camera controller script not found! Check path.", "error")
    
    # Use call_deferred to ensure proper scene tree integration
    call_deferred("add_child", camera)
    debug_log("Camera added to scene", "debug")

# Safely load game map
func _load_map_safely() -> void:
    debug_log("Loading game map...")
    var map_scene = load("res://scenes/game/map.tscn")
    if map_scene:
        var map_instance = map_scene.instance()
        call_deferred("add_child", map_instance)
    else:
        debug_log("Map scene could not be loaded!", "error")

# Prepare initial game state without spawning test entities
func _prepare_game_state() -> void:
    debug_log("Preparing initial game state...")
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager and game_manager.has_method("start_pregame_countdown"):
        game_manager.start_pregame_countdown()

# Validate complete game initialization
func _validate_game_initialization() -> void:
    debug_log("Performing final initialization validation...")
    
    var critical_systems = [
        "GameManager",
        "GridSystem",
        "UIManager"
    ]
    
    var initialization_successful = true
    
    for system in critical_systems:
        var node = get_node_or_null("/root/" + system)
        if not node:
            debug_log("Critical system " + system + " not initialized!", "error")
            initialization_successful = false
    
    if initialization_successful:
        debug_log("Game initialization validated successfully.")
    else:
        debug_log("Game initialization encountered issues!", "warning")

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        match event.scancode:
            KEY_G: # Toggle grid visualization
                var game_manager = get_node_or_null("/root/GameManager")
                if game_manager and game_manager.has_method("toggle_grid_visualization"):
                    game_manager.toggle_grid_visualization()

func _prepare_tech_trees() -> void:
    # Prepare default tech trees for teams
    if tech_tree_manager:
        tech_tree_manager.set_team_tech_tree(0, "human")
        tech_tree_manager.set_team_tech_tree(1, "orc")

func _configure_network_systems() -> void:
    var network_sys = get_node_or_null("NetworkManager")
    if network_sys:
        network_sys.debug_mode = debug_mode
        
        # Replace ternary with explicit method call
        if network_sys.has_method("initialize_network_settings"):
            network_sys.initialize_network_settings()

func _validate_system_readiness() -> void:
    # Final system readiness check
    var critical_systems = [
        grid_system,
        combat_system,
        economy_manager,
        building_manager
    ]
    
    for system in critical_systems:
        if not system:
            debug_log("Critical system not initialized!", "error")

func _explicitly_draw_grid() -> void:
    debug_log("Setting up permanent grid visualization...")
    
    # Try multiple ways to get the grid system
    var grid_sys = get_node_or_null("/root/GridSystem")
    if not grid_sys:
        grid_sys = get_node_or_null("GridSystem")
    
    if not grid_sys:
        # Try to create grid system if it doesn't exist
        if is_instance_valid(GridSystemScript):
            grid_sys = GridSystemScript.new()
            grid_sys.name = "GridSystem"
            get_tree().root.call_deferred("add_child", grid_sys)
            debug_log("Created missing GridSystem")
            
            # We need to wait until it's added to the tree
            yield (get_tree(), "idle_frame")
        else:
            debug_log("Cannot create grid system - script not valid", "error")
            return
    
    # Now try to draw the grid
    if grid_sys and grid_sys.has_method("draw_debug_grid"):
        # Use call_deferred to ensure grid system is ready
        call_deferred("_draw_grid_deferred", grid_sys)
    else:
        debug_log("GridSystem found but lacks draw_debug_grid method", "error")

func _verify_system_availability() -> void:
    debug_log("Verifying system availability...")
    
    # Check for critical autoloaded systems
    var autoload_systems = [
        "GameManager",
        "GridSystem",
        "EconomyManager",
        "BuildingManager",
        "UIManager",
        "NetworkManager",
        "CombatSystem"
    ]
    
    for system in autoload_systems:
        var node = get_node_or_null("/root/" + system)
        if node:
            debug_log("Found system: " + system)
        else:
            debug_log("System not found: " + system, "warning")
    
    # Check for required children nodes
    var required_children = ["GameWorld", "Ground", "Units", "Buildings", "Camera2D"]
    
    for child_name in required_children:
        var child = get_node_or_null(child_name)
        if child:
            debug_log("Found child node: " + child_name)
        else:
            debug_log("Child node not found: " + child_name, "warning")
            
            # Create essential missing nodes
            if child_name in ["GameWorld", "Ground", "Units", "Buildings"]:
                var new_node = Node2D.new()
                new_node.name = child_name
                call_deferred("add_child", new_node)
                debug_log("Created missing essential node: " + child_name)

func _deferred_initialize_managers() -> void:
    # Initialize each manager if it has the method
    var managers = [
        {"node": grid_system, "name": "GridSystem"},
        {"node": combat_system, "name": "CombatSystem"},
        {"node": economy_manager, "name": "EconomyManager"},
        {"node": building_manager, "name": "BuildingManager"},
        {"node": network_manager, "name": "NetworkManager"},
        {"node": ui_manager, "name": "UIManager"}
    ]
    
    for manager in managers:
        if manager.node and manager.node.has_method("initialize"):
            debug_log("Initializing " + manager.name)
            manager.node.initialize()
        elif manager.node:
            debug_log(manager.name + " found but lacks initialization method", "warning")
        else:
            debug_log(manager.name + " not found", "warning")

func _draw_grid_deferred(grid_sys) -> void:
    if is_instance_valid(grid_sys) and grid_sys.has_method("draw_debug_grid"):
        grid_sys.draw_debug_grid()
        
        # Make sure the grid visualizer is visible by default
        yield (get_tree(), "idle_frame") # Wait for visualizer to be created
        var visualizer = grid_sys.get_node_or_null("DebugGridVisualizer")
        if visualizer:
            visualizer.visible = true
            debug_log("Grid visualizer setup complete and visible")
        else:
            debug_log("Grid visualizer not found after creation", "warning")
    else:
        debug_log("Grid system invalid or missing draw method", "error")

# Connect signals with proper error handling
func _connect_signals() -> void:
    # Connect grid system signals
    if grid_system:
        var grid_connect_result = grid_system.connect("grid_initialized", self, "_on_grid_initialized")
        if grid_connect_result != OK:
            debug_log("Failed to connect grid_initialized signal", "warning")
    
    # Connect combat system signals
    if combat_system:
        var combat_connect_result = combat_system.connect("combat_event", self, "_on_combat_event")
        if combat_connect_result != OK:
            debug_log("Failed to connect combat_event signal", "warning")
    
    # Connect building manager signals
    if building_manager:
        var placed_connect_result = building_manager.connect("building_placed", self, "_on_building_placed")
        if placed_connect_result != OK:
            debug_log("Failed to connect building_placed signal", "warning")
        
        var destroyed_connect_result = building_manager.connect("building_destroyed", self, "_on_building_destroyed")
        if destroyed_connect_result != OK:
            debug_log("Failed to connect building_destroyed signal", "warning")

# Updated signal handlers with parameter prefixes
func _on_combat_event(_attacker, _target, _damage, _attack_type) -> void:
    # Placeholder for any game-wide combat event handling
    pass

func _on_building_placed(_building_type, _position, _team) -> void:
    # Placeholder for any game-wide building placement tracking
    pass

func _on_building_destroyed(_building) -> void:
    # Placeholder for any game-wide building destruction tracking
    pass


# Add these callback functions if they don't exist:
func _on_grid_initialized() -> void:
    debug_log("Grid system initialized", "info", "GameScene")
    
func _on_game_started() -> void:
    debug_log("Game started", "info", "GameScene")
    
func _on_game_ended(winning_team) -> void:
    debug_log("Game ended. Winner: Team " + str(winning_team), "info", "GameScene")

func _print_scene_tree(node, indent):
    var indent_str = ""
    for _i in range(indent):
        indent_str += "  "
    
    var visible_text = ""
    if "visible" in node:
        visible_text = " - visible: " + str(node.visible)
    
    print(indent_str + node.name + " (" + node.get_class() + ")" + visible_text)
    
    for child in node.get_children():
        _print_scene_tree(child, indent + 1)
