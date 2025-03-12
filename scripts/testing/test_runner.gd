extends "res://scripts/testing/simple_test.gd"

func _ready():
    run_tests()

func run_tests():
    # Run grid system tests
    current_test = "Grid System"
    test_grid_system()
    
    # Add more test categories as needed
    
    # Show summary
    print("=== Tests Complete ===")
    print("Ran: ", tests_run, " Passed: ", tests_passed, " Failed: ", tests_failed)

func test_grid_system():
    # Get a reference to the grid system
    var grid_system = get_node_or_null("/root/GridSystem")
    if not grid_system:
        print("Could not find GridSystem node")
        return
    
    # Test is_within_grid
    assert_true(grid_system.is_within_grid(Vector2(0, 0)), "Origin should be within grid")
    assert_false(grid_system.is_within_grid(Vector2(-1, 0)), "Negative X should be outside grid")
    
    # Test grid/world conversion
    var grid_pos = Vector2(5, 5)
    var world_pos = grid_system.grid_to_world(grid_pos)
    var converted = grid_system.world_to_grid(world_pos)
    assert_eq(int(converted.x), grid_pos.x, "Grid-world-grid X conversion should preserve values")
    assert_eq(int(converted.y), grid_pos.y, "Grid-world-grid Y conversion should preserve values")
    
    # More tests here