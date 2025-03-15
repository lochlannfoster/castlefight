# Network Manager - Handles networking and multiplayer functionality
# Path: scripts/networking/network_manager.gd
class_name NetworkManager
extends Node

# Network signals
signal server_started
signal server_stopped
signal client_connected(player_id)
signal client_disconnected(player_id)
signal connection_failed
signal connection_succeeded
signal player_list_changed(player_list)
signal match_ready
signal network_error(error_message)
signal ping_updated(player_id, ping)

# Network constants
const DEFAULT_PORT = 27015
const MAX_PLAYERS = 6  # Maximum of 3v3
const RECONNECT_TIMEOUT = 300  # 5 minutes (300 seconds)
const SERVER_TICK_RATE = 20  # Ticks per second
const USE_DELTA_COMPRESSION = true
const CHECKSUM_INTERVAL = 5.0  # How often to verify game state checksums

# Network properties
var network: NetworkedMultiplayerENet = null
var local_player_id: int = 0
var is_server: bool = false
var server_detachable: bool = true  # If true, server can continue running if host disconnects
var player_info: Dictionary = {}  # Player ID -> Player Info (name, team, ready, etc.)
var disconnected_players: Dictionary = {}  # Tracks players who disconnected for reconnection
var server_tick_timer: float = 0.0
var checksum_timer: float = 0.0
var last_ping_time: Dictionary = {}  # Player ID -> timestamp of last ping sent
var ping_values: Dictionary = {}  # Player ID -> current ping (ms)
var waiting_for_checksum: bool = false
var player_checksums: Dictionary = {}  # Player ID -> last checksum
var local_sequence_num: int = 0  # Local input sequence number
var last_processed_input: Dictionary = {}  # Player ID -> last processed input sequence

# Debug properties
var debug_mode: bool = false  # When true, host can control all workers

# Game state variables
var game_started: bool = false
var paused: bool = false
var match_id: String = ""

# References
var game_manager: GameManager

# Ready function
func _ready() -> void:
	# Get game manager reference
	game_manager = get_node_or_null("/root/GameManager")
	
	# Set network peer
	var _connect1 = get_tree().connect("network_peer_connected", self, "_on_player_connected")
	var _connect2 = get_tree().connect("network_peer_disconnected", self, "_on_player_disconnected")
	var _connect3 = get_tree().connect("connected_to_server", self, "_on_connected_to_server")
	var _connect4 = get_tree().connect("connection_failed", self, "_on_connection_failed")
	var _connect5 = get_tree().connect("server_disconnected", self, "_on_server_disconnected")

# Process function for server ticks and ping
func _process(delta: float) -> void:
	if not network:
		return
	
	if is_server and game_started:
		# Handle server ticks
		server_tick_timer += delta
		if server_tick_timer >= 1.0 / SERVER_TICK_RATE:
			server_tick_timer -= 1.0 / SERVER_TICK_RATE
			_process_server_tick()
	
	# Handle checksum verification
	if game_started:
		checksum_timer += delta
		if checksum_timer >= CHECKSUM_INTERVAL:
			checksum_timer = 0
			_verify_game_state()
	
	# Update pings
	_update_pings(delta)

# Start server
func start_server(server_name: String = "Local Game", max_players: int = MAX_PLAYERS, port: int = DEFAULT_PORT) -> bool:
	if network:
		# Already running a server or connected to one
		return false
	
	network = NetworkedMultiplayerENet.new()
	var result = network.create_server(port, max_players)
	
	if result != OK:
		emit_signal("network_error", "Failed to create server on port " + str(port))
		network = null
		return false
	
	get_tree().network_peer = network
	is_server = true
	local_player_id = get_tree().get_network_unique_id()
	
	# Initialize player info for server player
	player_info[local_player_id] = {
		"name": server_name + " (Host)",
		"team": 0,  # Default to Team A for host
		"ready": false,
		"is_host": true,
		"ping": 0
	}
	
	# Generate a unique match ID
	match_id = _generate_match_id()
	
	emit_signal("server_started")
	emit_signal("player_list_changed", player_info)
	
	print("Server started on port: ", port)
	return true

# Connect to server
func connect_to_server(ip: String, port: int = DEFAULT_PORT, player_name: String = "Player") -> bool:
	if network:
		# Already connected or running a server
		return false
	
	network = NetworkedMultiplayerENet.new()
	var result = network.create_client(ip, port)
	
	if result != OK:
		emit_signal("network_error", "Failed to connect to server at " + ip + ":" + str(port))
		network = null
		return false
	
	get_tree().network_peer = network
	is_server = false
	
	# Store player name for when we connect
	player_info[0] = {
		"name": player_name,
		"ready": false
	}
	
	print("Connecting to server at ", ip, ":", port)
	return true

# Disconnect from network
func disconnect_from_network() -> void:
	if network:
		network.close_connection()
		network = null
	
	get_tree().network_peer = null
	is_server = false
	local_player_id = 0
	player_info.clear()
	disconnected_players.clear()
	game_started = false
	paused = false
	
	print("Disconnected from network")
	emit_signal("server_stopped")

# Set player information
func set_player_info(p_name: String, team: int) -> void:
	if not network:
		return
	
	# Update local info
	if local_player_id == 0:
		local_player_id = get_tree().get_network_unique_id()
	
	# Set player info
	var info = {
		"name": p_name,
		"team": team,
		"ready": false,
		"is_host": is_server,
		"ping": 0
	}
	
	# Update local info
	player_info[local_player_id] = info
	
	# Send to server if we're a client
	if not is_server:
		rpc_id(1, "_receive_player_info", local_player_id, info)
	else:
		# If we're the server, broadcast to all clients
		emit_signal("player_list_changed", player_info)
		rpc("_update_player_list", player_info)

# Set player ready status
func set_player_ready(ready: bool) -> void:
	if not network or not player_info.has(local_player_id):
		return
	
	# Update local ready status
	player_info[local_player_id].ready = ready
	
	# Send to server if we're a client
	if not is_server:
		rpc_id(1, "_receive_player_ready", local_player_id, ready)
	else:
		# If we're the server, broadcast to all clients
		emit_signal("player_list_changed", player_info)
		rpc("_update_player_list", player_info)
		
		# Check if all players are ready to start
		_check_all_ready()

# Change team
func change_team(team: int) -> void:
	if not network or not player_info.has(local_player_id):
		return
	
	# Update local team
	player_info[local_player_id].team = team
	
	# Send to server if we're a client
	if not is_server:
		rpc_id(1, "_receive_player_team", local_player_id, team)
	else:
		# If we're the server, broadcast to all clients
		emit_signal("player_list_changed", player_info)
		rpc("_update_player_list", player_info)

# Start game for all players
func start_game() -> void:
	if not is_server:
		return
	
	# Make sure all players are ready
	for player_id in player_info.keys():
		if not player_info[player_id].ready:
			return
	
	# Set game started flag
	game_started = true
	
	# Reset timers
	server_tick_timer = 0
	checksum_timer = 0
	
	# Make sure all players have valid teams before starting
	# A player with team = -1 should be assigned to team 0 or 1
	for player_id in player_info.keys():
		if player_info[player_id].team < 0 or player_info[player_id].team > 1:
			# Assign to the team with fewer players
			var team0_count = 0
			var team1_count = 0
			
			for pid in player_info.keys():
				if player_info[pid].team == 0:
					team0_count += 1
				elif player_info[pid].team == 1:
					team1_count += 1
			
			# Use explicit assignment instead of ternary
			var new_team = 0
			if team1_count < team0_count:
				new_team = 1
			
			player_info[player_id].team = new_team
			
			# Notify the player of team change
			if player_id != local_player_id:
				rpc_id(player_id, "_update_team_assignment", new_team)
	
	# Notify all clients to start game
	rpc("_start_game_on_client", match_id)
	
	# Start game locally
	_start_game_locally()

# Add this method to NetworkManager
remote func _update_team_assignment(new_team: int) -> void:
	# Client receives team assignment from server
	if is_server:
		return
	
	if player_info.has(local_player_id):
		player_info[local_player_id].team = new_team

# Pause game
func pause_game(paused_state: bool) -> void:
	if not is_server:
		# Only server can pause
		rpc_id(1, "_request_pause", paused_state)
		return
	
	paused = paused_state
	rpc("_set_game_paused", paused)
	
	if game_manager:
		game_manager.toggle_pause()

# Send player input to server
func send_input(input_data: Dictionary) -> void:
	if not network or not game_started:
		return
	
	# Increment sequence number
	local_sequence_num += 1
	
	# Add sequence number to input data
	input_data.seq = local_sequence_num
	
	if is_server:
		# Process locally immediately if we're the server
		_process_player_input(local_player_id, input_data)
	else:
		# Send to server if we're a client
		rpc_id(1, "_receive_player_input", input_data)

# Calculate current game state checksum
func calculate_game_state_checksum() -> int:
	# This is a placeholder - real implementation would need to hash important game state
	var checksum = 0
	
	if game_manager:
		# Include grid state
		if game_manager.grid_system:
			for cell in game_manager.grid_system.grid_cells.values():
				checksum = (checksum + (1 if cell.occupied else 0)) % 1000000007
		
		# Include building state
		if game_manager.building_manager:
			for building in game_manager.building_manager.buildings.values():
				checksum = (checksum + int(building.health)) % 1000000007
		
		# Include economy state
		if game_manager.economy_manager:
			for team in range(2):
				checksum = (checksum + int(game_manager.economy_manager.get_income(team))) % 1000000007
				checksum = (checksum + int(game_manager.economy_manager.get_resource(team, 0))) % 1000000007
	
	return checksum

# Verify game state across all clients
func _verify_game_state() -> void:
	if not network or not game_started:
		return
	
	var checksum = calculate_game_state_checksum()
	
	if is_server:
		# Store server's checksum
		player_checksums[local_player_id] = checksum
		
		# Request checksums from all clients
		waiting_for_checksum = true
		player_checksums.clear()
		player_checksums[local_player_id] = checksum
		rpc("_request_game_state_checksum")
	else:
		# If client, send checksum to server when requested
		if waiting_for_checksum:
			rpc_id(1, "_receive_game_state_checksum", checksum)
			waiting_for_checksum = false

# Process server tick (server-side)
func _process_server_tick() -> void:
	if not is_server or not game_started or paused:
		return
	
	# This is where server would process game state updates
	# and send delta updates to clients
	
	# For now, just send a heartbeat
	rpc("_server_heartbeat", OS.get_ticks_msec())

# Update pings
func _update_pings(_delta: float) -> void:
	if not network:
		return
	
	# Send ping every second
	for player_id in player_info.keys():
		if player_id != local_player_id:
			if not last_ping_time.has(player_id) or OS.get_ticks_msec() - last_ping_time[player_id] > 1000:
				_send_ping(player_id)

# Send ping to a player
func _send_ping(player_id: int) -> void:
	if player_id == local_player_id:
		return
	
	last_ping_time[player_id] = OS.get_ticks_msec()
	
	if is_server:
		rpc_id(player_id, "_ping", OS.get_ticks_msec())
	else:
		if player_id == 1:  # Server
			rpc_id(1, "_ping", OS.get_ticks_msec())

# Start game locally
func _start_game_locally() -> void:
	print("NetworkManager: Starting game locally")
	print("Current scene: ", get_tree().current_scene.filename)
	
	# Change to game scene
	var scene_change_result = get_tree().change_scene("res://scenes/game/game.tscn")
	print("Scene change result: ", scene_change_result)

# Finish game start after scene change 
func _finish_game_start() -> void:
	# Now set up the game with GameManager
	var current_game_manager = get_node_or_null("/root/GameManager")
	if current_game_manager:
		# Set player teams
		for player_id in player_info.keys():
			var team = player_info[player_id].team
			var name = player_info[player_id].name
			current_game_manager.add_player(player_id, name, team)
		
		# Start the game
		current_game_manager.start_game()
	else:
		push_error("Could not find GameManager after scene change")

# Generate a unique match ID
func _generate_match_id() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var id = ""
	for _i in range(8):
		id += char(rng.randi_range(65, 90))  # A-Z
	
	return id

# Check if all players are ready
func _check_all_ready() -> void:
	if not is_server:
		return
	
	var all_ready = true
	for player_id in player_info.keys():
		if not player_info[player_id].ready:
			all_ready = false
			break
	
	if all_ready:
		emit_signal("match_ready")

# Send current game state to a player
func _send_game_state_to_player(player_id: int) -> void:
	if not is_server or not game_started:
		return
	
	# Create a snapshot of current game state
	var game_state = {
		"match_id": match_id,
		"paused": paused,
		"time": game_manager.match_timer if game_manager else 0
	}
	
	# Send to the specific player
	rpc_id(player_id, "_receive_game_state", game_state)

# RPC methods (prefixed with _ to distinguish them)
remote func _receive_player_info(player_id: int, info: Dictionary) -> void:
	# Server receives player info from clients
	if not is_server:
		return
	
	print("Received player info from: ", player_id)
	
	# Store player info
	player_info[player_id] = info
	
	# Broadcast updated player list
	emit_signal("player_list_changed", player_info)
	rpc("_update_player_list", player_info)

remote func _receive_player_ready(player_id: int, ready: bool) -> void:
	# Server receives player ready status
	if not is_server:
		return
	
	if player_info.has(player_id):
		player_info[player_id].ready = ready
		
		# Broadcast updated player list
		emit_signal("player_list_changed", player_info)
		rpc("_update_player_list", player_info)
		
		# Check if all players are ready
		_check_all_ready()

remote func _receive_player_team(player_id: int, team: int) -> void:
	# Server receives player team change
	if not is_server:
		return
	
	if player_info.has(player_id):
		player_info[player_id].team = team
		
		# Broadcast updated player list
		emit_signal("player_list_changed", player_info)
		rpc("_update_player_list", player_info)

remote func _update_player_list(updated_player_info: Dictionary) -> void:
	# Clients receive updated player list from server
	if is_server:
		return
	
	player_info = updated_player_info
	emit_signal("player_list_changed", player_info)

remote func _start_game_on_client(server_match_id: String) -> void:
	# Clients receive game start notification
	if is_server:
		return
	
	match_id = server_match_id
	game_started = true
	
	# Start game locally
	_start_game_locally()

remote func _set_game_paused(paused_state: bool) -> void:
	# All peers receive pause state change
	paused = paused_state
	
	if game_manager:
		game_manager.toggle_pause()

remote func _request_pause(paused_state: bool) -> void:
	# Server receives pause request from client
	if not is_server:
		return
	
	pause_game(paused_state)

remote func _receive_player_input(input_data: Dictionary) -> void:
	# Server receives input from clients
	if not is_server:
		return
	
	var player_id = get_tree().get_rpc_sender_id()
	_process_player_input(player_id, input_data)

remote func _server_heartbeat(_server_time: int) -> void:
	# Clients receive heartbeat from server
	if is_server:
		return
	
	# Could use this for latency calculation or to detect timeout
	pass

remote func _request_game_state_checksum() -> void:
	# Clients receive request for checksum
	if is_server:
		return
	
	waiting_for_checksum = true
	
	# Send checksum back to server
	var checksum = calculate_game_state_checksum()
	rpc_id(1, "_receive_game_state_checksum", checksum)

remote func _receive_game_state_checksum(checksum: int) -> void:
	# Server receives checksums from clients
	if not is_server:
		return
	
	var player_id = get_tree().get_rpc_sender_id()
	player_checksums[player_id] = checksum
	
	# Check if we have received checksums from all players
	var all_received = true
	for id in player_info.keys():
		if id != local_player_id and not player_checksums.has(id):
			all_received = false
			break
	
	if all_received:
		_validate_checksums()

remote func _ping(timestamp: int) -> void:
	# Receive ping request and respond with pong
	var sender_id = get_tree().get_rpc_sender_id()
	rpc_id(sender_id, "_pong", timestamp)

remote func _pong(timestamp: int) -> void:
	# Receive pong response and calculate ping
	var sender_id = get_tree().get_rpc_sender_id()
	var ping_ms = OS.get_ticks_msec() - timestamp
	ping_values[sender_id] = ping_ms
	
	if player_info.has(sender_id):
		player_info[sender_id].ping = ping_ms
		emit_signal("ping_updated", sender_id, ping_ms)

remote func _receive_game_state(game_state: Dictionary) -> void:
	# Client receives game state after reconnection
	if is_server:
		return
	
	match_id = game_state.match_id
	paused = game_state.paused
	
	# Apply game state to game manager
	if game_manager:
		game_manager.match_timer = game_state.time
	
	print("Received game state after reconnection")

# Process player input (server-side)
func _process_player_input(player_id: int, input_data: Dictionary) -> void:
	if not is_server:
		return
	
	# Check for sequence number to prevent processing outdated inputs
	if last_processed_input.has(player_id) and input_data.seq <= last_processed_input[player_id]:
		return
	
	last_processed_input[player_id] = input_data.seq
	
	# Process input based on type
	if input_data.has("type"):
		match input_data.type:
			"worker_move":
				# Notify game manager of worker movement
				if game_manager and player_info.has(player_id):
					var _team = player_info[player_id].team
					# Implement worker movement command
					pass
			
			"build":
				# Process building placement
				if game_manager and player_info.has(player_id):
					var team = player_info[player_id].team
					var building_type = input_data.building_type
					var position = Vector2(input_data.position.x, input_data.position.y)
					
					# Forward to building manager
					if game_manager.building_manager:
						game_manager.building_manager.place_building(building_type, position, team)
			
			"use_ability":
				# Process ability usage
				pass
			
			"purchase_item":
				# Process item purchase
				pass
	
	# Broadcast input to all clients (except the sender)
	for id in player_info.keys():
		if id != player_id:
			rpc_id(id, "_apply_remote_input", player_id, input_data)

remote func _apply_remote_input(_player_id: int, input_data: Dictionary) -> void:
	# Clients apply input received from server
	if is_server:
		return
	
	# Process input based on type
	if input_data.has("type"):
		match input_data.type:
			"worker_move":
				# Update worker position for the specific player
				pass
			
			"build":
				# Apply building placement
				pass
			
			"use_ability":
				# Apply ability usage
				pass
			
			"purchase_item":
				# Apply item purchase
				pass

# Validate checksums from all players
func _validate_checksums() -> void:
	if not is_server:
		return
	
	var server_checksum = player_checksums[local_player_id]
	var mismatch_players = []
	
	# Check for mismatches
func start_game() -> void:
	if not is_server:
		return
	
	# Make sure all players are ready
	for player_id in player_info.keys():
		if not player_info[player_id].ready:
			return
	
	# Set game started flag
	game_started = true
	
	# Reset timers
	server_tick_timer = 0
	checksum_timer = 0
	
	# Make sure all players have valid teams before starting
	# A player with team = -1 should be assigned to team 0 or 1
	for player_id in player_info.keys():
		if player_info[player_id].team < 0 or player_info[player_id].team > 1:
			# Assign to the team with fewer players
			var team0_count = 0
			var team1_count = 0
			
			for pid in player_info.keys():
				if player_info[pid].team == 0:
					team0_count += 1
				elif player_info[pid].team == 1:
					team1_count += 1
			
			# Explicit team assignment instead of ternary
			var new_team = 0
			if team1_count < team0_count:
				new_team = 1
			
			player_info[player_id].team = new_team
			
			# Notify the player of team change
			if player_id != local_player_id:
				rpc_id(player_id, "_update_team_assignment", new_team)
	
	# Notify all clients to start game
	rpc("_start_game_on_client", match_id)
	
	# Start game locally
	_start_game_locally()

# Modify _on_player_disconnected to handle erase() return values
func _on_player_disconnected(player_id: int) -> void:
	print("Player disconnected: ", player_id)
	
	emit_signal("client_disconnected", player_id)
	
	if is_server:
		if game_started and server_detachable:
			# Store player info for potential reconnection
			if player_info.has(player_id):
				disconnected_players[player_id] = {
					"info": player_info[player_id],
					"disconnect_time": OS.get_unix_time()
				}
				
				# Keep player in the list for a grace period
				player_info[player_id].disconnected = true
				
				# Broadcast updated player list
				emit_signal("player_list_changed", player_info)
				rpc("_update_player_list", player_info)
				
				# Start a timer to remove the player if they don't reconnect
				yield(get_tree().create_timer(RECONNECT_TIMEOUT), "timeout")
				
				if disconnected_players.has(player_id):
					# Player didn't reconnect within timeout
					var _disconnected_result = disconnected_players.erase(player_id)
					var _player_info_result = player_info.erase(player_id)
					
					# Broadcast updated player list
					emit_signal("player_list_changed", player_info)
					rpc("_update_player_list", player_info)
			else:
				var _player_info_result = player_info.erase(player_id)
				emit_signal("player_list_changed", player_info)
				
				if network:  # Make sure we're still connected
					rpc("_update_player_list", player_info)
					
# Handle reconnection of a player
func _handle_reconnection(player_id: int) -> void:
	if not is_server or not disconnected_players.has(player_id):
		return
	
	# Restore player info
	player_info[player_id] = disconnected_players[player_id].info
	
	# Remove from disconnected players
	var _removed = disconnected_players.erase(player_id)
	
	# Send current game state to reconnected player
	_send_game_state_to_player(player_id)
	
	# Broadcast updated player list
	emit_signal("player_list_changed", player_info)
	rpc("_update_player_list", player_info)
	
	print("Player reconnected: ", player_id)

func _on_connected_to_server() -> void:
	print("Connected to server")
	
	emit_signal("connection_succeeded")
	
	# Set our player ID
	local_player_id = get_tree().get_network_unique_id()
	
	# Send our player info to the server
	if player_info.has(0):  # We stored our info temporarily with ID 0
		var name = player_info[0].name
		player_info.erase(0)
		set_player_info(name, 0)  # Default to Team A

func _on_connection_failed() -> void:
	print("Connection failed")
	
	network = null
	get_tree().network_peer = null
	
	emit_signal("connection_failed")

func _on_server_disconnected() -> void:
	print("Server disconnected")
	
	emit_signal("network_error", "Lost connection to server")
	
	network = null
	get_tree().network_peer = null
	player_info.clear()
	is_server = false
	game_started = false
