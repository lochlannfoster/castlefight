extends Node2D

# Import required scripts for system initialization
const GridSystemScript = preload("res://scripts/core/grid_system.gd")
const CombatSystemScript = preload("res://scripts/combat/combat_system.gd")
const EconomyManagerScript = preload("res://scripts/economy/economy_manager.gd")
const BuildingManagerScript = preload("res://scripts/building/building_manager.gd")

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

# Logging utility with more robust implementation
func _log(message: String, level: String = "info") -> void:
    var prefix = ""
    match level:
        "error":
            prefix = "[ERROR] "
            push_error(message)
        "warning":
            prefix = "[WARNING] "
            push_warning(message)
        _:
            prefix = "[INFO] "
    
    print(prefix + message)


# Primary initialization entry point
# Then call this from _ready or initialize:
func _ready() -> void:
    # Use call_deferred to ensure safe, non-blocking initialization
    call_deferred("_initialize_game_systems")
    _verify_system_availability()
    
    # Add explicit grid drawing
    call_deferred("_explicitly_draw_grid")

# Centralized game systems initialization method
func _initialize_game_systems() -> void:
    _log("Beginning game systems initialization...")
    
    # Step 1: Setup core visual components
    _setup_safe_camera()
    _load_map_safely()
    
    # Step 2: Initialize game managers and systems
    _initialize_managers_sequentially()
    
    # Step 3: Prepare game state
    _prepare_game_state()
    
    # Step 4: Final setup checks
    _validate_game_initialization()
    
    _log("Game systems initialization complete.")

# Safely set up game camera with deferred addition
func _setup_safe_camera() -> void:
    _log("Setting up game camera...")
    var camera = Camera2D.new()
    camera.name = "GameCamera"
    camera.position = Vector2(400, 300)
    camera.current = true
    
    var camera_script = load("res://scripts/core/camera_controller.gd")
    if camera_script:
        camera.set_script(camera_script)
    else:
        _log("Camera controller script not found!", "warning")
    
    call_deferred("add_child", camera)

# Safely load game map
func _load_map_safely() -> void:
    _log("Loading game map...")
    var map_scene = load("res://scenes/game/map.tscn")
    if map_scene:
        var map_instance = map_scene.instance()
        call_deferred("add_child", map_instance)
    else:
        _log("Map scene could not be loaded!", "error")

# Sequential manager initialization
func _initialize_managers_sequentially() -> void:
    _log("Initializing game managers...")
    
    # First check if GameManager exists, as it's often a dependency for others
    game_manager_ref = get_node_or_null("/root/GameManager")
    
    # Get references to all managers first
    grid_system = get_node_or_null("/root/GridSystem")
    combat_system = get_node_or_null("/root/CombatSystem")
    economy_manager = get_node_or_null("/root/EconomyManager")
    building_manager = get_node_or_null("/root/BuildingManager")
    network_manager = get_node_or_null("/root/NetworkManager")
    ui_manager = get_node_or_null("/root/UIManager")
    
    # Create missing critical managers if needed
    if not grid_system and is_instance_valid(GridSystemScript):
        _log("Creating missing GridSystem")
        grid_system = GridSystemScript.new()
        grid_system.name = "GridSystem"
        get_tree().root.call_deferred("add_child", grid_system)
        
    if not building_manager and is_instance_valid(BuildingManagerScript):
        _log("Creating missing BuildingManager")
        building_manager = BuildingManagerScript.new()
        building_manager.name = "BuildingManager"
        get_tree().root.call_deferred("add_child", building_manager)
    
    # Initialize managers with a delay to ensure they're properly added
    call_deferred("_deferred_initialize_managers")

# Prepare initial game state without spawning test entities
func _prepare_game_state() -> void:
    _log("Preparing initial game state...")
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager and game_manager.has_method("start_pregame_countdown"):
        game_manager.start_pregame_countdown()

# Validate complete game initialization
func _validate_game_initialization() -> void:
    _log("Performing final initialization validation...")
    
    var critical_systems = [
        "GameManager",
        "GridSystem",
        "UIManager"
    ]
    
    var initialization_successful = true
    
    for system in critical_systems:
        var node = get_node_or_null("/root/" + system)
        if not node:
            _log("Critical system " + system + " not initialized!", "error")
            initialization_successful = false
    
    if initialization_successful:
        _log("Game initialization validated successfully.")
    else:
        _log("Game initialization encountered issues!", "warning")

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        match event.scancode:
            KEY_G: # Toggle grid visualization
                var game_manager = get_node_or_null("/root/GameManager")
                if game_manager and game_manager.has_method("toggle_grid_visualization"):
                    game_manager.toggle_grid_visualization()

func initialize() -> void:
    if not is_initialized:
        _safe_system_initialization()
        is_initialized = true

func _safe_system_initialization() -> void:
    # Centralized, controlled initialization of game subsystems
    _log("Beginning safe system initialization...", "info")
    
    # 1. Core Systems Initialization
    grid_system = _initialize_subsystem("GridSystem", GridSystemScript)
    combat_system = _initialize_subsystem("CombatSystem", CombatSystemScript)
    economy_manager = _initialize_subsystem("EconomyManager", EconomyManagerScript)
    building_manager = _initialize_subsystem("BuildingManager", BuildingManagerScript)
    
    # 2. Advanced System Setup
    if grid_system:
        grid_system.initialize_grid()
    
    if economy_manager:
        economy_manager.reset_team_resources()
    
    # 3. Tech Tree and Race Preparation
    _prepare_tech_trees()
    
    # 4. Network and Multiplayer Setup
    _configure_network_systems()
    
    # 5. Final Validation
    _validate_system_readiness()
    
    _log("Safe system initialization complete.", "info")

func _initialize_subsystem(system_name: String, system_script) -> Node:
    # Safely initialize a game subsystem
    var existing_system = get_node_or_null(system_name)
    if existing_system:
        return existing_system
    
    if system_script:
        var new_system = system_script.new()
        new_system.name = system_name
        add_child(new_system)
        _log("Initialized subsystem: " + system_name, "info")
        return new_system
    
    _log("Failed to initialize subsystem: " + system_name, "error")
    return null

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
            _log("Critical system not initialized!", "error")

func _explicitly_draw_grid() -> void:
    _log("Setting up permanent grid visualization...")
    
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
            _log("Created missing GridSystem")
            
            # We need to wait until it's added to the tree
            yield (get_tree(), "idle_frame")
        else:
            _log("Cannot create grid system - script not valid", "error")
            return
    
    # Now try to draw the grid
    if grid_sys and grid_sys.has_method("draw_debug_grid"):
        # Use call_deferred to ensure grid system is ready
        call_deferred("_draw_grid_deferred", grid_sys)
    else:
        _log("GridSystem found but lacks draw_debug_grid method", "error")

func _verify_system_availability() -> void:
    _log("Verifying system availability...")
    
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
            _log("Found system: " + system)
        else:
            _log("System not found: " + system, "warning")
    
    # Check for required children nodes
    var required_children = ["GameWorld", "Ground", "Units", "Buildings", "Camera2D"]
    
    for child_name in required_children:
        var child = get_node_or_null(child_name)
        if child:
            _log("Found child node: " + child_name)
        else:
            _log("Child node not found: " + child_name, "warning")
            
            # Create essential missing nodes
            if child_name in ["GameWorld", "Ground", "Units", "Buildings"]:
                var new_node = Node2D.new()
                new_node.name = child_name
                call_deferred("add_child", new_node)
                _log("Created missing essential node: " + child_name)

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
            _log("Initializing " + manager.name)
            manager.node.initialize()
        elif manager.node:
            _log(manager.name + " found but lacks initialization method", "warning")
        else:
            _log(manager.name + " not found", "warning")

func _draw_grid_deferred(grid_sys) -> void:
    if is_instance_valid(grid_sys) and grid_sys.has_method("draw_debug_grid"):
        grid_sys.draw_debug_grid()
        
        # Make sure the grid visualizer is visible by default
        yield (get_tree(), "idle_frame") # Wait for visualizer to be created
        var visualizer = grid_sys.get_node_or_null("DebugGridVisualizer")
        if visualizer:
            visualizer.visible = true
            _log("Grid visualizer setup complete and visible")
        else:
            _log("Grid visualizer not found after creation", "warning")
    else:
        _log("Grid system invalid or missing draw method", "error")