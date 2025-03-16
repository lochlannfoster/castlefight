# scripts/core/loggable.gd
extends Node
class_name Loggable

# Get logger reference
var _logger = null

func _get_logger():
    if not _logger:
        _logger = get_node_or_null("/root/UnifiedLogger")
    return _logger

# Log methods
func log_error(message, category = null):
    var logger = _get_logger()
    if logger:
        var actual_category = category if category else _get_default_category()
        logger.error(message, actual_category)
    else:
        print("[ERROR] " + message)

func log_warning(message, category = null):
    var logger = _get_logger()
    if logger:
        var actual_category = category if category else _get_default_category()
        logger.warning(message, actual_category)
    else:
        print("[WARNING] " + message)

func log_info(message, category = null):
    var logger = _get_logger()
    if logger:
        var actual_category = category if category else _get_default_category()
        logger.info(message, actual_category)
    else:
        print("[INFO] " + message)

func log(message, category = null):
    var logger = _get_logger()
    if logger:
        var actual_category = category if category else _get_default_category()
        logger.debug(message, actual_category)
    else:
        print("[DEBUG] " + message)

func log_verbose(message, category = null):
    var logger = _get_logger()
    if logger:
        var actual_category = category if category else _get_default_category()
        logger.verbose(message, actual_category)

func _get_default_category():
    # Try to derive category from class name or script path
    var script_path = get_script().get_path()
    var file_name = script_path.get_file().get_basename()
    
    # Map common script names to categories
    match file_name:
        "building_base", "building_manager", "hq_building":
            return "Building"
        "unit_base", "unit_factory":
            return "Unit"
        "combat_system":
            return "Combat"
        "economy_manager":
            return "Economy"
        "grid_system", "map_manager", "fog_of_war":
            return "Grid"
        "network_manager":
            return "Network"
        "ui_manager", "building_menu":
            return "UI"
        "game_manager", "game_scene":
            return "Game"
        _:
            # Default to script name if no mapping found
            return file_name.capitalize()

# Performance tracking methods
func profile_start(operation_name):
    var logger = _get_logger()
    if logger:
        return logger.log_performance_start(operation_name)
    return null

func profile_end(perf_data):
    var logger = _get_logger()
    if logger and perf_data:
        return logger.log_performance_end(perf_data)
    return null