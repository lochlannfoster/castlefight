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
export var match_duration: float = 1800.0 # 30 minutes maximum match time
export var pregame_countdown: float = 10.0 # 10 seconds countdown before game starts
export var max_players_per_team: int = 3
export var team_colors: Array = [Color(0, 0, 1), Color(1, 0, 0)] # Blue, Red

# Game state
enum GameState {SETUP, PREGAME, PLAYING, ENDED}
var current_state: int = GameState.SETUP
var match_timer: float = 0
var countdown_timer: float = 0
var is_paused: bool = false
var winning_team: int = -1
var match_id: String = ""

# Player and team tracking
var players: Dictionary = {} # player_id -> player data
var team_players: Dictionary = {
    0: [], # Team A player IDs
    1: [] # Team B player IDs
}

# Headquarters references
var headquarters: Dictionary = {
    0: null, # Team A HQ
    1: null # Team B HQ
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
var GridSystemScript = load("res://scripts/core/grid_system.gd")
var CombatSystemScript = load("res://scripts/combat/combat_system.gd")
var EconomyManagerScript = load("res://scripts/economy/economy_manager.gd")
var BuildingManagerScript = load("res://scripts/building/building_manager.gd")

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
    log_debug("Adding player: ID=" + str(player_id) + ", Name=" + player_name + ", Team=" + str(team), "info", "GameManager")
    
    # Ensure team is valid (0 or 1)
    if team < 0 or team > 1:
        team = 0 # Default to Team A if invalid
        log_debug("Invalid team provided, defaulting to Team A (0)", "warning", "GameManager")
    
    # Check if teams are full
    if team_players.has(team) and team_players[team].size() >= max_players_per_team:
        log_debug("Team " + str(team) + " is full, cannot add player", "warning", "GameManager")
        return false
    
    # Initialize team_players if needed
    if not team_players.has(0):
        team_players[0] = []
    if not team_players.has(1):
        team_players[1] = []
    
    # Create player data
    var player_data = {
        "id": player_id,
        "name": player_name,
        "team": team,
        "worker": null, # Will be created when game starts
        "resources": {
            "gold": 0,
            "wood": 0,
            "supply": 0
        }
    }
    
    # Add to player tracking
    players[player_id] = player_data
    team_players[team].append(player_id)
    
    log_debug("Player added successfully. Team " + str(team) + " now has " + str(team_players[team].size()) + " players", "info", "GameManager")
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

# In scripts/core/game_manager.gd
func start_game() -> void:
    log_debug("GameManager: Starting game...", "info", "GameManager")
    log_debug("Current state: " + str(current_state), "info", "GameManager")

    # Start the game properly
    if current_state == GameState.SETUP or current_state == GameState.PREGAME:
        change_game_state(GameState.PLAYING)
        log_debug("Game state changed to PLAYING", "info", "GameManager")
        
        # Create player workers
        log_debug("About to create workers...", "info", "GameManager")
        _create_player_workers()
        log_debug("Workers creation attempted", "info", "GameManager")
        
        # Create initial buildings (HQs)
        log_debug("About to create HQs...", "info", "GameManager")
        _create_starting_buildings()
        log_debug("HQ creation attempted", "info", "GameManager")
        
        emit_signal("game_started")
        log_debug("Game started signal emitted", "info", "GameManager")
    else:
        log_debug("Cannot start game: Current state is " + str(current_state), "error", "GameManager")

    log_debug("Game started function completed", "info", "GameManager")
    var camera = get_tree().current_scene.get_node_or_null("Camera2D")
    if camera:
        log_debug("Camera position: " + str(camera.global_position), "info", "GameManager")
        # Ensure camera sees the right area - for testing, move it to the expected HQ position
        camera.global_position = get_headquarters_position(0)
    
func _create_player_workers() -> void:
    log_debug("Creating player workers", "info", "GameManager")
    log_debug("Total players: " + str(players.size()), "info", "GameManager")
    for player_id in players.keys():
        log_debug("Player ID: " + str(player_id) + " Details: " + str(players[player_id]), "info", "GameManager")
    
    
    # Make sure worker scene loads properly
    var worker_scene = load("res://scenes/units/worker.tscn")
    if not worker_scene:
        log_debug("CRITICAL ERROR: Failed to load worker scene", "error", "GameManager")
        return
        
    # Continue with normal worker creation for actual players
    for player_id in players.keys():
        var player_data = players[player_id]
        var team = player_data.team
        
        log_debug("Processing player ID: " + str(player_id) + " on team " + str(team), "info", "GameManager")
        
        # Create worker instance - make sure 'worker' is declared here
        var worker = worker_scene.instance()
        
        # Set worker properties
        worker.team = team
        
        # Position worker at team's start position
        var start_position = Vector2(400 + (team * 200), 300) # Default position
        
        if map_manager and map_manager.has_method("get_team_start_position"):
            var map_position = map_manager.get_team_start_position(team)
            if map_position:
                start_position = map_position
                log_debug("Using map position for worker: " + str(start_position), "info", "GameManager")
            else:
                log_debug("Map position returned null, using default: " + str(start_position), "GameManager")
        else:
            log_debug("Map manager not available, using default position: " + str(start_position), "info", "GameManager")
        
        worker.position = start_position
        log_debug("Spawning worker for player " + str(player_id) + " at " + str(start_position), "info", "GameManager")
        
        # Add to scene tree
        var current_scene = get_tree().current_scene
        if current_scene:
            log_debug("Current scene: " + current_scene.name, "info", "GameManager")
            current_scene.add_child(worker)
            log_debug("Worker added to scene successfully", "info", "GameManager")
            log_debug("Worker created at position: " + str(worker.position), "info", "GameManager")
            log_debug("Worker has valid texture: " + str(worker.get_node_or_null("Sprite") != null && worker.get_node("Sprite").texture != null), "info", "GameManager")
        else:
            log_debug("CRITICAL ERROR: No current scene found!", "error", "GameManager")
            return
        
        # Store reference in player data
        player_data.worker = worker
        log_debug("Worker reference stored in player data", "info", "GameManager")

# Safe method to get a node without crashing if it doesn't exist
func safe_get_node(path):
    if has_node(path):
        return get_node(path)
    return null

func _create_starting_buildings() -> void:
    log_debug("Creating starting buildings...", "info", "GameManager")
    
    if not building_manager:
        log_debug("CRITICAL ERROR: No building manager available!", "error", "GameManager")
        return
    
    # Force creation of headquarters for debugging
    var hq_position_team_a = Vector2(200, 300) # Adjust as needed for visibility
    var hq_position_team_b = Vector2(600, 300) # Adjust as needed for visibility
    
    log_debug("Placing Team A headquarters at " + str(hq_position_team_a), "info", "GameManager")
    var hq_a = building_manager.place_building("headquarters", hq_position_team_a, 0)
    if hq_a:
        register_headquarters(hq_a, 0)
        log_debug("Team A headquarters placed successfully", "info", "GameManager")
    else:
        log_debug("Failed to place Team A headquarters", "error", "GameManager")
    
    log_debug("Placing Team B headquarters at " + str(hq_position_team_b), "info", "GameManager")
    var hq_b = building_manager.place_building("headquarters", hq_position_team_b, 1)
    if hq_b:
        register_headquarters(hq_b, 1)
        log_debug("Team B headquarters placed successfully", "info", "GameManager")
    else:
        log_debug("Failed to place Team B headquarters", "error", "GameManager")

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

    if map_manager:
        return map_manager.get_team_hq_position(team)
    
    push_error("Cannot get HQ position: no valid reference")
    return Vector2.ZERO

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
    return Color(1, 1, 1) # White for invalid team

# Reset the game after a match ends
func reset_game() -> void:
    # Reset game state
    current_state = GameState.SETUP
    match_timer = 0
    winning_team = -1
    
    # Clear existing units and buildings
    _clear_game_entities()
    
    # Reset grid
    if grid_system:
        grid_system.initialize_grid()
    
    # Reset resources
    if economy_manager:
        for team in range(2):
            economy_manager.set_resource(team, economy_manager.ResourceType.GOLD, 100)
            economy_manager.set_resource(team, economy_manager.ResourceType.WOOD, 50)
            economy_manager.set_resource(team, economy_manager.ResourceType.SUPPLY, 10)
    
    # Show race selection interface
    _show_race_selection()
    
    emit_signal("game_reset")

func _clear_game_entities() -> void:
    # Get all units and buildings
    var units = get_tree().get_nodes_in_group("units")
    var buildings = get_tree().get_nodes_in_group("buildings")
    
    # Remove all units
    for unit in units:
        unit.queue_free()
    
    # Remove all buildings
    for building in buildings:
        building.queue_free()
    
    # Reset headquarters references
    headquarters = {0: null, 1: null}

# Show race selection UI
func _show_race_selection() -> void:
    if ui_manager and ui_manager.has_method("show_race_selection"):
        ui_manager.show_race_selection()
    else:
        # Create basic race selection if UI manager doesn't have it
        _create_basic_race_selection()

# Create a basic race selection interface
func _create_basic_race_selection() -> void:
    var race_selection = Control.new()
    race_selection.name = "RaceSelection"
    race_selection.set_anchors_preset(Control.PRESET_FULL_RECT)
    
    var panel = Panel.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.margin_left = -200
    panel.margin_top = -150
    panel.margin_right = 200
    panel.margin_bottom = 150
    race_selection.add_child(panel)
    
    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.margin_left = 20
    vbox.margin_top = 20
    vbox.margin_right = -20
    vbox.margin_bottom = -20
    panel.add_child(vbox)
    
    var title = Label.new()
    title.text = "Select Race"
    title.align = Label.ALIGN_CENTER
    vbox.add_child(title)
    
    # Add race buttons
    var human_button = Button.new()
    human_button.text = "Human Alliance"
    human_button.connect("pressed", self, "_on_race_selected", ["human", 0])
    vbox.add_child(human_button)
    
    var orc_button = Button.new()
    orc_button.text = "Orc Horde"
    orc_button.connect("pressed", self, "_on_race_selected", ["orc", 0])
    vbox.add_child(orc_button)
    
    var start_button = Button.new()
    start_button.text = "Start Game"
    start_button.connect("pressed", self, "_on_race_selection_complete")
    vbox.add_child(start_button)
    
    get_tree().current_scene.add_child(race_selection)

# Handle race selection
func _on_race_selected(race: String, team: int) -> void:
    # Set race for the given team
    var tech_tree_manager = get_node_or_null("TechTreeManager")
    if not tech_tree_manager:
        # Try to find it in the root
        tech_tree_manager = get_node_or_null("/root/TechTreeManager")
    
    if tech_tree_manager:
        tech_tree_manager.set_team_tech_tree(team, race)
    else:
        print("Warning: Tech tree manager not found, race selection won't be saved")

# Handle race selection completion
func _on_race_selection_complete() -> void:
    # Remove race selection UI
    var race_selection = get_tree().current_scene.get_node_or_null("RaceSelection")
    if race_selection:
        race_selection.queue_free()
    
    # Start the game
    start_game()

# Validate the current game state and try to restore it if corrupted
func validate_and_restore_game_state() -> bool:
    var state_valid = true
    
    # Check if grid system is initialized
    if not grid_system or grid_system.grid_cells.empty():
        push_warning("Grid system not initialized, attempting to restore")
        if grid_system:
            grid_system.initialize_grid()
        state_valid = false
    
    # Check if headquarters exist
    for team in range(2):
        if not headquarters.has(team) or headquarters[team] == null:
            push_warning("Headquarters missing for team " + str(team) + ", attempting to restore")
            _create_headquarters_for_team(team)
            state_valid = false
    
    # Check player workers
    for player_id in players.keys():
        var player_data = players[player_id]
        if not player_data.has("worker") or player_data.worker == null:
            push_warning("Worker missing for player " + str(player_id) + ", attempting to restore")
            _create_worker_for_player(player_id)
            state_valid = false
    
    return state_valid

# Helper method to create headquarters
func _create_headquarters_for_team(team: int) -> void:
    if not building_manager or not map_manager:
        push_error("Cannot create headquarters: Missing required managers")
        return
    
    var hq_position = map_manager.get_team_hq_position(team)
    var hq = building_manager.place_building("headquarters", hq_position, team)
    
    if hq:
        register_headquarters(hq, team)
        push_warning("Successfully restored headquarters for team " + str(team))
    else:
        push_error("Failed to restore headquarters for team " + str(team))

# Helper method to create a worker
func _create_worker_for_player(player_id: int) -> void:
    if not players.has(player_id):
        push_error("Cannot create worker: Player ID not found: " + str(player_id))
        return
    
    var player_data = players[player_id]
    var team = player_data.team
    
    var worker_scene = load("res://scenes/units/worker.tscn")
    if not worker_scene:
        push_error("Cannot create worker: Scene not found")
        return
    
    var worker = worker_scene.instance()
    worker.team = team
    
    var spawn_position = map_manager.get_team_start_position(team)
    worker.position = spawn_position
    
    get_tree().current_scene.add_child(worker)
    player_data.worker = worker
    push_warning("Successfully restored worker for player " + str(player_id))

func log_debug(message: String, level: String = "debug", context: String = "") -> void:
    if Engine.has_singleton("DebugLogger"):
        var debug_logger = Engine.get_singleton("DebugLogger")
        match level.to_lower():
            "error":
                debug_logger.error(message, context)
            "warning":
                debug_logger.warning(message, context)
            "info":
                debug_logger.info(message, context)
            "verbose":
                debug_logger.verbose(message, context)
            _: # Default to debug level
                debug_logger.debug(message, context)
    else:
        # Fallback to print if DebugLogger is not available
        print(level.to_upper() + " [" + context + "]: " + message)

func _sync_player_data_to_game_manager() -> void:
    # Use a different variable name to avoid shadowing the class member
    var nm = get_node_or_null("NetworkManager")
    if not nm or not nm.has_method("get_player_info"):
        log_debug("ERROR: Cannot sync player data - NetworkManager not found or incompatible", "error", "GameManager")
        return
        
    log_debug("Syncing player data to GameManager...", "info", "GameManager")
    
    # Get player info from NetworkManager
    var player_data = nm.get_player_info()
    
    # Clear existing players
    players.clear()
    
    # Add all players from network_manager
    for player_id in player_data.keys():
        var p_data = player_data[player_id]
        # Only add players that have a team assigned
        if p_data.has("team") and p_data.team >= 0:
            log_debug("Adding player to GameManager: ID=" + str(player_id) + ", Name=" + str(p_data.name) + ", Team=" + str(p_data.team), "info", "GameManager")
            var _result = add_player(player_id, p_data.name, p_data.team)
    
    log_debug("Player sync complete. GameManager now has " + str(players.size()) + " players", "info", "GameManager")

func toggle_grid_visualization() -> void:
    if grid_system:
        if grid_system.has_node("DebugGridVisualizer"):
            var visualizer = grid_system.get_node("DebugGridVisualizer")
            visualizer.visible = !visualizer.visible
            log_debug("Grid visualization " + ("enabled" if visualizer.visible else "disabled"), "info", "GameManager")
        else:
            grid_system.draw_debug_grid()
            log_debug("Grid visualization created and enabled", "info", "GameManager")
