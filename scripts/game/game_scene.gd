extends Node2D

# Import required scripts for system initialization
const GridSystemScript = load("res://scripts/core/grid_system.gd")
const CombatSystemScript = load("res://scripts/combat/combat_system.gd")
const EconomyManagerScript = load("res://scripts/economy/economy_manager.gd")
const BuildingManagerScript = load("res://scripts/building/building_manager.gd")

# Declare initialization tracking variable
var is_initialized: bool = false

# Declare references to potential game systems with explicit types
var game_manager_ref: Node = null
var grid_system: Node = null
var combat_system: Node = null # Add this line to declare combat_system
var economy_manager: Node = null
var building_manager: Node = null
var network_manager: Node = null
var ui_manager: Node = null

export var debug_mode: bool = false

func debug_debug_log(message: String, level: String = "info", context: String = "") -> void:
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
        else if service_name:
            prefix += "[" + service_name + "]"
        print(prefix + " " + message)


# Primary initialization entry point
# Then call this from _ready or initialize:
func _ready() -> void:
    # Use call_deferred to ensure safe, non-blocking initialization
    call_deferred("initialize_game_systems")
    _verify_system_availability()
    
    # Add explicit grid drawing
    call_deferred("_explicitly_draw_grid")

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
    
    # Wait a frame for all systems to finish initializing
    yield (get_tree(), "idle_frame")
    
    # Connect signals after all systems are initialized
    _connect_signals()
    
    debug_log("All game systems initialized successfully", "info", "GameManager")

# Safely set up game camera with deferred addition
func _setup_safe_camera() -> void:
    debug_log("Setting up game camera...")
    var camera = Camera2D.new()
    camera.name = "GameCamera"
    camera.position = Vector2(400, 300)
    camera.current = true
    
    var camera_script = load("res://scripts/core/camera_controller.gd")
    if camera_script:
        camera.set_script(camera_script)
    else:
        debug_log("Camera controller script not found!", "warning")
    
    call_deferred("add_child", camera)

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
    var tech_tree_manager = get_node_or_null("TechTreeManager")
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
