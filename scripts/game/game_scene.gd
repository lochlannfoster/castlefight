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

# Initialize the game after a short delay
func _initialize_game():
    print("DEBUG: _initialize_game() started")
    # Get references to global managers
    var game_manager = get_node_or_null("/root/GameManager")
    var grid_system = get_node_or_null("/root/GridSystem")
    var economy_manager = get_node_or_null("/root/EconomyManager")
    
    # Get UI manager from game manager
    if game_manager and game_manager.ui_manager == null:
        # Load UI manager if it doesn't exist
        var ui_manager_script = load("res://scripts/ui/ui_manager.gd")
        if ui_manager_script:
            var ui_manager = ui_manager_script.new()
            ui_manager.name = "UIManager"
            game_manager.ui_manager = ui_manager
            add_child(ui_manager)
            print("UI Manager added to scene")
        else:
            push_error("Failed to load UI manager script")
    
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

func _input(event):
    # Only check for scancode on keyboard events
    if event is InputEventKey and event.pressed:
        print("Key pressed: " + str(event.scancode))
        
        if event.scancode == KEY_B:
            print("B key pressed - opening building menu")
            var ui_manager = get_node_or_null("UIManager")
            if ui_manager and ui_manager.has_method("toggle_building_menu"):
                ui_manager.toggle_building_menu()
        elif event.scancode == KEY_G:
            # Toggle grid visualization with G key
            print("G key pressed - toggling grid visualization")
            var game_manager = get_node_or_null("/root/GameManager")
            if game_manager and game_manager.has_method("toggle_grid_visualization"):
                game_manager.toggle_grid_visualization()
            
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

func _add_test_worker():
    print("Adding test worker to scene...")
    
    # Try to load the worker scene
    var worker_scene = load("res://scenes/units/worker.tscn")
    if not worker_scene:
        print("ERROR: Failed to load worker scene")
        return
        
    # Create worker instance
    var worker = worker_scene.instance()
    
    # Set team and position
    worker.team = 0 # Team A (blue)
    worker.position = Vector2(400, 300) # Center of screen
    
    # Add to scene
    add_child(worker)
    
    print("Test worker added at position: " + str(worker.position))
    
    # Select the worker with UI manager if available
    var ui_manager = get_node_or_null("UIManager")
    if ui_manager and ui_manager.has_method("select_worker"):
        ui_manager.select_worker(worker)
        print("Worker selected by UI manager")

func _draw():
    # Draw a grid every 100 pixels
    var grid_size = 100
    var grid_color = Color(0.3, 0.3, 0.3, 0.5)
    
    # Draw vertical lines
    for x in range(0, 3000, grid_size):
        draw_line(Vector2(x, 0), Vector2(x, 2000), grid_color)
    
    # Draw horizontal lines
    for y in range(0, 2000, grid_size):
        draw_line(Vector2(0, y), Vector2(0, 3000), grid_color)

func _process(_delta):
    # This will redraw the grid as the camera moves
    update()
