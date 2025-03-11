# Grid System for building placement and unit movement
# Path: scripts/core/grid_system.gd
class_name GridSystem
extends Node2D

signal cell_highlighted(grid_pos, is_valid)
signal grid_initialized

# Grid dimensions
var grid_width: int = 40  # Number of cells horizontally
var grid_height: int = 30  # Number of cells vertically
var cell_size: Vector2 = Vector2(64, 32)  # Size of each cell for isometric grid

# Grid data storage
var grid_cells: Dictionary = {}  # Stores information about each cell: position, occupancy, etc.
var valid_placement_cells: Array = []  # Cells where buildings can be placed
var team_a_cells: Array = []  # Cells in Team A's territory
var team_b_cells: Array = []  # Cells in Team B's territory
var lane_cells: Dictionary = {}  # Cells organized by lanes

# Visual debugging
var debug_mode: bool = false
var debug_grid: Node2D

# Team constants
enum Team {TEAM_A, TEAM_B}

func _ready():
	# Initialize the grid when the node enters the scene tree
	initialize_grid()
	
	# Setup debug visualization if enabled
	if debug_mode:
		create_debug_grid()

# Initialize the grid with all cells and their properties
func initialize_grid() -> void:
	grid_cells.clear()
	valid_placement_cells.clear()
	team_a_cells.clear()
	team_b_cells.clear()
	
	# Create cells for the entire grid
	for x in range(grid_width):
		for y in range(grid_height):
			var grid_pos = Vector2(x, y)
			var world_pos = grid_to_world(grid_pos)
			
			# Create a new cell data structure
			var cell_data = {
				"grid_position": grid_pos,
				"world_position": world_pos,
				"occupied": false,
				"building": null,
				"walkable": true,
				"team_territory": null,
				"lane": determine_lane(grid_pos)
			}
			
			# Assign the cell to its team territory based on position
			# Assuming Team A is on the left side, Team B on right side
			if x < grid_width / 2 - 5:  # Left side with 5-cell buffer
				cell_data.team_territory = Team.TEAM_A
				team_a_cells.append(grid_pos)
			elif x > grid_width / 2 + 5:  # Right side with 5-cell buffer
				cell_data.team_territory = Team.TEAM_B
				team_b_cells.append(grid_pos)
			else:
				# Neutral territory in the middle
				cell_data.team_territory = null
			
			# Store the cell in our grid
			grid_cells[grid_pos] = cell_data
			
			# Add to valid placement cells (could be adjusted based on game rules)
			if is_valid_placement_cell(grid_pos):
				valid_placement_cells.append(grid_pos)
				
			# Add to lane organization
			var lane = cell_data.lane
			if not lane_cells.has(lane):
				lane_cells[lane] = []
			lane_cells[lane].append(grid_pos)
	
	emit_signal("grid_initialized")

# Determine which lane a cell belongs to based on its position
func determine_lane(grid_pos: Vector2) -> int:
	# Divide the grid into 3 lanes (top, middle, bottom)
	# This is a simplified example - adjust based on your map design
	if grid_pos.y < grid_height / 3:
		return 0  # Top lane
	elif grid_pos.y < 2 * grid_height / 3:
		return 1  # Middle lane
	else:
		return 2  # Bottom lane

# Convert grid coordinates to world coordinates
func grid_to_world(grid_pos: Vector2) -> Vector2:
	# Isometric conversion
	var world_x = (grid_pos.x - grid_pos.y) * (cell_size.x / 2)
	var world_y = (grid_pos.x + grid_pos.y) * (cell_size.y / 2)
	return Vector2(world_x, world_y)

# Convert world coordinates to grid coordinates
func world_to_grid(world_pos: Vector2) -> Vector2:
	# Inverse isometric conversion
	var grid_x = (world_pos.x / (cell_size.x / 2) + world_pos.y / (cell_size.y / 2)) / 2
	var grid_y = (world_pos.y / (cell_size.y / 2) - world_pos.x / (cell_size.x / 2)) / 2
	return Vector2(round(grid_x), round(grid_y))

# Check if a cell is within the grid bounds
func is_within_grid(grid_pos: Vector2) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height

# Check if a cell is already occupied
func is_cell_occupied(grid_pos: Vector2) -> bool:
	if not grid_cells.has(grid_pos):
		return true  # Consider out-of-bounds as occupied
	return grid_cells[grid_pos].occupied

# Mark a cell as occupied by a building
func occupy_cell(grid_pos: Vector2, building_ref = null) -> bool:
	if not grid_cells.has(grid_pos) or grid_cells[grid_pos].occupied:
		return false
		
	grid_cells[grid_pos].occupied = true
	grid_cells[grid_pos].building = building_ref
	grid_cells[grid_pos].walkable = false
	
	# Remove from valid placement cells if it was there
	if valid_placement_cells.has(grid_pos):
		valid_placement_cells.erase(grid_pos)
		
	return true

# Mark a cell as unoccupied (e.g., when a building is destroyed)
func free_cell(grid_pos: Vector2) -> void:
	if not grid_cells.has(grid_pos):
		return
		
	grid_cells[grid_pos].occupied = false
	grid_cells[grid_pos].building = null
	grid_cells[grid_pos].walkable = true
	
	# If this cell qualifies as a valid placement cell, add it back
	if is_valid_placement_cell(grid_pos):
		valid_placement_cells.append(grid_pos)

# Check if a building of a specific size can be placed at a given position
func can_place_building(grid_pos: Vector2, size: Vector2, team: int) -> bool:
	# Check if all required cells are available
	for x in range(size.x):
		for y in range(size.y):
			var check_pos = grid_pos + Vector2(x, y)
			
			# Check if position is within grid
			if not is_within_grid(check_pos):
				return false
				
			# Check if cell is already occupied
			if is_cell_occupied(check_pos):
				return false
				
			# Check if cell belongs to the team's territory
			var cell_team = grid_cells[check_pos].team_territory
			if cell_team != team:
				return false
	
	return true

# Determine if a cell is valid for building placement
func is_valid_placement_cell(grid_pos: Vector2) -> bool:
	# A cell is valid if it's within the grid, not occupied,
	# and belongs to a team's territory
	if not is_within_grid(grid_pos):
		return false
		
	if is_cell_occupied(grid_pos):
		return false
		
	var cell_data = grid_cells[grid_pos]
	if cell_data.team_territory == null:  # Neutral territory
		return false
		
	return true

# Highlight valid cells for a building placement of given size
func highlight_valid_cells(size: Vector2, team: int) -> Array:
	var valid_positions = []
	
	# Check each cell in the team's territory
	var team_cells = team_a_cells if team == Team.TEAM_A else team_b_cells
	
	for start_pos in team_cells:
		if can_place_building(start_pos, size, team):
			valid_positions.append(start_pos)
			emit_signal("cell_highlighted", start_pos, true)
	
	return valid_positions

# Clear all highlights
func clear_highlights() -> void:
	emit_signal("cell_highlighted", Vector2.ZERO, false)

# Create visual debug grid
func create_debug_grid() -> void:
	debug_grid = Node2D.new()
	debug_grid.name = "DebugGrid"
	add_child(debug_grid)
	
	for grid_pos in grid_cells.keys():
		var cell = grid_cells[grid_pos]
		var world_pos = cell.world_position
		
		var rect = ColorRect.new()
		rect.rect_size = Vector2(5, 5)
		rect.rect_position = world_pos - Vector2(2.5, 2.5)
		
		if cell.team_territory == Team.TEAM_A:
			rect.color = Color(0, 0, 1, 0.5)  # Blue for Team A
		elif cell.team_territory == Team.TEAM_B:
			rect.color = Color(1, 0, 0, 0.5)  # Red for Team B
		else:
			rect.color = Color(0.5, 0.5, 0.5, 0.5)  # Gray for neutral
			
		debug_grid.add_child(rect)

# Updates the visual debugging when grid changes
func update_debug_grid() -> void:
	if not debug_mode or not is_instance_valid(debug_grid):
		return
		
	for child in debug_grid.get_children():
		child.queue_free()
		
	create_debug_grid()