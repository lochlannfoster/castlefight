# scripts/core/file_utils.gd
extends Node

# Ensure a directory exists
func ensure_directory(path: String) -> bool:
    var dir = DirAccess.new()
    if DirAccess.dir_exists_absolute(path):
        return true
        
    var error = DirAccess.make_dir_recursive_absolute(path)
    return error == OK

# Load a JSON file
func load_json(path: String, default_data: Dictionary = {}) -> Dictionary:    
    if not FileAccess.file_exists(path):
        return default_data
    
    var error = file.open(path, FileAccess.READ)
    if error != OK:
        print("Error opening file: " + path)
        return default_data
    
    var text = file.get_as_text()
    file.close()
    
    var test_json_conv = JSON.new()
    test_json_conv.parse(text)
    var parse_result = test_json_conv.get_data()
    if parse_result.error != OK:
        print("Error parsing JSON: " + path)
        return default_data
    
    return json.data

# Save a Dictionary as a JSON file
func save_json(path: String, data: Dictionary, pretty: bool = true) -> bool:
    # Ensure directory exists
    var dir_path = path.get_base_dir()
    var _result = ensure_directory(dir_path)
    
    # Save file    var error = file.open(path, FileAccess.WRITE)
    
    if error != OK:
        print("Error opening file for writing: " + path)
        return false
    
    file.store_string(JSON.stringify(data, "  " if pretty else ""))
    file.close()
    
    return true