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

# Debug settings
var verbose: bool = true

# Ready function
func _ready() -> void:
    # Set this to process after other autoloads
    pause_mode = Node.PAUSE_MODE_PROCESS
    
    # Log that service locator is initializing
    print("ServiceLocator: Initializing...")
    
    # Connect to the tree_changed signal to handle scene changes
    var _connect_result = get_tree().connect("tree_changed", self, "_on_tree_changed")
    
    # Validate classes exist
    _validate_service_classes()
    
    # Initial scan for existing services in the scene tree
    _scan_for_services()
    
    print("ServiceLocator: Initialization complete")

# Register a service with the service locator
func register_service(service_name: String, service_instance: Node) -> void:
    if _services.has(service_name):
        # Optional: Only print warning in debug mode
        if verbose:
            print("ServiceLocator: Service already registered: " + service_name + ". Skipping replacement.")
        return
    
    _services[service_name] = service_instance
    
    if verbose:
        print("ServiceLocator: Registered service: " + service_name)

# Get a service by name
func get_service(service_name: String) -> Node:
    # Check if service exists
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
    push_warning("ServiceLocator: Service not found: " + service_name)
    return null

# Create a new service instance
func _create_service(service_name: String) -> Node:
    if not _service_classes.has(service_name):
        push_error("ServiceLocator: No class defined for service: " + service_name)
        return null
    
    var script_path = _service_classes[service_name]
    var script = load(script_path)
    
    if not script:
        push_error("ServiceLocator: Failed to load script for service: " + service_name)
        return null
    
    var service = script.new()
    service.name = service_name
    
    # Add to the root node
    get_tree().root.call_deferred("add_child", service)
    
    # Wait until service is added to the tree
    yield (get_tree(), "idle_frame")
    
    # Register the service
    register_service(service_name, service)
    
    # Initialize if the service has an initialize method
    if service.has_method("initialize"):
        service.initialize()
    
    if verbose:
        print("ServiceLocator: Created and initialized service: " + service_name)
    
    return service

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

func initialize_all_services() -> void:
    print("ServiceLocator: Initializing all services...")
    
    for service_name in _initialization_order:
        if not _services.has(service_name):
            _create_service(service_name)
        elif _services[service_name].has_method("initialize"):
            _services[service_name].initialize()
    
    print("ServiceLocator: All services initialized.")

# Check if all services are properly initialized
func validate_services() -> bool:
    var all_valid = true
    
    for service_name in _service_classes.keys():
        if not _services.has(service_name):
            push_warning("ServiceLocator: Service not initialized: " + service_name)
            all_valid = false
    
    return all_valid

# Validate that service classes exist
func _validate_service_classes() -> void:
    for service_name in _service_classes.keys():
        var script_path = _service_classes[service_name]
        var script = load(script_path)
        
        if not script:
            push_warning("ServiceLocator: Service script not found: " + script_path + " for service " + service_name)

# Reset all services (useful for scene transitions)
func reset_services() -> void:
    for service_name in _services.keys():
        var service = _services[service_name]
        
        if service.has_method("reset"):
            service.reset()

# Handle scene changes
func _on_tree_changed() -> void:
    # Wait a frame to ensure the scene is fully loaded
    yield (get_tree(), "idle_frame")
    
    # Re-scan for services
    _scan_for_services()
