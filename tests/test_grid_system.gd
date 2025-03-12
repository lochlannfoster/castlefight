extends "res://addons/gut/test.gd"

var GridSystem = preload("res://scripts/core/grid_system.gd")
var grid_system

func before_each():
    grid_system = GridSystem.new()
    add_child(grid_system)
    grid_system.initialize_grid()

func after_each():
    grid_system.queue_free()
    grid_system = null

func test_is_within_grid():
    # Test valid positions
    assert_true(grid_system.is_within_grid(Vector2(0, 0)))
    assert_true(grid_system.is_within_grid(Vector2(grid_system.grid_width - 1, grid_system.grid_height - 1)))
    
    # Test invalid positions
    assert_false(grid_system.is_within_grid(Vector2(-1, 0)))
    assert_false(grid_system.is_within_grid(Vector2(0, -1)))
    assert_false(grid_system.is_within_grid(Vector2(grid_system.grid_width, 0)))
    assert_false(grid_system.is_within_grid(Vector2(0, grid_system.grid_height)))

func test_grid_to_world_conversion():
    var grid_pos = Vector2(5, 5)
    var world_pos = grid_system.grid_to_world(grid_pos)
    var converted_back = grid_system.world_to_grid(world_pos)
    
    # Check that conversion back and forth preserves position
    assert_eq(converted_back.x, grid_pos.x, "X position should be preserved in conversion")
    assert_eq(converted_back.y, grid_pos.y, "Y position should be preserved in conversion")

func test_cell_occupation():
    var grid_pos = Vector2(5, 5)
    
    # Check initial state
    assert_false(grid_system.is_cell_occupied(grid_pos))
    
    # Occupy cell
    assert_true(grid_system.occupy_cell(grid_pos, "test_building"))
    assert_true(grid_system.is_cell_occupied(grid_pos))
    
    # Free cell
    grid_system.free_cell(grid_pos)
    assert_false(grid_system.is_cell_occupied(grid_pos))

func test_can_place_building():
    var grid_pos = Vector2(5, 5)
    var size = Vector2(2, 2)
    var team = grid_system.Team.TEAM_A
    
    # Prepare the area by setting team territory
    var cells = grid_system.grid_cells
    for x in range(size.x):
        for y in range(size.y):
            var check_pos = grid_pos + Vector2(x, y)
            cells[check_pos].team_territory = team
    
    # Check initial state
    assert_true(grid_system.can_place_building(grid_pos, size, team))
    
    # Occupy one cell
    grid_system.occupy_cell(grid_pos)
    
    # Now should fail
    assert_false(grid_system.can_place_building(grid_pos, size, team))

	# Free the cell
	grid_system.free_cell(grid_pos)
	
	# Test wrong team
	var wrong_team = grid_system.Team.TEAM_B
	assert_false(grid_system.can_place_building(grid_pos, size, wrong_team))
	
	# Test out of bounds
	var edge_pos = Vector2(grid_system.grid_width - 1, grid_system.grid_height - 1)
	assert_false(grid_system.can_place_building(edge_pos, size, team))

func test_valid_placement_cells():
	var team = grid_system.Team.TEAM_A
	
	# Set up some team territory
	var cells = grid_system.grid_cells
	for x in range(10):
		for y in range(10):
			var pos = Vector2(x, y)
			cells[pos].team_territory = team
	
	# Highlight valid cells
	var valid_positions = grid_system.highlight_valid_cells(Vector2(1, 1), team)
	
	# Should have some valid positions
	assert_true(valid_positions.size() > 0)
	
	# Occupy a cell
	grid_system.occupy_cell(valid_positions[0])
	
	# Highlight again
	var new_valid_positions = grid_system.highlight_valid_cells(Vector2(1, 1), team)
	
	# Should have one less valid position
	assert_eq(new_valid_positions.size(), valid_positions.size() - 1)