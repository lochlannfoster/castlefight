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
    log_debug("GameManager: Starting game...", "GameManager")
    log_debug("Current state: " + str(current_state), "GameManager")

    # Start the game properly
    if current_state == GameState.SETUP or current_state == GameState.PREGAME:
        change_game_state(GameState.PLAYING)
        print("Game state changed to PLAYING")
        
        # Create player workers
        print("About to create workers...")
        _create_player_workers()
        print("Workers creation attempted")
        
        # Create initial buildings (HQs)
        print("About to create HQs...")
        _create_starting_buildings()
        print("HQ creation attempted")
        
        emit_signal("game_started")
        print("GameManager: Game started signal emitted")
    else:
        print("Cannot start game: Current state is ", current_state)

    log_debug("Game started signal emitted", "GameManager")
    
# Make _create_player_workers more robust
func _create_player_workers() -> void:
  log_debug("Creating player workers", "GameManager")
  
  var worker_scene = load("res://scenes/units/worker.tscn")
  if not worker_scene:
    log_debug("Failed to load worker scene", "GameManager")
    return
    
  for player_id in players.keys():
    var player_data = players[player_id]
    var team = player_data.team
    
    # Create worker instance
    var worker = worker_scene.instance()
    
    # Set worker properties
    worker.team = team
    
    # Position worker at a guaranteed position
    # Default positions if map_manager isn't available or fails
    var start_position = Vector2(100 + team * 800, 300)
    
    if map_manager and map_manager.has_method("get_team_start_position"):
      var map_position = map_manager.get_team_start_position(team)
      if map_position:
        start_position = map_position
    
    worker.position = start_position
    print("Spawning worker for team " + str(team) + " at " + str(start_position))
    log_debug("Spawning worker for player " + str(player_id) + " on team " + str(team), "GameManager")
    
    # Add worker to scene
    get_tree().current_scene.add_child(worker)
    log_debug("Worker created and added to scene", "GameManager")
    
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
# Create starting buildings (HQs)
func _create_starting_buildings() -> void:
    print("Creating starting buildings...")
    if not building_manager:
        print("No building manager available!")
        return
    
    # First, ensure territories are properly set up for both teams
    if grid_system:
        # Define territories for both teams
        var team_0_area = Rect2(0, 0, grid_system.grid_width / 3, grid_system.grid_height)
        var team_1_area = Rect2(grid_system.grid_width * 2 / 3, 0, grid_system.grid_width / 3, grid_system.grid_height)
        
        # Assign territories
        for x in range(grid_system.grid_width):
            for y in range(grid_system.grid_height):
                var pos = Vector2(x, y)
                if team_0_area.has_point(pos):
                    if grid_system.grid_cells.has(pos):
                        grid_system.grid_cells[pos].team_territory = 0
                elif team_1_area.has_point(pos):
                    if grid_system.grid_cells.has(pos):
                        grid_system.grid_cells[pos].team_territory = 1
        
        print("Team territories initialized")
    
    # Create headquarters for each team
    for current_team in range(2):
        # Determine HQ position
        var position_to_use
        if map_manager and map_manager.has_method("get_team_hq_position"):
            position_to_use = map_manager.get_team_hq_position(current_team)
        else:
            # Default positions if map_manager isn't available
            position_to_use = Vector2(100, 400) if current_team == 0 else Vector2(1500, 400)
        
        print("Attempting to create HQ at " + str(position_to_use) + " for team " + str(current_team))
        
        var hq = building_manager.place_building("headquarters", position_to_use, current_team)
        if hq:
            print("HQ successfully created for team " + str(current_team))
            register_headquarters(hq, current_team)
        else:
            print("Failed to create HQ for team " + str(current_team))

        # Debug information
        if grid_system:
            var grid_pos = grid_system.world_to_grid(position_to_use)
            print("Team " + str(current_team) + " HQ - World pos: " + str(position_to_use) + ", Grid pos: " + str(grid_pos))

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
    return Color(1, 1, 1)  # White for invalid team

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
        match level.to_lower():
            "error":
                log_debug(message, context)
            "warning":
                log_debug(message, context)
            "info":
                log_debug(message, context)
            "verbose":
                log_debug(message, context)
            _: # Default to debug level
                log_debug(message, context)
    else:
        # Fallback to print if DebugLogger is not available
        print(level.to_upper() + " [" + context + "]: " + message)