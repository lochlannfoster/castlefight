# scripts/core/service_locator.gd
extends Node

# Dictionary of all registered services
var _services: Dictionary = {}

# Dictionary of service class paths for auto-creation
var _service_classes: Dictionary = {
    "GridSystem": "res://scripts/core/grid_system.gd",
    "BuildingManager": "res://scripts/building/building_manager.gd",
    "EconomyManager": "res://scripts/economy/economy_manager.gd",
    "CombatSystem": "res://scripts/combat/combat_system.gd",
    "UnitFactory": "res://scripts/unit/unit_factory.gd",
    "UIManager": "res://scripts/ui/ui_manager.gd",
    "MapManager": "res://scripts/core/map_manager.gd",
    "FogOfWarManager": "res://scripts/core/fog_of_war.gd",
    "TechTreeManager": "res://scripts/core/tech_tree_manager.gd",
    "NetworkManager": "res://scripts/networking/network_manager.gd",
}

# Initialization order to resolve dependencies correctly
var _initialization_order: Array = [
    "GridSystem",
    "EconomyManager",
    "CombatSystem",
    "UnitFactory",
    "BuildingManager",
    "MapManager",
    "FogOfWarManager",
    "TechTreeManager",
    "UIManager",
    "NetworkManager"
]

# Track initialization state
var _initialized: bool = false
var _initializing: bool = false
var _services_in_initialization: Dictionary = {}

# Debug settings
var verbose: bool = false # Reduce log spam by setting this to false

func _ready():
    # Wait a frame to ensure the scene tree is fully loaded
    call_deferred("_delayed_init")

func _delayed_init():
    if not _initialized:
        # Set flag to prevent multiple initialization attempts
        _initialized = true
        initialize_services()

# Register a service with the service locator
func register_service(service_name: String, service_instance: Node) -> void:
    if _services.has(service_name):
        # Only log at verbose level to reduce spam
        if verbose:
            print("ServiceLocator: Service already registered: " + service_name)
        return
    
    _services[service_name] = service_instance
    
    if verbose:
        print("ServiceLocator: Registered service: " + service_name)

# Get a service by name
func get_service(service_name: String) -> Node:
    # Check if service is currently initializing to prevent dependency loops
    if _services_in_initialization.has(service_name):
        print("WARNING: Circular dependency detected for " + service_name)
        return null
        
    # Check if service exists in registry
    if _services.has(service_name):
        return _services[service_name]
    
    # If not, try to find it in the scene tree
    var service = get_node_or_null("/root/" + service_name)
    
    if service:
        # Register if found
        register_service(service_name, service)
        return service
    
    # Try to find in GameManager if it exists
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager:
        service = game_manager.get_node_or_null(service_name)
        
        if service:
            register_service(service_name, service)
            return service
    
    # If still not found and auto-creation is enabled, create it
    if _service_classes.has(service_name):
        return _create_service(service_name)
    
    # Return null if service cannot be found or created
    if verbose:
        push_warning("ServiceLocator: Service not found: " + service_name)
    return null

func _create_service(service_name: String) -> Node:
    if not _service_classes.has(service_name):
        push_error("ServiceLocator: No class defined for service: " + service_name)
        return null
    
    # Prevent circular dependencies
    _services_in_initialization[service_name] = true
    
    var script_path = _service_classes[service_name]
    var script = load(script_path)
    
    if not script:
        push_error("ServiceLocator: Failed to load script for service: " + service_name)
        _services_in_initialization.erase(service_name)
        return null
    
    var service = script.new()
    service.name = service_name
    
    # Add to the root node
    get_tree().root.add_child(service)
    
    # Register the service
    register_service(service_name, service)
    
    # Don't initialize here - the _ready function will handle that
    # The node will initialize itself when it's ready and in the tree
    
    if verbose:
        print("ServiceLocator: Created service: " + service_name)
    
    # Remove from initialization list after completing
    _services_in_initialization.erase(service_name)
    
    return service

# Initialize all services in the proper order
func initialize_all_services() -> void:
    # Prevent recursive initialization
    if _initializing:
        return
        
    _initializing = true
    
    print("ServiceLocator: Initializing all services...")
    
    # First scan for existing services to avoid recreating them
    _scan_for_services()
    
    # Then initialize services in the defined order
    for service_name in _initialization_order:
        if not _services.has(service_name):
            _create_service(service_name)
        elif _services[service_name].has_method("initialize"):
            _services[service_name].initialize()
    
    print("ServiceLocator: All services initialized.")
    _initializing = false

# Scan for existing services in the scene tree
func _scan_for_services() -> void:
    # Check for services at the root level (autoloads)
    for service_name in _service_classes.keys():
        var service = get_node_or_null("/root/" + service_name)
        
        if service:
            register_service(service_name, service)
    
    # Check for services under GameManager if it exists
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager:
        for service_name in _service_classes.keys():
            var service = game_manager.get_node_or_null(service_name)
            
            if service:
                register_service(service_name, service)

# Reset all services (useful for scene transitions)
func reset_services() -> void:
    for service_name in _services.keys():
        var service = _services[service_name]
        
        if service.has_method("reset"):
            service.reset()

# Validate that all required services are working properly
func validate_services() -> bool:
    var all_valid = true
    
    for service_name in _service_classes.keys():
        if not _services.has(service_name):
            push_warning("ServiceLocator: Service not initialized: " + service_name)
            all_valid = false
    
    return all_valid

# Helper for other scripts to ensure services are initialized
func initialize_services():
    if not _initialized:
        _initialized = true
        initialize_all_services()
