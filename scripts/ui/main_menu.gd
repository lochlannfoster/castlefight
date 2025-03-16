# Main Menu - Handles the main menu interface and navigation
# Path: scripts/ui/main_menu.gd
extends Control

# Ready function
func _ready() -> void:
    # Connect button signals
    var _connect1 = $VBoxContainer/MultiplayerButton.connect("pressed", self, "_on_multiplayer_button_pressed")
    var _connect2 = $VBoxContainer/VSingleplayerButton.connect("pressed", self, "_on_singleplayer_button_pressed")
    var _connect3 = $VBoxContainer/OptionsButton.connect("pressed", self, "_on_options_button_pressed")
    var _connect4 = $VBoxContainer/QuitButton.connect("pressed", self, "_on_quit_button_pressed")
    
    # Set version text
    $VersionLabel.text = "Version 0.1.0"
    
    # Debug connection success
    print("Main menu buttons connected successfully!")

# Navigate to multiplayer lobby
func _on_multiplayer_button_pressed() -> void:
    print("Multiplayer button pressed, changing to lobby scene")
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager and game_manager.has_method("change_scene"):
        var _result = game_manager.change_scene("res://scenes/lobby/lobby.tscn")
    else:
        # Fallback if not available
        var _result = get_tree().change_scene("res://scenes/lobby/lobby.tscn")

# Start a singleplayer game
func _on_singleplayer_button_pressed() -> void:
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager and game_manager.has_method("change_scene"):
        var _result = game_manager.change_scene("res://scenes/lobby/lobby.tscn")
    else:
        # Fallback if not available
        var _result = get_tree().change_scene("res://scenes/lobby/lobby.tscn")

# Open options menu
func _on_options_button_pressed() -> void:
    # Options menu not implemented yet
    var options_dialog = AcceptDialog.new()
    options_dialog.window_title = "Not Implemented"
    options_dialog.dialog_text = "Options menu is not implemented yet."
    add_child(options_dialog)
    options_dialog.popup_centered()

# Quit the game
func _on_quit_button_pressed() -> void:
    get_tree().quit()
