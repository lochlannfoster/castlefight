# Main Menu - Handles the main menu interface and navigation
# Path: scripts/ui/main_menu.gd
extends Control

func _ready():
    # Connect button signals with error handling
    var _mp_connect_result = $VBoxContainer/MultiplayerButton.connect("pressed", self, "_on_multiplayer_button_pressed")
    if _mp_connect_result != OK:
        push_warning("Failed to connect multiplayer button signal")
    
    var _options_connect_result = $VBoxContainer/OptionsButton.connect("pressed", self, "_on_options_button_pressed")
    if _options_connect_result != OK:
        push_warning("Failed to connect options button signal")
    
    var _quit_connect_result = $VBoxContainer/QuitButton.connect("pressed", self, "_on_quit_button_pressed")
    if _quit_connect_result != OK:
        push_warning("Failed to connect quit button signal")
    
    # Set version text
    $VersionLabel.text = "Version 0.1.0"
    
    print("Main menu buttons connection handling complete!")

func _on_multiplayer_button_pressed():
    print("Multiplayer button pressed, changing to lobby scene")
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager and game_manager.has_method("change_scene"):
        var _scene_change_result = game_manager.change_scene("res://scenes/lobby/lobby.tscn")
    else:
        # Fallback if not available
        var _scene_change_result = get_tree().change_scene("res://scenes/lobby/lobby.tscn")

# Open options menu
func _on_options_button_pressed():
    # Options menu placeholder
    var options_dialog = AcceptDialog.new()
    options_dialog.window_title = "Options"
    options_dialog.dialog_text = "Options menu coming soon!"
    add_child(options_dialog)
    options_dialog.popup_centered()

# Quit the game
func _on_quit_button_pressed():
    get_tree().quit()
