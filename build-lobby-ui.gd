# build_complete_lobby.gd
# Run with: godot -s build_complete_lobby.gd

extends SceneTree

func _init():
    # Create the complete lobby scene with all elements
    var lobby_scene = create_lobby_scene()
    
    # Save the scene
    var packed_scene = PackedScene.new()
    packed_scene.pack(lobby_scene)
    
    var save_result = ResourceSaver.save("res://scenes/lobby/lobby.tscn", packed_scene)
    print("Scene saved with result: " + str(save_result))
    
    quit()

func create_lobby_scene():
    # Create the root node
    var lobby = Control.new()
    lobby.name = "Lobby"
    
    # Add the NetworkManager
    var network_manager = Node.new()
    network_manager.name = "NetworkManager"
    network_manager.set_script(load("res://scripts/networking/network_manager.gd"))
    lobby.add_child(network_manager)
    network_manager.owner = lobby
    
    # Add background
    var background = ColorRect.new()
    background.name = "Background"
    background.anchor_right = 1.0
    background.anchor_bottom = 1.0
    background.color = Color(0.121569, 0.145098, 0.188235, 1)
    lobby.add_child(background)
    background.owner = lobby
    
    # Add title label
    var title_label = Label.new()
    title_label.name = "TitleLabel"
    title_label.anchor_left = 0.5
    title_label.anchor_right = 0.5
    title_label.margin_left = -200
    title_label.margin_top = 20
    title_label.margin_right = 200
    title_label.margin_bottom = 60
    title_label.text = "Castle Fight Lobby"
    title_label.align = Label.ALIGN_CENTER
    title_label.valign = Label.VALIGN_CENTER
    title_label.uppercase = true
    lobby.add_child(title_label)
    title_label.owner = lobby
    
    # Add Tab Container
    var tab_container = TabContainer.new()
    tab_container.name = "ModeTabContainer"
    tab_container.anchor_left = 0.5
    tab_container.anchor_top = 0.5
    tab_container.anchor_right = 0.5
    tab_container.anchor_bottom = 0.5
    tab_container.margin_left = -500
    tab_container.margin_top = -300
    tab_container.margin_right = 500
    tab_container.margin_bottom = 300
    lobby.add_child(tab_container)
    tab_container.owner = lobby
    
    # Add the three tabs
    add_create_game_tab(tab_container, lobby)
    add_join_game_tab(tab_container, lobby)
    add_lan_games_tab(tab_container, lobby)
    
    # Add back button
    var back_button = Button.new()
    back_button.name = "BackButton"
    back_button.margin_left = 20
    back_button.margin_top = 680
    back_button.margin_right = 120
    back_button.margin_bottom = 710
    back_button.text = "Back"
    lobby.add_child(back_button)
    back_button.owner = lobby
    
    # Add dialogs
    add_connection_dialog(lobby)
    add_error_dialog(lobby)
    
    # Set the script
    var script = load("res://scripts/ui/lobby_ui.gd")
    if script:
        lobby.set_script(script)
    
    return lobby

func add_create_game_tab(parent, owner_node):
    var tab = Tabs.new()
    tab.name = "Create Game"
    parent.add_child(tab)
    tab.owner = owner_node
    
    var panel = Panel.new()
    panel.name = "CreateGamePanel"
    panel.anchor_right = 1.0
    panel.anchor_bottom = 1.0
    tab.add_child(panel)
    panel.owner = owner_node
    
    # Game Settings Label
    var settings_label = Label.new()
    settings_label.name = "GameSettingsLabel"
    settings_label.margin_left = 20
    settings_label.margin_top = 20
    settings_label.margin_right = 480
    settings_label.margin_bottom = 50
    settings_label.text = "Game Settings"
    settings_label.align = Label.ALIGN_CENTER
    panel.add_child(settings_label)
    settings_label.owner = owner_node
    
    # Settings Container
    var settings_container = VBoxContainer.new()
    settings_container.name = "SettingsContainer"
    settings_container.margin_left = 20
    settings_container.margin_top = 60
    settings_container.margin_right = 480
    settings_container.margin_bottom = 400
    panel.add_child(settings_container)
    settings_container.owner = owner_node
    
    # Game Name row
    var game_name_container = HBoxContainer.new()
    game_name_container.name = "GameNameContainer"
    settings_container.add_child(game_name_container)
    game_name_container.owner = owner_node
    
    var game_name_label = Label.new()
    game_name_label.rect_min_size = Vector2(150, 0)
    game_name_label.text = "Game Name:"
    game_name_container.add_child(game_name_label)
    game_name_label.owner = owner_node
    
    var game_name_edit = LineEdit.new()
    game_name_edit.name = "GameNameEdit"
    game_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    game_name_edit.text = "Castle Fight Game"
    game_name_container.add_child(game_name_edit)
    game_name_edit.owner = owner_node
    
    # Player Name row
    var player_name_container = HBoxContainer.new()
    player_name_container.name = "PlayerNameContainer"
    settings_container.add_child(player_name_container)
    player_name_container.owner = owner_node
    
    var player_name_label = Label.new()
    player_name_label.rect_min_size = Vector2(150, 0)
    player_name_label.text = "Your Name:"
    player_name_container.add_child(player_name_label)
    player_name_label.owner = owner_node
    
    var player_name_edit = LineEdit.new()
    player_name_edit.name = "PlayerNameEdit"
    player_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    player_name_edit.text = "Player"
    player_name_container.add_child(player_name_edit)
    player_name_edit.owner = owner_node
    
    # Port row
    var port_container = HBoxContainer.new()
    port_container.name = "PortContainer"
    settings_container.add_child(port_container)
    port_container.owner = owner_node
    
    var port_label = Label.new()
    port_label.rect_min_size = Vector2(150, 0)
    port_label.text = "Port:"
    port_container.add_child(port_label)
    port_label.owner = owner_node
    
    var port_edit = LineEdit.new()
    port_edit.name = "PortEdit"
    port_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    port_edit.text = "27015"
    port_container.add_child(port_edit)
    port_edit.owner = owner_node
    
    # Max Players row
    var max_players_container = HBoxContainer.new()
    max_players_container.name = "MaxPlayersContainer"
    settings_container.add_child(max_players_container)
    max_players_container.owner = owner_node
    
    var max_players_label = Label.new()
    max_players_label.rect_min_size = Vector2(150, 0)
    max_players_label.text = "Max Players:"
    max_players_container.add_child(max_players_label)
    max_players_label.owner = owner_node
    
    var max_players_options = OptionButton.new()
    max_players_options.name = "MaxPlayersOptions"
    max_players_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    max_players_options.add_item("2 Players (1v1)")
    max_players_options.add_item("4 Players (2v2)")
    max_players_options.add_item("6 Players (3v3)")
    max_players_options.select(2)  # Default to 6 players
    max_players_container.add_child(max_players_options)
    max_players_options.owner = owner_node
    
    # Map row
    var map_container = HBoxContainer.new()
    map_container.name = "MapContainer"
    settings_container.add_child(map_container)
    map_container.owner = owner_node
    
    var map_label = Label.new()
    map_label.rect_min_size = Vector2(150, 0)
    map_label.text = "Map:"
    map_container.add_child(map_label)
    map_label.owner = owner_node
    
    var map_options = OptionButton.new()
    map_options.name = "MapOptions"
    map_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_options.add_item("Castle Fight Classic")
    map_options.add_item("Forest Warfare")
    map_options.add_item("Desert Siege")
    map_options.select(0)  # Default to Castle Fight Classic
    map_container.add_child(map_options)
    map_options.owner = owner_node
    
    # Players section
    var players_label = Label.new()
    players_label.name = "PlayersLabel"
    players_label.margin_left = 520
    players_label.margin_top = 20
    players_label.margin_right = 980
    players_label.margin_bottom = 50
    players_label.text = "Players"
    players_label.align = Label.ALIGN_CENTER
    panel.add_child(players_label)
    players_label.owner = owner_node
    
    var players_panel = Panel.new()
    players_panel.name = "PlayersPanel"
    players_panel.margin_left = 520
    players_panel.margin_top = 60
    players_panel.margin_right = 980
    players_panel.margin_bottom = 400
    panel.add_child(players_panel)
    players_panel.owner = owner_node
    
    # Team A section
    var team_a_label = Label.new()
    team_a_label.name = "TeamALabel"
    team_a_label.margin_left = 10
    team_a_label.margin_top = 10
    team_a_label.margin_right = 220
    team_a_label.margin_bottom = 30
    team_a_label.add_color_override("font_color", Color(0, 0.58, 1))
    team_a_label.text = "Team A (Blue)"
    team_a_label.align = Label.ALIGN_CENTER
    players_panel.add_child(team_a_label)
    team_a_label.owner = owner_node
    
    var team_a_list = ItemList.new()
    team_a_list.name = "TeamAList"
    team_a_list.margin_left = 10
    team_a_list.margin_top = 40
    team_a_list.margin_right = 220
    team_a_list.margin_bottom = 290
    players_panel.add_child(team_a_list)
    team_a_list.owner = owner_node
    
    # Team B section
    var team_b_label = Label.new()
    team_b_label.name = "TeamBLabel"
    team_b_label.margin_left = 230
    team_b_label.margin_top = 10
    team_b_label.margin_right = 440
    team_b_label.margin_bottom = 30
    team_b_label.add_color_override("font_color", Color(1, 0, 0))
    team_b_label.text = "Team B (Red)"
    team_b_label.align = Label.ALIGN_CENTER
    players_panel.add_child(team_b_label)
    team_b_label.owner = owner_node
    
    var team_b_list = ItemList.new()
    team_b_list.name = "TeamBList"
    team_b_list.margin_left = 230
    team_b_list.margin_top = 40
    team_b_list.margin_right = 440
    team_b_list.margin_bottom = 290
    players_panel.add_child(team_b_list)
    team_b_list.owner = owner_node
    
    # Team buttons
    var team_a_button = Button.new()
    team_a_button.name = "TeamAButton"
    team_a_button.margin_left = 50
    team_a_button.margin_top = 300
    team_a_button.margin_right = 180
    team_a_button.margin_bottom = 330
    team_a_button.text = "Join Team A"
    players_panel.add_child(team_a_button)
    team_a_button.owner = owner_node
    
    var team_b_button = Button.new()
    team_b_button.name = "TeamBButton"
    team_b_button.margin_left = 270
    team_b_button.margin_top = 300
    team_b_button.margin_right = 400
    team_b_button.margin_bottom = 330
    team_b_button.text = "Join Team B"
    players_panel.add_child(team_b_button)
    team_b_button.owner = owner_node
    
    # Create and Start Game buttons
    var create_button = Button.new()
    create_button.name = "CreateButton"
    create_button.margin_left = 155
    create_button.margin_top = 450
    create_button.margin_right = 345
    create_button.margin_bottom = 490
    create_button.text = "Create Game"
    panel.add_child(create_button)
    create_button.owner = owner_node
    
    var start_game_button = Button.new()
    start_game_button.name = "StartGameButton"
    start_game_button.margin_left = 655
    start_game_button.margin_top = 450
    start_game_button.margin_right = 845
    start_game_button.margin_bottom = 490
    start_game_button.text = "Start Game"
    start_game_button.disabled = true
    panel.add_child(start_game_button)
    start_game_button.owner = owner_node
    
    # Status label
    var status_label = Label.new()
    status_label.name = "StatusLabel"
    status_label.margin_left = 155
    status_label.margin_top = 500
    status_label.margin_right = 845
    status_label.margin_bottom = 520
    status_label.align = Label.ALIGN_CENTER
    panel.add_child(status_label)
    status_label.owner = owner_node

func add_join_game_tab(parent, owner_node):
    var tab = Tabs.new()
    tab.name = "Join Game"
    parent.add_child(tab)
    tab.owner = owner_node
    
    var panel = Panel.new()
    panel.name = "JoinGamePanel"
    panel.anchor_right = 1.0
    panel.anchor_bottom = 1.0
    tab.add_child(panel)
    panel.owner = owner_node
    
    # Connection Settings Label
    var settings_label = Label.new()
    settings_label.name = "ConnectionSettingsLabel"
    settings_label.margin_left = 20
    settings_label.margin_top = 20
    settings_label.margin_right = 480
    settings_label.margin_bottom = 50
    settings_label.text = "Connection Settings"
    settings_label.align = Label.ALIGN_CENTER
    panel.add_child(settings_label)
    settings_label.owner = owner_node
    
    # Settings Container
    var settings_container = VBoxContainer.new()
    settings_container.name = "SettingsContainer"
    settings_container.margin_left = 20
    settings_container.margin_top = 60
    settings_container.margin_right = 480
    settings_container.margin_bottom = 400
    panel.add_child(settings_container)
    settings_container.owner = owner_node
    
    # Player Name row
    var player_name_container = HBoxContainer.new()
    player_name_container.name = "PlayerNameContainer"
    settings_container.add_child(player_name_container)
    player_name_container.owner = owner_node
    
    var player_name_label = Label.new()
    player_name_label.rect_min_size = Vector2(150, 0)
    player_name_label.text = "Your Name:"
    player_name_container.add_child(player_name_label)
    player_name_label.owner = owner_node
    
    var player_name_edit = LineEdit.new()
    player_name_edit.name = "PlayerNameEdit"
    player_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    player_name_edit.text = "Player"
    player_name_container.add_child(player_name_edit)
    player_name_edit.owner = owner_node
    
    # IP Address row
    var ip_container = HBoxContainer.new()
    ip_container.name = "IPContainer"
    settings_container.add_child(ip_container)
    ip_container.owner = owner_node
    
    var ip_label = Label.new()
    ip_label.rect_min_size = Vector2(150, 0)
    ip_label.text = "Server IP:"
    ip_container.add_child(ip_label)
    ip_label.owner = owner_node
    
    var ip_edit = LineEdit.new()
    ip_edit.name = "IPEdit"
    ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ip_edit.text = "127.0.0.1"
    ip_container.add_child(ip_edit)
    ip_edit.owner = owner_node
    
    # Port row
    var port_container = HBoxContainer.new()
    port_container.name = "PortContainer"
    settings_container.add_child(port_container)
    port_container.owner = owner_node
    
    var port_label = Label.new()
    port_label.rect_min_size = Vector2(150, 0)
    port_label.text = "Port:"
    port_container.add_child(port_label)
    port_label.owner = owner_node
    
    var port_edit = LineEdit.new()
    port_edit.name = "PortEdit"
    port_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    port_edit.text = "27015"
    port_container.add_child(port_edit)
    port_edit.owner = owner_node
    
    # Connect button
    var connect_button = Button.new()
    connect_button.name = "ConnectButton"
    connect_button.margin_left = 155
    connect_button.margin_top = 450
    connect_button.margin_right = 345
    connect_button.margin_bottom = 490
    connect_button.text = "Connect to Server"
    panel.add_child(connect_button)
    connect_button.owner = owner_node
    
    # Players section (similar to Create Game tab)
    var players_label = Label.new()
    players_label.name = "PlayersLabel"
    players_label.margin_left = 520
    players_label.margin_top = 20
    players_label.margin_right = 980
    players_label.margin_bottom = 50
    players_label.text = "Players"
    players_label.align = Label.ALIGN_CENTER
    panel.add_child(players_label)
    players_label.owner = owner_node
    
    var players_panel = Panel.new()
    players_panel.name = "PlayersPanel"
    players_panel.margin_left = 520
    players_panel.margin_top = 60
    players_panel.margin_right = 980
    players_panel.margin_bottom = 400
    panel.add_child(players_panel)
    players_panel.owner = owner_node
    
    # Team A section
    var team_a_label = Label.new()
    team_a_label.name = "TeamALabel"
    team_a_label.margin_left = 10
    team_a_label.margin_top = 10
    team_a_label.margin_right = 220
    team_a_label.margin_bottom = 30
    team_a_label.add_color_override("font_color", Color(0, 0.58, 1))
    team_a_label.text = "Team A (Blue)"
    team_a_label.align = Label.ALIGN_CENTER
    players_panel.add_child(team_a_label)
    team_a_label.owner = owner_node
    
    var team_a_list = ItemList.new()
    team_a_list.name = "TeamAList"
    team_a_list.margin_left = 10
    team_a_list.margin_top = 40
    team_a_list.margin_right = 220
    team_a_list.margin_bottom = 290
    players_panel.add_child(team_a_list)
    team_a_list.owner = owner_node
    
    # Team B section
    var team_b_label = Label.new()
    team_b_label.name = "TeamBLabel"
    team_b_label.margin_left = 230
    team_b_label.margin_top = 10
    team_b_label.margin_right = 440
    team_b_label.margin_bottom = 30
    team_b_label.add_color_override("font_color", Color(1, 0, 0))
    team_b_label.text = "Team B (Red)"
    team_b_label.align = Label.ALIGN_CENTER
    players_panel.add_child(team_b_label)
    team_b_label.owner = owner_node
    
    var team_b_list = ItemList.new()
    team_b_list.name = "TeamBList"
    team_b_list.margin_left = 230
    team_b_list.margin_top = 40
    team_b_list.margin_right = 440
    team_b_list.margin_bottom = 290
    players_panel.add_child(team_b_list)
    team_b_list.owner = owner_node
    
    # Team buttons (initially disabled)
    var team_a_button = Button.new()
    team_a_button.name = "TeamAButton"
    team_a_button.margin_left = 50
    team_a_button.margin_top = 300
    team_a_button.margin_right = 180
    team_a_button.margin_bottom = 330
    team_a_button.text = "Join Team A"
    team_a_button.disabled = true
    players_panel.add_child(team_a_button)
    team_a_button.owner = owner_node
    
    var team_b_button = Button.new()
    team_b_button.name = "TeamBButton"
    team_b_button.margin_left = 270
    team_b_button.margin_top = 300
    team_b_button.margin_right = 400
    team_b_button.margin_bottom = 330
    team_b_button.text = "Join Team B"
    team_b_button.disabled = true
    players_panel.add_child(team_b_button)
    team_b_button.owner = owner_node
    
    # Status label
    var status_label = Label.new()
    status_label.name = "StatusLabel"
    status_label.margin_left = 155
    status_label.margin_top = 500
    status_label.margin_right = 845
    status_label.margin_bottom = 520
    status_label.align = Label.ALIGN_CENTER
    panel.add_child(status_label)
    status_label.owner = owner_node
    
    # Ready button
    var ready_button = Button.new()
    ready_button.name = "ReadyButton"
    ready_button.margin_left = 655
    ready_button.margin_top = 450
    ready_button.margin_right = 845
    ready_button.margin_bottom = 490
    ready_button.text = "Ready"
    ready_button.disabled = true
    panel.add_child(ready_button)
    ready_button.owner = owner_node

func add_lan_games_tab(parent, owner_node):
    var tab = Tabs.new()
    tab.name = "LAN Games"
    parent.add_child(tab)
    tab.owner = owner_node
    
    var panel = Panel.new()
    panel.name = "LANGamesPanel"
    panel.anchor_right = 1.0
    panel.anchor_bottom = 1.0
    tab.add_child(panel)
    panel.owner = owner_node
    
    # Available Games Label
    var games_label = Label.new()
    games_label.name = "AvailableGamesLabel"
    games_label.margin_left = 20
    games_label.margin_top = 20
    games_label.margin_right = 980
    games_label.margin_bottom = 50
    games_label.text = "Available LAN Games"
    games_label.align = Label.ALIGN_CENTER
    panel.add_child(games_label)
    games_label.owner = owner_node
    
    # Games List
    var games_list = ItemList.new()
    games_list.name = "GamesList"
    games_list.margin_left = 20
    games_list.margin_top = 60
    games_list.margin_right = 980
    games_list.margin_bottom = 400
    panel.add_child(games_list)
    games_list.owner = owner_node
    
    # Refresh button
    var refresh_button = Button.new()
    refresh_button.name = "RefreshButton"
    refresh_button.margin_left = 400
    refresh_button.margin_top = 420
    refresh_button.margin_right = 600
    refresh_button.margin_bottom = 460
    refresh_button.text = "Refresh Games List"
    panel.add_child(refresh_button)
    refresh_button.owner = owner_node
    
    # Join Selected button
    var join_selected_button = Button.new()
    join_selected_button.name = "JoinSelectedButton"
    join_selected_button.margin_left = 400
    join_selected_button.margin_top = 480
    join_selected_button.margin_right = 600
    join_selected_button.margin_bottom = 520
    join_selected_button.text = "Join Selected Game"
    join_selected_button.disabled = true
    panel.add_child(join_selected_button)
    join_selected_button.owner = owner_node

func add_connection_dialog(owner_node):
    var dialog = WindowDialog.new()
    dialog.name = "ConnectionDialog"
    dialog.window_title = "Connecting..."
    dialog.anchor_left = 0.5
    dialog.anchor_top = 0.5
    dialog.anchor_right = 0.5
    dialog.anchor_bottom = 0.5
    dialog.margin_left = -200
    dialog.margin_top = -100
    dialog.margin_right = 200
    dialog.margin_bottom = 100
    owner_node.add_child(dialog)
    dialog.owner = owner_node
    
    var vbox = VBoxContainer.new()
    vbox.name = "VBoxContainer"
    vbox.anchor_right = 1.0
    vbox.anchor_bottom = 1.0
    vbox.margin_left = 20
    vbox.margin_top = 20
    vbox.margin_right = -20
    vbox.margin_bottom = -20
    vbox.alignment = BoxContainer.ALIGN_CENTER
    dialog.add_child(vbox)
    vbox.owner = owner_node
    
    var status_label = Label.new()
    status_label.name = "StatusLabel"
    status_label.text = "Connecting to server..."
    status_label.align = Label.ALIGN_CENTER
    vbox.add_child(status_label)
    status_label.owner = owner_node
    
    var progress_bar = ProgressBar.new()
    progress_bar.name = "ProgressBar"
    progress_bar.max_value = 1.0
    progress_bar.step = 0.05
    progress_bar.value = 0.5
    vbox.add_child(progress_bar)
    progress_bar.owner = owner_node
    
    var cancel_button = Button.new()
    cancel_button.name = "CancelButton"
    cancel_button.text = "Cancel"
    vbox.add_child(cancel_button)
    cancel_button.owner = owner_node

func add_error_dialog(owner_node):
    var dialog = AcceptDialog.new()
    dialog.name = "ErrorDialog"
    dialog.window_title = "Error"
    dialog.anchor_left = 0.5
    dialog.anchor_top = 0.5
    dialog.anchor_right = 0.5
    dialog.anchor_bottom = 0.5
    dialog.margin_left = -200
    dialog.margin_top = -100
    dialog.margin_right = 200
    dialog.margin_bottom = 100
    owner_node.add_child(dialog)
    dialog.owner = owner_node
    
    var message_label = Label.new()
    message_label.name = "MessageLabel"
    message_label.margin_left = 8
    message_label.margin_top = 8
    message_label.margin_right = 392
    message_label.margin_bottom = 164
    message_label.size_flags_vertical = 0
    message_label.text = "An error occurred while connecting to the server."
    message_label.align = Label.ALIGN_CENTER
    message_label.valign = Label.VALIGN_CENTER
    message_label.autowrap = true
    dialog.add_child(message_label)
    message_label.owner = owner_node
