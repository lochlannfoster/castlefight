# scripts/core/resource_manager.gd
extends GameService
class_name ResourceManager

# Resource cache by type
var _scenes: Dictionary = {}
var _scripts: Dictionary = {}
var _textures: Dictionary = {}
var _materials: Dictionary = {}
var _audio: Dictionary = {}
var _json_data: Dictionary = {}

# Resource loading status tracking
var _load_errors: Dictionary = {}
var _load_attempts: Dictionary = {}

# Required directories for the project
var required_directories: Array = [
    "res://data/",
    "res://data/items/",
    "res://data/buildings/",
    "res://data/units/",
    "res://data/combat/",
    "res://data/tech_trees/",
    "res://data/maps/",
    "res://scenes/",
    "res://scenes/units/",
    "res://scenes/buildings/",
    "res://scenes/ui/",
    "res://scenes/game/",
    "res://assets/",
    "res://assets/units/",
    "res://assets/buildings/",
    "res://assets/ui/",
    "res://scripts/",
]

# Required base scenes that should always exist
var required_base_scenes: Dictionary = {
    "res://scenes/units/base_unit.tscn": {
        "type": "Unit",
        "script": "res://scripts/unit/unit_base.gd"
    },
    "res://scenes/units/worker.tscn": {
        "type": "Worker",
        "script": "res://scripts/worker/worker.gd"
    },
    "res://scenes/buildings/base_building.tscn": {
        "type": "Building",
        "script": "res://scripts/building/building_base.gd"
    },
    "res://scenes/buildings/hq_building.tscn": {
        "type": "HeadquartersBuilding",
        "script": "res://scripts/building/hq_building.gd"
    },
    "res://scenes/ui/building_menu.tscn": {
        "type": "BuildingMenu",
        "script": "res://scripts/ui/building_menu.gd"
    }
}

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
        else if service_name:
            prefix += "[" + service_name + "]"
        print(prefix + " " + message)

func _init() -> void:
    service_name = "ResourceManager"
    required_services = ["DebugLogger"]

func _initialize_impl() -> void:
    debug_log("Initializing resource manager...")
    
    # Ensure required directories exist
    _ensure_directories_exist()
    
    # Ensure required base scenes exist
    _ensure_base_scenes_exist()
    
    # Preload essential resources
    _preload_essential_resources()
    
    debug_log("Resource manager initialized successfully")

# Ensure all required directories exist
func _ensure_directories_exist() -> void:
    var dir = Directory.new()
    
    for directory in required_directories:
        if not dir.dir_exists(directory):
            debug_log("Creating missing directory: " + directory)
            var err = dir.make_dir_recursive(directory)
            if err != OK:
                debug_log("Failed to create directory: " + directory, "error")

# Ensure all required base scenes exist
func _ensure_base_scenes_exist() -> void:
    var file = File.new()
    
    for scene_path in required_base_scenes.keys():
        var scene_info = required_base_scenes[scene_path]
        
        if not file.file_exists(scene_path):
            debug_log("Required scene not found: " + scene_path + ". Creating it...", "warning")
            _create_base_scene(scene_path, scene_info)

# Create a base scene
func _create_base_scene(scene_path: String, scene_info: Dictionary) -> void:
    var script_path = scene_info.script
    var script = load(script_path)
    
    if not script:
        debug_log("Failed to load script for scene: " + scene_path, "error")
        return
    
    # Create appropriate root node based on type
    var root_node
    match scene_info.type:
        "Unit", "Worker":
            root_node = KinematicBody2D.new()
            
            # Add required components for units
            var sprite = Sprite.new()
            sprite.name = "Sprite"
            root_node.add_child(sprite)
            
            var collision = CollisionShape2D.new()
            collision.name = "CollisionShape2D"
            var shape = CircleShape2D.new()
            shape.radius = 16.0
            collision.shape = shape
            root_node.add_child(collision)
            
        "Building", "HeadquartersBuilding":
            root_node = StaticBody2D.new()
            
            # Add required components for buildings
            var sprite = Sprite.new()
            sprite.name = "Sprite"
            root_node.add_child(sprite)
            
            var collision = CollisionShape2D.new()
            collision.name = "CollisionShape2D"
            var shape = RectangleShape2D.new()
            shape.extents = Vector2(32, 32)
            collision.shape = shape
            root_node.add_child(collision)
            
        "BuildingMenu":
            root_node = Control.new()
            
            # Add required components for building menu
            var panel = Panel.new()
            panel.name = "Panel"
            panel.rect_position = Vector2(10, 10)
            panel.rect_size = Vector2(400, 300)
            root_node.add_child(panel)
            
            var title = Label.new()
            title.name = "TitleLabel"
            title.text = "Building Menu"
            title.rect_position = Vector2(10, 10)
            title.rect_size = Vector2(380, 30)
            title.align = Label.ALIGN_CENTER
            panel.add_child(title)
            
            var grid = GridContainer.new()
            grid.name = "BuildingGrid"
            grid.columns = 3
            grid.rect_position = Vector2(10, 50)
            grid.rect_size = Vector2(380, 230)
            panel.add_child(grid)
            
            var close_button = Button.new()
            close_button.name = "CloseButton"
            close_button.text = "X"
            close_button.rect_position = Vector2(370, 10)
            close_button.rect_size = Vector2(20, 20)
            panel.add_child(close_button)
            
        _:
            root_node = Node.new()
    
    # Set name and script
    root_node.name = scene_info.type
    root_node.set_script(script)
    
    # Pack scene
    var packed_scene = PackedScene.new()
    packed_scene.pack(root_node)
    
    # Save scene
    var err = ResourceSaver.save(scene_path, packed_scene)
    if err != OK:
        debug_log("Failed to save scene: " + scene_path + " with error: " + str(err), "error")
    else:
        debug_log("Successfully created scene: " + scene_path)

# Preload essential resources
func _preload_essential_resources() -> void:
    # Preload all base scenes
    for scene_path in required_base_scenes.keys():
        load_scene(scene_path)

# Load a scene
func load_scene(path: String) -> PackedScene:
    if _scenes.has(path):
        return _scenes[path]
    
    _track_load_attempt(path)
    
    var scene = load(path)
    if scene:
        _scenes[path] = scene
        return scene
    
    _track_load_error(path, "Scene not found")
    return null

# Load a script
func load_script(path: String) -> Script:
    if _scripts.has(path):
        return _scripts[path]
    
    _track_load_attempt(path)
    
    var script = load(path)
    if script:
        _scripts[path] = script
        return script
    
    _track_load_error(path, "Script not found")
    return null

# Load a texture
func load_texture(path: String) -> Texture:
    if _textures.has(path):
        return _textures[path]
    
    _track_load_attempt(path)
    
    var texture = load(path)
    if texture:
        _textures[path] = texture
        return texture
    
    _track_load_error(path, "Texture not found")
    return null

# Load JSON data
func load_json_data(path: String) -> Dictionary:
    if _json_data.has(path):
        return _json_data[path]
    
    _track_load_attempt(path)
    
    var file = File.new()
    if not file.file_exists(path):
        _track_load_error(path, "JSON file not found")
        return {}
    
    var error = file.open(path, File.READ)
    if error != OK:
        _track_load_error(path, "Could not open JSON file: " + str(error))
        return {}
    
    var text = file.get_as_text()
    file.close()
    
    var parse_result = JSON.parse(text)
    if parse_result.error != OK:
        _track_load_error(path, "JSON parse error: " + parse_result.error_string)
        return {}
    
    var data = parse_result.result
    _json_data[path] = data
    return data

# Create default JSON data
func create_default_json(path: String, default_data: Dictionary) -> Dictionary:
    var file = File.new()
    
    # Ensure directory exists
    var dir = Directory.new()
    var directory = path.get_base_dir()
    if not dir.dir_exists(directory):
        dir.make_dir_recursive(directory)
    
    # If file doesn't exist, create it with default data
    if not file.file_exists(path):
        var error = file.open(path, File.WRITE)
        if error != OK:
            debug_log("Could not create default JSON file: " + path, "error")
            return {}
        
        var json_text = JSON.print(default_data, "  ")
        file.store_string(json_text)
        file.close()
        
        # Store in cache
        _json_data[path] = default_data
        debug_log("Created default JSON file: " + path)
        
        return default_data
    
    # If file exists, load it
    return load_json_data(path)

# Track resource load attempt
func _track_load_attempt(path: String) -> void:
    if not _load_attempts.has(path):
        _load_attempts[path] = 0
    
    _load_attempts[path] += 1

# Track resource load error
func _track_load_error(path: String, error: String) -> void:
    _load_errors[path] = error
    debug_log("Resource load error: " + path + " - " + error, "error")

# Get load error for a path
func get_load_error(path: String) -> String:
    if _load_errors.has(path):
        return _load_errors[path]
    return ""

# Clear resource caches
func clear_caches() -> void:
    _scenes.clear()
    _scripts.clear()
    _textures.clear()
    _materials.clear()
    _audio.clear()
    # Don't clear JSON data as it rarely changes
    
    debug_log("Resource caches cleared")

# Reset the manager
func reset() -> void:
    clear_caches()