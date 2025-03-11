extends GutTest

var network_manager = null

func before_each():
	network_manager = NetworkManager.new()
	add_child(network_manager)
	
	# Mock NetworkedMultiplayerENet
	network_manager.network = mock("NetworkedMultiplayerENet", self)

func after_each():
	network_manager.queue_free()
	network_manager = null

func test_initialization():
	assert_eq(network_manager.local_player_id, 0)
	assert_false(network_manager.is_server)
	assert_eq(network_manager.player_info.size(), 0)
	assert_false(network_manager.game_started)

func test_set_player_info():
	var test_player_name = "TestPlayer"
	var test_team = 0
	
	# Mock get_network_unique_id
	network_manager.local_player_id = 123
	
	# Set player info
	network_manager.set_player_info(test_player_name, test_team)
	
	# Check player info was set correctly
	assert_true(network_manager.player_info.has(123))
	assert_eq(network_manager.player_info[123].name, test_player_name)
	assert_eq(network_manager.player_info[123].team, test_team)
	assert_false(network_manager.player_info[123].ready)

func test_set_player_ready():
	# Mock get_network_unique_id
	network_manager.local_player_id = 123
	
	# Set player info first
	network_manager.set_player_info("TestPlayer", 0)
	
	# Initially not ready
	assert_false(network_manager.player_info[123].ready)
	
	# Set ready
	network_manager.set_player_ready(true)
	assert_true(network_manager.player_info[123].ready)
	
	# Set not ready
	network_manager.set_player_ready(false)
	assert_false(network_manager.player_info[123].ready)

func test_change_team():
	# Mock get_network_unique_id
	network_manager.local_player_id = 123
	
	# Set player info first
	network_manager.set_player_info("TestPlayer", 0)
	
	# Initially team 0
	assert_eq(network_manager.player_info[123].team, 0)
	
	# Change to team 1
	network_manager.change_team(1)
	assert_eq(network_manager.player_info[123].team, 1)
	
	# Change back to team 0
	network_manager.change_team(0)
	assert_eq(network_manager.player_info[123].team, 0)

func test_server_functions():
	# Test start_server function
	network_manager.network = null
	stub(NetworkedMultiplayerENet, "create_server").to_return(OK)
	
	var result = network_manager.start_server("Test Server", 6, 12345)
	assert_true(result)
	assert_true(network_manager.is_server)
	
	# Check server player was added correctly
	assert_true(network_manager.player_info.has(network_manager.local_player_id))
	assert_true(network_manager.player_info[network_manager.local_player_id].is_host)
	
	# Test failed server start
	network_manager.network = null
	stub(NetworkedMultiplayerENet, "create_server").to_return(ERR_CANT_CREATE)
	
	result = network_manager.start_server("Test Server", 6, 12345)
	assert_false(result)
	assert_null(network_manager.network)

func test_client_functions():
	# Test connect_to_server function
	network_manager.network = null
	stub(NetworkedMultiplayerENet, "create_client").to_return(OK)
	
	var result = network_manager.connect_to_server("127.0.0.1", 12345, "Test Client")
	assert_true(result)
	assert_false(network_manager.is_server)
	
	# Test failed connection
	network_manager.network = null
	stub(NetworkedMultiplayerENet, "create_client").to_return(ERR_CANT_CONNECT)
	
	result = network_manager.connect_to_server("127.0.0.1", 12345, "Test Client")
	assert_false(result)
	assert_null(network_manager.network)

func test_disconnect_function():
	# Setup
	network_manager.network = mock("NetworkedMultiplayerENet", self)
	network_manager.is_server = true
	network_manager.local_player_id = 123
	network_manager.player_info[123] = {"name": "Test", "team": 0, "ready": false}
	
	# Disconnect
	network_manager.disconnect_from_network()
	
	# Check state
	assert_null(network_manager.network)
	assert_false(network_manager.is_server)
	assert_eq(network_manager.local_player_id, 0)
	assert_eq(network_manager.player_info.size(), 0)
	assert_false(network_manager.game_started)

func test_game_state_checksum():
	# Mock game manager and its subsystems
	var mock_game_manager = mock("GameManager", self)
	var mock_grid_system = mock("GridSystem", self)
	var mock_building_manager = mock("BuildingManager", self)
	var mock_economy_manager = mock("EconomyManager", self)
	
	stub(mock_game_manager, "grid_system").to_return(mock_grid_system)
	stub(mock_game_manager, "building_manager").to_return(mock_building_manager)
	stub(mock_game_manager, "economy_manager").to_return(mock_economy_manager)
	
	stub(mock_grid_system, "grid_cells").to_return({
		Vector2(0, 0): {"occupied": true},
		Vector2(1, 1): {"occupied": false}
	})
	
	stub(mock_building_manager, "buildings").to_return({
		"building1": {"health": 100},
		"building2": {"health": 50}
	})
	
	stub(mock_economy_manager, "get_income").to_return(10)
	stub(mock_economy_manager, "get_resource").to_return(100)
	
	network_manager.game_manager = mock_game_manager
	
	# Calculate checksum
	var checksum = network_manager.calculate_game_state_checksum()
	
	# Can't predict exact value, but should be non-zero
	assert_true(checksum != 0)

func test_ping_system():
	var timestamp = OS.get_ticks_msec()
	var player_id = 123
	
	# Test _send_ping
	network_manager._send_ping(player_id)
	assert_true(network_manager.last_ping_time.has(player_id))
	
	# Simulate ping response
	network_manager.ping_values[player_id] = 50
	
	# Update should maintain the ping value
	network_manager._update_pings(0.5)
	assert_eq(network_manager.ping_values[player_id], 50)

func test_player_connection_handling():
	# Test player connected
	var player_id = 123
	
	# Setup as server
	network_manager.is_server = true
	
	# Simulate player connection
	network_manager._on_player_connected(player_id)
	
	# Check player was added
	assert_true(network_manager.player_info.has(player_id))
	
	# Test player disconnected
	network_manager._on_player_disconnected(player_id)
	
	# In detachable server mode, player should be marked as disconnected but not removed
	assert_true(network_manager.disconnected_players.has(player_id))