extends Node

# This is a simple test runner for GUT tests
func _ready():
    print("Starting tests...")
    
    # Add your test scripts here
    var test_scripts = [
        "res://tests/test_combat_system.gd",
        "res://tests/test_economy_manager.gd",
        "res://tests/test_grid_system.gd",
        "res://tests/test_network_manager.gd"
    ]
    
    # Run each test script
    for script_path in test_scripts:
        print("Running tests in: " + script_path)
        var script = load(script_path)
        if script:
            var test_instance = script.new()
            add_child(test_instance)
            
            # Run test methods
            for method in test_instance.get_method_list():
                if method.name.begins_with("test_"):
                    print("  Running: " + method.name)
                    test_instance.call(method.name)
                    
            # Remove test instance
            remove_child(test_instance)
            test_instance.queue_free()
        else:
            print("  Could not load script: " + script_path)
    
    print("Tests completed.")