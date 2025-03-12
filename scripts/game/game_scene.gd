extends Node2D

func _ready():
	print("Game scene loaded")
	
	# Get references to global managers using normal get_node
	var game_manager = null
	var grid_system = null
	
	if has_node("/root/GameManager"):
		game_manager = get_node("/root/GameManager")
	
	if has_node("/root/GridSystem"):
		grid_system = get_node("/root/GridSystem")
	
	# Initialize grid
	if grid_system:
		grid_system.initialize_grid()
		print("Grid system initialized")
	
	# If game wasn't started by NetworkManager, we can start it directly
	if game_manager:
		if game_manager.players.empty():
			game_manager.add_player(1, "Player", 0)
		# Use a timer to delay the game start a bit
		var timer = Timer.new()
		add_child(timer)
		timer.wait_time = 0.5
		timer.one_shot = true
		timer.connect("timeout", self, "_start_game", [game_manager])
		timer.start()

# Method to start the game after a short delay
func _start_game(game_manager):
	game_manager.start_game()
