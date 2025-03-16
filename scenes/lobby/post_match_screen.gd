# Post Match Screen - Shows match results and statistics
# Path: res://scenes/lobby/post_match_screen.gd
extends Control

# References to UI elements
onready var win_message = $VBoxContainer/WinMessage
onready var match_stats = $VBoxContainer/StatsPanel/VBoxContainer/MatchStats
onready var team_a_stats = $VBoxContainer/StatsPanel/VBoxContainer/TeamAStats
onready var team_b_stats = $VBoxContainer/StatsPanel/VBoxContainer/TeamBStats
onready var continue_button = $VBoxContainer/ContinueButton

# Network manager reference
var network_manager

# Ready function
func _ready():
    # Get network manager reference
    network_manager = get_node_or_null("/root/NetworkManager")
    if not network_manager:
        network_manager = get_node_or_null("/root/GameManager/NetworkManager")
    
    # Connect button signals
    continue_button.connect("pressed", self, "_on_continue_button_pressed")
    
    # Display match results
    _display_match_results()

# Display match results
func _display_match_results():
    if not network_manager:
        win_message.text = "Match Results Unavailable"
        return
    
    # Display winner message
    var winner = network_manager.match_winner
    if winner == 0:
        win_message.text = "Team A Wins!"
        win_message.add_color_override("font_color", Color(0, 0, 1)) # Blue
    elif winner == 1:
        win_message.text = "Team B Wins!"
        win_message.add_color_override("font_color", Color(1, 0, 0)) # Red
    else:
        win_message.text = "Match Ended"
    
    # Display match statistics
    var duration_mins = int(network_manager.match_duration / 60)
    var duration_secs = int(network_manager.match_duration) % 60
    match_stats.text = "Match Duration: %02d:%02d\nReason: %s" % [
        duration_mins,
        duration_secs,
        network_manager.match_end_reason
    ]
    
    # Get game manager for more detailed stats
    var game_manager = get_node_or_null("/root/GameManager")
    if not game_manager:
        return
    
    # Get economy manager for resource stats
    var economy_manager = get_node_or_null("/root/GameManager/EconomyManager")
    
    # Team A stats
    var team_a_text = "Team A Statistics:\n"
    if economy_manager:
        team_a_text += "Final Gold: %d\n" % economy_manager.get_resource(0, 0)
        team_a_text += "Final Income: %.1f gold/tick\n" % economy_manager.get_income(0)
    
    if game_manager.building_manager:
        var team_a_buildings = game_manager.building_manager.get_team_buildings(0)
        team_a_text += "Buildings Remaining: %d\n" % team_a_buildings.size()
    
    team_a_stats.text = team_a_text
    
    # Team B stats
    var team_b_text = "Team B Statistics:\n"
    if economy_manager:
        team_b_text += "Final Gold: %d\n" % economy_manager.get_resource(1, 0)
        team_b_text += "Final Income: %.1f gold/tick\n" % economy_manager.get_income(1)
    
    if game_manager.building_manager:
        var team_b_buildings = game_manager.building_manager.get_team_buildings(1)
        team_b_text += "Buildings Remaining: %d\n" % team_b_buildings.size()
    
    team_b_stats.text = team_b_text

# Continue button handler
func _on_continue_button_pressed():
    # Return to lobby
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager and game_manager.has_method("change_scene"):
        game_manager.change_scene("res://scenes/lobby/lobby.tscn")
    else:
    # Fallback if not available
        var _result = get_tree().change_scene("res://scenes/lobby/lobby.tscn")