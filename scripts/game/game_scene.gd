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
func _ready() -> void:
    # Use call_deferred to ensure safe, non-blocking initialization
    call_deferred("_initialize_game_systems")

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
    
    var managers_to_init = [
        {"name": "GameManager", "ref_var": "game_manager_ref"},
        {"name": "GridSystem", "ref_var": "grid_system"},
        {"name": "EconomyManager", "ref_var": "economy_manager"},
        {"name": "BuildingManager", "ref_var": "building_manager"},
        {"name": "NetworkManager", "ref_var": "network_manager"},
        {"name": "UIManager", "ref_var": "ui_manager"}
    ]
    
    for manager_config in managers_to_init:
        var manager_name = manager_config["name"]
        var ref_var_name = manager_config["ref_var"]
        
        var manager = get_node_or_null("/root/" + manager_name)
        if manager and manager.has_method("initialize"):
            _log("Initializing " + manager_name)
            manager.initialize()
            
            # Dynamically set reference using set()
            set(ref_var_name, manager)
        else:
            _log("Manager " + manager_name + " not found or lacks initialization method", "warning")

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

# Optional: Input handling for game scene
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
