# Replace the entire file with this corrected structure

extends Node

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

# Configuration for logging behavior
var _config: Dictionary = {
    "current_level": LogLevel.INFO,
    "destination": LogDestination.BOTH,
    "log_file_path": "user://logs/game_log.txt",
    "max_log_files": 5,
    "max_file_size_mb": 10
}

# Log storage for potential replay or analysis
var _log_buffer: Array = []
var _file_handle: File = null

# Log Entry Structure - A structured way to capture log information
class LogEntry:
    var timestamp: int # When the log was created
    var level: int # Severity of the log
    var category: String # Source of the log (e.g., "NetworkManager", "EconomySystem")
    var message: String # Actual log content
    var context: Dictionary # Additional metadata about the log

# Initialize logging system
func _ready() -> void:
    # Ensure log directory exists
    var dir = Directory.new()
    if not dir.dir_exists("user://logs"):
        dir.make_dir_recursive("user://logs")
    
    # Rotate log files if needed
    _rotate_log_files()
    
    # Open initial log file
    _open_log_file()

# Core logging method
func debug_log(level: int, message: String, category: String = "General", context: Dictionary = {}) -> void:
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
    debug_log(LogLevel.VERBOSE, message, category)

func debug(message: String, category: String = "General") -> void:
    debug_log(LogLevel.DEBUG, message, category)

func info(message: String, category: String = "General", context: Dictionary = {}) -> void:
    # Log the basic message
    debug_log(LogLevel.INFO, message, category)
    
    # Optionally log additional context if needed
    if not context.empty():
        for key in context.keys():
            debug_log(LogLevel.VERBOSE, str(key) + ": " + str(context[key]), category)

func warning(message: String, category: String = "General") -> void:
    debug_log(LogLevel.WARNING, message, category)

func error(message: String, category: String = "General") -> void:
    debug_log(LogLevel.ERROR, message, category)

func critical(message: String, category: String = "General") -> void:
    debug_log(LogLevel.CRITICAL, message, category)

# Performance tracking and logging
func track_performance(operation_name: String, start_time: int, start_memory: int) -> void:
    var end_time = OS.get_ticks_msec()
    var end_memory = OS.get_static_memory_usage()
    
    var duration = end_time - start_time
    var memory_change = end_memory - start_memory
    
    debug_log(LogLevel.INFO,
        "Performance: %s took %d ms, memory change %d bytes" % [
            operation_name, duration, memory_change
        ],
        "Performance"
    )

# Internal logging methods (file, console output)
func _log_to_console(entry: LogEntry) -> void:
    # Colorize and format console output
    var _color = _get_level_color(entry.level)
    var formatted_message = "[%s] [%s] %s" % [
        _get_level_name(entry.level),
        entry.category,
        entry.message
    ]
    print(formatted_message) # Godot's print handles colored console output

# File logging implementation
func _log_to_file(entry: LogEntry) -> void:
    # Check if file handle is valid
    if _file_handle == null or not _file_handle.is_open():
        _open_log_file()
        
    if _file_handle and _file_handle.is_open():
        # Format timestamp
        var datetime = OS.get_datetime_from_unix_time(entry.timestamp)
        var time_str = "%04d-%02d-%02d %02d:%02d:%02d" % [
            datetime.year, datetime.month, datetime.day,
            datetime.hour, datetime.minute, datetime.second
        ]
        
        # Format log message
        var log_line = "[%s] [%s] [%s] %s\n" % [
            time_str,
            _get_level_name(entry.level),
            entry.category,
            entry.message
        ]
        
        # Write to file
        _file_handle.store_string(log_line)
    
    # Check file size and rotate if needed
    if _file_handle and _file_handle.get_len() > _config.max_file_size_mb * 1024 * 1024:
        _rotate_log_files()

# Open log file method
func _open_log_file() -> void:
    # Close existing file handle if open
    if _file_handle != null and _file_handle.is_open():
        _file_handle.close()
    
    # Create new file handle
    _file_handle = File.new()
    var err = _file_handle.open(_config.log_file_path, File.WRITE)
    
    if err != OK:
        print("ERROR: Failed to open log file: " + _config.log_file_path)
        _file_handle = null

# Rotate log files method
func _rotate_log_files() -> void:
    # Close current log file
    if _file_handle != null and _file_handle.is_open():
        _file_handle.close()
    
    # Get list of existing log files
    var dir = Directory.new()
    var log_dir = _config.log_file_path.get_base_dir()
    
    if not dir.dir_exists(log_dir):
        dir.make_dir_recursive(log_dir)
        
    var log_files = []
    
    if dir.open(log_dir) == OK:
        dir.list_dir_begin(true, true)
        var file_name = dir.get_next()
        
        while file_name != "":
            if file_name.ends_with(".txt") or file_name.ends_with(".log"):
                log_files.append(log_dir + "/" + file_name)
            file_name = dir.get_next()
        
        dir.list_dir_end()
    
    # Sort files by modification time (oldest first)
    log_files.sort_custom(self, "_sort_files_by_time")
    
    # Remove oldest files if we have too many
    while log_files.size() >= _config.max_log_files:
        var oldest_file = log_files[0]
        dir.remove(oldest_file)
        log_files.remove(0)
    
    # Rename current log file with timestamp
    var datetime = OS.get_datetime()
    var timestamp = "%04d%02d%02d_%02d%02d%02d" % [
        datetime.year, datetime.month, datetime.day,
        datetime.hour, datetime.minute, datetime.second
    ]
    
    var new_log_path = _config.log_file_path.get_basename() + "_" + timestamp + ".log"
    dir.rename(_config.log_file_path, new_log_path)
    
    # Open a new log file
    _open_log_file()

func _sort_files_by_time(a: String, b: String) -> bool:
    var dir = Directory.new()
    var time_a = dir.get_modified_time(a)
    var time_b = dir.get_modified_time(b)
    return time_a < time_b

func _get_level_name(level: int) -> String:
    match level:
        LogLevel.VERBOSE: return "VERBOSE"
        LogLevel.DEBUG: return "DEBUG"
        LogLevel.INFO: return "INFO"
        LogLevel.WARNING: return "WARNING"
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