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

    print("Main menu scene loaded")
    print("Scene tree structure:")
    _print_scene_tree(self, 0)
    
    # Ensure all elements are visible
    for child in get_children():
        if child is Control or child is Node2D:
            child.visible = true
            print("Setting " + child.name + " to visible")
    # Create debug scene viewer
    call_deferred("create_debug_viewer")
    
    # Add this to verify assets are loading correctly
    verify_critical_assets()


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

func _print_scene_tree(node, indent):
    var indent_str = ""
    for _i in range(indent):
        indent_str += "  "
    
    print(indent_str + node.name + " (" + node.get_class() + ")" +
          (" - visible: " + str(node.visible) if "visible" in node else ""))
    
    for child in node.get_children():
        _print_scene_tree(child, indent + 1)

func verify_critical_assets():
    debug_log("Verifying critical assets...", "info", "GameManager")
    
    # Check shaders
    var shader_path = "res://shaders/fog_of_war.shader"
    var file = File.new()
    if file.file_exists(shader_path):
        debug_log("Fog of War shader exists", "info", "GameManager")
    else:
        debug_log("Fog of War shader missing!", "error", "GameManager")
    
    # Check critical scenes
    var critical_scenes = [
        "res://scenes/main_menu/main_menu.tscn",
        "res://scenes/game/game.tscn",
        "res://scenes/lobby/lobby.tscn"
    ]
    
    for scene_path in critical_scenes:
        if file.file_exists(scene_path):
            debug_log("Scene exists: " + scene_path, "info", "GameManager")
        else:
            debug_log("Critical scene missing: " + scene_path, "error", "GameManager")
    
    debug_log("Asset verification complete", "info", "GameManager")

func debug_log(message: String, level: String = "info", context: String = "") -> void:
    var logger = get_node_or_null("/root/UnifiedLogger")
    if logger:
        match level.to_lower():
            "error":
                logger.error(message, context if context else "MainMenu")
            "warning":
                logger.warning(message, context if context else "MainMenu")
            "debug":
                logger.debug(message, context if context else "MainMenu")
            "verbose":
                logger.verbose(message, context if context else "MainMenu")
            _:
                logger.info(message, context if context else "MainMenu")
    else:
        # Fallback to print
        var prefix = "[" + level.to_upper() + "]"
        if context:
            prefix += "[" + context + "]"
        else:
            prefix += "[MainMenu]"
        print(prefix + " " + message)
