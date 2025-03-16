# scripts/core/game_service.gd
extends Node
class_name GameService

# Service status
var is_initialized: bool = false
var service_name: String = ""
var required_services: Array = []

# Service dependencies (override in derived classes)
var dependencies: Dictionary = {}

# Debug settings
export var debug_mode: bool = false
export var verbose_logging: bool = false

# Signal to indicate initialization complete
signal initialization_completed
signal service_ready

func _init(service_name_override: String = "") -> void:
    if service_name_override != "":
        service_name = service_name_override
    else:
        # Use class name if no override provided
        service_name = get_script().get_path().get_file().get_basename()

func _ready() -> void:
    # When ready, register with ServiceLocator
    var service_locator = get_node_or_null("/root/ServiceLocator")
    if service_locator:
        service_locator.register_service(service_name, self)
        
    # Log service creation
    if verbose_logging:
        print(service_name + ": Ready")
    
    # Connect to tree_changed signal to handle service references
    var _result = get_tree().connect("tree_changed", self, "_on_tree_changed")
    
    # Initialize if not already done (deferred to wait for all references)
    if not is_initialized:
        call_deferred("initialize")

# Main initialization method - override in derived classes
func initialize() -> void:
    if is_initialized:
        return
        
    # Log initialization start
    log(service_name + ": Initializing...", "info")
    
    # Resolve service dependencies
    if not _resolve_dependencies():
        log(service_name + ": Initialization deferred - waiting for dependencies", "warning")
        call_deferred("initialize") # Try again next frame
        return
    
    # Call implementation-specific initialization
    _initialize_impl()
    
    # Mark as initialized
    is_initialized = true
    
    # Log initialization success
    log(service_name + ": Initialization complete", "info")
    
    # Emit signals
    emit_signal("initialization_completed")
    emit_signal("service_ready")

# This is a virtual method to be implemented by derived classes
func _initialize_impl() -> void:
    # Override in subclasses
    pass

# Reset service state - override in derived classes
func reset() -> void:
    # Default implementation just logs the reset
    if verbose_logging:
        print(service_name + ": Reset")

# Resolve dependencies from ServiceLocator
func _resolve_dependencies() -> bool:
    var service_locator = get_node_or_null("/root/ServiceLocator")
    if not service_locator:
        push_error(service_name + ": ServiceLocator not found")
        return false
    
    var all_resolved = true
    
    # Resolve each dependency
    for dependency_name in required_services:
        var service = service_locator.get_service(dependency_name)
        
        if service:
            dependencies[dependency_name] = service
        else:
            all_resolved = false
            break
    
    return all_resolved

# Access a dependent service
func get_dependency(dependency_name: String) -> Node:
    if dependencies.has(dependency_name):
        return dependencies[dependency_name]
    
    # Try to resolve on-demand
    var service_locator = get_node_or_null("/root/ServiceLocator")
    if service_locator:
        var service = service_locator.get_service(dependency_name)
        if service:
            dependencies[dependency_name] = service
            return service
    
    push_warning(service_name + ": Dependency not found: " + dependency_name)
    return null

func log(message: String, level: String = "info", context: String = "") -> void:
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

# Handle scene changes
func _on_tree_changed() -> void:
    # Check if we need to re-resolve dependencies
    if is_initialized and dependencies.size() < required_services.size():
        call_deferred("_resolve_dependencies")

func get_logger():
    return get_node_or_null("/root/UnifiedLogger")