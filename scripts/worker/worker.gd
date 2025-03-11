# Worker unit - the only player-controlled unit
# Path: scripts/worker/worker.gd
class_name Worker
extends KinematicBody2D

# Worker signals
signal building_placement_started(building_type, position)
signal building_placement_canceled
signal building_construction_started(building_type, position)
signal building_construction_completed(building_reference)
signal worker_item_purchased(item_reference)
signal worker_item_used(item_reference)

# Worker properties
export var speed: float = 200.0  # Movement speed
export var team: int = 0  # 0 = Team A, 1 = Team B
export var build_range: float = 100.0  # How close worker must be to build

# Building placement variables
var is_placing_building: bool = false
var current_building_type: String = ""
var building_size: Vector2 = Vector2.ONE
var can_place: bool = false
var placement_indicator: Node2D
var construction_time: Dictionary = {}  # Dictionary of building types and their construction times

# Path finding variables
var path: Array = []
var current_target: Vector2 = Vector2.ZERO
var move_to_target: bool = false
var pathfinding: AStar2D

# References to game systems
var grid_system: GridSystem
var economy_manager

# Inventory system
var inventory: Array = []
var max_inventory_size: int = 6

# Animation handling
var animation_player: AnimationPlayer
var sprite: Sprite
var current_animation: String = "idle"

# Auto-repair variables
var auto_repair_enabled: bool = false
var repair_range: float = 150.0
var repair_amount: float = 2.0
var repair_interval: float = 1.0
var repair_timer: float = 0.0

# Initialization
func _ready() -> void:
	# Get references to required systems
	grid_system = get_node("/root/GameManager/GridSystem")
	economy_manager = get_node("/root/GameManager/EconomyManager")
	
	# Setup animation
	animation_player = $AnimationPlayer
	sprite = $Sprite
	
	# Create placement indicator
	_create_placement_indicator()
	
	# Setup pathfinding
	_initialize_pathfinding()

# Handle movement and input processing
func _physics_process(delta: float) -> void:
	# Check if this worker should be controllable by the local player
	if _is_locally_controllable():
		# Handle player input for worker movement
		_handle_movement(delta)
		
		# Handle construction functionality
		if is_placing_building:
			_update_building_placement()
	
	# Auto-repair nearby buildings if enabled
	if auto_repair_enabled:
		_handle_auto_repair(delta)
		
# Determine if this worker should be controllable by the local player
func _is_locally_controllable() -> bool:
	# Get reference to network manager
	var network_manager = get_node_or_null("/root/GameManager/NetworkManager")
	if not network_manager:
		# If no network manager, this is single player or not networked - allow control
		return true
		
	# In debug mode, server can control all workers
	if network_manager.is_server and network_manager.debug_mode:
		return true
		
	# Check if this worker's team matches the local player's team
	var local_player_id = network_manager.local_player_id
	if network_manager.player_info.has(local_player_id):
		var local_player_team = network_manager.player_info[local_player_id].team
		return team == local_player_team
	
	# Default: not controllable
	return false

# Handle worker movement based on player input or path
func _handle_movement(delta: float) -> void:
	var velocity = Vector2.ZERO
	
	if move_to_target and not path.empty():
		# Path following logic
		var next_point = path[0]
		var distance_to_next = global_position.distance_to(next_point)
		
		if distance_to_next < 10:  # If close enough to the next point
			path.remove(0)  # Remove the first point
			
			if path.empty():
				move_to_target = false
				
				# If we were trying to reach a building placement spot, start building
				if is_placing_building and can_place:
					_start_construction()
				return
		
		# Move toward the next point
		velocity = global_position.direction_to(next_point) * speed
	else:
		# Direct control via keyboard/gamepad
		var input_dir = Vector2.ZERO
		input_dir.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		input_dir.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		
		# Normalize to prevent faster diagonal movement
		if input_dir.length() > 1:
			input_dir = input_dir.normalized()
			
		velocity = input_dir * speed
	
	# Apply movement
	velocity = move_and_slide(velocity)
	
	# Update animation based on movement
	_update_animation(velocity)

# Update worker animation based on current state
func _update_animation(velocity: Vector2) -> void:
	var new_animation = "idle"
	
	if velocity.length() > 10:  # If moving
		new_animation = "walk"
		
		# Set facing direction based on movement
		sprite.flip_h = velocity.x < 0
	elif is_placing_building:
		new_animation = "build"
	
	# Play animation if it's different
	if new_animation != current_animation:
		animation_player.play(new_animation)
		current_animation = new_animation

# Initialize pathfinding system
func _initialize_pathfinding() -> void:
	pathfinding = AStar2D.new()
	
	# Wait for grid system to be initialized
	if not grid_system.is_connected("grid_initialized", self, "_on_grid_initialized"):
		grid_system.connect("grid_initialized", self, "_on_grid_initialized")
	
	if grid_system.grid_cells.size() > 0:
		_setup_pathfinding_points()

# Setup pathfinding points based on grid
func _setup_pathfinding_points() -> void:
	pathfinding.clear()
	
	# Add all walkable cells as points
	for grid_pos in grid_system.grid_cells.keys():
		var cell = grid_system.grid_cells[grid_pos]
		if cell.walkable:
			# Convert 2D vector to unique ID
			var point_id = _get_point_id(grid_pos)
			pathfinding.add_point(point_id, cell.world_position)
	
	# Connect points with their neighbors
	for grid_pos in grid_system.grid_cells.keys():
		if not grid_system.grid_cells[grid_pos].walkable:
			continue
			
		var point_id = _get_point_id(grid_pos)
		
		# Check all 8 surrounding cells (cardinal + diagonal)
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0:
					continue  # Skip the cell itself
					
				var neighbor_pos = grid_pos + Vector2(x, y)
				if grid_system.is_within_grid(neighbor_pos) and grid_system.grid_cells[neighbor_pos].walkable:
					var neighbor_id = _get_point_id(neighbor_pos)
					
					# Calculate distance (use higher weight for diagonal)
					var weight = 1.0
					if abs(x) + abs(y) == 2:  # Diagonal movement
						weight = 1.4  # Approximately sqrt(2)
						
					# Connect points if not already connected
					if not pathfinding.are_points_connected(point_id, neighbor_id):
						pathfinding.connect_points(point_id, neighbor_id, weight)

# Convert grid position to unique point ID for AStar2D
func _get_point_id(grid_pos: Vector2) -> int:
	return int(grid_pos.y * grid_system.grid_width + grid_pos.x)

# Called when grid system is initialized
func _on_grid_initialized() -> void:
	_setup_pathfinding_points()

# Start building placement mode
func start_building_placement(building_type: String, size: Vector2 = Vector2.ONE) -> void:
	current_building_type = building_type
	building_size = size
	is_placing_building = true
	can_place = false
	
	# Make placement indicator visible
	placement_indicator.visible = true
	
	# Tell grid system to highlight valid cells
	var valid_cells = grid_system.highlight_valid_cells(building_size, team)
	
	emit_signal("building_placement_started", building_type, Vector2.ZERO)

# Cancel building placement
func cancel_building_placement() -> void:
	is_placing_building = false
	current_building_type = ""
	placement_indicator.visible = false
	
	# Clear grid highlights
	grid_system.clear_highlights()
	
	emit_signal("building_placement_canceled")

# Update building placement indicator
func _update_building_placement() -> void:
	# Get mouse position in world coordinates
	var mouse_pos = get_global_mouse_position()
	
	# Convert to grid position
	var grid_pos = grid_system.world_to_grid(mouse_pos)
	
	# Check if placement is valid
	can_place = grid_system.can_place_building(grid_pos, building_size, team)
	
	# Update placement indicator
	placement_indicator.position = grid_system.grid_to_world(grid_pos)
	
	# Set color based on validity
	if can_place:
		placement_indicator.modulate = Color(0, 1, 0, 0.5)  # Green for valid
	else:
		placement_indicator.modulate = Color(1, 0, 0, 0.5)  # Red for invalid
	
	# If player clicks, attempt to place or move to position
	if Input.is_action_just_pressed("ui_select"):  # Left click
		if can_place:
			# Check if worker is in range
			var distance_to_placement = global_position.distance_to(grid_system.grid_to_world(grid_pos))
			
			if distance_to_placement <= build_range:
				# Worker is in range, start construction
				_start_construction()
			else:
				# Worker needs to move closer first
				move_to_position(grid_system.grid_to_world(grid_pos))
		else:
			# Can't place here, do nothing or provide feedback
			pass
	
	# Right click to cancel placement
	if Input.is_action_just_pressed("ui_cancel"):  # Right click
		cancel_building_placement()

# Create placement indicator visual
func _create_placement_indicator() -> void:
	placement_indicator = Node2D.new()
	placement_indicator.name = "PlacementIndicator"
	add_child(placement_indicator)
	
	# Create a rectangle showing building size
	var rect = ColorRect.new()
	rect.rect_size = Vector2(building_size.x * grid_system.cell_size.x, 
							 building_size.y * grid_system.cell_size.y)
	rect.rect_position = -rect.rect_size/2  # Center it
	rect.color = Color(0, 1, 0, 0.3)
	placement_indicator.add_child(rect)
	
	# Hide until needed
	placement_indicator.visible = false

# Start construction of a building
func _start_construction() -> void:
	# Get grid position
	var grid_pos = grid_system.world_to_grid(placement_indicator.global_position)
	
	# Check if we can afford the building
	if not economy_manager.can_afford_building(current_building_type):
		# Can't afford, provide feedback and cancel
		print("Can't afford this building!")
		cancel_building_placement()
		return
	
	# Deduct the resources
	economy_manager.purchase_building(current_building_type)
	
	# Mark cells as occupied
	for x in range(building_size.x):
		for y in range(building_size.y):
			var cell_pos = grid_pos + Vector2(x, y)
			grid_system.occupy_cell(cell_pos)
	
	# Start construction animation/process
	emit_signal("building_construction_started", current_building_type, grid_system.grid_to_world(grid_pos))
	
	# Update pathfinding graph
	_setup_pathfinding_points()
	
	# Reset building placement mode
	is_placing_building = false
	placement_indicator.visible = false
	grid_system.clear_highlights()
	
	# TODO: Create actual building instance or defer to a BuildingManager

# Move worker to a specific position
func move_to_position(target_position: Vector2) -> void:
	# Convert target to grid position to ensure it's on the grid
	var grid_target = grid_system.world_to_grid(target_position)
	var world_target = grid_system.grid_to_world(grid_target)
	
	# Find path using AStar
	var start_grid_pos = grid_system.world_to_grid(global_position)
	var end_grid_pos = grid_target
	
	var start_id = _get_point_id(start_grid_pos)
	var end_id = _get_point_id(end_grid_pos)
	
	# Make sure both points exist in the pathfinding graph
	if not pathfinding.has_point(start_id):
		var closest_point = _find_closest_walkable_point(start_grid_pos)
		start_id = _get_point_id(closest_point)
		
	if not pathfinding.has_point(end_id):
		var closest_point = _find_closest_walkable_point(end_grid_pos)
		end_id = _get_point_id(closest_point)
	
	# Get path
	var id_path = pathfinding.get_id_path(start_id, end_id)
	
	# Convert ID path to positions
	path = []
	for id in id_path:
		path.append(pathfinding.get_point_position(id))
	
	# Remove the first point if it's too close to current position
	if not path.empty() and global_position.distance_to(path[0]) < 10:
		path.remove(0)
	
	# Start moving
	move_to_target = true
	current_target = world_target

# Find closest walkable point to a given grid position
func _find_closest_walkable_point(grid_pos: Vector2) -> Vector2:
	var closest_dist = INF
	var closest_pos = grid_pos
	
	# Check a 5x5 area around the target
	for x in range(-2, 3):
		for y in range(-2, 3):
			var check_pos = grid_pos + Vector2(x, y)
			
			if not grid_system.is_within_grid(check_pos):
				continue
				
			if not grid_system.grid_cells[check_pos].walkable:
				continue
				
			var dist = grid_pos.distance_squared_to(check_pos)
			if dist < closest_dist:
				closest_dist = dist
				closest_pos = check_pos
	
	return closest_pos

# Toggle auto-repair functionality
func toggle_auto_repair() -> void:
	auto_repair_enabled = !auto_repair_enabled
	print("Auto-repair: ", "Enabled" if auto_repair_enabled else "Disabled")

# Handle auto-repair of nearby buildings
func _handle_auto_repair(delta: float) -> void:
	repair_timer += delta
	
	if repair_timer >= repair_interval:
		repair_timer = 0
		
		# Find damaged buildings in range
		var space_state = get_world_2d().direct_space_state
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = repair_range
		
		var query = Physics2DShapeQueryParameters.new()
		query.set_shape(circle_shape)
		query.transform = global_transform
		query.collide_with_bodies = true
		query.collision_layer = 2  # Assuming buildings are on layer 2
		
		var result = space_state.intersect_shape(query)
		
		# Repair the first damaged building found
		for collision in result:
			var collider = collision.collider
			if collider.has_method("repair") and collider.team == team and collider.health < collider.max_health:
				collider.repair(repair_amount)
				
				# Play repair animation/effect if available
				if animation_player.has_animation("repair"):
					animation_player.play("repair")
				break

# Purchase and equip an item
func purchase_item(item_type: String) -> bool:
	# Check if inventory has space
	if inventory.size() >= max_inventory_size:
		print("Inventory full!")
		return false
	
	# Check if player can afford the item
	if not economy_manager.can_afford_item(item_type):
		print("Can't afford this item!")
		return false
	
	# Deduct resources
	economy_manager.purchase_item(item_type)
	
	# Create item instance (depends on your item system implementation)
	var item = {
		"type": item_type,
		"uses_remaining": 3  # Example - could be defined in item data
	}
	
	# Add to inventory
	inventory.append(item)
	
	emit_signal("worker_item_purchased", item)
	return true

# Use an equipped item
func use_item(item_index: int) -> bool:
	if item_index < 0 or item_index >= inventory.size():
		return false
	
	var item = inventory[item_index]
	
	# Apply item effect (implement based on your game's items)
	print("Using item: ", item.type)
	
	# Reduce uses or remove if depleted
	item.uses_remaining -= 1
	if item.uses_remaining <= 0:
		inventory.remove(item_index)
	
	emit_signal("worker_item_used", item)
	return true

# Method for external calls to complete a building's construction
func complete_construction(building_reference) -> void:
	emit_signal("building_construction_completed", building_reference)
