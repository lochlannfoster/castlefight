extends Node2D

# Game scene script - Manages the game scene initialization
# Path: scripts/game/game_scene.gd

# Called when the scene enters the tree
func _ready():
	print("Game scene loaded")
	
	# Load the map scene first
	var map_scene = load("res://scenes/game/map.tscn")
	if map_scene:
		var map_instance = map_scene.instance()
		add_child(map_instance)
		print("Map loaded successfully")
	else:
		print("ERROR: Could not load map scene!")
	
func _emergency_init():
	print("Emergency initialization triggered")
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.start_game()
	

# Initialize the game after a short delay
func _initialize_game():
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
	
	# Setup simple UI for testing
	call_deferred("_setup_simple_ui")
	
	# If game wasn't started by NetworkManager, we can start it directly
	if game_manager:
		if game_manager.current_state == game_manager.GameState.SETUP:
			print("Starting game in single player mode")
			
			# Create a player in single-player mode if needed
			if game_manager.players.empty():
				game_manager.add_player(1, "Player", 0)
				print("Added default player")
			
			# Start game
			call_deferred("_start_single_player_game", game_manager)

# Start the game in single player mode
func _start_single_player_game(game_manager):
	if game_manager:
		game_manager.start_game()

# Setup a simple UI manager for testing
func _setup_simple_ui():
	print("Setting up simple UI for testing...")
	
	# First check if a UI manager already exists
	var existing_ui = get_node_or_null("/root/GameManager/UIManager")
	if existing_ui:
		print("Game already has a UI manager, using that")
		return
	
	# Create directory if needed
	var dir = Directory.new()
	if not dir.dir_exists("res://scripts/ui"):
		dir.make_dir_recursive("res://scripts/ui")
	
	# Check if the simple UI script exists, create it if not
	var simple_ui_path = "res://scripts/ui/simple_ui_manager.gd"
	var file = File.new()
	
	if !file.file_exists(simple_ui_path):
		print("Simple UI manager script not found, it should be created automatically")
	
	# Load the script
	var simple_ui_script = load(simple_ui_path)
	
	if simple_ui_script:
		print("Creating UI manager instance")
		var ui_manager = CanvasLayer.new()
		ui_manager.name = "SimpleUIManager"
		ui_manager.set_script(simple_ui_script)
		
		# Add to scene tree - use call_deferred to avoid errors
		call_deferred("_add_ui_manager", ui_manager)
	else:
		push_error("Failed to load simple_ui_manager.gd script")

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

func _add_test_worker():
	print("DEBUG: Creating test worker...")
	
	var worker_scene = load("res://scenes/units/worker.tscn")
	if not worker_scene:
		print("DEBUG: Worker scene file could not be loaded!")
		return
		
	var worker = worker_scene.instance()
	if not worker:
		print("DEBUG: Failed to instance worker scene!")
		return
		
	print("DEBUG: Worker instance created")
	worker.position = Vector2(400, 300)
	worker.team = 0  # Team A
	
	# Add directly to the scene
	add_child(worker)
	print("DEBUG: Worker added to scene at " + str(worker.position))
	
	# Make worker stand out
	var sprite = worker.get_node_or_null("Sprite")
	if sprite:
		sprite.modulate = Color(0, 1, 0)  # Bright green
		print("DEBUG: Worker colored bright green for visibility")
	
	# Select the worker
	if worker.has_method("select"):
		worker.select()
		print("DEBUG: Worker select() method called")
	
	# Select via UI manager too
	var ui_manager = get_node_or_null("SimpleUIManager")
	if ui_manager and ui_manager.has_method("select_worker"):
		ui_manager.select_worker(worker)
		print("DEBUG: UI manager select_worker() called")

func _input(event):
	if event is InputEventKey and event.pressed:
		print("Key pressed: " + str(event.scancode))
		
		if event.scancode == KEY_B:
			print("B key pressed - opening building menu")
			var ui_manager = get_node_or_null("SimpleUIManager")
			if ui_manager and ui_manager.has_method("toggle_building_menu"):
				ui_manager.toggle_building_menu()
			
		elif event.scancode == KEY_H:
			print("H key pressed - creating emergency HQ")
			# Create an HQ manually
			var game_manager = get_node_or_null("/root/GameManager")
			if game_manager and game_manager.building_manager:
				for team in range(2):
					var position = Vector2(200 + team * 600, 300)
					var hq = game_manager.building_manager.place_building("headquarters", position, team)
					if hq:
						print("Created HQ for team " + str(team))
					else:
						print("Failed to create HQ for team " + str(team))

