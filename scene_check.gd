# Run this in Godot to check if game.tscn exists and create it if needed

extends SceneTree

func _init():
	var file = File.new()
	var scene_path = "res://scenes/game/game.tscn"
	
	if not file.file_exists(scene_path):
		print("Game scene does not exist, creating it")
		
		# Create the directory if it doesn't exist
		var dir = Directory.new()
		if not dir.dir_exists("res://scenes/game"):
			dir.make_dir_recursive("res://scenes/game")
		
		# Create a basic game scene
		var game_scene = Node2D.new()
		game_scene.name = "Game"
		
		# Add a script
		var script = load("res://scripts/game/game_scene.gd")
		if script:
			game_scene.set_script(script)
		else:
			# Create the script if it doesn't exist
			dir = Directory.new()
			if not dir.dir_exists("res://scripts/game"):
				dir.make_dir_recursive("res://scripts/game")
			
			file = File.new()
			file.open("res://scripts/game/game_scene.gd", File.WRITE)
			file.store_string(
"""extends Node2D

func _ready():
	print("Game scene loaded")
	
	# Get references to global managers
	var game_manager = get_node_or_null("/root/GameManager")
	var grid_system = get_node_or_null("/root/GridSystem")
	
	# Initialize grid
	if grid_system:
		grid_system.initialize_grid()
		print("Grid system initialized")
	
	# If game wasn't started by NetworkManager, we can start it directly
	if game_manager and game_manager.current_state == game_manager.GameState.SETUP:
		print("Starting game from game scene")
		# For testing only - create a player in single-player mode
		if game_manager.players.empty():
			game_manager.add_player(1, "Player", 0)
		game_manager.start_game()
"""
			)
			file.close()
			
			# Load the script
			script = load("res://scripts/game/game_scene.gd")
			game_scene.set_script(script)
		
		# Create basic game world
		var game_world = Node2D.new()
		game_world.name = "GameWorld"
		game_scene.add_child(game_world)
		
		# Add ground node
		var ground = Node2D.new()
		ground.name = "Ground"
		game_world.add_child(ground)
		
		# Add units node
		var units = Node2D.new()
		units.name = "Units"
		game_world.add_child(units)
		
		# Add buildings node
		var buildings = Node2D.new()
		buildings.name = "Buildings"
		game_world.add_child(buildings)
		
		# Add camera
		var camera = Camera2D.new()
		camera.name = "Camera2D"
		camera.current = true
		game_scene.add_child(camera)
		
		# Save the scene
		var packed_scene = PackedScene.new()
		packed_scene.pack(game_scene)
		ResourceSaver.save(scene_path, packed_scene)
		
		print("Game scene created at: " + scene_path)
	else:
		print("Game scene already exists at: " + scene_path)
	
	quit()
