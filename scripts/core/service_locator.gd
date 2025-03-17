# scripts/core/service_locator.gd
extends Node

var service_locator_name: String = "ServiceLocator"

# Dictionary of all registered services
var _services: Dictionary = {}

# Dictionary of service class paths for auto-creation
var _service_classes: Dictionary = {
    "MapManager": "res://scripts/core/map_manager.gd",
    "GridSystem": "res://scripts/core/grid_system.gd",
    "BuildingManager": "res://scripts/building/building_manager.gd",
    "EconomyManager": "res://scripts/economy/economy_manager.gd",
    "CombatSystem": "res://scripts/combat/combat_system.gd",
    "UnitFactory": "res://scripts/unit/unit_factory.gd",
    "UIManager": "res://scripts/ui/ui_manager.gd",
    "FogOfWarManager": "res://scripts/core/fog_of_war.gd",
    "TechTreeManager": "res://scripts/core/tech_tree_manager.gd",
    "NetworkManager": "res://scripts/networking/network_manager.gd",
}

# Initialization order to resolve dependencies correctly
var _initialization_order = [
    "GridSystem",
    "EconomyManager",
    "CombatSystem",
    "MapManager",
    "BuildingManager",
    "UnitFactory",
    "TechTreeManager",
    "FogOfWarManager",
    "UIManager",
    "NetworkManager"
]

# Tracking variables
var _pending_initializations = []
var _initialized: bool = false
var _initializing: bool = false
var _services_in_initialization: Dictionary = {}

# Debug settings
var verbose: bool = true

func _ready():
    # Wait a frame to ensure the scene tree is fully loaded
    call_deferred("_delayed_init")

func _delayed_init():
    if not _initialized:
        # Set flag to prevent multiple initialization attempts
        _initialized = true
        initialize_services()

# Register a service with the service locator
func register_service(service_identifier: String, service_instance: Node) -> void:
    if _services.has(service_identifier):
        # Only log at verbose level to reduce spam
        if verbose:
            debug_log("Service already registered: " + service_identifier)
        return
    
    _services[service_identifier] = service_instance
    
    if verbose:
        debug_log("Registered service: " + service_identifier)

# Get a service by name
func get_service(service_identifier: String) -> Node:
    # Check if service is currently initializing to prevent dependency loops
    if _services_in_initialization.has(service_identifier):
        debug_log("Circular dependency detected for " + service_identifier, "warning")
        return null
        
    # Check if service exists in registry
    if _services.has(service_identifier):
        return _services[service_identifier]
    
    # If not, try to find it in the scene tree
    var service = get_node_or_null("/root/" + service_identifier)
    
    if service:
        # Register if found
        register_service(service_identifier, service)
        return service
    
    # Try to find in GameManager if it exists
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager:
        service = game_manager.get_node_or_null(service_identifier)
        
        if service:
            register_service(service_identifier, service)
            return service
    
    # If still not found and auto-creation is enabled, create it
    if _service_classes.has(service_identifier):
        return _create_service(service_identifier)
    
    # Return null if service cannot be found or created
    if verbose:
        debug_log("Service not found: " + service_identifier, "warning")
    return null

func _create_service(service_identifier: String) -> Node:
    if not _service_classes.has(service_identifier):
        debug_log("No class defined for service: " + service_identifier, "error")
        return null
    
    # Prevent circular dependencies
    _services_in_initialization[service_identifier] = true
    
    var script_path = _service_classes[service_identifier]
    var script = load(script_path)
    
    if not script:
        debug_log("Failed to load script for service: " + service_identifier, "error")
        var _removed = _services_in_initialization.erase(service_identifier)
        return null
    
    var service = script.new()
    service.name = service_identifier
    
    # Add to the root node
    get_tree().root.add_child(service)
    
    # Register the service
    register_service(service_identifier, service)
    
    # Remove from initialization tracking
    var _removed = _services_in_initialization.erase(service_identifier)
    
    if verbose:
        debug_log("Created service: " + service_identifier)
    
    return service

# Initialize all services
func initialize_all_services() -> void:
    if _initializing:
        return
        
    _initializing = true
    _pending_initializations.clear()
    
    debug_log("Initializing all services in order...")
    
    # First scan for existing services
    _scan_for_services()
    
    # Then initialize in the correct order
    for service_name in _initialization_order:
        # Get or create the service
        var service = get_service(service_name)
        
        if service and service.has_method("initialize"):
            # Skip if already initialized
            if service.has_method("is_initialized") and service.is_initialized:
                debug_log("Service " + service_name + " already initialized, skipping.")
                continue
                
            # Check if this is a GameService that has these signals
            var has_initialization_signals = service.has_signal("initialization_completed")
            
            if has_initialization_signals:
                # Connect to the signals if not already connected
                if not service.is_connected("initialization_completed", self, "_on_service_initialized"):
                    service.connect("initialization_completed", self, "_on_service_initialized", [service_name])
                    
                if not service.is_connected("initialization_failed", self, "_on_service_initialization_failed"):
                    service.connect("initialization_failed", self, "_on_service_initialization_failed", [service_name])
                    
                # Add to pending initializations
                if not _pending_initializations.has(service_name):
                    _pending_initializations.append(service_name)
            
            # Start initialization
            debug_log("Starting initialization of " + service_name)
            service.initialize()
            
            # If it doesn't have the signals, consider it initialized immediately
            if not has_initialization_signals:
                debug_log("Service " + service_name + " initialized (no signals)")
    
    # Resolve any circular dependencies
    call_deferred("resolve_circular_dependencies")
    
    # Check if any services need to be waited on
    if _pending_initializations.empty():
        debug_log("All services initialized immediately.")
        _initializing = false
    else:
        debug_log("Waiting for " + str(_pending_initializations.size()) + " services to complete initialization.")

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

# Validate that all required services are working properly
func validate_services() -> bool:
    var all_valid = true
    
    for service_name in _service_classes.keys():
        if not _services.has(service_name):
            debug_log("Service not initialized: " + service_name, "warning")
            all_valid = false
    
    return all_valid

# Helper for other scripts to ensure services are initialized
func initialize_services():
    if not _initialized:
        _initialized = true
        initialize_all_services()

func _on_service_initialized(service_name: String) -> void:
    debug_log("Service initialized: " + service_name)
    
    # Remove from pending list
    if _pending_initializations.has(service_name):
        _pending_initializations.erase(service_name)
    
    # Check if all services are initialized
    if _pending_initializations.empty():
        debug_log("All services initialized successfully")
        _initializing = false
        
func _on_service_initialization_failed(error_message: String, service_name: String) -> void:
    debug_log("Service initialization failed: " + service_name + " - " + error_message, "error")
    
    # Remove from pending list
    if _pending_initializations.has(service_name):
        _pending_initializations.erase(service_name)
    
    # Even if a service fails, we continue with others
    if _pending_initializations.empty():
        debug_log("All service initializations completed, but some failed", "warning")
        _initializing = false

func debug_log(message: String, level: String = "info", context: String = "") -> void:
    var logger = get_node_or_null("/root/UnifiedLogger")
    if logger:
        match level.to_lower():
            "error":
                logger.error(message, context if context else service_locator_name)
            "warning":
                logger.warning(message, context if context else service_locator_name)
            "debug":
                logger.debug(message, context if context else service_locator_name)
            "verbose":
                logger.verbose(message, context if context else service_locator_name)
            _:
                logger.info(message, context if context else service_locator_name)
    else:
        # Fallback to print
        var prefix = "[" + level.to_upper() + "]"
        if context:
            prefix += "[" + context + "]"
        elif service_locator_name:
            prefix += "[" + service_locator_name + "]"
        print(prefix + " " + message)

# Resolve circular dependencies between services
func resolve_circular_dependencies() -> void:
    debug_log("Resolving circular dependencies...")
    
    # Get all services with pending dependencies
    var services_with_dependencies = []
    
    for service_name in _services.keys():
        var service = _services[service_name]
        
        # Check if this is a GameService with unresolved dependencies
        if service.has_method("get_unresolved_dependencies") and service.get_unresolved_dependencies().size() > 0:
            services_with_dependencies.append(service)
    
    # Try to resolve dependencies for each service
    for service in services_with_dependencies:
        var unresolved = service.get_unresolved_dependencies()
        
        for dependency_name in unresolved:
            var dependency = get_service(dependency_name)
            
            if dependency:
                if service.has_method("resolve_dependency"):
                    service.resolve_dependency(dependency_name, dependency)
                    debug_log("Resolved dependency: " + dependency_name + " for " + service.service_name)
    
    debug_log("Circular dependency resolution complete")
