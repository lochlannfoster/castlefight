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
signal initialization_started
signal initialization_completed
signal initialization_failed(error_message)
signal service_ready

var _initialization_state = "not_started" # "not_started", "in_progress", "completed", "failed"

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
        debug_log(service_name + ": Ready")
    
    # Connect to tree_changed signal to handle service references
    if get_tree():
        var _result = get_tree().connect("tree_changed", self, "_on_tree_changed")

func initialize() -> void:
    # Prevent double initialization
    if _initialization_state == "in_progress" or _initialization_state == "completed":
        return
        
    # Mark as in progress and emit signal
    _initialization_state = "in_progress"
    emit_signal("initialization_started")
    
    # Log initialization start
    debug_log(service_name + ": Starting initialization", "info")
    
    # Resolve service dependencies
    if not _resolve_dependencies():
        debug_log(service_name + ": Initialization failed - dependencies not resolved", "error")
        _initialization_state = "failed"
        emit_signal("initialization_failed", "Dependencies not resolved")
        return
    
    # Call implementation-specific initialization
    # This is where child classes will do their specific initialization
    _initialize_impl()
    
    # Mark as initialized and emit signal
    _initialization_state = "completed"
    is_initialized = true
    
    # Log initialization success
    debug_log(service_name + ": Initialization complete", "info")
    
    # Emit completion signal
    emit_signal("initialization_completed")

func _initialize_impl() -> void:
    # Generic initialization logic
    # Signal that the service is fully initialized and ready
    if verbose_logging:
        debug_log(service_name + ": Service fully initialized")
    
    emit_signal("service_ready")

# Reset service state - override in derived classes
func reset() -> void:
    # Default implementation just logs the reset
    if verbose_logging:
        debug_log(service_name + ": Reset")

# Resolve dependencies safely with the ServiceLocator
func _resolve_dependencies() -> bool:
    # Must be in tree to use absolute paths
    if not is_inside_tree():
        call_deferred("initialize")
        return false
    
    var service_locator = get_node_or_null("/root/ServiceLocator")
    if not service_locator:
        debug_log(service_name + ": ServiceLocator not found", "error")
        return false
    
    var all_resolved = true
    
    # Resolve each dependency
    for dependency_name in required_services:
        var service = service_locator.get_service(dependency_name)
        
        if service:
            dependencies[dependency_name] = service
        else:
            all_resolved = false
            debug_log("Dependency not found: " + dependency_name, "warning")
    
    return all_resolved

# Access a dependent service
func get_dependency(dependency_name: String) -> Node:
    if dependencies.has(dependency_name):
        return dependencies[dependency_name]
    
    # Try to resolve on-demand if in tree
    if is_inside_tree():
        var service_locator = get_node_or_null("/root/ServiceLocator")
        if service_locator:
            var service = service_locator.get_service(dependency_name)
            if service:
                dependencies[dependency_name] = service
                return service
    
    debug_log(service_name + ": Dependency not found: " + dependency_name, "warning")
    return null

# Handle scene changes
func _on_tree_changed() -> void:
    # Check if we need to re-resolve dependencies
    if is_initialized and dependencies.size() < required_services.size():
        call_deferred("_resolve_dependencies")

func get_logger():
    # Only try to get logger if in tree
    if is_inside_tree():
        return get_node_or_null("/root/UnifiedLogger")
    return null

func get_unresolved_dependencies() -> Array:
    var unresolved = []
    
    for dependency_name in required_services:
        if not dependencies.has(dependency_name) or dependencies[dependency_name] == null:
            unresolved.append(dependency_name)
    
    return unresolved

func resolve_dependency(dependency_name: String, dependency_instance) -> void:
    dependencies[dependency_name] = dependency_instance