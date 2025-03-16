# scripts/core/logger.gd
extends Node

# This is a simple global accessor for the unified logger
# It allows any script to use the logger without needing to lookup references

var _logger = null

func _ready():
    # Get a reference to the real logger
    _logger = get_node_or_null("/root/UnifiedLogger")
    
    # Log initialization
    if _logger:
        _logger.info("Logger API singleton initialized", "System")
    else:
        print("WARNING: UnifiedLogger not found!")

# Forward logging methods to the real logger
func error(message, category = "General"):
    if _logger:
        _logger.error(message, category)
    else:
        print("[ERROR] [" + category + "] " + message)

func warning(message, category = "General"):
    if _logger:
        _logger.warning(message, category)
    else:
        print("[WARNING] [" + category + "] " + message)

func info(message, category = "General"):
    if _logger:
        _logger.info(message, category)
    else:
        print("[INFO] [" + category + "] " + message)

func debug(message, category = "General"):
    if _logger:
        _logger.debug(message, category)
    else:
        print("[DEBUG] [" + category + "] " + message)

func verbose(message, category = "General"):
    if _logger:
        _logger.verbose(message, category)
    else:
        print("[VERBOSE] [" + category + "] " + message)

# Add this to autoload in project.godot as Logger