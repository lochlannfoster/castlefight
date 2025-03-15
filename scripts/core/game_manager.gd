# Game Manager - Coordinates all game systems
# Path: scripts/core/game_manager.gd
extends Node

# Game signals
signal game_started
signal game_ended(winning_team)
signal player_joined(player_id, team)
signal player_left(player_id)
signal team_eliminated(team)
signal match_countdown_updated(time_remaining)

# Game settings
export var match_duration: float = 1800.0  # 30 minutes maximum match time
export var pregame_countdown: float = 10.0  # 10 seconds countdown before game starts
export var max_players_per_team: int = 3
export var team_colors: Array = [Color(0, 0, 1), Color(1, 0, 0)]  # Blue, Red

# Game state
enum GameState {SETUP, PREGAME, PLAYING, ENDED}
var current_state: int = GameState.SETUP
var match_timer: float = 0
var countdown_timer: float = 0
var is_paused: bool = false
var winning_team: int = -1
var match_id: String = ""

# Player and team tracking
var players: Dictionary = {}  # player_id -> player data
var team_players: Dictionary = {
	0: [],  # Team A player IDs
	1: []   # Team B player IDs
}

# Headquarters references
var headquarters: Dictionary = {
	0: null,  # Team A HQ
	1: null   # Team B HQ
}

# System references (will be initialized in _ready)
var grid_system
var building_manager
var combat_system
var economy_manager
onready var unit_factory = get_node_or_null("/root/UnitFactory")
var ui_manager
var fog_of_war_manager
var network_manager
var map_manager

# Script references for instantiation
var GridSystemScript = preload("res://scripts/core/grid_system.gd")
var CombatSystemScript = preload("res://scripts/combat/combat_system.gd")
var EconomyManagerScript = preload("res://scripts/economy/economy_manager.gd")
var BuildingManagerScript = preload("res://scripts/building/building_manager.gd")



# Ready function
func _ready() -> void:
	# Initialize match ID
	match_id = "match_" + str(OS.get_unix_time())
	
	# Run scene creator to ensure all required scenes exist
	_create_required_scenes()
	
	# Initialize and add subsystems as needed
	_initialize_systems()
	
	# Connect signals
	_connect_signals()
	
	# Start in setup state
	change_game_state(GameState.SETUP)

# Create required scenes if they don't exist yet
func _create_required_scenes() -> void:
	print("Checking for required scenes...")
	
	# Check if scene_creator.gd exists
	var scene_creator_path = "res://scripts/core/scene_creator.gd"
	var file = File.new()
	
	if file.file_exists(scene_creator_path):
		var SceneCreator = load(scene_creator_path)
		if SceneCreator:
			var creator = SceneCreator.new()
			add_child(creator)
			print("Scene creator is running...")
	else:
		print("Scene creator script not found at: " + scene_creator_path)

# Process function
func _process(delta: float) -> void:
	if is_paused:
		return
	
	match current_state:
		GameState.PREGAME:
			_update_pregame(delta)
		GameState.PLAYING:
			_update_gameplay(delta)

# Initialize all game subsystems
func _initialize_systems() -> void:
	# Initialize Grid System if not already in scene
	if not has_node("GridSystem"):
		# Use the preloaded script to instantiate
		grid_system = GridSystemScript.new()
		grid_system.name = "GridSystem"
		add_child(grid_system)
	else:
		grid_system = $GridSystem
	
	# Initialize Combat System
	if not has_node("CombatSystem"):
		# Use the preloaded script to instantiate
		combat_system = CombatSystemScript.new()
		combat_system.name = "CombatSystem"
		add_child(combat_system)
	else:
		combat_system = $CombatSystem
	
	# Initialize Economy Manager
	if not has_node("EconomyManager"):
		# Use the preloaded script to instantiate
		economy_manager = EconomyManagerScript.new()
		economy_manager.name = "EconomyManager"
		add_child(economy_manager)
	else:
		economy_manager = $EconomyManager
	
	# Initialize Building Manager
	if not has_node("BuildingManager"):
		# Use the preloaded script to instantiate
		building_manager = BuildingManagerScript.new()
		building_manager.name = "BuildingManager"
		add_child(building_manager)
	else:
		building_manager = $BuildingManager
	
	# Initialize Unit Factory (already a singleton)
	unit_factory = get_node_or_null("/root/UnitFactory")
	if not unit_factory:
		print("WARNING: UnitFactory not found! Creating manually.")
		unit_factory = load("res://scripts/unit/unit_factory.gd").new()
		add_child(unit_factory)
	
	# Initialize UI Manager if available
	ui_manager = get_node_or_null("UIManager")
	
	# Initialize Fog of War Manager if available
	fog_of_war_manager = get_node_or_null("FogOfWarManager")
	
	# Initialize Network Manager if available
	network_manager = get_node_or_null("NetworkManager")
	
	# Initialize Map Manager if available
	map_manager = get_node_or_null("MapManager")

# Connect signals between systems
func _connect_signals() -> void:
	# Connect building manager signals
	if building_manager:
		building_manager.connect("building_destroyed", self, "_on_building_destroyed")
	
	# Other connections will be added as needed

# Update pregame countdown
func _update_pregame(delta: float) -> void:
	countdown_timer -= delta
	
	emit_signal("match_countdown_updated", countdown_timer)
	
	if countdown_timer <= 0:
		start_game()

# Update gameplay
func _update_gameplay(delta: float) -> void:
	match_timer += delta
	
	# Check for match time limit
	if match_timer >= match_duration:
		_trigger_game_end_by_time()
	
	# TODO: Implement late-game escalation mechanics if needed

# Change the game state
func change_game_state(new_state: int) -> void:
	current_state = new_state
	
	match new_state:
		GameState.SETUP:
			# Reset game elements for setup
			_reset_game()
		GameState.PREGAME:
			# Start countdown to game start
			countdown_timer = pregame_countdown
		GameState.PLAYING:
			# Game is in progress
			match_timer = 0
		GameState.ENDED:
			# Game has ended
			pass

# Reset game to initial state
func _reset_game() -> void:
	# Reset timers
	match_timer = 0
	countdown_timer = pregame_countdown
	
	# Reset team data and headquarters
	headquarters = {0: null, 1: null}
	
	# Reset subsystems
	if grid_system:
		grid_system.initialize_grid()
	
	if economy_manager:
		# Reset resources to starting values
		pass

# Add a player to the game
func add_player(player_id, player_name: String, team: int) -> bool:
	# Ensure team is valid (0 or 1)
	if team < 0 or team > 1:
		team = 0  # Default to Team A if invalid
	
	# Check if teams are full
	if team_players[team].size() >= max_players_per_team:
		return false
	
	# Create player data
	var player_data = {
		"id": player_id,
		"name": player_name,
		"team": team,
		"worker": null,  # Will be created when game starts
		"resources": {
			"gold": 0,
			"wood": 0,
			"supply": 0
		}
	}
	
	# Add to player tracking
	players[player_id] = player_data
	team_players[team].append(player_id)
	
	emit_signal("player_joined", player_id, team)
	
	return true
	
# Remove a player from the game
func remove_player(player_id) -> void:
	if not players.has(player_id):
		return
	
	var team = players[player_id].team
	
	# Remove from team
	if team_players.has(team):
		team_players[team].erase(player_id)
	
	# Remove player data
	var _removed = players.erase(player_id)
	
	emit_signal("player_left", player_id)
	
	# Check if team is eliminated
	if team_players[team].empty():
		emit_signal("team_eliminated", team)
		
		# If team is eliminated, other team wins
		var other_team_wins = 1 if team == 0 else 0
		_trigger_game_end(other_team_wins)

# Start the pregame countdown
func start_pregame_countdown() -> void:
	change_game_state(GameState.PREGAME)

# Start the game
func start_game() -> void:
	print("GameManager: Attempting to start game")
	print("Current state: ", current_state)
	
	# Force the game to start from any state
	if current_state == GameState.PREGAME:
		countdown_timer = 0  # Skip countdown
	elif current_state != GameState.PLAYING:
		change_game_state(GameState.PLAYING)
	
	# Create workers for all players
	print("Creating player workers")
	_create_player_workers()
	
	# Create initial buildings (HQs)
	print("Creating starting buildings")
	_create_starting_buildings()
	
	# Start the game if not already in PLAYING state
	if current_state != GameState.PLAYING:
		change_game_state(GameState.PLAYING)
	
	emit_signal("game_started")
	print("GameManager: Game started signal emitted")
	
# Make _create_player_workers more robust
func _create_player_workers() -> void:
	print("Creating player workers")
	var worker_scene = load("res://scenes/units/worker.tscn")
	if not worker_scene:
		push_error("Failed to load worker scene")
		return
	
	for player_id in players.keys():
		var player_data = players[player_id]
		var team = player_data.team
		
		# Create worker instance
		var worker = worker_scene.instance()
		
		# Set worker properties
		worker.team = team
		
		# Position worker near team's starting area
		var start_position
		if has_node("MapManager") and get_node("MapManager").has_method("get_team_start_position"):
			start_position = get_node("MapManager").get_team_start_position(team)
		else:
			# Fallback positions if no map manager
			start_position = Vector2(100 + team * 800, 300)
		
		worker.position = start_position
		print("Spawning worker for team " + str(team) + " at " + str(start_position))
		
		# Add worker to scene
		get_tree().current_scene.add_child(worker)
		
		# Store reference in player data
		player_data.worker = worker

		print("Making worker visible for team " + str(team))
		var sprite = worker.get_node_or_null("Sprite")
		if sprite:
		# Make sprite bright green or red depending on team
			sprite.modulate = Color(0, 1, 0) if team == 0 else Color(1, 0, 0)
			sprite.scale = Vector2(2, 2)  # Make it twice as big

# Safe method to get a node without crashing if it doesn't exist
func safe_get_node(path):
	if has_node(path):
		return get_node(path)
	return null

# Create starting buildings (HQs)
func _create_starting_buildings() -> void:
	print("Creating starting buildings...")
	if not building_manager:
		print("No building manager available!")
		return
	
	# Use a much larger x-coordinate for Team 1's HQ to ensure it maps to their territory
	var hq_positions = [
		Vector2(50, 300),  # Team 0 HQ
		Vector2(750, 300)   # Team 1 HQ 
	]
	
	for team in range(2):  # For both teams
		var hq_position = hq_positions[team]
		print("Attempting to create HQ at " + str(hq_position) + " for team " + str(team))
		
		var hq = building_manager.place_building("headquarters", hq_position, team)
		if hq:
			print("HQ successfully created for team " + str(team))
			register_headquarters(hq, team)
		else:
			print("Failed to create HQ for team " + str(team))

		# Debug information
		var grid_pos = grid_system.world_to_grid(hq_position)
		print("Team " + str(team) + " HQ - World pos: " + str(hq_position) + ", Grid pos: " + str(grid_pos))

# Register a building as a team's headquarters
func register_headquarters(building, team: int) -> void:
	headquarters[team] = building
	
	# Connect its destroyed signal
	if not building.is_connected("building_destroyed", self, "_on_headquarters_destroyed"):
		building.connect("building_destroyed", self, "_on_headquarters_destroyed", [team])

# Handle headquarters destruction
func _on_headquarters_destroyed(team: int) -> void:
	headquarters[team] = null
	
	# Other team wins
	var other_team_wins = 1 if team == 0 else 0
	_trigger_game_end(other_team_wins)

# Handle any building being destroyed
func _on_building_destroyed(_building) -> void:
	# This could be used for statistics or other game state updates
	pass

# Trigger game end with a winning team
func _trigger_game_end(team: int) -> void:
	if current_state == GameState.ENDED:
		return
	
	winning_team = team
	change_game_state(GameState.ENDED)
	
	emit_signal("game_ended", winning_team)

# Trigger game end by time limit
func _trigger_game_end_by_time() -> void:
	# Determine winner based on some metric (e.g., most buildings, resources, etc.)
	var team_a_score = _calculate_team_score(0)
	var team_b_score = _calculate_team_score(1)
	
	var time_winner = 0 if team_a_score > team_b_score else 1
	_trigger_game_end(time_winner)

# Calculate a team's score for time-based win determination
func _calculate_team_score(team: int) -> float:
	var score = 0.0
	
	# Score based on buildings
	if building_manager:
		var team_buildings = building_manager.get_team_buildings(team)
		score += team_buildings.size() * 100
		
		# Bonus for specialized buildings
		for building in team_buildings:
			if building.building_id == "bank_vault":
				score += 500
	
	# Score based on economy
	if economy_manager:
		score += economy_manager.get_income(team) * 10
	
	return score

# Get a headquarters position
func get_headquarters_position(team: int) -> Vector2:
	if headquarters.has(team) and headquarters[team] != null:
		return headquarters[team].global_position
	
	# Return a default position if HQ doesn't exist
	return map_manager.get_team_hq_position(team) if map_manager else Vector2(500, 300) * team

# Pause/unpause the game
func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused

# Check if the game is over
func is_game_over() -> bool:
	return current_state == GameState.ENDED

# Get the team color
func get_team_color(team: int) -> Color:
	if team >= 0 and team < team_colors.size():
		return team_colors[team]
	return Color(1, 1, 1)  # White for invalid team
