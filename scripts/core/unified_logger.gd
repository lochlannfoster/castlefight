# Unified Logging System
# Path: scripts/core/unified_logger.gd
extends Node

# Log levels
enum LogLevel {
    DEBUG,
    INFO,
    WARNING,
    ERROR,
    CRITICAL
}

# Log output destinations
enum LogDestination {
    CONSOLE,
    FILE,
    BOTH
}

# Log entry structure
class LogEntry:
    var timestamp: int
    var level: int
    var category: String
    var message: String
    var context: Dictionary = {}

# Logging configuration
var _config: Dictionary = {
    "current_level": LogLevel.INFO,
    "destination": LogDestination.BOTH,
    "log_file_path": "user://logs/game_log.txt",
    "max_log_files": 5,
    "log_file_size_limit_mb": 10
}

# Log buffer
var _log_buffer: Array = []
var _file_handle: File = null

# Performance tracking
var _performance_logs: Array = []

func _ready():
    # Ensure log directory exists
    var dir = Directory.new()
    if not dir.dir_exists("user://logs"):
        dir.make_dir_recursive("user://logs")
    
    # Rotate log files if needed
    _rotate_log_files()
    
    # Open log file
    _open_log_file()

func _exit_tree():
    # Close log file on exit
    if _file_handle and _file_handle.is_open():
        _file_handle.close()

# Open log file for writing
func _open_log_file():
    _file_handle = File.new()
    var open_result = _file_handle.open(_config.log_file_path, File.WRITE)
    
    if open_result != OK:
        push_error("Could not open log file: " + _config.log_file_path)

# Rotate log files to prevent excessive growth
func _rotate_log_files():
    var dir = Directory.new()
    var base_path = _config.log_file_path
    
    # Check file size and rotate if too large
    var file = File.new()
    if file.file_exists(base_path):
        file.open(base_path, File.READ)
        var file_size = file.get_len()
        file.close()
        
        if file_size > _config.log_file_size_limit_mb * 1024 * 1024:
            for i in range(_config.max_log_files - 1, 0, -1):
                var old_path = base_path + "." + str(i)
                var new_path = base_path + "." + str(i + 1)
                
                if dir.file_exists(old_path):
                    dir.rename(old_path, new_path)
            
            # Rename current log file
            dir.rename(base_path, base_path + ".1")

# Core logging method
func log(level: int, message: String, category: String = "General", context: Dictionary = {}):
    # Skip logs below current level
    if level < _config.current_level:
        return
    
    var entry = LogEntry.new()
    entry.timestamp = OS.get_unix_time()
    entry.level = level
    entry.category = category
    entry.message = message
    entry.context = context
    
    # Console output
    if _config.destination == LogDestination.CONSOLE or _config.destination == LogDestination.BOTH:
        _log_to_console(entry)
    
    # File output
    if _config.destination == LogDestination.FILE or _config.destination == LogDestination.BOTH:
        _log_to_file(entry)

# Log to console
func _log_to_console(entry: LogEntry):
    var level_prefix = _get_level_prefix(entry.level)
    var console_message = "[%s] [%s] %s" % [level_prefix, entry.category, entry.message]
    print(console_message)

# Log to file
func _log_to_file(entry: LogEntry):
    if not _file_handle or not _file_handle.is_open():
        _open_log_file()
    
    var file_message = "[%d] [%s] [%s] %s" % [
        entry.timestamp,
        _get_level_prefix(entry.level),
        entry.category,
        entry.message
    ]
    
    # Write to file
    _file_handle.store_line(file_message)
    _file_handle.flush()

# Get string prefix for log level
func _get_level_prefix(level: int) -> String:
    match level:
        LogLevel.DEBUG:
            return "DEBUG"
        LogLevel.INFO:
            return "INFO"
        LogLevel.WARNING:
            return "WARN"
        LogLevel.ERROR:
            return "ERROR"
        LogLevel.CRITICAL:
            return "CRIT"
        _:
            return "LOG"

# Performance logging
func log_performance_start(operation_name: String) -> Dictionary:
    var start_time = OS.get_ticks_msec()
    var start_memory = OS.get_static_memory_usage()
    
    return {
        "operation": operation_name,
        "start_time": start_time,
        "start_memory": start_memory
    }

func log_performance_end(perf_data: Dictionary):
    var end_time = OS.get_ticks_msec()
    var end_memory = OS.get_static_memory_usage()
    
    var duration = end_time - perf_data.start_time
    var memory_change = end_memory - perf_data.start_memory
    
    log(
        LogLevel.INFO,
        "Performance: %s took %d ms, memory change %d bytes" % [
            perf_data.operation,
            duration,
            memory_change
        ],
        "Performance"
    )

# Convenience methods for different log levels
func debug(message: String, category: String = "General", context: Dictionary = {}):
    log(LogLevel.DEBUG, message, category, context)

func info(message: String, category: String = "General", context: Dictionary = {}):
    log(LogLevel.INFO, message, category, context)

func warning(message: String, category: String = "General", context: Dictionary = {}):
    log(LogLevel.WARNING, message, category, context)

func error(message: String, category: String = "General", context: Dictionary = {}):
    log(LogLevel.ERROR, message, category, context)

func critical(message: String, category: String = "General", context: Dictionary = {}):
    log(LogLevel.CRITICAL, message, category, context)