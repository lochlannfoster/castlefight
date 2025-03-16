extends Node2D

# Game scene script - Manages the game scene initialization
# Path: scripts/game/game_scene.gd

# Called when the scene enters the tree
func _ready() -> void:
    print("Game scene is initializing...")
    
    # Load the map scene
    var map_scene = load("res://scenes/game/map.tscn")
    if map_scene:
        var map_instance = map_scene.instance()
        add_child(map_instance)
        print("Map loaded successfully")
    else:
        print("ERROR: Failed to load map scene")
    
    # Setup camera with improved debugging
    print("Setting up camera...")
    _setup_camera()
    print("Camera setup complete")
    
    # Initialize game
    print("Initializing game...")
    _initialize_game()
    
    # Add test worker after a short delay
    print("Scheduling test worker spawn...")
    var timer = Timer.new()
    add_child(timer)
    timer.wait_time = 1.0
    timer.one_shot = true
    timer.connect("timeout", self, "_add_test_worker")
    timer.start()

# Initialize the game after a short delay
func _initialize_game():
    print("DEBUG: _initialize_game() started")
    # Get references to global managers
    var game_manager = get_node_or_null("/root/GameManager")
    var grid_system = get_node_or_null("/root/GridSystem")
    var economy_manager = get_node_or_null("/root/EconomyManager")
    
    # Log what we found
    print("Found game manager: ", game_manager != null)
    print("Found grid system: ", grid_system != null)
    print("Found economy manager: ", economy_manager != null)
    
    # Initialize grid
    if grid_system:
        print("Initializing grid system...")
        grid_system.initialize_grid()
    
# Start the game in single player mode
func _start_single_player_game(game_manager):
    print("DEBUG: _start_single_player_game() called with game_manager:" + str(game_manager))
    if game_manager:
        print("DEBUG: About to call game_manager.start_game()")
        game_manager.start_game()
        print("DEBUG: game_manager.start_game() completed")


    # Load the comprehensive UI manager script
    var ui_manager_path = "res://scripts/ui/ui_manager.gd"
    var file = File.new()
    
    if !file.file_exists(ui_manager_path):
        print("UI manager script not found, please create it first")
        return
    
    # Load the script and create proper UIManager instance
    var ui_manager_script = load(ui_manager_path)
    
    if ui_manager_script:
        print("Creating UI manager instance")
        var ui_manager = ui_manager_script.new()
        ui_manager.name = "UIManager"
        
        # Add to scene tree - use call_deferred to avoid errors
        call_deferred("_add_ui_manager", ui_manager)
    else:
        push_error("Failed to load UI manager script")

# Add the UI manager to the scene  
func _add_ui_manager(ui_manager):
    add_child(ui_manager)
    
    # Set up a timer to add the worker after the UI manager is initialized
    var worker_timer = Timer.new()
    add_child(worker_timer)
    worker_timer.wait_time = 0.2
    worker_timer.one_shot = true
    worker_timer.autostart = true
    worker_timer.connect("timeout", self, "_add_test_worker")
    worker_timer.connect("timeout", worker_timer, "queue_free")

func _input(event):
    # Only check for scancode on keyboard events
    if event is InputEventKey and event.pressed:
        print("Key pressed: " + str(event.scancode))
        
        if event.scancode == KEY_B:
            print("B key pressed - opening building menu")
            var ui_manager = get_node_or_null("UIManager")
            if ui_manager and ui_manager.has_method("toggle_building_menu"):
                ui_manager.toggle_building_menu()
            
    # Handle other input types if needed
    elif event is InputEventMouseButton:
        # Mouse button code here
        pass

func _setup_camera():
    var camera = Camera2D.new()
    camera.name = "GameCamera"
    camera.position = Vector2(400, 300) # Center of the default view
    camera.current = true
    
    # Add camera control script if available
    var camera_script = load("res://scripts/core/camera_controller.gd")
    if camera_script:
        camera.set_script(camera_script)
    
    add_child(camera)
    print("Camera set up at position: " + str(camera.position))
