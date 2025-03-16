# scripts/core/file_utils.gd
extends Node

# Ensure a directory exists
func ensure_directory(path: String) -> bool:
    var dir = Directory.new()
    if dir.dir_exists(path):
        return true
        
    var error = dir.make_dir_recursive(path)
    return error == OK

# Load a JSON file
func load_json(path: String, default_data: Dictionary = {}) -> Dictionary:
    var file = File.new()
    
    if not file.file_exists(path):
        return default_data
    
    var error = file.open(path, File.READ)
    if error != OK:
        print("Error opening file: " + path)
        return default_data
    
    var text = file.get_as_text()
    file.close()
    
    var parse_result = JSON.parse(text)
    if parse_result.error != OK:
        print("Error parsing JSON: " + path)
        return default_data
    
    return parse_result.result

# Save a Dictionary as a JSON file
func save_json(path: String, data: Dictionary, pretty: bool = true) -> bool:
    # Ensure directory exists
    var dir_path = path.get_base_dir()
    ensure_directory(dir_path)
    
    # Save file
    var file = File.new()
    var error = file.open(path, File.WRITE)
    
    if error != OK:
        print("Error opening file for writing: " + path)
        return false
    
    file.store_string(JSON.print(data, "  " if pretty else ""))
    file.close()
    
    return true