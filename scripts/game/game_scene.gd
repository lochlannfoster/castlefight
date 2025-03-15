extends Node2D

# Game scene script - Manages the game scene initialization
# Path: scripts/game/game_scene.gd

# Called when the scene enters the tree
func _ready():
	print("DEBUG: game_scene _ready() started")
	
	# Load the map scene first
	var map_scene = load("res://scenes/game/map.tscn")
	if map_scene:
		var map_instance = map_scene.instance()
		add_child(map_instance)
		print("Map loaded successfully")
	else:
		print("ERROR: Failed to load map scene")
	
	# Set up camera
	print("Setting up camera")
	var camera = get_node_or_null("Camera2D")
	if camera:
		camera.position = Vector2(400, 300)
		camera.current = true
		print("Camera positioned at " + str(camera.position))
	else:
		print("Creating new camera")
		camera = Camera2D.new()
		camera.name = "Camera2D"
		camera.position = Vector2(400, 300)
		camera.current = true
		add_child(camera)
		print("Created new camera at " + str(camera.position))
	
	# Call initialization functions to set up the game
	print("DEBUG: About to call _initialize_game()")
	_initialize_game()
	
	# Call emergency init after a short delay to ensure everything is loaded
	print("DEBUG: Setting up emergency init timer")
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.connect("timeout", self, "_emergency_init")
	timer.start()
	
	print("DEBUG: game_scene _ready() completed")

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
	
	# Debug game manager state
	if game_manager:
		print("DEBUG: Game manager current_state = ", game_manager.current_state)
		print("DEBUG: Game manager players count = ", game_manager.players.size())
	else:
		print("ERROR: Game manager not found")
	
	# Initialize grid
	if grid_system:
		print("Initializing grid system...")
		grid_system.initialize_grid()
	else:
		print("ERROR: Grid system not found")
	
	# Setup simple UI for testing
	print("DEBUG: About to call _setup_simple_ui()")
	call_deferred("_setup_simple_ui")
	
	# If game wasn't started by NetworkManager, we can start it directly
	if game_manager:
		if game_manager.current_state == game_manager.GameState.SETUP:
			print("Starting game in single player mode")
			
			# Create a player in single-player mode if needed
			if game_manager.players.empty():
				print("DEBUG: Adding default player")
				game_manager.add_player(1, "Player", 0)
				print("Added default player")
			else:
				print("DEBUG: Players already exist, count =", game_manager.players.size())
			
			# Start game
			print("DEBUG: Calling deferred _start_single_player_game()")
			call_deferred("_start_single_player_game", game_manager)
		else:
			print("DEBUG: Game not in SETUP state, current_state =", game_manager.current_state)
	else:
		print("ERROR: Game manager not found for game start")
	
	print("DEBUG: _initialize_game() completed")
		
func _emergency_init():
	print("Emergency initialization triggered")
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		print("DEBUG: Emergency - Game manager found")
		print("DEBUG: Emergency - Game manager current_state =", game_manager.current_state)
		print("DEBUG: Emergency - Game manager players count =", game_manager.players.size())
		
		if game_manager.current_state == game_manager.GameState.PLAYING:
			print("DEBUG: Game already in PLAYING state, emergency not needed")
			return
			
		game_manager.start_game()
		
		# Try to directly create HQs and workers
		print("Creating emergency game elements...")
		
		# Try to create HQs
		if game_manager.building_manager:
			print("DEBUG: Emergency - Building manager found")
			for team in range(2):
				var position = Vector2(200 + team * 400, 300)
				print("DEBUG: Emergency - Creating HQ for team", team, "at", position)
				var hq = game_manager.building_manager._create_headquarters_building(position, team)
				if hq:
					print("Successfully created emergency HQ for team " + str(team))
				else:
					print("Failed to create emergency HQ for team " + str(team))
		else:
			print("DEBUG: Emergency - Building manager not found")
		
		# Try to create a worker
		print("DEBUG: Emergency - Creating test worker")
		_add_test_worker()
	else:
		print("DEBUG: Emergency - Game manager not found")

func _start_single_player_game(game_manager):
	print("DEBUG: _start_single_player_game() called with game_manager:", game_manager)
	if game_manager:
		print("DEBUG: About to call game_manager.start_game()")
		game_manager.start_game()
		print("DEBUG: game_manager.start_game() completed")
	else:
		print("ERROR: game_manager is null in _start_single_player_game")

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
	print("Making worker visible for team " + str(worker.team))
	var sprite = worker.get_node_or_null("Sprite")
	if sprite:
		# Make sprite bright green or red depending on team
		sprite.modulate = Color(0, 1, 0) if worker.team == 0 else Color(1, 0, 0)  
		sprite.scale = Vector2(2, 2)  # Make it twice as big
	
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

