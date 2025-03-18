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

func debug_log(message: String, level: String = "info", context: String = "") -> void:
    var logger = get_node_or_null("/root/UnifiedLogger")
    if logger:
        match level.to_lower():
            "error":
                logger.error(message, context if context else "Worker")
            "warning":
                logger.warning(message, context if context else "Worker")
            "debug":
                logger.debug(message, context if context else "Worker")
            "verbose":
                logger.verbose(message, context if context else "Worker")
            _:
                logger.info(message, context if context else "Worker")
    else:
        # Fallback to print
        var prefix = "[" + level.to_upper() + "]"
        if context:
            prefix += "[" + context + "]"
        else:
            prefix += "[Worker]"
        print(prefix + " " + message)

func _ready() -> void:
    # Get references to manager nodes
    _get_manager_references()
    
    # Setup worker visuals
    _setup_visuals()
    
    # Setup building ghost for placement preview
    _setup_building_ghost()
    
    # Add the worker to the units group
    if not is_in_group("units"):
        add_to_group("units")
    
    # Setup debug logging
    debug_log("Worker initialized for team " + str(team), "info", "Worker")

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
    # Try to get references from game manager first
    var game_manager = get_node_or_null("/root/GameManager")
    var service_locator = get_node_or_null("/root/ServiceLocator")
    
    # Prioritize service locator if available
    if service_locator:
        grid_system = service_locator.get_service("GridSystem")
        building_manager = service_locator.get_service("BuildingManager")
        economy_manager = service_locator.get_service("EconomyManager")
        ui_manager = service_locator.get_service("UIManager")
    
    # Fallback to direct node lookup
    if not grid_system:
        grid_system = get_node_or_null("/root/GridSystem")
    
    if not building_manager:
        building_manager = get_node_or_null("/root/BuildingManager")
    
    if not economy_manager:
        economy_manager = get_node_or_null("/root/EconomyManager")
    
    if not ui_manager:
        ui_manager = get_node_or_null("/root/UIManager")
    
    # If game manager exists, try getting references from there
    if game_manager:
        if not grid_system:
            grid_system = game_manager.get_node_or_null("GridSystem")
        if not building_manager:
            building_manager = game_manager.get_node_or_null("BuildingManager")
        if not economy_manager:
            economy_manager = game_manager.get_node_or_null("EconomyManager")
        if not ui_manager:
            ui_manager = game_manager.get_node_or_null("UIManager")
    
    # Log any missing references
    debug_log("Manager references initialized", "debug")
    
    if not grid_system:
        debug_log("Warning: GridSystem not found", "warning")
    if not building_manager:
        debug_log("Warning: BuildingManager not found", "warning")
    if not economy_manager:
        debug_log("Warning: EconomyManager not found", "warning")
    if not ui_manager:
        debug_log("Warning: UIManager not found", "warning")

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
        debug_log("Moving worker with velocity: " + str(velocity), "debug")
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

func _execute_repair_command(params: Dictionary) -> void:
    # Find the target building to repair
    var target_building = params.get("target")
    
    # Validate the target
    if not target_building or not is_instance_valid(target_building):
        debug_log("Repair command failed: Invalid target", "warning")
        return
    
    # Check if the building belongs to the worker's team
    if target_building.team != team:
        debug_log("Cannot repair enemy building", "warning")
        return
    
    # Check if the building needs repair
    if target_building.health >= target_building.max_health:
        debug_log("Building is already at full health", "info")
        return
    
    # Set the command state
    current_command = CommandType.REPAIR
    command_target = target_building
    command_params = params
    
    # Move to the building if not in repair range
    var distance = global_position.distance_to(target_building.global_position)
    if distance > repair_range:
        # Move closer to the building
        move_to(target_building.global_position, {
            "is_building_target": true,
            "cancel_current_action": true
        })
    else:
        # Already in range, start auto-repair
        auto_repair = true
        current_target_building = target_building

func handle_command(command_type, params: Dictionary = {}) -> void:
    match command_type:
        CommandType.MOVE:
            _execute_move_command(params)
        CommandType.BUILD:
            _execute_build_command(params)
        CommandType.REPAIR:
            _execute_repair_command(params)
        CommandType.STOP:
            _stop_current_action()

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
        debug_log("Cannot place building: Missing manager references", "warning")
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
        debug_log("Cannot place building: Invalid position", "warning")
        return
    
    # Check if we can afford it
    if not economy_manager.can_afford_building(team, current_building_type):
        debug_log("Cannot place building: Cannot afford", "warning")
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
        debug_log("Failed to place building", "warning")

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
    
    debug_log("Auto-repair " + ("enabled" if auto_repair else "disabled"), "info")

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

func move_to(pos: Vector2, options: Dictionary = {}) -> void:
    debug_log("Worker moving to " + str(pos), "debug")
    target_position = pos
    is_moving_to_target = true
    current_target_building = options.get("is_building_target", false)
    
    # Cancel any current action if requested
    if options.get("cancel_current_action", true):
        if is_placing_building:
            cancel_building_placement()

func select() -> void:
    debug_log("Worker select() called. Current team: " + str(team), "debug")
    is_selected = true
    
    # Create or update selection indicator
    var selection_indicator = get_node_or_null("SelectionIndicator")
    if not selection_indicator:
        # Create a new selection indicator
        selection_indicator = Node2D.new()
        selection_indicator.name = "SelectionIndicator"
        add_child(selection_indicator)
        
        # Create visual indicator (a simple colored rectangle)
        var rect = ColorRect.new()
        rect.rect_size = Vector2(32, 32)
        rect.rect_position = Vector2(-16, -16)
        rect.color = Color(0, 1, 0, 0.3) # Semi-transparent green
        selection_indicator.add_child(rect)
    
    # Make selection indicator visible
    selection_indicator.visible = true
    
    # More verbose logging for UI manager interaction
    var worker_ui_manager = get_node_or_null("/root/GameManager/UIManager")
    if worker_ui_manager:
        debug_log("Attempting to select worker with UI Manager. Team: " + str(team), "debug")
        worker_ui_manager.select_worker(self)
    else:
        debug_log("No UI Manager found during worker selection", "warning")

# Deselect this worker
func deselect() -> void:
    is_selected = false
    var selection_indicator = get_node_or_null("SelectionIndicator")
    if selection_indicator:
        selection_indicator.visible = false

# Get worker's team
func get_team() -> int:
    return team

# Add or modify this function in your worker.gd script
func _setup_visuals() -> void:
    debug_log("Setting up worker visuals for team " + str(team), "debug")
    
    # Create or get sprite
    var sprite = get_node_or_null("Sprite")
    if not sprite:
        debug_log("Creating new Sprite node", "debug")
        sprite = Sprite.new()
        sprite.name = "Sprite"
        add_child(sprite)
    
    # Try to load texture from path
    var texture_path = "res://assets/units/human/worker/idle/idle.png"
    var texture = load(texture_path)
    
    
    # Set the texture
    sprite.texture = texture
    
    # Set color based on team
    if team == 0:
        sprite.modulate = Color(0, 0, 1) # Blue for Team A
    else:
        sprite.modulate = Color(1, 0, 0) # Red for Team B
    
    debug_log("Worker visuals setup complete", "debug")

func _execute_move_command(params: Dictionary) -> void:
    var move_target_position = params.get("position", Vector2.ZERO)
    var move_options = params.get("options", {})
    move_to(move_target_position, move_options)

func _execute_build_command(params: Dictionary) -> void:
    var building_type = params.get("building_type", "")
    var size = params.get("size", Vector2.ONE)
    
    # If a specific position is provided, consider how to handle it
    # You might want to move to that position first
    var position = params.get("position", null)
    
    if position:
        # Move to the specified position first, then start building placement
        move_to(position, {
            "is_building_target": true,
            "cancel_current_action": true
        })
    
    # Always start building placement from current position
    start_building_placement(building_type, size)

func _stop_current_action() -> void:
    is_moving_to_target = false
    velocity = Vector2.ZERO
    current_command = null
    command_target = null
    command_params = {}
    
    if is_placing_building:
        cancel_building_placement()
