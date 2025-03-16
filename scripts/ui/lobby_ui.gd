# Lobby UI - Handles the multiplayer lobby user interface
# Path: scripts/ui/lobby_ui.gd
extends Control

# References to UI elements - Create Game tab
onready var create_game_name_edit = get_node("ModeTabContainer/Create Game/CreateGamePanel/SettingsContainer/GameNameContainer/GameNameEdit")
onready var create_player_name_edit = get_node("ModeTabContainer/Create Game/CreateGamePanel/SettingsContainer/PlayerNameContainer/PlayerNameEdit")
onready var create_port_edit = get_node("ModeTabContainer/Create Game/CreateGamePanel/SettingsContainer/PortContainer/PortEdit")
onready var max_players_options = get_node("ModeTabContainer/Create Game/CreateGamePanel/SettingsContainer/MaxPlayersContainer/MaxPlayersOptions")
onready var map_options = get_node("ModeTabContainer/Create Game/CreateGamePanel/SettingsContainer/MapContainer/MapOptions")
onready var debug_mode_checkbox = get_node("ModeTabContainer/Create Game/CreateGamePanel/DebugModeContainer/DebugModeCheckBox")
onready var create_button = get_node("ModeTabContainer/Create Game/CreateGamePanel/CreateButton")
onready var start_game_button = get_node("ModeTabContainer/Create Game/CreateGamePanel/StartGameButton")
onready var create_team_a_list = get_node("ModeTabContainer/Create Game/CreateGamePanel/PlayersPanel/TeamAList")
onready var create_team_b_list = get_node("ModeTabContainer/Create Game/CreateGamePanel/PlayersPanel/TeamBList")
onready var create_team_a_button = get_node("ModeTabContainer/Create Game/CreateGamePanel/PlayersPanel/TeamAButton")
onready var create_team_b_button = get_node("ModeTabContainer/Create Game/CreateGamePanel/PlayersPanel/TeamBButton")
onready var create_status_label = get_node("ModeTabContainer/Create Game/CreateGamePanel/StatusLabel")
onready var debug_info_label = get_node("ModeTabContainer/Create Game/CreateGamePanel/DebugInfoLabel")

# References to UI elements - Join Game tab
onready var join_player_name_edit = get_node("ModeTabContainer/Join Game/JoinGamePanel/SettingsContainer/PlayerNameContainer/PlayerNameEdit")
onready var join_ip_edit = get_node("ModeTabContainer/Join Game/JoinGamePanel/SettingsContainer/IPContainer/IPEdit")
onready var join_port_edit = get_node("ModeTabContainer/Join Game/JoinGamePanel/SettingsContainer/PortContainer/PortEdit")
onready var connect_button = get_node("ModeTabContainer/Join Game/JoinGamePanel/ConnectButton")
onready var join_team_a_list = get_node("ModeTabContainer/Join Game/JoinGamePanel/PlayersPanel/TeamAList")
onready var join_team_b_list = get_node("ModeTabContainer/Join Game/JoinGamePanel/PlayersPanel/TeamBList")
onready var join_team_a_button = get_node("ModeTabContainer/Join Game/JoinGamePanel/PlayersPanel/TeamAButton")
onready var join_team_b_button = get_node("ModeTabContainer/Join Game/JoinGamePanel/PlayersPanel/TeamBButton")
onready var join_status_label = get_node("ModeTabContainer/Join Game/JoinGamePanel/StatusLabel")
onready var ready_button = get_node("ModeTabContainer/Join Game/JoinGamePanel/ReadyButton")

# References to UI elements - LAN Games tab
onready var games_list = get_node("ModeTabContainer/LAN Games/LANGamesPanel/GamesList")
onready var refresh_button = get_node("ModeTabContainer/LAN Games/LANGamesPanel/RefreshButton")
onready var join_selected_button = get_node("ModeTabContainer/LAN Games/LANGamesPanel/JoinSelectedButton")

# References to dialogs
onready var connection_dialog = get_node("ConnectionDialog")
onready var error_dialog = get_node("ErrorDialog")

# References to common elements
onready var back_button = get_node("BackButton")
onready var network_manager = get_node("NetworkManager")
onready var tab_container = get_node("ModeTabContainer")

# UI state
var current_team: int = 0 # 0 = Team A, 1 = Team B
var is_ready: bool = false
var current_tab: int = 0

# Ready function
func _ready() -> void:
    # Add debug info label if it doesn't exist
    if not has_node("ModeTabContainer/Create Game/CreateGamePanel/DebugInfoLabel"):
        debug_info_label = Label.new()
        debug_info_label.name = "DebugInfoLabel"
        debug_info_label.rect_position = Vector2(20, 410)
        debug_info_label.rect_size = Vector2(480, 40)
        debug_info_label.align = Label.ALIGN_CENTER
        debug_info_label.add_color_override("font_color", Color(1, 0.5, 0, 1)) # Orange color
        debug_info_label.text = "Debug Mode: In this mode, you can start the game with just one player."
        debug_info_label.visible = false
        get_node("ModeTabContainer/Create Game/CreateGamePanel").add_child(debug_info_label)
    
    # Connect debug checkbox signal
    debug_mode_checkbox.connect("toggled", self, "_on_debug_mode_toggled")
    
    # Connect button signals
    create_button.connect("pressed", self, "_on_create_button_pressed")
    start_game_button.connect("pressed", self, "_on_start_game_button_pressed")
    create_team_a_button.connect("pressed", self, "_on_team_a_button_pressed")
    create_team_b_button.connect("pressed", self, "_on_team_b_button_pressed")
    
    connect_button.connect("pressed", self, "_on_connect_button_pressed")
    join_team_a_button.connect("pressed", self, "_on_team_a_button_pressed")
    join_team_b_button.connect("pressed", self, "_on_team_b_button_pressed")
    ready_button.connect("pressed", self, "_on_ready_button_pressed")
    
    refresh_button.connect("pressed", self, "_on_refresh_button_pressed")
    join_selected_button.connect("pressed", self, "_on_join_selected_button_pressed")
    
    back_button.connect("pressed", self, "_on_back_button_pressed")
    
    # Connect dialog signals
    connection_dialog.get_node("VBoxContainer/CancelButton").connect("pressed", self, "_on_connection_cancel_pressed")
    
    # Connect NetworkManager signals
    network_manager.connect("server_started", self, "_on_server_started")
    network_manager.connect("server_stopped", self, "_on_server_stopped")
    network_manager.connect("client_connected", self, "_on_client_connected")
    network_manager.connect("client_disconnected", self, "_on_client_disconnected")
    network_manager.connect("connection_failed", self, "_on_connection_failed")
    network_manager.connect("connection_succeeded", self, "_on_connection_succeeded")
    network_manager.connect("player_list_changed", self, "_on_player_list_changed")
    network_manager.connect("match_ready", self, "_on_match_ready")
    network_manager.connect("network_error", self, "_on_network_error")
    network_manager.connect("ping_updated", self, "_on_ping_updated")
    
    # Connect tab container signal
    tab_container.connect("tab_changed", self, "_on_tab_changed")
    
    # Set default player name
    var default_name = "Player" + str(randi() % 1000)
    create_player_name_edit.text = default_name
    join_player_name_edit.text = default_name
    
    # Initialize UI
    _update_ui()

# Handler for debug mode toggle
func _on_debug_mode_toggled(button_pressed: bool) -> void:
    if debug_info_label:
        debug_info_label.visible = button_pressed
    
    # Update UI to reflect whether Start Game button should be enabled
    if network_manager.is_server:
        update_player_lists(network_manager.player_info)

# Create a new game server
func create_game() -> void:
    var game_name = create_game_name_edit.text
    var player_name = create_player_name_edit.text
    var port = int(create_port_edit.text)

    # Validate input
    if game_name.empty() or player_name.empty():
        _show_error("Game name and player name cannot be empty.")
        return
    
    if port < 1024 or port > 65535:
        _show_error("Port must be between 1024 and 65535.")
        return
    
    # Get max players based on selection
    var max_players = 6
    match max_players_options.selected:
        0: max_players = 2
        1: max_players = 4
        2: max_players = 6
    
    # Set debug mode
    network_manager.debug_mode = debug_mode_checkbox.pressed
    
    # Try to start server
    var success = network_manager.start_server(game_name, port, max_players)
        
    if success:
        # Set player info AFTER server creation
        network_manager.set_player_info(player_name, current_team)
        
        create_status_label.text = "Server started. Waiting for players..."
        if debug_mode_checkbox.pressed:
            create_status_label.text += "\nDEBUG MODE: You can start with just one player."
        
        _update_ui()
    else:
        _show_error("Failed to start server. Port might be in use.")

# Connect to a game server
func connect_to_game() -> void:
    var player_name = join_player_name_edit.text
    var ip = join_ip_edit.text
    var port = int(join_port_edit.text)
    
    # Validate input
    if player_name.empty() or ip.empty():
        _show_error("Player name and server IP cannot be empty.")
        return
    
    if port < 1024 or port > 65535:
        _show_error("Port must be between 1024 and 65535.")
        return
    
    # Show connection dialog
    connection_dialog.popup_centered()
    connection_dialog.get_node("VBoxContainer/StatusLabel").text = "Connecting to " + ip + ":" + str(port) + "..."
    connection_dialog.get_node("VBoxContainer/ProgressBar").value = 0.5
    
    # Try to connect
    var success = network_manager.connect_to_server(ip, port, player_name)
    
    if not success:
        connection_dialog.hide()
        _show_error("Failed to connect to server. Check IP and port.")

# Refresh the LAN games list
func refresh_lan_games() -> void:
    # Clear current list
    games_list.clear()
    
    # TODO: Implement LAN discovery using UDP broadcast
    # For now, just display a message
    games_list.add_item("LAN discovery not implemented yet")
    
    join_selected_button.disabled = true

# Join the selected LAN game
func join_selected_game() -> void:
    var selected_indices = games_list.get_selected_items()
    if selected_indices.empty():
        return
    
    # TODO: Implement joining selected game
    # For now, just show a message
    _show_error("LAN game joining not implemented yet")

# Set player ready status
func set_ready(ready: bool) -> void:
    is_ready = ready
    network_manager.set_player_ready(network_manager.local_player_id, is_ready)
    
    if ready:
        ready_button.text = "Not Ready"
        join_status_label.text = "Ready! Waiting for other players..."
    else:
        ready_button.text = "Ready"
        join_status_label.text = "Not ready."

# Start the game (host only)
func start_game() -> void:
    print("LobbyUI: Starting game")
    print("Network manager debug mode: ", network_manager.debug_mode)
    print("Network manager is_server: ", network_manager.is_server)
    print("Network manager game_phase: ", network_manager.game_phase)
    
    # Try to ensure conditions are correct
    if network_manager.debug_mode:
        network_manager.game_phase = network_manager.GamePhase.PREGAME
    
    network_manager.start_match()

# Update player lists based on current player info
func update_player_lists(player_info: Dictionary) -> void:
    # Clear current lists
    create_team_a_list.clear()
    create_team_b_list.clear()
    join_team_a_list.clear()
    join_team_b_list.clear()
    
    var team_a_count = 0
    var team_b_count = 0
    
    # Add players to appropriate lists
    for player_id in player_info.keys():
        var data = player_info[player_id]
        var player_text = data.name
        
        # Add host indicator
        if data.has("is_host") and data.is_host:
            player_text += " (Host)"
        
        # Add ready indicator
        if data.has("ready") and data.ready:
            player_text += " ✓"
        
        # Add ping if available
        if data.has("ping"):
            player_text += " (" + str(data.ping) + "ms)"
        
        # Add to appropriate team list
        if data.has("team") and data.team == 1:
            create_team_b_list.add_item(player_text)
            join_team_b_list.add_item(player_text)
            team_b_count += 1
        else:
            create_team_a_list.add_item(player_text)
            join_team_a_list.add_item(player_text)
            team_a_count += 1
    
    # Update start game button based on readiness
    var all_ready = true
    for player_id in player_info.keys():
        if not player_info[player_id].has("ready") or not player_info[player_id].ready:
            all_ready = false
            break
    
    var is_host = network_manager.is_server
    var debug_mode = debug_mode_checkbox.pressed
    
    # In debug mode, we don't require players on both teams
    var has_players = (team_a_count > 0 or team_b_count > 0) if debug_mode else (team_a_count > 0 and team_b_count > 0)
    
    # Update start button state
    start_game_button.disabled = !(is_host and all_ready and has_players)
    
    # Update status message for debugging
    if is_host and debug_mode and start_game_button.disabled:
        if !all_ready:
            create_status_label.text = "All players must be ready to start the game."
        elif !has_players:
            create_status_label.text = "You need at least one player to start the game."

# Update UI state based on network status
func _update_ui() -> void:
    var is_connected = network_manager.network != null
    var _is_host = network_manager.is_server


    # Update Create Game tab
    create_game_name_edit.editable = !is_connected
    create_player_name_edit.editable = !is_connected
    create_port_edit.editable = !is_connected
    max_players_options.disabled = is_connected
    map_options.disabled = is_connected
    debug_mode_checkbox.disabled = is_connected
    create_button.disabled = is_connected
    
    # Update Join Game tab
    join_player_name_edit.editable = !is_connected
    join_ip_edit.editable = !is_connected
    join_port_edit.editable = !is_connected
    connect_button.disabled = is_connected
    join_team_a_button.disabled = !is_connected
    join_team_b_button.disabled = !is_connected
    ready_button.disabled = !is_connected
    
    # Update team buttons
    if is_connected:
        # Update team buttons based on current team
        create_team_a_button.text = "Leave Team A" if current_team == 0 else "Join Team A"
        create_team_b_button.text = "Leave Team B" if current_team == 1 else "Join Team B"
        join_team_a_button.text = "Leave Team A" if current_team == 0 else "Join Team A"
        join_team_b_button.text = "Leave Team B" if current_team == 1 else "Join Team B"
        
        # Ready button
        ready_button.text = "Not Ready" if is_ready else "Ready"
    else:
        # Reset team buttons
        create_team_a_button.text = "Join Team A"
        create_team_b_button.text = "Join Team B"
        join_team_a_button.text = "Join Team A"
        join_team_b_button.text = "Join Team B"
        ready_button.text = "Ready"

# Show error dialog with custom message
func _show_error(message: String) -> void:
    error_dialog.get_node("MessageLabel").text = message
    error_dialog.popup_centered()

# Signal handlers
func _on_create_button_pressed() -> void:
    create_game()

func _on_start_game_button_pressed() -> void:
    start_game()

func _on_connect_button_pressed() -> void:
    connect_to_game()

func _on_team_a_button_pressed() -> void:
    if current_team == 0:
        current_team = -1 # No team
    else:
        current_team = 0 # Team A
    
    network_manager.change_team(current_team)
    _update_ui()

func _on_team_b_button_pressed() -> void:
    if current_team == 1:
        current_team = -1 # No team
    else:
        current_team = 1 # Team B
    
    network_manager.change_team(current_team)
    _update_ui()

func _on_ready_button_pressed() -> void:
    set_ready(!is_ready)

func _on_refresh_button_pressed() -> void:
    refresh_lan_games()

func _on_join_selected_button_pressed() -> void:
    join_selected_game()

func _on_back_button_pressed() -> void:
    # If connected, ask about disconnecting
    if network_manager.network != null:
        # TODO: Add confirmation dialog
        network_manager.disconnect_from_network()
    
    # Return to main menu
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager and game_manager.has_method("change_scene"):
        game_manager.change_scene("res://scenes/lobby/lobby.tscn")
    else:
        # Fallback if not available
        get_tree().change_scene("res://scenes/lobby/lobby.tscn")


func _on_connection_cancel_pressed() -> void:
    connection_dialog.hide()
    
    # Cancel connection if in progress
    if network_manager.network != null and !network_manager.is_server:
        network_manager.disconnect_from_network()

func _on_tab_changed(tab: int) -> void:
    current_tab = tab
    
    # Update appropriate status label based on tab
    var status_label
    match tab:
        0: # Create Game
            status_label = create_status_label
        1: # Join Game
            status_label = join_status_label
    
    # Clear status text
    if status_label:
        status_label.text = ""

# Network signal handlers
func _on_server_started() -> void:
    create_status_label.text = "Server started. Waiting for players..."
    _update_ui()

func _on_server_stopped() -> void:
    create_status_label.text = "Server stopped."
    join_status_label.text = ""
    
    # Reset UI
    _update_ui()
    is_ready = false
    
    # Clear player lists
    create_team_a_list.clear()
    create_team_b_list.clear()
    join_team_a_list.clear()
    join_team_b_list.clear()

func _on_client_connected(player_id: int) -> void:
    if network_manager.is_server:
        create_status_label.text = "Player connected: " + str(player_id)

func _on_client_disconnected(player_id: int) -> void:
    if network_manager.is_server:
        create_status_label.text = "Player disconnected: " + str(player_id)

func _on_connection_failed() -> void:
    connection_dialog.hide()
    _show_error("Failed to connect to server. Server might be offline or unreachable.")
    
    # Reset UI
    _update_ui()

func _on_connection_succeeded() -> void:
    connection_dialog.hide()
    join_status_label.text = "Connected to server!"
    
    # Update UI
    _update_ui()

func _on_player_list_changed(player_info: Dictionary) -> void:
    update_player_lists(player_info)

func _on_match_ready() -> void:
    if network_manager.is_server:
        create_status_label.text = "All players ready! You can start the game."
        start_game_button.disabled = false

func _on_network_error(error_message: String) -> void:
    connection_dialog.hide()
    _show_error(error_message)

func _on_ping_updated(_player_id: int, _ping: int) -> void:
    # Update player lists to show updated ping
    if network_manager.player_info.size() > 0:
        update_player_lists(network_manager.player_info)
