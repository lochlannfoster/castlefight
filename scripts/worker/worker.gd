# Worker Unit - The player-controlled builder unit
# Path: scripts/worker/worker.gd
extends KinematicBody2D

# Signals
signal building_placement_started(building_type, size)
signal building_placement_completed(building_type, position)
signal building_placement_cancelled
signal auto_repair_toggled(enabled)

# Movement properties
export var speed: float = 200.0
export var team: int = 0 # 0 = Team A, 1 = Team B
export var acceleration: float = 800.0
export var friction: float = 600.0

# Building placement properties
var is_placing_building: bool = false
var current_building_type: String = ""
var current_building_size: Vector2 = Vector2.ONE
var building_ghost: Node2D
var can_place: bool = false
var placement_range: float = 100.0 # How far the worker can place a building from itself

enum CommandType {
    MOVE,
    BUILD,
    REPAIR,
    STOP
}

# Add with the other property declarations
var current_command = null
var command_target = null
var command_params = {}

# Auto-repair properties
var auto_repair: bool = false
var repair_range: float = 150.0
var repair_amount: float = 5.0
var repair_interval: float = 0.5
var repair_timer: float = 0.0

# References
var grid_system
var building_manager
var economy_manager
var ui_manager

# State tracking
var velocity: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var is_moving_to_target: bool = false
var current_target_building = null
var is_selected: bool = false

func _physics_process(delta: float) -> void:
    # If selected, handle player input
    if is_selected:
        _handle_input()
    
    # Handle movement
    _handle_movement(delta)
    
    # Update building placement preview if active
    if is_placing_building:
        _update_building_preview()
    
    # Handle auto-repair if enabled
    if auto_repair:
        _handle_auto_repair(delta)
    
    # Check if we need to continue processing a command
    if current_command == CommandType.REPAIR and command_target != null:
        # Check if we're in range of repair target
        var distance = global_position.distance_to(command_target.global_position)
        if distance <= repair_range:
            # We're in range, start repairing
            auto_repair = true
            _handle_auto_repair(delta)
        elif !is_moving_to_target:
            # We're not in range and not moving, start moving to target
            move_to(command_target.global_position)

# Get references to manager nodes
func _get_manager_references() -> void:
    # Try multiple paths for each manager
    grid_system = get_node_or_null("/root/GridSystem")
    if not grid_system:
        grid_system = get_node_or_null("/root/GameManager/GridSystem")
    
    # Get game manager
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager:
        # Try to get managers from game manager
        building_manager = game_manager.get_node_or_null("BuildingManager")
        if not building_manager:
            building_manager = get_node_or_null("/root/BuildingManager")
            
        economy_manager = game_manager.get_node_or_null("EconomyManager")
        if not economy_manager:
            economy_manager = get_node_or_null("/root/EconomyManager")
            
        ui_manager = game_manager.get_node_or_null("UIManager")
        if not ui_manager:
            ui_manager = get_node_or_null("/root/UIManager")
    else:
        # Fallback to root level managers
        building_manager = get_node_or_null("/root/BuildingManager")
        economy_manager = get_node_or_null("/root/EconomyManager")
        ui_manager = get_node_or_null("/root/UIManager")
    
    # Additional logging for debugging
    print("Worker references - Grid: ", grid_system != null,
          " Building: ", building_manager != null,
          " Economy: ", economy_manager != null,
          " UI: ", ui_manager != null)

# Set up building ghost for placement preview
func _setup_building_ghost() -> void:
    building_ghost = Node2D.new()
    building_ghost.name = "BuildingGhost"
    add_child(building_ghost)
    
    var ghost_visual = ColorRect.new()
    ghost_visual.name = "GhostVisual"
    ghost_visual.rect_size = Vector2(64, 64) # Default size, will be updated
    ghost_visual.rect_position = Vector2(-32, -32)
    ghost_visual.color = Color(0, 1, 0, 0.5) # Green transparent
    building_ghost.add_child(ghost_visual)
    
    # Hide by default
    building_ghost.visible = false

# Handle input for the worker
func _handle_input() -> void:
    # Get input direction
    var input_direction = Vector2.ZERO
    
    # Check for arrow key input
    if Input.is_action_pressed("ui_right"):
        input_direction.x += 1
    if Input.is_action_pressed("ui_left"):
        input_direction.x -= 1
    if Input.is_action_pressed("ui_down"):
        input_direction.y += 1
    if Input.is_action_pressed("ui_up"):
        input_direction.y -= 1
    
    # Apply input to velocity
    if input_direction != Vector2.ZERO:
        is_moving_to_target = false
        velocity = input_direction.normalized() * speed
        print("Moving worker with velocity: " + str(velocity))
    elif not is_moving_to_target:
        velocity = velocity.move_toward(Vector2.ZERO, friction)
    
    # Building placement - left click to place
    if is_placing_building and Input.is_action_just_pressed("select"):
        var mouse_pos = get_global_mouse_position()
        _try_place_building(mouse_pos)
    
    # Cancel building placement - right click or ESC
    if is_placing_building and (Input.is_action_just_pressed("ui_cancel") or Input.is_mouse_button_pressed(BUTTON_RIGHT)):
        cancel_building_placement()
    
    # Apply input to velocity
    if input_direction != Vector2.ZERO:
        is_moving_to_target = false
        velocity = input_direction.normalized() * speed
    elif not is_moving_to_target:
        velocity = velocity.move_toward(Vector2.ZERO, friction)
    
    # Building placement - left click to place
    if is_placing_building and Input.is_action_just_pressed("select"):
        var mouse_pos = get_global_mouse_position()
        _try_place_building(mouse_pos)
    
    # Cancel building placement - right click
    if is_placing_building and Input.is_action_just_pressed("ui_cancel"):
        cancel_building_placement()

func handle_command(command_type, params = {}) -> void:
    # Reset current command
    current_command = command_type
    command_params = params
    
    match command_type:
        CommandType.MOVE:
            if params.has("position"):
                move_to(params.position)
                
        CommandType.BUILD:
            if params.has("building_type") and params.has("size"):
                # Start building placement
                start_building_placement(params.building_type, params.size)
                # If position is specified, try to place it there
                if params.has("position"):
                    _try_place_building(params.position)
                    
        CommandType.REPAIR:
            if params.has("building"):
                command_target = params.building
                # Move to building first if not in range
                var distance = global_position.distance_to(command_target.global_position)
                if distance > repair_range:
                    move_to(command_target.global_position)
                # Otherwise start repairing
                else:
                    # Start auto-repair temporarily
                    var was_auto_repair = auto_repair
                    auto_repair = true
                    _handle_auto_repair(0.1) # Try immediate repair
                    auto_repair = was_auto_repair
                    
        CommandType.STOP:
            # Stop current action
            is_moving_to_target = false
            velocity = Vector2.ZERO
            current_command = null
            command_target = null
            command_params = {}
            if is_placing_building:
                cancel_building_placement()

# Handle movement
func _handle_movement(_delta: float) -> void:
    if is_moving_to_target:
        # Move towards target position
        var direction = global_position.direction_to(target_position)
        var distance = global_position.distance_to(target_position)
        
        if distance < 10:
            # Reached target
            is_moving_to_target = false
            velocity = Vector2.ZERO
            
            # If moving to place a building, try placing it
            if is_placing_building and current_target_building:
                _try_place_building(target_position)
        else:
            velocity = direction * speed
    
    # Apply movement
    velocity = move_and_slide(velocity)

# Update building preview during placement
func _update_building_preview() -> void:
    var mouse_pos = get_global_mouse_position()
    
    # Get grid position
    var grid_pos = grid_system.world_to_grid(mouse_pos) if grid_system else Vector2.ZERO
    var world_pos = grid_system.grid_to_world(grid_pos) if grid_system else mouse_pos
    
    # Update ghost position
    building_ghost.global_position = world_pos
    
    # Check if placement is valid
    can_place = _can_place_at_position(grid_pos)
    
    # Update ghost color
    var ghost_visual = building_ghost.get_node("GhostVisual")
    if ghost_visual:
        ghost_visual.color = Color(0, 1, 0, 0.5) if can_place else Color(1, 0, 0, 0.5)

# Start building placement
func start_building_placement(building_type: String, size: Vector2) -> void:
    current_building_type = building_type
    current_building_size = size
    is_placing_building = true
    
    # Update ghost size
    var ghost_visual = building_ghost.get_node("GhostVisual")
    if ghost_visual:
        ghost_visual.rect_size = size * grid_system.cell_size if grid_system else Vector2(64, 64) * size
        ghost_visual.rect_position = - ghost_visual.rect_size / 2
    
    building_ghost.visible = true
    
    emit_signal("building_placement_started", building_type, size)

# Try to place a building at the given position
func _try_place_building(position: Vector2) -> void:
    if not building_manager or not grid_system:
        print("Cannot place building: Missing manager references")
        return
    
    var grid_pos = grid_system.world_to_grid(position)
    
    # Check if worker is close enough to place
    var distance_to_place = global_position.distance_to(position)
    if distance_to_place > placement_range:
        # Too far to place, move closer
        target_position = position
        is_moving_to_target = true
        current_target_building = true # Flag that we're moving to place a building
        return
    
    # Check if placement is valid
    if not _can_place_at_position(grid_pos):
        print("Cannot place building: Invalid position")
        return
    
    # Check if we can afford it
    if not economy_manager.can_afford_building(team, current_building_type):
        print("Cannot place building: Cannot afford")
        return
    
    # Place the building
    var building = building_manager.place_building(current_building_type, position, team)
    
    if building:
        emit_signal("building_placement_completed", current_building_type, position)
        
        # Stop placement mode
        is_placing_building = false
        building_ghost.visible = false
        current_building_type = ""
        current_building_size = Vector2.ONE
    else:
        print("Failed to place building")

# Cancel building placement
func cancel_building_placement() -> void:
    is_placing_building = false
    building_ghost.visible = false
    current_building_type = ""
    current_building_size = Vector2.ONE
    
    emit_signal("building_placement_cancelled")

# Check if a building can be placed at the given grid position
func _can_place_at_position(grid_pos: Vector2) -> bool:
    if not grid_system:
        return false
    
    return grid_system.can_place_building(grid_pos, current_building_size, team)

# Toggle auto-repair mode
func toggle_auto_repair() -> void:
    auto_repair = !auto_repair
    emit_signal("auto_repair_toggled", auto_repair)
    
    print("Auto-repair ", "enabled" if auto_repair else "disabled")

# Handle auto-repair of nearby buildings
func _handle_auto_repair(delta: float) -> void:
    if not auto_repair or not building_manager:
        return
    
    repair_timer += delta
    
    if repair_timer >= repair_interval:
        repair_timer = 0
        
        # Find damaged buildings in range
        var buildings = building_manager.get_team_buildings(team)
        var closest_damaged = null
        var closest_distance = repair_range
        
        for building in buildings:
            if building.health < building.max_health:
                var distance = global_position.distance_to(building.global_position)
                if distance < closest_distance:
                    closest_damaged = building
                    closest_distance = distance
        
        # Repair the closest damaged building
        if closest_damaged:
            closest_damaged.repair(repair_amount)

# Move to a target position
func move_to(pos: Vector2) -> void:
  print("Worker moving to " + str(pos))
  target_position = pos
  is_moving_to_target = true
  current_target_building = false

func select() -> void:
    print("DEBUG: Worker select() called. Current team: " + str(team))
    is_selected = true
    
    # Create or update selection indicator
    var selection_indicator = get_node_or_null("SelectionIndicator")
    if not selection_indicator:
        selection_indicator = Node2D.new()
        selection_indicator.name = "SelectionIndicator"
        
        # Create a simple selection visual
        var selection_rect = ColorRect.new()
        selection_rect.rect_size = Vector2(32, 32)
        selection_rect.rect_position = Vector2(-16, -16)
        selection_rect.color = Color(0, 1, 1, 0.3) # Cyan semi-transparent
        selection_indicator.add_child(selection_rect)
        
        # Hide by default
        selection_indicator.visible = true
        add_child(selection_indicator)
    else:
        selection_indicator.visible = true
    
    # More verbose logging for UI manager interaction
    var worker_ui_manager = get_node_or_null("/root/GameManager/UIManager")
    if worker_ui_manager:
        print("DEBUG: Attempting to select worker with UI Manager. Team: " + str(team))
        worker_ui_manager.select_worker(self)
    else:
        print("WARNING: No UI Manager found during worker selection")

# Deselect this worker
func deselect() -> void:
    is_selected = false
    var selection_indicator = get_node_or_null("SelectionIndicator")
    if selection_indicator:
        selection_indicator.visible = false

# Get worker's team
func get_team() -> int:
    return team

func _ready() -> void:
    print("Worker initialized. Team: " + str(team))
    
    # Get references to manager nodes
    _get_manager_references()
    
    # Set up visual appearance for the worker
    _setup_visuals()
    
    # Set up building ghost for placement preview
    _setup_building_ghost()
    
    # Set up selection indicator
    var selection_indicator = Node2D.new()
    selection_indicator.name = "SelectionIndicator"
    
    # Create a simple selection visual
    var selection_rect = ColorRect.new()
    selection_rect.rect_size = Vector2(32, 32)
    selection_rect.rect_position = Vector2(-16, -16)
    selection_rect.color = Color(0, 1, 1, 0.3) # Cyan semi-transparent
    selection_indicator.add_child(selection_rect)
    
    # Hide by default
    selection_indicator.visible = false
    add_child(selection_indicator)
    
    print("Worker ready complete")
    print("Worker initialized. Team: " + str(team))

# Add or modify this function in your worker.gd script
func _setup_visuals() -> void:
    print("Setting up worker visuals for team " + str(team))
    
    # Create or get sprite
    var sprite = get_node_or_null("Sprite")
    if not sprite:
        print("Creating new Sprite node")
        sprite = Sprite.new()
        sprite.name = "Sprite"
        add_child(sprite)
    
    # Try to load texture from path
    var texture_path = "res://assets/units/human/worker/idle/idle.png"
    var texture = load(texture_path)
    
    # If loading fails, try fallback method
    if not texture:
        print("Failed to load worker texture, trying fallback")
        
        # Create a placeholder texture
        var img = Image.new()
        img.create(32, 32, false, Image.FORMAT_RGBA8)
        
        # Fill with team color
        var color = Color(0, 0, 1) if team == 0 else Color(1, 0, 0)
        img.fill(color)
        
        # Draw a simple worker figure
        for x in range(12, 20):
            for y in range(16, 24):
                img.set_pixel(x, y, Color.white)
        
        for y in range(16, 28):
            img.set_pixel(16, y, Color.white)
        
        # Create texture
        texture = ImageTexture.new()
        texture.create_from_image(img)
        print("Created fallback worker texture")
    
    # Set the texture
    sprite.texture = texture
    
    # Set color based on team
    if team == 0:
        sprite.modulate = Color(0, 0, 1) # Blue for Team A
    else:
        sprite.modulate = Color(1, 0, 0) # Red for Team B
    
    print("Worker visuals setup complete")
