# Main Menu - Handles the main menu interface and navigation
# Path: scripts/ui/main_menu.gd
extends Control

# Ready function
func _ready() -> void:
	# Connect button signals
	$VBoxContainer/MultiplayerButton.connect("pressed", self, "_on_multiplayer_button_pressed")
	$VBoxContainer/VSingleplayerButton.connect("pressed", self, "_on_singleplayer_button_pressed")
	$VBoxContainer/OptionsButton.connect("pressed", self, "_on_options_button_pressed")
	$VBoxContainer/QuitButton.connect("pressed", self, "_on_quit_button_pressed")
	
	# Set version text
	$VersionLabel.text = "Version 0.1.0"

# Navigate to multiplayer lobby
func _on_multiplayer_button_pressed() -> void:
	get_tree().change_scene("res://scenes/lobby/lobby.tscn")

# Start a singleplayer game
func _on_singleplayer_button_pressed() -> void:
	get_tree().change_scene("res://scenes/singleplayer/singleplayer_setup.tscn")

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