extends "res://addons/gut/gut.gd"

func _ready():
    # Configure GUT
    gut_config_script = "res://test_config.gd"
    
    # Add test scripts
    add_script("res://tests/test_combat_system.gd")
    add_script("res://tests/test_economy_manager.gd")
    add_script("res://tests/test_grid_system.gd")
    add_script("res://tests/test_network_manager.gd")
    
    # Run tests
    test_scripts()