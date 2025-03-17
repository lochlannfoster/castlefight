# Game Manager - Coordinates all game systems
# Path: scripts/core/game_manager.gd
extends Node
var service_name: String = "GameManager"

# Game signals
signal game_started
signal game_ended(winning_team)
signal player_joined(player_id, team)
signal player_left(player_id)
signal team_eliminated(team)
signal match_countdown_updated(time_remaining)
signal headquarters_registered(team, hq_building)

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
var map_manager: Node = null
var tech_tree_manager

var is_initialized: bool = false

# Script references for instantiation
var GridSystemScript = load("res://scripts/core/grid_system.gd")
var CombatSystemScript = load("res://scripts/combat/combat_system.gd")
var EconomyManagerScript = load("res://scripts/economy/economy_manager.gd")
var BuildingManagerScript = load("res://scripts/building/building_manager.gd")

export var debug_mode: bool = false

func debug_log(message: String, level: String = "info", context: String = "") -> void:
    var logger = get_node_or_null("/root/Logger")
    if logger:
        match level.to_lower():
            "error":
                logger.error(message, context if context else service_name)
            "warning":
                logger.warning(message, context if context else service_name)
            "debug":
                logger.debug(message, context if context else service_name)
            "verbose":
                logger.debug(message, context if context else service_name)
            _:
                logger.info(message, context if context else service_name)
    else:
        # Fallback to print
        var prefix = "[" + level.to_upper() + "]"
        if context:
            prefix += "[" + context + "]"
        elif service_name:
            prefix += "[" + service_name + "]"
        print(prefix + " " + message)

func _ready() -> void:
    var logger = get_node("/root/UnifiedLogger")
    
    # Initialize match ID with detailed logging
    match_id = "match_" + str(OS.get_unix_time())
    logger.info("Match ID generated: " + match_id, "GameManager")
    
    # Ensure required data directories exist
    ensure_data_directories_exist()
    
    logger.debug("GameManager initialization complete", "GameManager")
    call_deferred("_initialize_map_manager")

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
    var service_locator = get_node_or_null("/root/ServiceLocator")
    if service_locator:
        service_locator.initialize_all_services()
        
        # Get references to services
        grid_system = service_locator.get_service("GridSystem")
        combat_system = service_locator.get_service("CombatSystem")
        economy_manager = service_locator.get_service("EconomyManager")
        building_manager = service_locator.get_service("BuildingManager")
        unit_factory = service_locator.get_service("UnitFactory")
        ui_manager = service_locator.get_service("UIManager")
        fog_of_war_manager = service_locator.get_service("FogOfWarManager")
        network_manager = service_locator.get_service("NetworkManager")
        map_manager = service_locator.get_service("MapManager")

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
    debug_log("Adding player: ID=" + str(player_id) + ", Name=" + player_name + ", Team=" + str(team), "info", "GameManager")
    
    # Ensure team is valid (0 or 1)
    if team < 0 or team > 1:
        team = 0 # Default to Team A if invalid
        debug_log("Invalid team provided, defaulting to Team A (0)", "warning", "GameManager")
    
    # Check if teams are full
    if team_players.has(team) and team_players[team].size() >= max_players_per_team:
        debug_log("Team " + str(team) + " is full, cannot add player", "warning", "GameManager")
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
    
    debug_log("Player added successfully. Team " + str(team) + " now has " + str(team_players[team].size()) + " players", "info", "GameManager")
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
    var logger = get_node("/root/UnifiedLogger")
    
    logger.info("===== START GAME CALLED =====", "GameManager")
    logger.debug("Current game state: " + str(current_state), "GameManager")
    logger.debug("Debug mode status: " + str(debug_mode), "GameManager")
    logger.debug("Total players: " + str(players.size()), "GameManager")

    if current_state != GameState.SETUP and current_state != GameState.PREGAME:
        logger.error("Cannot start game: Invalid game state", "GameManager", {
            "current_state": current_state
        })
        return
        
        # Extensive logging for critical initialization steps
    logger.info("Attempting to create player workers", "GameManager")
    _create_player_workers()
    
    logger.info("Creating starting buildings", "GameManager")
    _create_starting_buildings()
    
    emit_signal("game_started")

func ensure_core_systems() -> void:
    # This function makes sure all core systems are available
    # and creates them if they're missing
    # Check for grid system
    if not grid_system:
        grid_system = get_node_or_null("/root/GridSystem")
        if not grid_system:
            var grid_system_class = load("res://scripts/core/grid_system.gd")
            if grid_system_class:
                grid_system = grid_system_class.new()
                grid_system.name = "GridSystem"
                add_child(grid_system)
                # Initialize grid
                grid_system.initialize_grid()
                debug_log("Created and initialized GridSystem", "info", "GameManager")
    
    # Check for unit factory
    if not unit_factory:
        unit_factory = get_node_or_null("/root/UnitFactory")
        if not unit_factory:
            var unit_factory_class = load("res://scripts/unit/unit_factory.gd")
            if unit_factory_class:
                unit_factory = unit_factory_class.new()
                unit_factory.name = "UnitFactory"
                add_child(unit_factory)
                debug_log("Created UnitFactory", "info", "GameManager")
    
    # Check for economy manager
    if not economy_manager:
        economy_manager = get_node_or_null("/root/EconomyManager")
        if not economy_manager:
            var economy_manager_class = load("res://scripts/economy/economy_manager.gd")
            if economy_manager_class:
                economy_manager = economy_manager_class.new()
                economy_manager.name = "EconomyManager"
                add_child(economy_manager)
                debug_log("Created EconomyManager", "info", "GameManager")
    
    # Check for building manager
    if not building_manager:
        building_manager = get_node_or_null("/root/BuildingManager")
        if not building_manager:
            var building_manager_class = load("res://scripts/building/building_manager.gd")
            if building_manager_class:
                building_manager = building_manager_class.new()
                building_manager.name = "BuildingManager"
                add_child(building_manager)
                debug_log("Created BuildingManager", "info", "GameManager")
    
    # Check for UI manager
    if not ui_manager:
        ui_manager = get_node_or_null("/root/UIManager")
        if not ui_manager:
            var ui_manager_class = load("res://scripts/ui/ui_manager.gd")
            if ui_manager_class:
                ui_manager = ui_manager_class.new()
                ui_manager.name = "UIManager"
                add_child(ui_manager)
                debug_log("Created UIManager", "info", "GameManager")

func _create_player_workers() -> void:
    debug_log("Initiating player worker creation process", "info", "GameManager")
    
    # First get or create the Units container
    var units_container = get_tree().current_scene.get_node_or_null("Units")
    if not units_container:
        debug_log("Creating Units container node", "info", "GameManager")
        units_container = Node2D.new()
        units_container.name = "Units"
        get_tree().current_scene.add_child(units_container)
    
    # Direct worker creation method
    var worker_scene = load("res://scenes/units/worker.tscn")
    if worker_scene:
        # Create worker for Team A at fixed position
        var spawn_position = Vector2(250, 300)
        var worker = worker_scene.instance()
        
        # Set worker properties
        worker.team = 0
        worker.position = spawn_position
        
        # Add to scene
        units_container.add_child(worker)
        debug_log("Worker created directly at position: " + str(spawn_position), "info", "GameManager")
        
        # If we're in debug mode, store this worker
        if debug_mode and players.has(1):
            players[1]["worker"] = worker
    else:
        debug_log("Failed to load worker scene", "error", "GameManager")

# Safe method to get a node without crashing if it doesn't exist
func safe_get_node(path):
    if has_node(path):
        return get_node(path)
    return null

func _create_starting_buildings() -> void:
    debug_log("Creating starting buildings...", "info", "GameManager")
    
    # Force creation of headquarters for debugging
    var hq_position_team_a = Vector2(200, 300) # Fixed position for visibility
    var hq_position_team_b = Vector2(600, 300) # Fixed position for visibility
    
    # Add direct debug output
    print("ATTEMPTING TO CREATE HQ AT: " + str(hq_position_team_a) + " and " + str(hq_position_team_b))
    
    # Create Team A HQ directly with scene instantiation as fallback
    var hq_scene = load("res://scenes/buildings/hq_building.tscn")
    if hq_scene:
        var hq_a = hq_scene.instance()
        hq_a.team = 0
        hq_a.position = hq_position_team_a
        
        # Get buildings container
        var buildings_container = get_tree().current_scene.get_node_or_null("Buildings")
        if not buildings_container:
            buildings_container = Node2D.new()
            buildings_container.name = "Buildings"
            get_tree().current_scene.add_child(buildings_container)
            
        buildings_container.add_child(hq_a)
        register_headquarters(hq_a, 0)
        debug_log("Team A headquarters placed using direct instantiation", "info", "GameManager")
        
        # Do the same for Team B
        var hq_b = hq_scene.instance()
        hq_b.team = 1
        hq_b.position = hq_position_team_b
        buildings_container.add_child(hq_b)
        register_headquarters(hq_b, 1)
        debug_log("Team B headquarters placed using direct instantiation", "info", "GameManager")
    else:
        debug_log("Failed to load headquarters scene", "error", "GameManager")

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
    tech_tree_manager = get_node_or_null("TechTreeManager")
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

func _sync_player_data_to_game_manager() -> void:
    # Use a different variable name to avoid shadowing the class member
    var nm = get_node_or_null("NetworkManager")
    if not nm or not nm.has_method("get_player_info"):
        debug_log("ERROR: Cannot sync player data - NetworkManager not found or incompatible", "error", "GameManager")
        return
        
    debug_log("Syncing player data to GameManager...", "info", "GameManager")
    
    # Get player info from NetworkManager
    var player_data = nm.get_player_info()
    
    # Clear existing players
    players.clear()
    
    # Add all players from network_manager
    for player_id in player_data.keys():
        var p_data = player_data[player_id]
        # Only add players that have a team assigned
        if p_data.has("team") and p_data.team >= 0:
            debug_log("Adding player to GameManager: ID=" + str(player_id) + ", Name=" + str(p_data.name) + ", Team=" + str(p_data.team), "info", "GameManager")
            var _result = add_player(player_id, p_data.name, p_data.team)
    
    debug_log("Player sync complete. GameManager now has " + str(players.size()) + " players", "info", "GameManager")

func toggle_grid_visualization() -> void:
    # Get grid system reference
    var grid_sys = get_node_or_null("/root/GridSystem")
    if not grid_sys:
        grid_sys = get_node_or_null("GridSystem")
        
    if grid_sys:
        if grid_sys.has_node("DebugGridVisualizer"):
            var visualizer = grid_sys.get_node("DebugGridVisualizer")
            visualizer.visible = !visualizer.visible
            print("Grid visualization " + ("enabled" if visualizer.visible else "disabled"))
        else:
            if grid_sys.has_method("draw_debug_grid"):
                grid_sys.draw_debug_grid()
                print("Grid visualization created and enabled")
            else:
                print("Grid system doesn't have draw_debug_grid method")
    else:
        print("Grid system not found")

func ensure_data_directories_exist() -> void:
    # List of required directories
    var dirs_to_check = [
        "res://data/items/",
        "res://data/buildings/",
        "res://data/units/",
        "res://data/combat/",
        "res://data/tech_trees/"
    ]
    
    # Create each directory
    var dir = Directory.new()
    for path in dirs_to_check:
        if !dir.dir_exists(path):
            print("Creating directory: " + path)
            var err = dir.make_dir_recursive(path)
            if err != OK:
                print("Failed to create directory: " + path + " Error: " + str(err))
            else:
                print("Created directory: " + path)
                
                # Create a default file in each directory as needed
                var default_files = {
                    "res://data/items/": "health_potion.json",
                    "res://data/buildings/": "", # Skip if you already have building files
                    "res://data/units/": "", # Skip if you already have unit files
                    "res://data/combat/": "", # Skip if you already have combat files
                    "res://data/tech_trees/": "" # Skip if you already have tech tree files
                }
                
                if default_files[path] != "":
                    _create_default_file(path + default_files[path])

func _create_default_file(file_path: String) -> void:
    # Check if file already exists
    var file = File.new()
    if file.file_exists(file_path):
        print("File already exists: " + file_path)
        return
    
    # Create the file with appropriate content based on type
    if file.open(file_path, File.WRITE) == OK:
        var content = ""
        
        # Determine file type from path and create appropriate content
        if file_path.ends_with(".json"):
            if "items" in file_path:
                # Create a default item
                content = JSON.print({
                    "item_id": file_path.get_file().get_basename(),
                    "display_name": "Default Item",
                    "description": "A default item created by the game",
                    "gold_cost": 50,
                    "wood_cost": 0,
                    "supply_cost": 0,
                    "effect": {
                        "type": "heal",
                        "value": 50
                    },
                    "icon_path": "res://assets/items/default_item.png"
                }, "  ")
            elif "buildings" in file_path:
                # Create a default building
                content = JSON.print({
                    "building_id": file_path.get_file().get_basename(),
                    "display_name": "Default Building",
                    "description": "A default building created by the game",
                    "race": "common",
                    "scene_path": "res://scenes/buildings/base_building.tscn",
                    "stats": {
                        "health": 500,
                        "armor": 5,
                        "armor_type": "fortified",
                        "vision_range": 300
                    },
                    "construction": {
                        "time": 30,
                        "gold_cost": 100,
                        "wood_cost": 50,
                        "supply_cost": 0,
                        "size_x": 2,
                        "size_y": 2
                    }
                }, "  ")
            elif "units" in file_path:
                # Create a default unit
                content = JSON.print({
                    "unit_id": file_path.get_file().get_basename(),
                    "display_name": "Default Unit",
                    "description": "A default unit created by the game",
                    "race": "common",
                    "scene_path": "res://scenes/units/base_unit.tscn",
                    "stats": {
                        "health": 100,
                        "armor": 2,
                        "armor_type": "medium",
                        "attack_damage": 10,
                        "attack_type": "normal",
                        "attack_range": 60,
                        "attack_speed": 1.2,
                        "movement_speed": 90,
                        "collision_radius": 16,
                        "vision_range": 250,
                        "health_regen": 0.25
                    }
                }, "  ")
            elif "combat" in file_path:
                # Create a default damage table
                content = JSON.print({
                    "normal": {
                        "light": 1.0,
                        "medium": 1.0,
                        "heavy": 1.0,
                        "fortified": 0.5,
                        "hero": 1.0,
                        "unarmored": 1.0
                    },
                    "piercing": {
                        "light": 1.5,
                        "medium": 0.75,
                        "heavy": 1.0,
                        "fortified": 0.35,
                        "hero": 0.5,
                        "unarmored": 1.0
                    }
                }, "  ")
            elif "tech_trees" in file_path:
                # Create a default tech tree
                content = JSON.print({
                    "race_id": file_path.get_file().get_basename().replace("_tech", ""),
                    "race_name": "Default Race",
                    "description": "A default race created by the game",
                    "starting_buildings": ["headquarters"],
                    "buildings": [
                        {
                            "id": "headquarters",
                            "name": "Headquarters",
                            "tier": 0,
                            "description": "Main base structure.",
                            "requirements": [],
                            "unlocks": ["barracks"]
                        },
                        {
                            "id": "barracks",
                            "name": "Barracks",
                            "tier": 1,
                            "description": "Trains basic infantry units",
                            "requirements": ["headquarters"],
                            "unlocks": ["footman"]
                        }
                    ],
                    "units": [
                        {
                            "id": "footman",
                            "name": "Footman",
                            "tier": 1,
                            "building": "barracks",
                            "description": "Basic melee infantry unit",
                            "abilities": []
                        }
                    ]
                }, "  ")
        else:
            # Default to an empty file for unknown types
            content = "# Default file created by GameManager\n"
        
        # Write the content to the file
        file.store_string(content)
        file.close()
        print("Created default file: " + file_path)
    else:
        print("Failed to create default file: " + file_path)

func ensure_icon_exists() -> void:
    var file = File.new()
    if not file.file_exists("res://icon.png"):
        print("Creating default icon.png")
        var img = Image.new()
        img.create(64, 64, false, Image.FORMAT_RGBA8)
        
        # Fill with blue color
        img.fill(Color(0.2, 0.4, 0.8))
        
        # Draw simple castle shape
        for x in range(10, 54):
            # Base
            for y in range(40, 50):
                img.set_pixel(x, y, Color.white)
            
            # Towers
            if x == 15 or x == 30 or x == 45:
                for y in range(20, 40):
                    img.set_pixel(x, y, Color.white)
                
                # Tower tops
                for xt in range(x - 3, x + 4):
                    if xt >= 10 and xt <= 54:
                        img.set_pixel(xt, 20, Color.white)
        
        # Save the image
        img.save_png("res://icon.png")
        print("Created default icon.png")

# Function to verify game state and fix if needed
func verify_game_state() -> void:
    print("Verifying game state...")
    
    # Check if we have the required scenes
    var required_scenes = [
        "res://scenes/units/worker.tscn",
        "res://scenes/units/base_unit.tscn",
        "res://scenes/buildings/base_building.tscn",
        "res://scenes/buildings/hq_building.tscn",
        "res://scenes/ui/building_menu.tscn"
    ]
    
    var dir = Directory.new()
    for scene_path in required_scenes:
        if not dir.file_exists(scene_path):
            print("Warning: Required scene not found: " + scene_path)
            # You could call a scene creator function here to create the missing scene
    
    # Check if we have all required systems
    var systems_check = {
        "GridSystem": grid_system != null,
        "CombatSystem": combat_system != null,
        "EconomyManager": economy_manager != null,
        "BuildingManager": building_manager != null,
        "UnitFactory": unit_factory != null,
        "UIManager": ui_manager != null,
        "TechTreeManager": tech_tree_manager != null,
        "MapManager": map_manager != null
    }
    
    # Log any missing systems
    for system_name in systems_check:
        if not systems_check[system_name]:
            print("Warning: Required system missing: " + system_name)
    
    print("Game state verification complete")

func get_system(system_name: String) -> Node:
    # First check if the system is a direct child
    var system = get_node_or_null(system_name)
    if system:
        return system
        
    # Then check if it's at root level (autoload)
    system = get_node_or_null("/root/" + system_name)
    if system:
        return system
        
    # Finally check in common parent nodes
    var parent_paths = ["/root/game", "/root/game/GameWorld", "/root/GameManager"]
    for path in parent_paths:
        var parent = get_node_or_null(path)
        if parent:
            system = parent.get_node_or_null(system_name)
            if system:
                return system
                
    # Not found
    print("WARNING: System not found: " + system_name)
    return null

func verify_critical_nodes() -> void:
    var critical_paths = [
        "/root/GameManager",
        "/root/GridSystem",
        "/root/EconomyManager",
        "/root/BuildingManager"
    ]
    
    for path in critical_paths:
        var node = get_node_or_null(path)
        if node:
            print("VERIFIED: " + path + " exists")
        else:
            print("MISSING: " + path + " does not exist")
            
    # Also check local paths
    if has_node("GameWorld"):
        print("VERIFIED: GameWorld exists")
    else:
        print("MISSING: GameWorld does not exist")

func change_scene(scene_path: String, transition: bool = false) -> bool:
    # Declare fade_layer in the method scope
    var fade_layer: CanvasLayer = null
    
    if transition:
        # Create transition effect
        fade_layer = CanvasLayer.new()
        fade_layer.name = "SceneTransition"
        fade_layer.layer = 100 # Make sure it's on top
        get_tree().root.add_child(fade_layer)
        
        var fade_rect = ColorRect.new()
        fade_rect.color = Color(0, 0, 0, 0) # Start transparent
        fade_rect.rect_size = get_viewport().size
        fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP # Block input during transition
        fade_layer.add_child(fade_rect)
        
        # Animate fade out
        var tween = Tween.new()
        fade_layer.add_child(tween)
        tween.interpolate_property(fade_rect, "color",
            Color(0, 0, 0, 0), Color(0, 0, 0, 1),
            0.5, Tween.TRANS_CUBIC, Tween.EASE_IN)
        tween.start()
        
        # Wait for fade to complete
        yield (tween, "tween_all_completed")
    
    # Verify scene exists before trying to load it
    var file = File.new()
    if !file.file_exists(scene_path):
        debug_log("Scene file does not exist: " + scene_path, "error", "GameManager")
        
        # Try to recover by checking if scene_creator can make it
        var scene_creator = get_node_or_null("/root/SceneCreator")
        if scene_creator and scene_creator.has_method("ensure_scene_exists"):
            debug_log("Attempting to create missing scene", "warning", "GameManager")
            scene_creator.ensure_scene_exists(scene_path)
        else:
            # If we can't recover, notify and abort
            if transition:
                # Clean up transition
                fade_layer.queue_free()
            return false
    
    # Change to the scene
    var error = get_tree().change_scene(scene_path)
    
    if error != OK:
        debug_log("Failed to change scene with error code: " + str(error), "error", "GameManager")
        
        if transition:
            # Clean up transition
            fade_layer.queue_free()
        return false
    
    if transition:
        # Wait for scene to load and then fade back in
        yield (get_tree(), "idle_frame")
        
        # Get our transition layer again (it might have been recreated during scene change)
        fade_layer = get_tree().root.get_node_or_null("SceneTransition")
        if fade_layer:
            var tween = fade_layer.get_node_or_null("Tween")
            var fade_rect = fade_layer.get_node_or_null("ColorRect")
            
            if tween and fade_rect:
                # Animate fade in
                tween.interpolate_property(fade_rect, "color",
                    Color(0, 0, 0, 1), Color(0, 0, 0, 0),
                    0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
                tween.start()
                
                yield (tween, "tween_all_completed")
            
            # Remove transition layer
            fade_layer.queue_free()
    
    debug_log("Scene changed successfully to: " + scene_path, "info", "GameManager")
    return true

# Helper to check if a scene exists
func does_scene_exist(scene_path: String) -> bool:
    var file = File.new()
    return file.file_exists(scene_path)

func load_scene_resource(scene_path: String) -> PackedScene:
    if does_scene_exist(scene_path):
        var resource = ResourceLoader.load(scene_path)
        if resource is PackedScene:
            return resource
        else:
            push_error("Loaded resource is not a PackedScene")
            return null
    return null

# Register a headquarters for a specific team
func register_headquarters(hq_building, team: int) -> void:
    debug_log("Registering headquarters for Team " + str(team), "info", "GameManager")
    
    # Validate input
    if team < 0 or team > 1:
        push_error("Invalid team for headquarters registration: " + str(team))
        return
    
    # Store the headquarters reference
    headquarters[team] = hq_building
    
    # Additional optional setup
    if hq_building and hq_building.has_method("complete_construction"):
        hq_building.complete_construction()
    
    # Emit signal if needed
    emit_signal("headquarters_registered", team, hq_building)
