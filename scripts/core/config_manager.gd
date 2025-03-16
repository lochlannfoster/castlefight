# Centralized Configuration and Service Management
# Path: scripts/core/config_manager.gd
extends Node

# Singleton for managing game configurations and service initialization

# Configuration storage
var _config: Dictionary = {
    "game": {
        "version": "0.1.0",
        "debug_mode": false,
        "default_resolution": Vector2(1280, 720)
    },
    "network": {
        "default_port": 27015,
        "max_players": 6,
        "timeout": 300
    },
    "performance": {
        "target_fps": 60,
        "draw_debug_info": false
    }
}

# Initialization order and dependencies
var _initialization_order: Array = [
    "GridSystem",
    "EconomyManager",
    "CombatSystem",
    "BuildingManager",
    "NetworkManager",
    "UIManager"
]

# Get a configuration value with optional default
func get_config(category: String, key: String, default = null):
    if _config.has(category) and _config[category].has(key):
        return _config[category][key]
    return default

# Set a configuration value
func set_config(category: String, key: String, value):
    if not _config.has(category):
        _config[category] = {}
    _config[category][key] = value

# Load configuration from file
func load_config(path: String = "res://config.json") -> bool:
    var file = File.new()
    if not file.file_exists(path):
        push_warning("Configuration file not found: " + path)
        return false
    
    var json_text = file.get_as_text()
    file.close()
    
    var parse_result = JSON.parse(json_text)
    if parse_result.error != OK:
        push_error("JSON Parse Error: " + parse_result.error_string)
        return false
    
    # Merge loaded config with existing
    var loaded_config = parse_result.result
    for category in loaded_config:
        if not _config.has(category):
            _config[category] = {}
        for key in loaded_config[category]:
            _config[category][key] = loaded_config[category][key]
    
    return true

# Save current configuration to file
func save_config(path: String = "user://config.json") -> bool:
    var file = File.new()
    if file.open(path, File.WRITE) != OK:
        push_error("Could not open file for writing: " + path)
        return false
    
    file.store_string(JSON.print(_config, "  "))
    file.close()
    return true

# Debug method to print current configuration
func print_config() -> void:
    print("Current Game Configuration:")
    for category in _config:
        print(f"[{category}]")
        for key in _config[category]:
            print(f"  {key}: {_config[category][key]}")