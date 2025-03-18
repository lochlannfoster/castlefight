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
export var collision_radius: float = 16.0 # Add this line

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

var selection_start: Vector2 = Vector2.ZERO
var is_selecting: bool = false
var draw_selection: bool = false

export var debug_mode: bool = false

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
    
    # Connect to input events
    set_process_input(true)
    
    # Setup worker visuals
    _setup_visuals()
    
    # Make sure we have collision shape properly set up
    var collision = get_node_or_null("CollisionShape2D")
    if not collision:
        var new_collision = CollisionShape2D.new()
        var shape = CircleShape2D.new()
        # Use a default radius if collision_radius isn't defined
        var radius = 16.0
        if "collision_radius" in self:
            radius = collision_radius
        shape.radius = radius
        new_collision.shape = shape
        add_child(new_collision)
    
    # Setup building ghost for placement preview
    _setup_building_ghost()
    
    # Add the worker to the units group
    if not is_in_group("units"):
        add_to_group("units")
    
    # Add to clickable group
    if not is_in_group("selectable"):
        add_to_group("selectable")
    
    # If using input action "select" for mouse selection, ensure it exists
    if not InputMap.has_action("select"):
        InputMap.add_action("select")
        var event = InputEventMouseButton.new()
        event.button_index = BUTTON_LEFT
        event.pressed = true
        InputMap.action_add_event("select", event)
    
    # Setup debug logging
    debug_log("Worker initialized for team " + str(team), "info", "Worker")

func _physics_process(delta: float) -> void:
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

# Modify the _get_manager_references function to better locate the UI Manager
func _get_manager_references() -> void:
    # Try to get references from multiple possible locations
    var game_manager = get_node_or_null("/root/GameManager")
    var service_locator = get_node_or_null("/root/ServiceLocator")
    
    # Prioritize service locator if available
    if service_locator:
        grid_system = service_locator.get_service("GridSystem")
        building_manager = service_locator.get_service("BuildingManager")
        economy_manager = service_locator.get_service("EconomyManager")
        ui_manager = service_locator.get_service("UIManager")
    
    # Check if UI Manager is already directly in the scene tree
    if not ui_manager:
        ui_manager = get_node_or_null("/root/UIManager")
    
    # If not, try to find it via GameManager
    if not ui_manager and game_manager:
        ui_manager = game_manager.get_node_or_null("UIManager")
    
    # If all fails, try looking up in the current scene
    if not ui_manager:
        var current_scene = get_tree().get_current_scene()
        if current_scene:
            ui_manager = current_scene.get_node_or_null("UIManager")
    
    # Log the results for debugging
    debug_log("Manager references initialized", "debug")
    
    if not grid_system:
        debug_log("Warning: GridSystem not found", "warning")
    if not building_manager:
        debug_log("Warning: BuildingManager not found", "warning")
    if not economy_manager:
        debug_log("Warning: EconomyManager not found", "warning")
    if not ui_manager:
        debug_log("Warning: UIManager not found, worker movement may not function", "warning")

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

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        match event.scancode:
            KEY_G: # Toggle grid visualization
                var game_manager = get_node_or_null("/root/GameManager")
                if game_manager and game_manager.has_method("toggle_grid_visualization"):
                    game_manager.toggle_grid_visualization()
            
            KEY_R: # Toggle auto-repair
                if is_selected and has_method("toggle_auto_repair"):
                    toggle_auto_repair()
            
            KEY_ESCAPE:
                # Handle escape key, e.g., to cancel building placement
                var current_ui_manager = get_node_or_null("/root/UIManager")
                if current_ui_manager and current_ui_manager.selected_worker:
                    var worker = current_ui_manager.selected_worker
                    if worker.has_method("cancel_building_placement") and worker.is_placing_building:
                        worker.cancel_building_placement()

    # Mouse button handling
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            if event.pressed:
                # Start selection
                selection_start = event.position
                is_selecting = true
                draw_selection = false
            else:
                # End selection
                if is_selecting:
                    # Calculate selection rectangle in screen space
                    var end_pos = event.position
                    var rect = Rect2(
                        min(selection_start.x, end_pos.x),
                        min(selection_start.y, end_pos.y),
                        abs(end_pos.x - selection_start.x),
                        abs(end_pos.y - selection_start.y)
                    )
                    
                    # Only do selection if we've moved the mouse enough
                    if rect.size.length() > 5:
                        # In Godot 3.5.3, we need to handle world-to-screen conversion ourselves
                        # Get our camera instance
                        var camera = get_node_or_null("Camera2D")
                        if not camera:
                            camera = get_node_or_null("GameCamera")
                        
                        if camera and camera is Camera2D:
                            # Convert screen space to world space
                            var transform = get_viewport().get_canvas_transform()
                            var world_top_left = transform.affine_inverse().xform(rect.position)
                            var world_bottom_right = transform.affine_inverse().xform(rect.position + rect.size)
                            var world_rect = Rect2(world_top_left, world_bottom_right - world_top_left)
                            
                            # Select units in this world rectangle
                            _select_units_in_rectangle(world_rect, false)
                        else:
                            # Fallback if no camera is found
                            _select_units_in_rectangle(rect, false)
                    else:
                        # Just a click, select unit directly at position
                        var world_pos = get_global_mouse_position()
                        _select_unit_at_position(world_pos, false)
                
                is_selecting = false
                draw_selection = false
                update() # Redraw to clear selection box
        
        # Right-click handling for context-sensitive action
        elif event.button_index == BUTTON_RIGHT and event.pressed:
            # Only process if this worker is selected
            var current_ui_manager = get_node_or_null("/root/UIManager")
            if current_ui_manager and current_ui_manager.selected_worker == self:
                # Perform context-sensitive right-click action
                _handle_context_sensitive_action()

    # Mouse motion for selection box
    elif event is InputEventMouseMotion and is_selecting:
        if selection_start.distance_to(event.position) > 5:
            draw_selection = true
            update() # Request redraw to show selection box

    # Mouse motion handling for selection
    elif event is InputEventMouseMotion and is_selecting:
        # If mouse has moved enough, start drawing the selection box
        if selection_start.distance_to(event.position) > 5:
            draw_selection = true
            update() # Request redraw to show selection box

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

func _handle_movement(_delta: float) -> void:
    # If actively moving to a target
    if is_moving_to_target:
        # Calculate direction to target
        var direction = global_position.direction_to(target_position)
        var distance = global_position.distance_to(target_position)
        
        # Debug the movement
        if velocity != Vector2.ZERO:
            debug_log("Moving with velocity: " + str(velocity) + ", distance: " + str(distance), "verbose")
        
        # Stop when close enough
        if distance < 10:
            # Reached target
            is_moving_to_target = false
            velocity = Vector2.ZERO
            debug_log("Reached target position", "debug")
            
            # If moving to place a building, try placing it
            if is_placing_building and current_target_building:
                _try_place_building(target_position)
        else:
            # Update velocity based on direction to keep moving toward target
            velocity = direction * speed
    
    # Apply movement
    var previous_position = global_position
    velocity = move_and_slide(velocity)
    
    # If we didn't move but should have, we might be stuck - try to unstick
    if is_moving_to_target and previous_position.distance_to(global_position) < 0.1 and velocity.length() > 0:
        debug_log("Worker seems stuck, attempting to unstick", "debug")
        # Try slight variations in direction
        var perturbed_direction = global_position.direction_to(target_position).rotated(rand_range(-0.5, 0.5))
        velocity = perturbed_direction * speed
        # Try the new direction
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
    # Store the target position
    target_position = pos
    # Mark as moving
    is_moving_to_target = true
    current_target_building = options.get("is_building_target", false)
    
    # Calculate initial move direction
    var direction = global_position.direction_to(target_position)
    
    # Set an initial velocity based on direction
    velocity = direction.normalized() * speed
    
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
    
    # First try UIManager using multiple paths
    var worker_ui_manager = null
    
    # Try direct reference first
    if ui_manager:
        worker_ui_manager = ui_manager
    else:
        # Try root level
        worker_ui_manager = get_node_or_null("/root/UIManager")
        
        # Try under GameManager
        if not worker_ui_manager:
            var game_manager = get_node_or_null("/root/GameManager")
            if game_manager:
                worker_ui_manager = game_manager.get_node_or_null("UIManager")
                
        # Try service locator
        if not worker_ui_manager:
            var service_locator = get_node_or_null("/root/ServiceLocator")
            if service_locator:
                worker_ui_manager = service_locator.get_service("UIManager")
    
    if worker_ui_manager:
        debug_log("Successfully located UI Manager. Selecting worker.", "debug")
        if worker_ui_manager.has_method("select_worker"):
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

# Add this function for more direct worker movement
func direct_move_to_position(pos: Vector2) -> void:
    debug_log("Direct movement command to: " + str(pos), "debug")
    
    # Set target position and movement flags
    target_position = pos
    is_moving_to_target = true
    velocity = global_position.direction_to(target_position) * speed
    
    # Cancel any active building placement
    if is_placing_building:
        cancel_building_placement()

func _handle_context_sensitive_action() -> void:
    # Use raycasting to detect what's under the mouse
    var mouse_pos = get_global_mouse_position()
    
    var space_state = get_world_2d().direct_space_state
    var query = Physics2DShapeQueryParameters.new()
    var shape = CircleShape2D.new()
    shape.radius = 50 # Detection radius
    query.set_shape(shape)
    query.transform = Transform2D(0, mouse_pos)
    query.collision_layer = 2 # Adjust to match your game's collision layers
    
    var results = space_state.intersect_shape(query)
    
    for result in results:
        var collider = result.collider
        
        # Prioritize repairing damaged buildings on the same team
        if collider.has_method("repair") and collider.team == team:
            if collider.health < collider.max_health:
                current_command = CommandType.REPAIR
                command_target = collider
                move_to(collider.global_position, {
                    "is_building_target": true,
                    "cancel_current_action": true
                })
                return

func _select_units_in_rectangle(rect: Rect2, use_debug_mode: bool = false) -> void:
    # Get all selectable units
    var selectables = get_tree().get_nodes_in_group("selectable")
    
    # Find units within the rectangle
    var closest_unit = null
    var closest_distance = INF
    var selected_units = []
    
    for unit in selectables:
        # Use global_position for accurate world position
        if rect.has_point(unit.global_position):
            selected_units.append(unit)
            
            # Calculate distance to rect origin
            var distance = rect.position.distance_to(unit.global_position)
            if distance < closest_distance:
                closest_distance = distance
                closest_unit = unit
    
    # Deselect any previously selected units
    for unit in selectables:
        if unit.has_method("deselect"):
            unit.deselect()
    
    # If we found units, select the closest one
    if selected_units.size() > 0:
        # For debug mode, we can select any team's worker
        var nm = get_node_or_null("/root/NetworkManager")
        var is_debug = debug_mode # Use class-level debug_mode
        if nm:
            is_debug = nm.debug_mode
        
        # In debug mode, select closest
        if is_debug or use_debug_mode:
            if closest_unit and closest_unit.has_method("select"):
                closest_unit.select()
        else:
            # In normal mode, only select team's own workers
            var um = get_node_or_null("/root/UIManager")
            var current_team = 0
            if um:
                current_team = um.current_team
                
            for unit in selected_units:
                if unit.team == current_team and unit.has_method("select"):
                    unit.select()
                    break

func _select_unit_at_position(position: Vector2, use_debug_mode: bool = false) -> void:
    # Use a small selection area for direct clicks
    var small_rect = Rect2(position - Vector2(10, 10), Vector2(20, 20))
    _select_units_in_rectangle(small_rect, use_debug_mode)
