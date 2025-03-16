extends GameService

# Signal for when grid is initialized
signal grid_initialized

# Grid dimensions
var grid_width: int = 40 # Number of cells horizontally
var grid_height: int = 30 # Number of cells vertically
var cell_size: Vector2 = Vector2(64, 32) # Size of each cell for isometric grid

# Grid data storage
var grid_cells: Dictionary = {} # Stores information about each cell: position, occupancy, etc.
var valid_placement_cells: Array = [] # Cells where buildings can be placed
var team_a_cells: Array = [] # Cells in Team A's territory
var team_b_cells: Array = [] # Cells in Team B's territory
var lane_cells: Dictionary = {} # Cells organized by lanes

# Team constants
enum Team {TEAM_A, TEAM_B}

func debug_debug_log(message: String, level: String = "info", context: String = "") -> void:
    var logger = get_node_or_null("/root/Logger")
    if logger:
        match level.to_lower():
            "error":
                logger.error(message, context if context else service_name)
            "warning":
                logger.warning(message, context if context else service_name)
            "debug":
                logger.debug(message, context if context else service_name)
            "verbose":
                logger.debug(message, context if context else service_name)
            _:
                logger.info(message, context if context else service_name)
    else:
        # Fallback to print
        var prefix = "[" + level.to_upper() + "]"
        if context:
            prefix += "[" + context + "]"
        elif service_name:
            prefix += "[" + service_name + "]"
        print(prefix + " " + message)

func _initialize_impl() -> void:
    # Initialize grid cells
    grid_cells.clear()
    valid_placement_cells.clear()
    team_a_cells.clear()
    team_b_cells.clear()
    lane_cells.clear()
    
    # Create all cells
    for x in range(grid_width):
        for y in range(grid_height):
            var grid_pos = Vector2(x, y)
            var world_pos = grid_to_world(grid_pos)
            
            # Create a new cell data structure with territories initialized based on position
            var cell_data = {
                "grid_position": grid_pos,
                "world_position": world_pos,
                "occupied": false,
                "building": null,
                "walkable": true,
                "team_territory": null,
                "lane": determine_lane(grid_pos)
            }
            
            # Assign territory based on position
            if x < float(grid_width) / 3.0:
                cell_data.team_territory = 0 # Team A
                team_a_cells.append(grid_pos)
            elif x >= 2.0 * float(grid_width) / 3.0:
                cell_data.team_territory = 1 # Team B
                team_b_cells.append(grid_pos)
            
            # Store the cell in our grid
            grid_cells[grid_pos] = cell_data
            
            # Add to lane organization  
            var lane = cell_data.lane
            if not lane_cells.has(lane):
                lane_cells[lane] = []
            lane_cells[lane].append(grid_pos)
    
    # Update valid placement cells
    for x in range(grid_width):
        for y in range(grid_height):
            var grid_pos = Vector2(x, y)
            if is_valid_placement_cell(grid_pos):
                valid_placement_cells.append(grid_pos)
                
    debug_log("Grid initialized with " + str(team_a_cells.size()) + " Team A cells and " +
          str(team_b_cells.size()) + " Team B cells", "info")
    
    emit_signal("grid_initialized")

# Initialize the grid with all cells and their properties
func initialize_grid() -> void:
    grid_cells.clear()
    valid_placement_cells.clear()
    team_a_cells.clear()
    team_b_cells.clear()
    lane_cells.clear()
    
    # First create all cells
    for x in range(grid_width):
        for y in range(grid_height):
            var grid_pos = Vector2(x, y)
            var world_pos = grid_to_world(grid_pos)
            
            # Create a new cell data structure with territories initialized based on position
            var cell_data = {
                "grid_position": grid_pos,
                "world_position": world_pos,
                "occupied": false,
                "building": null,
                "walkable": true,
                "team_territory": null, # Will be set below
                "lane": determine_lane(grid_pos)
            }
            
            if x < float(grid_width) / 3.0:
                cell_data.team_territory = 0 # Team A
                team_a_cells.append(grid_pos)
            elif x >= 2.0 * float(grid_width) / 3.0:
                cell_data.team_territory = 1 # Team B
                team_b_cells.append(grid_pos)
            
            # Store the cell in our grid
            grid_cells[grid_pos] = cell_data
            
            # Add to lane organization  
            var lane = cell_data.lane
            if not lane_cells.has(lane):
                lane_cells[lane] = []
            lane_cells[lane].append(grid_pos)
    
    # Update valid placement cells
    for x in range(grid_width):
        for y in range(grid_height):
            var grid_pos = Vector2(x, y)
            if is_valid_placement_cell(grid_pos):
                valid_placement_cells.append(grid_pos)
                
    debug_log("Grid initialized with " + str(team_a_cells.size()) + " Team A cells and " + str(team_b_cells.size()) + " Team B cells", "info")
    
    emit_signal("grid_initialized")

# Determine which lane a cell belongs to based on its position
func determine_lane(grid_pos: Vector2) -> int:
    # Divide the grid into 3 lanes (top, middle, bottom)
    if grid_pos.y < float(grid_height) / 3.0:
        return 0 # Top lane
    elif grid_pos.y < 2.0 * float(grid_height) / 3.0:
        return 1 # Middle lane
    else:
        return 2 # Bottom lane

# Convert grid coordinates to world coordinates
func grid_to_world(grid_pos: Vector2) -> Vector2:
    # Isometric conversion
    var world_x = (grid_pos.x - grid_pos.y) * (float(cell_size.x) / 2.0)
    var world_y = (grid_pos.x + grid_pos.y) * (float(cell_size.y) / 2.0)
    return Vector2(world_x, world_y)

func world_to_grid(world_pos: Vector2) -> Vector2:
    # Inverse isometric conversion
    var grid_x = (world_pos.x / (float(cell_size.x) / 2.0) + world_pos.y / (float(cell_size.y) / 2.0)) / 2.0
    var grid_y = (world_pos.y / (float(cell_size.y) / 2.0) - world_pos.x / (float(cell_size.x) / 2.0)) / 2.0
    
    # Round to nearest integer and clamp to valid grid range
    var final_x = clamp(round(grid_x), 0.0, float(grid_width - 1))
    var final_y = clamp(round(grid_y), 0.0, float(grid_height - 1))
    
    return Vector2(final_x, final_y)

# Check if a cell is within the grid bounds
func is_within_grid(grid_pos: Vector2) -> bool:
    return grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height

# Check if a cell is already occupied
func is_cell_occupied(grid_pos: Vector2) -> bool:
    if not grid_cells.has(grid_pos):
        return true # Consider out-of-bounds as occupied
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

func can_place_building(grid_pos: Vector2, size: Vector2, team: int) -> bool:
    # Check if all required cells are available
    for x in range(size.x):
        for y in range(size.y):
            var check_pos = grid_pos + Vector2(x, y)
            
            # Check if position is within grid
            if not is_within_grid(check_pos):
                print("Building placement failed: position out of grid bounds")
                return false
                
            # Check if cell is already occupied
            if is_cell_occupied(check_pos):
                print("Building placement failed: cell already occupied")
                return false
                
            # Check if cell belongs to the team's territory
            var cell_team = grid_cells[check_pos].team_territory
            print("Checking cell at " + str(check_pos) + " for team " + str(team) + ", cell team: " + str(cell_team))
            if cell_team != team:
                print("Building placement failed: cell territory mismatch")
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
    if cell_data.team_territory == null: # Neutral territory
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

func draw_debug_grid() -> void:
    # Create a debug node for visualization if it doesn't exist
    if not has_node("DebugGridVisualizer"):
        var debug_draw = Node2D.new()
        debug_draw.name = "DebugGridVisualizer"
        add_child(debug_draw)
        
        # Connect draw signal
        debug_draw.connect("draw", self, "_on_debug_draw")
    
    # Force update
    var debug_visualizer = get_node("DebugGridVisualizer")
    debug_visualizer.update()
    
    print("Debug grid visualization enabled")

func _on_debug_draw() -> void:
    var debug_draw = get_node("DebugGridVisualizer")
    if not debug_draw:
        return
        
    # Draw grid lines
    for x in range(grid_width + 1):
        var start_pos = grid_to_world(Vector2(x, 0))
        var end_pos = grid_to_world(Vector2(x, grid_height))
        debug_draw.draw_line(start_pos, end_pos, Color(0.5, 0.5, 0.5, 0.3), 1.0)
        
    for y in range(grid_height + 1):
        var start_pos = grid_to_world(Vector2(0, y))
        var end_pos = grid_to_world(Vector2(grid_width, y))
        debug_draw.draw_line(start_pos, end_pos, Color(0.5, 0.5, 0.5, 0.3), 1.0)
    
    # Draw territory highlights
    for x in range(grid_width):
        for y in range(grid_height):
            var grid_pos = Vector2(x, y)
            if grid_cells.has(grid_pos):
                var cell = grid_cells[grid_pos]
                var world_pos = grid_to_world(grid_pos)
                
                if cell.team_territory == 0: # Team A
                    debug_draw.draw_rect(Rect2(world_pos - Vector2(cell_size.x / 2, cell_size.y / 2),
                                        cell_size), Color(0, 0, 1, 0.2), true)
                elif cell.team_territory == 1: # Team B
                    debug_draw.draw_rect(Rect2(world_pos - Vector2(cell_size.x / 2, cell_size.y / 2),
                                        cell_size), Color(1, 0, 0, 0.2), true)
