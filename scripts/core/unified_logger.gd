# Unified Logging System
# Provides comprehensive, configurable logging across the entire game

# Logging Levels - From most verbose to most critical
enum LogLevel {
    VERBOSE, # Extremely detailed tracing
    DEBUG, # Diagnostic information
    INFO, # General operational events
    WARNING, # Potential issues that don't prevent execution
    ERROR, # Serious problems that might impact functionality
    CRITICAL # Catastrophic errors that require immediate attention
}

# Logging Destinations
enum LogDestination {
    CONSOLE, # Print to Godot's console
    FILE, # Write to log file
    BOTH # Log to console and file
}

# Log Entry Structure - A structured way to capture log information
class LogEntry:
    var timestamp: int # When the log was created
    var level: int # Severity of the log
    var category: String # Source of the log (e.g., "NetworkManager", "EconomySystem")
    var message: String # Actual log content
    var context: Dictionary # Additional metadata about the log

class UnifiedLogger:
    # Configuration for logging behavior
    var _config: Dictionary = {
        "current_level": LogLevel.INFO, # Default log level
        "destination": LogDestination.BOTH,
        "log_file_path": "user://logs/game_log.txt",
        "max_log_files": 5, # Number of log files to keep
        "max_file_size_mb": 10 # Maximum log file size before rotation
    }

    # Log storage for potential replay or analysis
    var _log_buffer: Array = []
    var _file_handle: File = null

    # Initialize logging system
    func initialize() -> void:
        # Ensure log directory exists
        var dir = Directory.new()
        if not dir.dir_exists("user://logs"):
            dir.make_dir_recursive("user://logs")
        
        # Rotate log files if needed
        _rotate_log_files()
        
        # Open initial log file
        _open_log_file()

    # Core logging method
    func log(level: int, message: String, category: String = "General", context: Dictionary = {}) -> void:
        # Skip logs below current configuration level
        if level < _config.current_level:
            return
        
        var entry = LogEntry.new()
        entry.timestamp = OS.get_unix_time()
        entry.level = level
        entry.category = category
        entry.message = message
        entry.context = context
        
        # Store in log buffer
        _log_buffer.append(entry)
        
        # Trim buffer if it gets too large
        if _log_buffer.size() > 1000:
            _log_buffer.pop_front()
        
        # Output based on destination configuration
        match _config.destination:
            LogDestination.CONSOLE:
                _log_to_console(entry)
            LogDestination.FILE:
                _log_to_file(entry)
            LogDestination.BOTH:
                _log_to_console(entry)
                _log_to_file(entry)

    # Convenience methods for different log levels
    func verbose(message: String, category: String = "General") -> void:
        log(LogLevel.VERBOSE, message, category)
    
    func debug(message: String, category: String = "General") -> void:
        log(LogLevel.DEBUG, message, category)
    
    func info(message: String, category: String = "General") -> void:
        log(LogLevel.INFO, message, category)
    
    func warning(message: String, category: String = "General") -> void:
        log(LogLevel.WARNING, message, category)
    
    func error(message: String, category: String = "General") -> void:
        log(LogLevel.ERROR, message, category)
    
    func critical(message: String, category: String = "General") -> void:
        log(LogLevel.CRITICAL, message, category)

    # Performance tracking and logging
    func track_performance(operation_name: String, start_time: int, start_memory: int) -> void:
        var end_time = OS.get_ticks_msec()
        var end_memory = OS.get_static_memory_usage()
        
        var duration = end_time - start_time
        var memory_change = end_memory - start_memory
        
        log(LogLevel.INFO,
            "Performance: %s took %d ms, memory change %d bytes" % [
                operation_name, duration, memory_change
            ],
            "Performance"
        )

    # Internal logging methods (file, console output)
    func _log_to_console(entry: LogEntry) -> void:
        # Colorize and format console output
        var color = _get_level_color(entry.level)
        var formatted_message = "[%s] [%s] %s" % [
            _get_level_name(entry.level),
            entry.category,
            entry.message
        ]
        print(formatted_message) # Godot's print handles colored console output
    
    func _log_to_file(entry: LogEntry) -> void:
        # File logging implementation
        # Similar to console, but writes to file
        # Add implementation for file logging
    # Utility methods for log level handling
    func _get_level_name(level: int) -> String:
        match level:
            LogLevel.VERBOSE: return "VERBOSE"
            LogLevel.DEBUG: return "DEBUG"
            LogLevel.INFO: return "INFO"
            LogLevel.WARNING: return "WARN"
            LogLevel.ERROR: return "ERROR"
            LogLevel.CRITICAL: return "CRITICAL"
            _: return "UNKNOWN"
    
    func _get_level_color(level: int) -> Color:
        match level:
            LogLevel.VERBOSE: return Color(0.5, 0.5, 0.5) # Gray
            LogLevel.DEBUG: return Color(0, 1, 0) # Green
            LogLevel.INFO: return Color(0, 0, 1) # Blue
            LogLevel.WARNING: return Color(1, 1, 0) # Yellow
            LogLevel.ERROR: return Color(1, 0, 0) # Red
            LogLevel.CRITICAL: return Color(1, 0, 0) # Red
            _: return Color(1, 1, 1) # White
}

# Global singleton instance
var logger = UnifiedLogger.new()