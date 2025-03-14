# Map Manager - Handles map generation, terrain, and layout
# Path: scripts/core/map_manager.gd
class_name MapManager
extends Node2D

# Map signals
signal map_loaded
signal map_generated
signal lane_created(lane_id, lane_data)

# Map properties
export var map_width: int = 40  # Width in grid cells
export var map_height: int = 30  # Height in grid cells
export var lane_count: int = 3  # Number of lanes
export var base_size: int = 8  # Size of team bases in grid cells
export var team_a_color: Color = Color(0, 0, 1)  # Blue
export var team_b_color: Color = Color(1, 0, 0)  # Red
export var neutral_color: Color = Color(0.5, 0.5, 0.5)  # Gray

# Map data
var map_data: Dictionary = {}
var lanes: Array = []
var team_a_base_rect: Rect2
var team_b_base_rect: Rect2
var neutral_zone_rect: Rect2
var team_a_start_pos: Vector2
var team_b_start_pos: Vector2
var team_a_hq_pos: Vector2
var team_b_hq_pos: Vector2
var map_obstacles: Array = []

# References
var grid_system: GridSystem
var map_node: Node2D

# Ready function
func _ready() -> void:
	# Get grid system reference
	grid_system = get_node_or_null("/root/GameManager/GridSystem")
	
	# Create map display node
	map_node = Node2D.new()
	map_node.name = "MapDisplay"
	add_child(map_node)
	
	# Connect grid signals
	if grid_system:
		var _connect_result = grid_system.connect("grid_initialized", self, "_on_grid_initialized")

# Generate a new map
func generate_map() -> void:
	# Clear existing map data
	map_data.clear()
	lanes.clear()
	map_obstacles.clear()
	
	# Define team bases
	team_a_base_rect = Rect2(0, 0, base_size, map_height)
	team_b_base_rect = Rect2(map_width - base_size, 0, base_size, map_height)
	neutral_zone_rect = Rect2(base_size, 0, map_width - 2 * base_size, map_height)
	
	# Define starting positions and HQ positions
	team_a_start_pos = Vector2(float(base_size) / 2.0, float(map_height) / 2.0)
	team_b_start_pos = Vector2(float(map_width) - float(base_size) / 2.0, float(map_height) / 2.0)
	team_a_hq_pos = Vector2(float(base_size) / 4.0, float(map_height) / 2.0)
	team_b_hq_pos = Vector2(float(map_width) - float(base_size) / 4.0, float(map_height) / 2.0)
	
	# Define lanes
	_generate_lanes()
	
	# Place obstacles
	_generate_obstacles()
	
	# Create map data structure
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2(x, y)
			var cell_data = {
				"position": pos,
				"terrain_type": _get_terrain_type(pos),
				"lane": _get_lane_for_position(pos),
				"walkable": true,
				"buildable": _is_position_buildable(pos)
			}
			
			map_data[_position_to_key(pos)] = cell_data
	
	emit_signal("map_generated")
	_update_map_display()

# Load an existing map from file
func load_map(map_name: String) -> bool:
	var file_path = "res://maps/" + map_name + ".json"
	var file = File.new()
	
	if not file.file_exists(file_path):
		print("Map file does not exist: " + file_path)
		return false
	
	if file.open(file_path, File.READ) != OK:
		print("Could not open map file: " + file_path)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json_result = JSON.parse(json_text)
	if json_result.error != OK:
		print("Error parsing map data: " + json_result.error_string)
		return false
	
	var data = json_result.result
	
	# Load map properties
	map_width = data.map_width
	map_height = data.map_height
	lane_count = data.lane_count
	base_size = data.base_size
	
	# Load team bases
	team_a_base_rect = Rect2(data.team_a_base.x, data.team_a_base.y, 
							 data.team_a_base.width, data.team_a_base.height)
	team_b_base_rect = Rect2(data.team_b_base.x, data.team_b_base.y, 
							 data.team_b_base.width, data.team_b_base.height)
	neutral_zone_rect = Rect2(data.neutral_zone.x, data.neutral_zone.y, 
							  data.neutral_zone.width, data.neutral_zone.height)
	
	# Load positions
	team_a_start_pos = Vector2(data.team_a_start.x, data.team_a_start.y)
	team_b_start_pos = Vector2(data.team_b_start.x, data.team_b_start.y)
	team_a_hq_pos = Vector2(data.team_a_hq.x, data.team_a_hq.y)
	team_b_hq_pos = Vector2(data.team_b_hq.x, data.team_b_hq.y)
	
	# Load lanes
	lanes = data.lanes
	
	# Load obstacles
	map_obstacles = data.obstacles
	
	# Load cell data
	map_data.clear()
	for cell in data.cells:
		var pos = Vector2(cell.position.x, cell.position.y)
		var cell_data = {
			"position": pos,
			"terrain_type": cell.terrain_type,
			"lane": cell.lane,
			"walkable": cell.walkable,
			"buildable": cell.buildable
		}
		map_data[_position_to_key(pos)] = cell_data
	
	emit_signal("map_loaded")
	_update_map_display()
	
	return true

# Save the current map to file
func save_map(map_name: String) -> bool:
	var file_path = "res://maps/" + map_name + ".json"
	var file = File.new()
	
	if file.open(file_path, File.WRITE) != OK:
		print("Could not open map file for writing: " + file_path)
		return false
	
	var save_data = {
		"map_width": map_width,
		"map_height": map_height,
		"lane_count": lane_count,
		"base_size": base_size,
		"team_a_base": {
			"x": team_a_base_rect.position.x,
			"y": team_a_base_rect.position.y,
			"width": team_a_base_rect.size.x,
			"height": team_a_base_rect.size.y
		},
		"team_b_base": {
			"x": team_b_base_rect.position.x,
			"y": team_b_base_rect.position.y,
			"width": team_b_base_rect.size.x,
			"height": team_b_base_rect.size.y
		},
		"neutral_zone": {
			"x": neutral_zone_rect.position.x,
			"y": neutral_zone_rect.position.y,
			"width": neutral_zone_rect.size.x,
			"height": neutral_zone_rect.size.y
		},
		"team_a_start": {
			"x": team_a_start_pos.x,
			"y": team_a_start_pos.y
		},
		"team_b_start": {
			"x": team_b_start_pos.x,
			"y": team_b_start_pos.y
		},
		"team_a_hq": {
			"x": team_a_hq_pos.x,
			"y": team_a_hq_pos.y
		},
		"team_b_hq": {
			"x": team_b_hq_pos.x,
			"y": team_b_hq_pos.y
		},
		"lanes": lanes,
		"obstacles": map_obstacles,
		"cells": []
	}
	
	# Convert map data to array for saving
	for key in map_data.keys():
		var cell = map_data[key]
		save_data.cells.append({
			"position": {
				"x": cell.position.x,
				"y": cell.position.y
			},
			"terrain_type": cell.terrain_type,
			"lane": cell.lane,
			"walkable": cell.walkable,
			"buildable": cell.buildable
		})
	
	var json_text = JSON.print(save_data, "  ")
	file.store_string(json_text)
	file.close()
	
	print("Map saved to: " + file_path)
	return true

# Apply map data to grid system
func apply_map_to_grid() -> void:
	if not grid_system:
		return
	
	# Update grid dimensions if needed
	grid_system.grid_width = map_width
	grid_system.grid_height = map_height
	
	# If grid is not initialized, do so now
	if grid_system.grid_cells.empty():
		grid_system.initialize_grid()
		return  # Grid initialization will call _on_grid_initialized
	
	# Otherwise, update existing grid cells
	for key in map_data.keys():
		var cell_data = map_data[key]
		var grid_pos = cell_data.position
		
		if grid_system.grid_cells.has(grid_pos):
			var grid_cell = grid_system.grid_cells[grid_pos]
			
			# Set territory
			if team_a_base_rect.has_point(grid_pos):
				grid_cell.team_territory = grid_system.Team.TEAM_A
			elif team_b_base_rect.has_point(grid_pos):
				grid_cell.team_territory = grid_system.Team.TEAM_B
			else:
				grid_cell.team_territory = null
			
			# Set walkable
			grid_cell.walkable = cell_data.walkable
			
			# Set lane
			grid_cell.lane = cell_data.lane

# Get team starting position
func get_team_start_position(team: int) -> Vector2:
	if team == 0:  # Team A
		return grid_system.grid_to_world(team_a_start_pos)
	else:  # Team B
		return grid_system.grid_to_world(team_b_start_pos)

# Get team HQ position
func get_team_hq_position(team: int) -> Vector2:
	if team == 0:  # Team A
		return grid_system.grid_to_world(team_a_hq_pos)
	else:  # Team B
		return grid_system.grid_to_world(team_b_hq_pos)

# Generate lanes for the map
func _generate_lanes() -> void:
	lanes.clear()
	
	# Calculate lane height
	var lane_height = float(map_height) / float(lane_count)
	
	for i in range(lane_count):
		var start_y = i * lane_height
		var end_y = start_y + lane_height
		
		# Create lane data
		var lane_data = {
			"id": i,
			"name": "Lane " + str(i + 1),
			"start_y": start_y,
			"end_y": end_y,
			"team_a_entry": Vector2(base_size, start_y + lane_height / 2.0),
			"team_b_entry": Vector2(map_width - base_size, start_y + lane_height / 2.0),
			"waypoints": _generate_lane_waypoints(base_size, start_y + lane_height / 2.0, map_width - base_size, start_y + lane_height / 2.0)
		}
		
		lanes.append(lane_data)
		emit_signal("lane_created", i, lane_data)

# Generate waypoints for a lane
func _generate_lane_waypoints(start_x: int, start_y: int, end_x: int, _end_y: int) -> Array:
	var waypoints = []
	
	# Simple straight lane for now
	var steps = 5  # Number of waypoints to create
	var step_x = (end_x - start_x) / float(steps - 1)
	
	for i in range(steps):
		var x = start_x + i * step_x
		var pos = Vector2(x, start_y)
		waypoints.append(pos)
	
	return waypoints

# Generate obstacles on the map
func _generate_obstacles() -> void:
	map_obstacles.clear()
	
	# No obstacles in the basic implementation
	# Could add various obstacle types:
	# - Impassable rocks
	# - Trees (can be cleared for wood)
	# - Resource nodes
	# - Decorative elements
	pass

# Get terrain type for a position
func _get_terrain_type(pos: Vector2) -> String:
	if team_a_base_rect.has_point(pos):
		return "team_a_base"
	elif team_b_base_rect.has_point(pos):
		return "team_b_base"
	else:
		return "neutral"

# Get lane ID for a position
func _get_lane_for_position(pos: Vector2) -> int:
	var lane_height = float(map_height) / float(lane_count)
	
	for i in range(lane_count):
		var start_y = i * lane_height
		var end_y = start_y + lane_height
		
		if pos.y >= start_y and pos.y < end_y:
			return i
	
	return 0  # Default to first lane

# Check if a position is buildable
func _is_position_buildable(pos: Vector2) -> bool:
	# Can build in team bases but not in neutral territory
	if team_a_base_rect.has_point(pos) or team_b_base_rect.has_point(pos):
		return true
	
	return false

# Convert position to map data key
func _position_to_key(pos: Vector2) -> String:
	return str(int(pos.x)) + "_" + str(int(pos.y))

# Update map visual display
func _update_map_display() -> void:
	# Clear existing display
	for child in map_node.get_children():
		child.queue_free()
	
	# Only show debug display in editor
	if not Engine.editor_hint:
		return
	
	# Create a visual representation of the map
	for key in map_data.keys():
		var cell_data = map_data[key]
		var pos = cell_data.position
		
		var cell_rect = ColorRect.new()
		cell_rect.rect_size = Vector2(16, 16)
		cell_rect.rect_position = pos * 16
		
		match cell_data.terrain_type:
			"team_a_base":
				cell_rect.color = team_a_color
			"team_b_base":
				cell_rect.color = team_b_color
			"neutral":
				cell_rect.color = neutral_color
		
		map_node.add_child(cell_rect)
	
	# Draw lane markers
	for lane in lanes:
		for waypoint in lane.waypoints:
			var marker = ColorRect.new()
			marker.rect_size = Vector2(8, 8)
			marker.rect_position = waypoint * 16 - Vector2(4, 4)
			marker.color = Color(1, 1, 0)  # Yellow
			map_node.add_child(marker)
	
	# Draw start and HQ positions
	var team_a_start_marker = ColorRect.new()
	team_a_start_marker.rect_size = Vector2(10, 10)
	team_a_start_marker.rect_position = team_a_start_pos * 16 - Vector2(5, 5)
	team_a_start_marker.color = Color(0, 1, 0)  # Green
	map_node.add_child(team_a_start_marker)
	
	var team_b_start_marker = ColorRect.new()
	team_b_start_marker.rect_size = Vector2(10, 10)
	team_b_start_marker.rect_position = team_b_start_pos * 16 - Vector2(5, 5)
	team_b_start_marker.color = Color(0, 1, 0)  # Green
	map_node.add_child(team_b_start_marker)
	
	var team_a_hq_marker = ColorRect.new()
	team_a_hq_marker.rect_size = Vector2(12, 12)
	team_a_hq_marker.rect_position = team_a_hq_pos * 16 - Vector2(6, 6)
	team_a_hq_marker.color = Color(1, 1, 1)  # White
	map_node.add_child(team_a_hq_marker)
	
	var team_b_hq_marker = ColorRect.new()
	team_b_hq_marker.rect_size = Vector2(12, 12)
	team_b_hq_marker.rect_position = team_b_hq_pos * 16 - Vector2(6, 6)
	team_b_hq_marker.color = Color(1, 1, 1)  # White
	map_node.add_child(team_b_hq_marker)

# Signal handlers
func _on_grid_initialized() -> void:
	apply_map_to_grid()