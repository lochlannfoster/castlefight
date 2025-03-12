extends Node2D

# Game scene script - Manages the game scene initialization
# Path: scripts/game/game_scene.gd

# Called when the scene enters the tree
func _ready():
	print("Game scene loaded")
	
	# Fallback initialization if automated methods fail
	call_deferred("_emergency_init")

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

# Add a test worker for UI testing
func _add_test_worker():
	print("Adding test worker...")
	
	# Make sure the worker directory exists
	var dir = Directory.new()
	if not dir.dir_exists("res://scenes/units"):
		dir.make_dir_recursive("res://scenes/units")
	
	# Check if the worker scene exists
	var worker_scene_path = "res://scenes/units/worker.tscn"
	var file = File.new()
	var worker_scene
	
	if file.file_exists(worker_scene_path):
		worker_scene = load(worker_scene_path)
	
	if not worker_scene:
		print("Worker scene not found or couldn't be loaded, creating simple worker directly")
		
		# Create a basic worker directly
		var worker = KinematicBody2D.new()
		worker.name = "TestWorker"
		
		# Load worker script
		var script = load("res://scripts/worker/worker.gd")
		if script:
			worker.set_script(script)
		else:
			print("Could not load worker script!")
			return
		
		var sprite = Sprite.new()
		sprite.name = "Sprite"
		worker.add_child(sprite)
		
		var collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape = CircleShape2D.new()
		shape.radius = 16.0
		collision.shape = shape
		worker.add_child(collision)
		
		# Add indicator and ghost nodes
		var selection_indicator = Node2D.new()
		selection_indicator.name = "SelectionIndicator"
		selection_indicator.visible = false
		worker.add_child(selection_indicator)
		
		var selection_rect = ColorRect.new()
		selection_rect.rect_size = Vector2(36, 36)
		selection_rect.rect_position = Vector2(-18, -18)
		selection_rect.color = Color(0, 1, 0, 0.3)
		selection_indicator.add_child(selection_rect)
		
		var building_ghost = Node2D.new()
		building_ghost.name = "BuildingGhost"
		building_ghost.visible = false
		worker.add_child(building_ghost)
		
		var ghost_visual = ColorRect.new()
		ghost_visual.name = "GhostVisual"
		ghost_visual.rect_size = Vector2(64, 64)
		ghost_visual.rect_position = Vector2(-32, -32)
		ghost_visual.color = Color(0, 1, 0, 0.5)
		building_ghost.add_child(ghost_visual)
		
		# Set worker properties and add to scene
		worker.position = Vector2(400, 300)
		worker.team = 0  # Team A
		worker.add_to_group("workers")
		
		# Adding directly to scene
		add_child(worker)
		print("Created test worker")
		return
	
	# Create instance from scene
	var worker = worker_scene.instance()
	worker.position = Vector2(400, 300)
	worker.team = 0  # Team A
	worker.add_to_group("workers")
	add_child(worker)
	print("Added test worker from scene")
