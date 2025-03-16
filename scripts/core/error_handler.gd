# Centralized Error Handling System
# Path: scripts/core/error_handler.gd
extends Node

var service_name: String = "ErrorHandler"

# Error types
enum ErrorType {
    CONFIGURATION,
    RESOURCE_LOADING,
    NETWORK,
    RUNTIME,
    DEPENDENCY
}

# Error reporting structure
class ErrorReport:
    var timestamp: int
    var type: int
    var message: String
    var context: Dictionary = {}
    var stack_trace: Array = []

# Crash handling configuration
var _crash_handling_config: Dictionary = {
    "auto_report": true,
    "crash_log_path": "user://crash_logs/",
    "max_crash_logs": 10
}

# Error history
var _error_history: Array = []

# Signal for error reporting
signal error_occurred(report)
signal critical_error(report)

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

func _ready():
    # Ensure crash log directory exists
    var dir = Directory.new()
    if not dir.dir_exists(_crash_handling_config.crash_log_path):
        dir.make_dir_recursive(_crash_handling_config.crash_log_path)

# Report an error
func report_error(type: int, message: String, context: Dictionary = {}) -> ErrorReport:
    var report = ErrorReport.new()
    report.timestamp = OS.get_unix_time()
    report.type = type
    report.message = message
    report.context = context
    report.stack_trace = get_stack()
    
    # Store in error history
    _error_history.append(report)
    
    # Trim error history if too large
    if _error_history.size() > 100:
        _error_history.pop_front()
    
    # Emit signals
    emit_signal("error_occurred", report)
    
    # Log the error
    _log_error(report)
    
    # Handle critical errors
    if type == ErrorType.RUNTIME:
        emit_signal("critical_error", report)
        _handle_critical_error(report)
    
    return report

# Log error to file
func _log_error(report: ErrorReport):
    var log_file = File.new()
    var filename = _crash_handling_config.crash_log_path + "error_" + str(report.timestamp) + ".log"
    
    if log_file.open(filename, File.WRITE) == OK:
        log_file.store_line("Timestamp: " + str(report.timestamp))
        log_file.store_line("Type: " + _get_error_type_name(report.type))
        log_file.store_line("Message: " + report.message)
        
        # Log context
        log_file.store_line("\nContext:")
        for key in report.context:
            log_file.store_line(str(key) + ": " + str(report.context[key]))
        
        # Log stack trace
        log_file.store_line("\nStack Trace:")
        for trace in report.stack_trace:
            log_file.store_line(
                "%s:%d in function %s" % [
                    trace.source,
                    trace.line,
                    trace.function
                ]
            )
        
        log_file.close()
    
    # Rotate crash logs if needed
    _rotate_crash_logs()

# Continuing Error Handler Implementation
func _rotate_crash_logs():
    var dir = Directory.new()
    var crash_log_path = _crash_handling_config.crash_log_path
    
    # Get all crash log files
    var crash_logs = []
    dir.open(crash_log_path)
    dir.list_dir_begin()
    
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.begins_with("error_") and file_name.ends_with(".log"):
            crash_logs.append(file_name)
        file_name = dir.get_next()
    dir.list_dir_end()
    
    # Sort logs by timestamp (newest first)
    crash_logs.sort_custom(self, "_sort_crash_logs")
    
    # Remove excess logs
    while crash_logs.size() > _crash_handling_config.max_crash_logs:
        var log_to_remove = crash_logs.pop_back()
        dir.remove(crash_log_path + log_to_remove)

# Custom sort function for crash logs
func _sort_crash_logs(a: String, b: String) -> bool:
    # Extract timestamps and compare
    var timestamp_a = int(a.substr(6, a.length() - 10))
    var timestamp_b = int(b.substr(6, b.length() - 10))
    return timestamp_a > timestamp_b

# Handle critical errors
func _handle_critical_error(report: ErrorReport):
    # Attempt graceful shutdown or recovery
    debug_log("Critical Error Detected: " + report.message, "error", "ErrorHandler")
    
    # Optional: Show error dialog
    var dialog = AcceptDialog.new()
    dialog.dialog_text = """
    A critical error has occurred in the game.
    
    Error: %s
    
    The game may become unstable. 
    Please restart the application.
    """ % report.message
    
    # Add to scene to ensure visibility
    get_tree().root.add_child(dialog)
    dialog.popup_centered()

# Get human-readable error type name
func _get_error_type_name(type: int) -> String:
    match type:
        ErrorType.CONFIGURATION:
            return "Configuration Error"
        ErrorType.RESOURCE_LOADING:
            return "Resource Loading Error"
        ErrorType.NETWORK:
            return "Network Error"
        ErrorType.RUNTIME:
            return "Runtime Error"
        ErrorType.DEPENDENCY:
            return "Dependency Error"
        _:
            return "Unknown Error"

# Utility method to safely load resources
func safe_resource_load(path: String, expected_type: String = "") -> Resource:
    var resource = null
    var error_context = {"path": path}
    
    # Attempt to load resource
    resource = load(path)
    
    # Check if resource loaded successfully
    if not resource:
        var _report = report_error(
            ErrorType.RESOURCE_LOADING,
            "Failed to load resource: " + path,
            error_context
        )
        return null
    
    # Optional type checking
    if expected_type and not (resource is Object and resource.get_class() == expected_type):
        var _report = report_error(
            ErrorType.RESOURCE_LOADING,
            "Resource is not of expected type",
            {
                "path": path,
                "expected_type": expected_type,
                "actual_type": resource.get_class()
            }
        )
        return null
    
    return resource

# Create a safe method for directory operations
func safe_create_directory(path: String) -> bool:
    var dir = Directory.new()
    
    # Check if directory exists
    if dir.dir_exists(path):
        return true
    
    # Attempt to create directory
    var error = dir.make_dir_recursive(path)
    
    if error != OK:
        var _report = report_error(
            ErrorType.CONFIGURATION,
            "Failed to create directory",
            {
                "path": path,
                "error_code": error
            }
        )
        return false
    
    return true

# Dependency injection and validation
func validate_dependencies(dependencies: Dictionary) -> bool:
    var all_dependencies_valid = true
    
    for dep_name in dependencies:
        var dependency = dependencies[dep_name]
        
        if not is_instance_valid(dependency):
            var _report = report_error(
                ErrorType.DEPENDENCY,
                "Invalid dependency detected",
                {
                    "dependency_name": dep_name,
                    "dependency_type": typeof(dependency)
                }
            )
            all_dependencies_valid = false
    
    return all_dependencies_valid

# Global error handler for uncaught exceptions
func _notification(what):
    if what == MainLoop.NOTIFICATION_CRASH:
        # Capture and log any unexpected crashes
        var error_report = report_error(
            ErrorType.RUNTIME,
            "Unexpected application crash",
            {
                "os": OS.get_name(),
                "version": OS.get_engine_version()
            }
        )
        
        # Optional: Send crash report
        _send_crash_report(error_report)

# Optional crash reporting (would need external service integration)
func _send_crash_report(report: ErrorReport):
    # Placeholder for crash reporting service
    # In a real implementation, this would send data to a crash reporting service
    print("Crash report generated: " + report.message)