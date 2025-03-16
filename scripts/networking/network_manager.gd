# Network Manager - Comprehensive Multiplayer Networking System
# Path: scripts/networking/network_manager.gd
class_name NetworkManager
extends Node

# Network Connection Constants
const DEFAULT_PORT = 27015
const MAX_PLAYERS = 6  # Maximum 3v3 support
const RECONNECT_TIMEOUT = 300  # 5 minutes reconnect window
const SERVER_TICK_RATE = 20  # Server updates per second
const MATCH_TIMEOUT = 1800  # 30-minute match limit
const PROTOCOL_VERSION = "1.0.0"

# Networking State Enums
enum ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    SERVER_RUNNING
}

# Game State Management Enums
enum GamePhase {
    LOBBY,
    PREGAME,
    LOADING,
    ACTIVE,
    PAUSED,
    ENDED
}

# Input Types for Networked Gameplay
enum InputType {
    MOVE,
    ATTACK,
    BUILD,
    USE_ABILITY,
    PURCHASE
}

# Comprehensive Networking Signals
signal server_started
signal server_stopped
signal client_connected(player_id)
signal client_disconnected(player_id)
signal connection_failed
signal connection_succeeded
signal player_joined(player_id)
signal player_left(player_id)
signal team_changed(player_id, old_team, new_team)
signal match_preparing
signal match_started
signal match_ended(winner, reason)
signal network_error(error_message)
signal ping_updated(player_id, ping)
signal player_list_changed(players)  # Add this signal
signal match_ready  # Add this signal

# Core Networking Properties
var network: NetworkedMultiplayerENet = null
var local_player_id: int = 0
var connection_state: int = ConnectionState.DISCONNECTED
var game_phase: int = GamePhase.LOBBY

# Player Management Structures
var players: Dictionary = {
    0: [],  # Team A
    1: []   # Team B
}
var player_info: Dictionary = {}
var spectator_players: Array = []

# Match Configuration
var match_config: Dictionary = {
    "map": "default_map",
    "max_players": 6,
    "game_mode": "standard",
    "team_size": 3,
    "allow_spectators": true
}

var is_server: bool = false  # Whether this client is hosting as a server

# Match State Tracking
var match_start_time: float = 0.0
var match_duration: float = 0.0
var match_winner: int = -1
var match_end_reason: String = ""

# Networking Technical Variables
var server_tick_timer: float = 0.0
var ping_timer: float = 0.0
var last_network_update: float = 0.0
var ping_interval: float = 1.0
var player_pings: Dictionary = {}
var input_sequence: int = 0
var last_processed_inputs: Dictionary = {}

# Game System References
var game_manager = null
var economy_manager = null
var unit_factory = null
var tech_tree_manager = null
var ui_manager
var map_manager
var fog_of_war_manager

# Debugging and Development
var debug_mode: bool = false
var log_network_traffic: bool = false
var network_log: Array = []

# Anti-Cheat and Security
var server_seed: int = 0
var client_checksums: Dictionary = {}
var server_checksum: int = 0

# Performance and Optimization
var network_compression_enabled: bool = true
var delta_updates_enabled: bool = true
var bandwidth_limit: int = 100000  # Bytes per second

# Player Authentication (Placeholder for future implementation)
var player_tokens: Dictionary = {}
var authentication_required: bool = false

# Initialization Method
func _ready() -> void:
    # Initialize game system references
    _initialize_game_references()
    
    # Setup network connection handling
    _setup_network_signals()
    
    # Generate initial server seed for synchronization
    _generate_server_seed()
    
    print("NetworkManager initialized - Protocol Version: " + PROTOCOL_VERSION)

    _verify_required_scenes()

func _verify_required_scenes() -> void:
    var required_scenes = [
        "res://scenes/game/game.tscn",
        "res://scenes/game/map.tscn"
    ]
    
    for scene_path in required_scenes:
        var file = File.new()
        if file.file_exists(scene_path):
            print("Scene exists: " + scene_path)
        else:
            print("WARNING: Required scene does not exist: " + scene_path)
            # Try to create a minimal version of the scene
            _create_minimal_scene(scene_path)

func _create_minimal_scene(scene_path: String) -> void:
    var dir_path = scene_path.get_base_dir()
    var dir = Directory.new()
    # Create directory if needed
    if not dir.dir_exists(dir_path):
        dir.make_dir_recursive(dir_path)
    
    # Create a basic scene based on the scene type
    if scene_path.ends_with("game.tscn"):
        # Create a basic game scene
        var scene = PackedScene.new()
        var root = Node2D.new()
        root.name = "game"
        
        # Add script
        var script = load("res://scripts/game/game_scene.gd")
        if script:
            root.set_script(script)
        
        # Pack the root node into the scene
        scene.pack(root)
        
        # Save the scene
        var save_result = ResourceSaver.save(scene_path, scene)
        if save_result == OK:
            print("Successfully created scene at: " + scene_path)
        else:
            push_error("Failed to save scene with error: " + str(save_result))
    
    elif scene_path.ends_with("map.tscn"):
        # Similar changes for the map scene...
        var scene = PackedScene.new()
        var root = Node2D.new()
        root.name = "Map"
        
        # Add child nodes
        var ground = Node2D.new()
        ground.name = "Ground"
        root.add_child(ground)
        ground.owner = root
        
        var units = Node2D.new()
        units.name = "Units"
        root.add_child(units)
        units.owner = root
        
        var buildings = Node2D.new()
        buildings.name = "Buildings"
        root.add_child(buildings)
        buildings.owner = root
        
        # Pack the root node into the scene
        scene.pack(root)
        
        # Save the scene
        var save_result = ResourceSaver.save(scene_path, scene)
        if save_result == OK:
            print("Created minimal scene at: " + scene_path)
        else:
            push_error("Failed to save scene: " + str(save_result))

func _initialize_game_references() -> void:
    game_manager = get_node_or_null("/root/GameManager")
    economy_manager = get_node_or_null("/root/EconomyManager")
    unit_factory = get_node_or_null("/root/UnitFactory")
    tech_tree_manager = get_node_or_null("/root/TechTreeManager")
    
    # Get UI manager from game manager if available
    if game_manager:
        ui_manager = game_manager.get_node_or_null("UIManager")
        map_manager = game_manager.get_node_or_null("MapManager")
        fog_of_war_manager = game_manager.get_node_or_null("FogOfWarManager")
    
    if debug_mode:
        print("Game system references initialized")
        
func _setup_network_signals() -> void:
    var _err1 = get_tree().connect("network_peer_connected", self, "_on_player_connected")
    var _err2 = get_tree().connect("network_peer_disconnected", self, "_on_player_disconnected")
    var _err3 = get_tree().connect("connected_to_server", self, "_on_connected_to_server")
    var _err4 = get_tree().connect("connection_failed", self, "_on_connection_failed")
    var _err5 = get_tree().connect("server_disconnected", self, "_on_server_disconnected")

func _generate_server_seed() -> void:
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    server_seed = rng.randi()

# Server Creation Method
func start_server(server_name: String = "Castle Fight Server", 
                 port: int = DEFAULT_PORT, 
                 max_players: int = MAX_PLAYERS) -> bool:
    # Prevent multiple server instances
    if network:
        print("Server already running!")
        return false
    
    # Create network instance
    network = NetworkedMultiplayerENet.new()
    
    # Configure network compression if enabled
    if network_compression_enabled:
        network.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_FASTLZ)
    
    # Attempt to create server
    var result = network.create_server(port, max_players)
    
    if result != OK:
        var error_message = "Failed to create server on port " + str(port)
        if result == ERR_CANT_CREATE:
            error_message += ": Port may be in use"
        elif result == ERR_ALREADY_EXISTS:
            error_message += ": Server already exists"
            
        print(error_message)
        network = null
        emit_signal("network_error", error_message)
        return false
    
    # Set network peer and update connection state
    get_tree().network_peer = network
    connection_state = ConnectionState.SERVER_RUNNING
    local_player_id = 1  # Server always has ID 1
    is_server = true
    game_phase = GamePhase.LOBBY  # Start in LOBBY phase
    
    # Initialize players dictionary properly
    players = {
        0: [],  # Team A
        1: []   # Team B
    }
    
    # Initialize server player info
    player_info[local_player_id] = {
        "name": server_name,
        "team": 0,
        "is_host": true,
        "ready": true,
        "ping": 0
    }
    
    # Log server start
    if debug_mode:
        print("Server started on port " + str(port))
    
    emit_signal("server_started")
    return true

# Client Connection Method
func connect_to_server(ip: String, 
                     port: int = DEFAULT_PORT, 
                     player_name: String = "Player") -> bool:
    # Prevent multiple connection attempts
    if network:
        print("Already connected or server running")
        return false
    
    # Create network instance
    network = NetworkedMultiplayerENet.new()
    
    # Configure network compression if enabled
    if network_compression_enabled:
        network.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_FASTLZ)
    
    # Attempt to connect to server
    var result = network.create_client(ip, port)
    
    if result != OK:
        print("Failed to connect to " + ip + ":" + str(port))
        network = null
        emit_signal("network_error", "Connection failed")
        return false
    
    # Set network peer and update connection state
    get_tree().network_peer = network
    connection_state = ConnectionState.CONNECTING  # Use CONNECTING, not SERVER_RUNNING
    is_server = false  # Client is not the server
    
    # Initialize players dictionary properly
    players = {
        0: [],  # Team A
        1: []  # Team B
    }
    
    # Store temporary player info
    player_info[0] = {
        "name": player_name,
        "team": -1,
        "ready": false,
        "ping": -1
    }
    
    # Log connection attempt
    if debug_mode:
        print("Connecting to server: " + ip + ":" + str(port))
    
    return true

# Disconnect from Network
func disconnect_from_network() -> void:
    if network:
        network.close_connection()
        network = null
    
    get_tree().network_peer = null
    
    connection_state = ConnectionState.DISCONNECTED
    game_phase = GamePhase.LOBBY
    local_player_id = 0
    is_server = false  # Reset is_server
    
    # Clear player and match information
    player_info.clear()
    players = {0: [], 1: []}
    spectator_players.clear()
    
    # Reset match state
    match_start_time = 0.0
    match_duration = 0.0
    match_winner = -1
    
    # Clear technical variables
    input_sequence = 0
    last_processed_inputs.clear()
    player_pings.clear()
    
    # Emit signals
    emit_signal("server_stopped")
    emit_signal("connection_failed")

# Player Connection Handlers
func _on_player_connected(player_id: int) -> void:
    print("Player connected: " + str(player_id))
    emit_signal("client_connected", player_id)
    
    if is_server:
        # Initialize player info if not existing
        if not player_info.has(player_id):
            player_info[player_id] = {
                "name": "Player_" + str(player_id),
                "team": -1,
                "ready": false,
                "ping": -1
            }
        
        # Broadcast updated player list
        rpc("_update_player_list", player_info)
        
        # Emit player list changed signal for local UI update
        emit_signal("player_list_changed", player_info)
        
        # Emit player joined signal
        emit_signal("player_joined", player_id)

func _on_player_disconnected(player_id: int) -> void:
    print("Player disconnected: " + str(player_id))
    emit_signal("client_disconnected", player_id)
    
    if is_server:
        # Remove player from teams
        for team in players:
            if player_id in players[team]:
                var _result = players[team].erase(player_id)  # Use team instead of current_team
        
        # Remove player info
        var _result2 = player_info.erase(player_id)  # Capture the return value
        
        # Update player list for all clients
        rpc("_update_player_list", player_info)
        
        # Emit player left signal
        emit_signal("player_left", player_id)
        
        # Check match validity
        _check_match_validity()

func _on_connected_to_server() -> void:
    print("Successfully connected to server")
    connection_state = ConnectionState.CONNECTED
    local_player_id = get_tree().get_network_unique_id()
    
    # Transfer temporary player info
    if player_info.has(0):
        var temp_info = player_info[0]
        var _result = player_info.erase(0)  # Changed player_id to 0
        player_info[local_player_id] = temp_info
    
    emit_signal("connection_succeeded")

func _on_connection_failed() -> void:
    print("Connection to server failed")
    connection_state = ConnectionState.DISCONNECTED
    network = null
    get_tree().network_peer = null
    
    emit_signal("connection_failed")

func _on_server_disconnected() -> void:
    print("Disconnected from server")
    
    # Try to reconnect if in active game
    if game_phase == GamePhase.ACTIVE:
        # Store game state for potential reconnection
        var saved_state = _capture_game_state_snapshot()
        
        # Try reconnecting
        var reconnect_timer = Timer.new()
        reconnect_timer.one_shot = true
        reconnect_timer.wait_time = 5.0
        reconnect_timer.connect("timeout", self, "_attempt_reconnect", [saved_state])
        add_child(reconnect_timer)
        reconnect_timer.start()
        
        emit_signal("network_error", "Server connection lost. Attempting to reconnect...")
    else:
        disconnect_from_network()
        emit_signal("network_error", "Server connection lost")

# Team and Player Management Methods
func change_player_team(player_id: int, new_team: int) -> bool:
    if not is_server or new_team < 0 or new_team > 1:
        return false
    
    # Initialize players dictionary if needed
    if not players.has(0):
        players[0] = []
    if not players.has(1):
        players[1] = []
    
    # Get current team
    var current_team = -1
    for team in players.keys():
        if players[team].has(player_id):
            current_team = team
            break
    
    # Remove from current team if already on a team
    if current_team != -1 and players.has(current_team):
        players[current_team].erase(player_id)
    
    # Add to new team
    if players.has(new_team):
        players[new_team].append(player_id)
    
    # Update player info
    if player_info.has(player_id):
        player_info[player_id]["team"] = new_team
    
    # Emit team change signal
    emit_signal("team_changed", player_id, current_team, new_team)
    
    # Broadcast updated player list
    rpc("_update_player_list", player_info)
    
    return true

# Add this to the NetworkManager class
func set_player_info(player_name: String, team: int) -> void:
    if not network:
        print("Cannot set player info: No active network connection")
        return
        
    if is_server:
        # For server, directly set info
        player_info[local_player_id] = {
            "name": player_name,
            "team": team,
            "is_host": true,
            "ready": true,
            "ping": 0
        }
        emit_signal("player_list_changed", player_info)
    else:
        # For client, send info to server
        rpc_id(1, "_request_set_player_info", player_name, team)

func set_player_ready(player_id: int, is_ready: bool) -> void:
    if not is_server:
        return
    
    if player_info.has(player_id):
        player_info[player_id]["ready"] = is_ready
    
    # Broadcast updated player list
    rpc("_update_player_list", player_info)
    
    # Check match start conditions
    _check_match_start_conditions()

# Also add this to NetworkManager
remote func _request_set_player_info(player_name: String, team: int) -> void:
    if not is_server:
        return
        
    var player_id = get_tree().get_rpc_sender_id()
    if player_info.has(player_id):
        player_info[player_id]["name"] = player_name
        player_info[player_id]["team"] = team
        
        # Update team assignment - use team, not new_team
        var _change_result = change_player_team(player_id, team)
        
        # Broadcast updated player list
        rpc("_update_player_list", player_info)
        emit_signal("player_list_changed", player_info)

func _check_match_start_conditions() -> void:
    # Ensure players dictionary has required keys
    if not players.has(0):
        players[0] = []
    if not players.has(1):
        players[1] = []
    
    # Ensure both teams have players and all are ready
    var team_0_ready = _team_all_ready(0)
    var team_1_ready = _team_all_ready(1)
    
    # Check team sizes and readiness
    var both_teams_ready = team_0_ready and team_1_ready
    var has_enough_players = players[0].size() > 0 and players[1].size() > 0
    
    # In debug mode, we just need one team to be ready
    if debug_mode:
        has_enough_players = players[0].size() > 0 or players[1].size() > 0
        both_teams_ready = (players[0].size() > 0 and team_0_ready) or (players[1].size() > 0 and team_1_ready)
    
    # Set the game phase if conditions are met
    if both_teams_ready and has_enough_players:
        # Make sure to change the game phase to PREGAME
        game_phase = GamePhase.PREGAME
        # Emit match ready signal before starting match preparation
        emit_signal("match_ready")

func _team_all_ready(team: int) -> bool:
    if not players.has(team):
        print("Team " + str(team) + " does not exist")
        return false
        
    if players[team].empty():
        return true  # Empty team is considered "ready"
    
    for player_id in players[team]:
        if not player_info.has(player_id):
            continue
        if not player_info[player_id].get("ready", false):
            return false
    return true

func _prepare_match_start() -> void:
    if game_phase != GamePhase.LOBBY:
        return
    
    game_phase = GamePhase.PREGAME
    emit_signal("match_preparing")
    
    # Broadcast match preparation to all clients
    rpc("_begin_match_preparation")

remote func _begin_match_preparation() -> void:
    if is_server:
        return
    
    game_phase = GamePhase.PREGAME
    
    # Perform any client-side pre-match setup
    _client_pre_match_setup()

func _client_pre_match_setup() -> void:
    # Prepare client-side systems for the upcoming match
    if ui_manager and ui_manager.has_method("show_match_preparation"):
        ui_manager.show_match_preparation()
    
    # Preload necessary resources
    if game_manager and game_manager.has_method("prepare_resources"):
        game_manager.prepare_resources()
    
    print("Client pre-match setup completed")

func start_match() -> void:
    # Print more debug info
    print("Starting match - is_server: " + str(is_server) + ", game_phase: " + str(game_phase))
    
    if not is_server or game_phase != GamePhase.PREGAME:
        print("Cannot start game: Not server or wrong game phase. Current phase: " + str(game_phase))
        return
    
    # Set match start time and phase
    match_start_time = OS.get_unix_time()
    match_duration = 0.0
    game_phase = GamePhase.ACTIVE
    
    # Reset match-related variables
    match_winner = -1
    match_end_reason = ""
    
    # Broadcast match start to all client
    rpc("_match_started")
    
    # Change to game scene
    print("Server changing to game scene...")
    var error = get_tree().change_scene("res://scenes/game/game.tscn")
    if error != OK:
        print("ERROR: Failed to change to game scene with error code: " + str(error))
    emit_signal("match_started")

remote func _match_started() -> void:
    if is_server:
        return
    
    game_phase = GamePhase.ACTIVE
    
    print("Client changing to game scene...")
    var error = get_tree().change_scene("res://scenes/game/game.tscn")
    if error != OK:
        print("ERROR: Failed to change to game scene with error code: " + str(error))

func _client_match_start_setup() -> void:
    # Ensure game manager exists
    if not game_manager:
        push_error("Game Manager not initialized for match start")
        return
    
    # Reset game state
    game_manager.reset_game_state()
    
    # Initialize UI for match
    if ui_manager:
        ui_manager.prepare_match_ui()
    
    # Load and initialize map
    if map_manager:
        map_manager.load_match_map(match_config.get("map", "default_map"))
    
    # Initialize economy for match
    if economy_manager:
        economy_manager.reset_team_resources()
    
    # Set up initial units and structures
    _spawn_initial_match_units()
    
    # Initialize fog of war
    if fog_of_war_manager:
        fog_of_war_manager.reset_visibility()
    
    # Sync initial game state
    _sync_initial_game_state()

# Spawn initial units for match start
func _spawn_initial_match_units() -> void:
    # Make sure unit factory and game manager exist
    if not unit_factory or not game_manager:
        push_error("Cannot spawn initial units: Missing unit factory or game manager")
        return
    
    # Get map manager for spawn positions
    var _current_map_manager = game_manager.get_node_or_null("MapManager")
    
    # Spawn worker for local player
    var local_team = -1
    
    # Get team from player info
    if player_info.has(local_player_id):
        local_team = player_info[local_player_id].get("team", -1)
    
    # Only spawn if on a valid team
    if local_team >= 0:
        # Get spawn position from map manager if available
        var spawn_position
        if map_manager and map_manager.has_method("get_team_start_position"):
            spawn_position = map_manager.get_team_start_position(local_team)
        else:
            # Fallback position based on team
            spawn_position = Vector2(100 + local_team * 800, 300)
        
        # Get worker scene path (could be stored in config)
        var worker_scene_path = "res://scenes/units/worker.tscn"
        
        # Load worker scene 
        var worker_scene = load(worker_scene_path)
        if worker_scene:
            # Instance the worker
            var worker = worker_scene.instance()
            
            # Configure worker properties
            worker.team = local_team
            worker.position = spawn_position
            
            # Add to scene
            game_manager.add_child(worker)
            
            # Register worker with game manager if required
            if game_manager.has_method("register_player_worker"):
                game_manager.register_player_worker(local_player_id, worker)
            
            print("Spawned initial worker for player " + str(local_player_id) + " at " + str(spawn_position))
        else:
            push_error("Failed to load worker scene: " + worker_scene_path)
    else:
        print("Player has no team assigned, not spawning worker")

# Synchronize initial game state when match starts
func _sync_initial_game_state() -> void:
    if is_server:
        # Server collects and broadcasts initial state
        var initial_state = {
            "timestamp": OS.get_ticks_msec(),
            "match_config": match_config,
            "resources": {},
            "buildings": [],
            "server_seed": server_seed
        }
        
        # Collect initial resource state
        if economy_manager:
            for team in range(2):
                initial_state["resources"][str(team)] = {
                    "0": economy_manager.get_resource(team, 0), # Gold
                    "1": economy_manager.get_resource(team, 1), # Wood
                    "2": economy_manager.get_resource(team, 2)  # Supply
                }
        
        # Collect building state (only headquarters initially)
        if game_manager and game_manager.headquarters:
            for team in range(2):
                if game_manager.headquarters.has(team) and game_manager.headquarters[team]:
                    var hq = game_manager.headquarters[team]
                    initial_state["buildings"].append(_collect_building_state(hq))
        
        # Broadcast to all clients
        for player_id in player_info.keys():
            if player_id != 1:  # Skip server
                rpc_id(player_id, "_receive_initial_state", initial_state)
    else:
        # Client requests initial state
        rpc_id(1, "_request_initial_state", local_player_id)
        print("Requesting initial game state from server")
    
    # Set up a fallback timer to prevent clients from being stuck
    # if server doesn't respond
    var fallback_timer = Timer.new()
    fallback_timer.one_shot = true
    fallback_timer.wait_time = 5.0
    fallback_timer.connect("timeout", self, "_on_sync_timeout")
    add_child(fallback_timer)
    fallback_timer.start()

# Remote function called when player list is updated
remote func _update_player_list(updated_player_info: Dictionary) -> void:
    # Update the local player info
    player_info = updated_player_info
    
    # Emit signal to update UI
    emit_signal("player_list_changed", player_info)

# Request handler for initial state
remote func _request_initial_state(requester_id: int) -> void:
    if not is_server:
        return
    
    # Same as in _sync_initial_game_state, but sending only to requester
    var initial_state = {
        "timestamp": OS.get_ticks_msec(),
        "match_config": match_config,
        "resources": {},
        "buildings": [],
        "server_seed": server_seed
    }
    
    # Collect resource state
    if economy_manager:
        for team in range(2):
            initial_state["resources"][str(team)] = {
                "0": economy_manager.get_resource(team, 0),
                "1": economy_manager.get_resource(team, 1),
                "2": economy_manager.get_resource(team, 2)
            }
    
    # Add headquarters
    if game_manager and game_manager.headquarters:
        for team in range(2):
            if game_manager.headquarters.has(team) and game_manager.headquarters[team]:
                initial_state["buildings"].append(_collect_building_state(game_manager.headquarters[team]))
    
    # Send to requester
    rpc_id(requester_id, "_receive_initial_state", initial_state)

# Receiver for initial state
remote func _receive_initial_state(state_data: Dictionary) -> void:
    print("Received initial game state")
    
    # Apply server seed for deterministic randomness
    if state_data.has("server_seed"):
        var rng = RandomNumberGenerator.new()
        rng.seed = state_data.server_seed
        
    # Apply match configuration
    if state_data.has("match_config"):
        match_config = state_data.match_config
    
    # Apply resource state
    if state_data.has("resources") and economy_manager:
        for team_str in state_data.resources:
            var team = int(team_str)
            for resource_type_str in state_data.resources[team_str]:
                var resource_type = int(resource_type_str)
                economy_manager.set_resource(team, resource_type, 
                                          state_data.resources[team_str][resource_type_str])
    
    # Apply building state
    if state_data.has("buildings") and game_manager and game_manager.building_manager:
        for building_data in state_data.buildings:
            # For headquarters or other starting buildings
            if building_data.has("type") and building_data.has("position"):
                var position = Vector2(building_data.position.x, building_data.position.y)
                game_manager.building_manager.place_building(
                    building_data.type, position, building_data.team
                )
    
    print("Initial game state synchronized")

# Fallback in case synchronization fails
func _on_sync_timeout() -> void:
    print("Game state sync timed out - using default state")
    # Game will proceed with default starting state
    # Remove the timer
    var timer = get_node_or_null("Timer")
    if timer:
        timer.queue_free()

# Match End Handling
func _trigger_match_end_by_timeout() -> void:
    if not is_server or game_phase != GamePhase.ACTIVE:
        return
    
    var team_0_score = _calculate_team_score(0)
    var team_1_score = _calculate_team_score(1)
    
    var winning_team = 0 if team_0_score >= team_1_score else 1
    _end_match(winning_team, "timeout")

func _end_match(winning_team: int, reason: String = "standard") -> void:
    if game_phase == GamePhase.ENDED:
        return
    
    game_phase = GamePhase.ENDED
    match_winner = winning_team
    match_end_reason = reason
    
    # Broadcast match end to all clients
    rpc("_match_concluded", winning_team, reason)
    
    emit_signal("match_ended", winning_team, reason)

remote func _match_concluded(winner: int, reason: String) -> void:
    if is_server:
        return
    
    game_phase = GamePhase.ENDED
    match_winner = winner
    match_end_reason = reason
    
    # Client-side match end handling
    _client_match_end_processing()

func _client_match_end_processing() -> void:
    # Stop active game processes
    if game_manager:
        game_manager.stop_game_simulation()
    
    # Disable active UI elements
    if ui_manager:
        ui_manager.show_end_game_screen(match_winner, match_end_reason)
    
    # Collect and display match statistics
    var match_stats = _collect_match_statistics()
    
    # Save match replay or log (if enabled)
    if debug_mode:
        _save_match_replay(match_stats)
    
    # Reset game systems
    _reset_game_systems()
    
    # Transition to post-match lobby or menu
    var _scene_change = get_tree().change_scene("res://scenes/lobby/post_match_screen.tscn")

# Reset game systems to clean state after match
func _reset_game_systems() -> void:
    # Reset relevant game systems to prepare for a new match or return to lobby
    if game_manager:
        if game_manager.has_method("reset_game_state"):
            game_manager.reset_game_state()
    
    if economy_manager:
        if economy_manager.has_method("reset_team_resources"):
            economy_manager.reset_team_resources()
    
    if tech_tree_manager:
        if tech_tree_manager.has_method("reset_tech_trees"):
            tech_tree_manager.reset_tech_trees()
        
    if fog_of_war_manager:
        if fog_of_war_manager.has_method("reset_visibility"):
            fog_of_war_manager.reset_visibility()
    
    # Reset network-specific state
    match_start_time = 0.0
    match_duration = 0.0
    match_winner = -1
    match_end_reason = ""
    input_sequence = 0
    last_processed_inputs.clear()

# Team Score Calculation
func _calculate_team_score(team: int) -> float:
    var score = 0.0
    
    # Buildings score
    if game_manager and game_manager.building_manager:
        var team_buildings = game_manager.building_manager.get_team_buildings(team)
        score += team_buildings.size() * 100.0
        
        for building in team_buildings:
            match building.building_id:
                "headquarters": score += 1000.0
                "bank_vault": score += 500.0
    
    # Economy score
    if economy_manager:
        score += economy_manager.get_income(team) * 10.0
        score += economy_manager.get_resource(team, 0) * 0.1  # Gold resources
    
    return score

# Match Validity Check
func _check_match_validity() -> void:
    # Ensure players dictionary is properly initialized
    if not players.has(0):
        players[0] = []
    if not players.has(1):
        players[1] = []
    
    # End match if either team is empty
    if players[0].empty() or players[1].empty():
        var winning_team = 0 if players[1].empty() else 1
        _end_match(winning_team, "team_eliminated")

# Input Handling and Synchronization
func send_player_input(input_type: int, input_data: Dictionary) -> void:
    if not network or game_phase != GamePhase.ACTIVE:
        return
    
    # Increment input sequence
    input_sequence += 1
    
    # Add sequence to input data
    input_data["sequence"] = input_sequence
    input_data["type"] = input_type
    
    if is_server:
        # Process input locally if server
        _process_player_input(local_player_id, input_data)
    else:
        # Send to server
        rpc_id(1, "_receive_player_input", input_data)

remote func _receive_player_input(input_data: Dictionary) -> void:
    if not is_server:
        return
    
    var player_id = get_tree().get_rpc_sender_id()
    _process_player_input(player_id, input_data)

func _process_player_input(player_id: int, input_data: Dictionary) -> void:
    # Validate input
    if not _validate_player_input(player_id, input_data):
        return
    
    # Process input based on type
    match input_data["type"]:
        InputType.MOVE:
            _handle_move_input(player_id, input_data)
        InputType.ATTACK:
            _handle_attack_input(player_id, input_data)
        InputType.BUILD:
            _handle_build_input(player_id, input_data)
        InputType.USE_ABILITY:
            _handle_ability_input(player_id, input_data)
        InputType.PURCHASE:
            _handle_purchase_input(player_id, input_data)
    
    # Broadcast input to other clients
    _broadcast_input(player_id, input_data)

func _validate_player_input(player_id: int, input_data: Dictionary) -> bool:
    # Verify player exists and is in the correct team
    if not player_info.has(player_id):
        return false
        
    # Verify player is in the match
    if game_phase != GamePhase.ACTIVE:
        return false
        
    # Verify input sequence is reasonable (anti-cheat)
    var last_seq = last_processed_inputs.get(player_id, 0)
    if input_data.sequence <= last_seq:
        return false
        
    # Verify input type is valid
    if not input_data.has("type") or not InputType.values().has(input_data.type):
        return false
        
    # Store sequence number
    last_processed_inputs[player_id] = input_data.sequence
        
    return true

# Get a player's worker unit by player ID
func _get_player_worker(player_id: int):
    # Check if player exists in player info
    if not player_info.has(player_id):
        return null
        
    # Get player's team
    var team = player_info[player_id].get("team", -1)
    if team < 0:
        return null
        
    # Try to get worker from game manager's players dictionary
    if game_manager and game_manager.players.has(player_id):
        return game_manager.players[player_id].get("worker")
        
    # Alternative approach if game_manager doesn't have that property
    if game_manager and game_manager.has_method("get_player_worker"):
        return game_manager.get_player_worker(player_id)
        
    return null

func _handle_move_input(player_id: int, input_data: Dictionary) -> void:
    # Get player worker
    var worker = _get_player_worker(player_id)
    if not worker:
        return
        
    # Extract position data
    var position = Vector2(input_data.position.x, input_data.position.y)
    
    # Command worker to move
    worker.move_to(position)

func _handle_attack_input(_player_id: int, _input_data: Dictionary) -> void:
    # Implement attack input handling
    pass

func _handle_build_input(_player_id: int, _input_data: Dictionary) -> void:
    # Implement build input handling
    pass

func _handle_ability_input(_player_id: int, _input_data: Dictionary) -> void:
    # Implement ability input handling
    pass

func _handle_purchase_input(_player_id: int, _input_data: Dictionary) -> void:
    # Implement purchase input handling
    pass

func _broadcast_input(_sender_id: int, _input_data: Dictionary) -> void:
    # Broadcast input to other clients
    for player_id in player_info.keys():
        if player_id != _sender_id:
            rpc_id(player_id, "_apply_remote_input", _sender_id, _input_data)

remote func _apply_remote_input(_player_id: int, _input_data: Dictionary) -> void:
    # Client-side input application
    if is_server:
        return
    
    # Process and apply received input
    match _input_data["type"]:
        InputType.MOVE:
            # Apply move input
            pass
        InputType.ATTACK:
            # Apply attack input
            pass
        InputType.BUILD:
            # Apply build input
            pass
        InputType.USE_ABILITY:
            # Apply ability input
            pass
        InputType.PURCHASE:
            # Apply purchase input
            pass


# Network Performance Optimization
func _optimize_network_bandwidth() -> void:
    if not network:
        return
    
    # Adjust send buffer size
    network.set_stats_enabled(true)
    network.set_max_packet_size(1024 * 64)  # 64KB max packet
    
    # Enable delta compression
    if network_compression_enabled:
        network.set_compression_mode(NetworkedMultiplayerENet.COMPRESSION_RANGE)

func _process(delta: float) -> void:
    # Update game state
    if game_phase == GamePhase.ACTIVE:
        _update_game_state(delta)
        

# Advanced Anti-Cheat Mechanisms
func _generate_network_checksum() -> int:
    var checksum_data = {
        "game_state": _capture_game_state_snapshot(),
        "player_actions": last_processed_inputs,
        "timestamp": OS.get_unix_time()
    }
    
    # Use a robust checksum generation method
    var checksum = hash(JSON.print(checksum_data))
    return int(abs(checksum)) % 100000  # Normalize to a smaller range

func _validate_network_checksum(client_checksum: int) -> bool:
    var _current_checksum = _generate_network_checksum()
    
    # Allow small variance to account for network latency
    var checksum_tolerance = 5
    
    return abs(server_checksum - client_checksum) <= checksum_tolerance

# Comprehensive Logging System
func _log_network_event(event_type: String, details: Dictionary) -> void:
    var log_entry = {
        "timestamp": OS.get_datetime(),
        "event_type": event_type,
        "player_id": local_player_id,
        "details": details
    }
    
    # Store in memory
    network_log.append(log_entry)
    
    # Optionally write to file in debug mode
    if debug_mode:
        _write_network_log_to_file(log_entry)

func _write_network_log_to_file(log_entry: Dictionary) -> void:
    var log_dir = "user://network_logs/"
    var dir = Directory.new()
    
    # Create log directory if it doesn't exist
    if not dir.dir_exists(log_dir):
        dir.make_dir_recursive(log_dir)
    
    var log_file_path = log_dir + "network_log_" + str(OS.get_unix_time()) + ".json"
    var file = File.new()
    
    if file.open(log_file_path, File.WRITE) == OK:
        file.store_string(JSON.print(log_entry, "\t"))
        file.close()

# Detailed Match Statistics Collection
func _collect_match_statistics() -> Dictionary:
    var match_stats = {
        "match_id": match_config.get("id", "unknown"),
        "duration": match_duration,
        "winner": match_winner,
        "end_reason": match_end_reason,
        "teams": {
            0: _collect_team_statistics(0),
            1: _collect_team_statistics(1)
        },
        "player_performances": {}
    }
    
    # Collect individual player performances
    for player_id in player_info:
        match_stats["player_performances"][player_id] = _collect_player_performance(player_id)
    
    return match_stats

func _collect_team_statistics(team: int) -> Dictionary:
    var team_stats = {
        "buildings_destroyed": 0,
        "units_killed": 0,
        "total_income": 0,
        "resources_collected": {},
        "upgrades_researched": []
    }
    
    # Populate stats using game manager systems
    if game_manager:
        # Example population methods (would need corresponding implementations)
        if game_manager.building_manager:
            team_stats["buildings_destroyed"] = game_manager.building_manager.get_destroyed_buildings_count(team)
        
        if economy_manager:
            team_stats["total_income"] = economy_manager.get_total_income(team)
            
            # Collect resources
            for resource_type in [0, 1, 2]:  # Assuming GOLD, WOOD, SUPPLY
                team_stats["resources_collected"][resource_type] = economy_manager.get_total_resources_collected(team, resource_type)
        
        if tech_tree_manager:
            team_stats["upgrades_researched"] = tech_tree_manager.get_researched_upgrades(team)
    
    return team_stats

func _collect_player_performance(player_id: int) -> Dictionary:
    var performance = {
        "name": player_info[player_id].get("name", "Unknown"),
        "team": player_info[player_id].get("team", -1),
        "units_created": 0,
        "units_killed": 0,
        "buildings_constructed": 0,
        "total_resources_spent": 0,
        "ping": player_pings.get(player_id, -1)
    }
    
    # Populate performance data (would require corresponding game system methods)
    if game_manager:
        # Example method calls (to be implemented in respective managers)
        if unit_factory:
            performance["units_created"] = unit_factory.get_units_created_by_player(player_id)
        
        if game_manager.combat_system:
            performance["units_killed"] = game_manager.combat_system.get_units_killed_by_player(player_id)
        
        if game_manager.building_manager:
            performance["buildings_constructed"] = game_manager.building_manager.get_buildings_constructed_by_player(player_id)
        
        if economy_manager:
            performance["total_resources_spent"] = economy_manager.get_total_resources_spent_by_player(player_id)
    
    return performance

func _connect_signals() -> void:
    if game_manager:
        game_manager.connect("game_started", self, "_on_game_started")
        game_manager.connect("game_ended", self, "_on_game_ended")
        
    if economy_manager:
        economy_manager.connect("resources_changed", self, "_on_resources_changed")

# Network Replay System (Basic Implementation)
func _save_match_replay(match_stats: Dictionary) -> void:
    var replay_dir = "user://replays/"
    var dir = Directory.new()
    
    # Create replay directory if it doesn't exist
    if not dir.dir_exists(replay_dir):
        dir.make_dir_recursive(replay_dir)
    
    # Generate unique replay filename
    var replay_filename = "replay_" + str(OS.get_unix_time()) + ".json"
    var replay_path = replay_dir + replay_filename
    
    var file = File.new()
    if file.open(replay_path, File.WRITE) == OK:
        file.store_string(JSON.print({
            "match_stats": match_stats,
            "network_log": network_log,
            "server_seed": server_seed
        }, "\t"))
        file.close()
        
        print("Match replay saved: " + replay_path)

# Additional Utility Methods for Robust Networking
func get_player_name(player_id: int) -> String:
    return player_info.get(player_id, {}).get("name", "Unknown Player")

func is_player_in_match(player_id: int) -> bool:
    return (player_info.has(player_id) and 
            player_info[player_id].get("team", -1) != -1 and 
            game_phase == GamePhase.ACTIVE)

# Capture a snapshot of the current game state for checksum generation
func _capture_game_state_snapshot() -> Dictionary:
    var snapshot = {
        "timestamp": OS.get_unix_time(),
        "game_phase": game_phase,
        "players": {},
        "team_resources": {}
    }
    
    # Capture player states
    for player_id in player_info:
        snapshot["players"][player_id] = {
            "team": player_info[player_id].get("team", -1),
            "ready": player_info[player_id].get("ready", false)
        }
    
    # Capture team resources
    if economy_manager:
        for team in [0, 1]:
            snapshot["team_resources"][team] = {
                "gold": economy_manager.get_resource(team, 0),
                "wood": economy_manager.get_resource(team, 1),
                "supply": economy_manager.get_resource(team, 2)
            }
    
    return snapshot

# Advanced Connection Quality Assessment
func assess_network_quality() -> Dictionary:
    var network_quality = {
        "overall_quality": "good",
        "latency": {
            "avg_ping": 0,
            "max_ping": 0,
            "min_ping": 999
        },
        "packet_loss": 0.0,
        "connection_stability": 1.0  # 1.0 is perfect, 0.0 is worst
    }
    
    # Calculate ping statistics
    var total_ping = 0
    for ping in player_pings.values():
        total_ping += ping
        network_quality["latency"]["max_ping"] = max(network_quality["latency"]["max_ping"], ping)
        network_quality["latency"]["min_ping"] = min(network_quality["latency"]["min_ping"], ping)
    
    # Average ping
    if player_pings.size() > 0:
        network_quality["latency"]["avg_ping"] = total_ping / player_pings.size()
    
    # Determine overall quality
    if network_quality["latency"]["avg_ping"] > 200:
        network_quality["overall_quality"] = "poor"
    elif network_quality["latency"]["avg_ping"] > 100:
        network_quality["overall_quality"] = "fair"
    
    return network_quality

# Connection Troubleshooting Recommendations
func get_connection_recommendations() -> Array:
    var recommendations = []
    var quality = assess_network_quality()
    
    match quality["overall_quality"]:
        "poor":
            recommendations.append("Your network connection is unstable.")
            recommendations.append("Try connecting to a server closer to your location.")
            recommendations.append("Close background applications consuming bandwidth.")
        "fair":
            recommendations.append("Your connection might cause slight gameplay interruptions.")
            recommendations.append("Consider using a wired internet connection.")
    
    return recommendations

# Debug Information Gathering
func generate_debug_report() -> Dictionary:
    return {
        "protocol_version": PROTOCOL_VERSION,
        "connection_state": connection_state,
        "game_phase": game_phase,
        "local_player_id": local_player_id,
        "network_quality": assess_network_quality(),
        "player_count": player_info.size(),
        "match_config": match_config,
        "debug_mode": debug_mode,
        "network_log_entries": network_log.size(),
        "recommendations": get_connection_recommendations()
    }

# Export debug report to file
func export_debug_report() -> String:
    var report = generate_debug_report()
    var export_path = "user://debug_reports/debug_report_" + str(OS.get_unix_time()) + ".json"
    
    var dir = Directory.new()
    if not dir.dir_exists("user://debug_reports"):
        dir.make_dir_recursive("user://debug_reports")
    
    var file = File.new()
    if file.open(export_path, File.WRITE) == OK:
        file.store_string(JSON.print(report, "\t"))
        file.close()
        print("Debug report exported to: " + export_path)
    
    return export_path

# Collect the current state of a building for network synchronization
func _collect_building_state(building) -> Dictionary:
    return {
        "id": building.get_instance_id(),
        "type": building.building_id,
        "team": building.team,
        "health": building.health,
        "max_health": building.max_health,
        "position": {
            "x": building.global_position.x,
            "y": building.global_position.y
        },
        "grid_position": {
            "x": building.grid_position.x if "grid_position" in building else 0,
            "y": building.grid_position.y if "grid_position" in building else 0
        },
        "is_constructed": building.is_constructed if "is_constructed" in building else true,
        "construction_progress": building.construction_progress if "construction_progress" in building else 100.0
    }

# Collect the current state of a unit for network synchronization
func _collect_unit_state(unit) -> Dictionary:
    return {
        "id": unit.get_instance_id(),
        "type": unit.unit_id if "unit_id" in unit else "generic_unit",
        "team": unit.team,
        "health": unit.health if "health" in unit else 100,
        "max_health": unit.max_health if "max_health" in unit else 100,
        "position": {
            "x": unit.global_position.x,
            "y": unit.global_position.y
        },
        "velocity": {
            "x": unit.velocity.x if "velocity" in unit else 0,
            "y": unit.velocity.y if "velocity" in unit else 0
        },
        "state": unit.current_state if "current_state" in unit else 0,
        "target_id": unit.target.get_instance_id() if "target" in unit and unit.target != null else 0
    }

# Synchronize game state between clients
remote func _sync_game_state(state_data: Dictionary) -> void:
    if is_server:
        # Server shouldn't receive this
        return
        
    # Apply received state data to local game state
    if game_manager:
        # Update resource state
        if state_data.has("resources") and economy_manager:
            for team_str in state_data.resources:
                var team = int(team_str)
                for resource_type_str in state_data.resources[team_str]:
                    var resource_type = int(resource_type_str)
                    economy_manager.set_resource(team, resource_type, 
                                               state_data.resources[team_str][resource_type_str])
        
        # Update building state
        if state_data.has("buildings") and game_manager.building_manager:
            for building_data in state_data.buildings:
                # Find building by ID or create if not exists
                var building = instance_from_id(building_data.id) if instance_exists(building_data.id) else null
                
                if building == null and building_data.has("type") and building_data.has("position"):
                    # Create building if it doesn't exist
                    var position = Vector2(building_data.position.x, building_data.position.y)
                    building = game_manager.building_manager.place_building(
                        building_data.type, position, building_data.team
                    )
                    
                if building != null:
                    # Update building properties
                    building.health = building_data.health
                    
                    # Update construction progress if applicable
                    if "is_constructed" in building and not building.is_constructed:
                        building.construction_progress = building_data.construction_progress
                        
                        # Complete construction if needed
                        if building.construction_progress >= 100.0:
                            building.complete_construction()
        
        # Update unit state
        if state_data.has("units"):
            for unit_data in state_data.units:
                # Find unit by ID or create if not exists
                var unit = instance_from_id(unit_data.id) if instance_exists(unit_data.id) else null
                
                if unit == null and unit_data.has("type") and unit_data.has("position"):
                    # Create unit if it doesn't exist
                    var position = Vector2(unit_data.position.x, unit_data.position.y)
                    unit = unit_factory.create_unit(unit_data.type, position, unit_data.team)
                    
                if unit != null:
                    # Update unit properties
                    unit.health = unit_data.health
                    
                    # Update unit state if applicable
                    if "current_state" in unit:
                        unit.current_state = unit_data.state
                    
                    # Update target if applicable
                    if "target" in unit and unit_data.target_id != 0:
                        unit.target = instance_from_id(unit_data.target_id) if instance_exists(unit_data.target_id) else null

# Helper function to check if instance exists
func instance_exists(instance_id: int) -> bool:
    return instance_from_id(instance_id) != null

# Send current game state to clients (server only)
func _broadcast_game_state() -> void:
    if not is_server or game_phase != GamePhase.ACTIVE:
        return
    
    # Collect current game state
    var state_data = {
        "timestamp": OS.get_ticks_msec(),
        "resources": {},
        "buildings": [],
        "units": []
    }
    
    # Collect resource state
    if economy_manager:
        for team in range(2):
            state_data.resources[str(team)] = {
                "0": economy_manager.get_resource(team, 0), # Gold
                "1": economy_manager.get_resource(team, 1), # Wood
                "2": economy_manager.get_resource(team, 2)  # Supply
            }
    
    # Collect building state
    if game_manager and game_manager.building_manager:
        # Get all buildings for both teams
        var all_buildings = []
        for team in range(2):
            all_buildings.append_array(game_manager.building_manager.get_team_buildings(team))
            
        # Collect state for each building
        for building in all_buildings:
            state_data.buildings.append(_collect_building_state(building))
    
    # Collect unit state
    # Find all units in the scene
    var units = get_tree().get_nodes_in_group("units")
    if units.empty() and game_manager:
        # If no units in group, try to find them in the scene
        var main_scene = get_tree().current_scene
        if main_scene:
            var units_node = main_scene.get_node_or_null("Units")
            if units_node:
                units = units_node.get_children()
    
    # Collect state for each unit
    for unit in units:
        state_data.units.append(_collect_unit_state(unit))
    
    # Broadcast state to all clients
    for player_id in player_info.keys():
        if player_id != 1:  # Skip server (ID 1)
            rpc_id(player_id, "_sync_game_state", state_data)

func _update_game_state(delta: float) -> void:
    if not network or game_phase != GamePhase.ACTIVE:
        return
        
    # Update match duration
    match_duration += delta
        
    # Only server broadcasts game state
    if is_server:
        server_tick_timer += delta
        
        # Broadcast state at regular intervals
        if server_tick_timer >= 1.0 / SERVER_TICK_RATE:
            server_tick_timer = 0
            _broadcast_game_state()
    
    # Update ping for all players
    ping_timer += delta
    if ping_timer >= ping_interval:
        ping_timer = 0
        _update_pings()

# Add ping update functionality
func _update_pings() -> void:
    # Update ping measurements for all connected players
    if is_server:
        # Server measures ping to all clients
        for player_id in player_info.keys():
            if player_id != 1:  # Skip server
                # Send ping request to client
                rpc_id(player_id, "_ping_request", OS.get_ticks_msec())
    else:
        # Client measures ping to server
        rpc_id(1, "_ping_request", OS.get_ticks_msec())

# Ping request handler
remote func _ping_request(timestamp: int) -> void:
    # Send ping response back to sender
    var sender_id = get_tree().get_rpc_sender_id()
    rpc_id(sender_id, "_ping_response", timestamp)

# Ping response handler
remote func _ping_response(timestamp: int) -> void:
    # Calculate ping time
    var ping_time = OS.get_ticks_msec() - timestamp
    var sender_id = get_tree().get_rpc_sender_id()
    
    # Update player ping information
    if player_info.has(sender_id):
        player_info[sender_id]["ping"] = ping_time
        player_pings[sender_id] = ping_time
        
        # Emit signal for UI updates
        emit_signal("ping_updated", sender_id, ping_time)

func start_game() -> void:
    if not is_server or game_phase != GamePhase.PREGAME:
        print("Cannot start game: Not server or wrong game phase")
        return
    
    print("NetworkManager: Starting match")
    start_match()

func change_team(new_team: int) -> bool:
    if not network:
        print("Cannot change team: No active network connection")
        return false
    
    if is_server:
        var change_result = change_player_team(local_player_id, new_team)
        return change_result  # Return the result from change_player_team
    else:
        rpc_id(1, "_request_change_team", new_team)
        return true

remote func _request_change_team(new_team: int) -> void:
    if not is_server:
        return
    
    var player_id = get_tree().get_rpc_sender_id()
    var _change_result = change_player_team(player_id, new_team)
