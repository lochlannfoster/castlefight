# Base class for all buildings
# Path: scripts/building/building_base.gd
class_name Building
extends StaticBody2D

# Building signals
signal unit_spawned(unit_reference)
signal building_destroyed
signal building_damaged(amount, attacker)
signal building_repaired(amount)
signal construction_progress_changed(progress)
signal construction_completed

# Building properties
export var building_id: String = "base_building"
export var display_name: String = "Building"
export var health: float = 100.0
export var max_health: float = 100.0
export var armor: float = 0.0
export var armor_type: String = "normal"  # normal, heavy, light, fortified, etc.
export var team: int = 0  # 0 = Team A, 1 = Team B
export var size: Vector2 = Vector2(1, 1)  # Size in grid cells
export var construction_time: float = 5.0  # Time in seconds to construct

# Spawning properties
export var can_spawn_units: bool = false
export var spawn_interval: float = 10.0  # Time between unit spawns
export var spawn_point_offset: Vector2 = Vector2(0, 32)  # Offset from building center
export var unit_types: Array = []  # Array of unit IDs this building can spawn

# Visual properties
export var construction_texture: Texture
export var completed_texture: Texture
export var damaged_texture: Texture
export var destroyed_texture: Texture

# State tracking
var is_constructed: bool = false
var is_spawning: bool = false
var construction_progress: float = 0.0
var spawn_timer: float = 0.0
var is_destroyed: bool = false

# References
var grid_system: GridSystem
var unit_factory
var sprite: Sprite
var animation_player: AnimationPlayer
var construction_progress_bar: ProgressBar
var selection_indicator: Node2D
var spawn_points: Array = []
var grid_position: Vector2

# Initialize
func _ready() -> void:
    # Get references
    grid_system = get_node("/root/GameManager/GridSystem")
    unit_factory = get_node_or_null("/root/UnitFactory")
    
    # Setup components
    sprite = $Sprite
    animation_player = $AnimationPlayer if has_node("AnimationPlayer") else null
    
    # Setup construction progress bar
    _setup_progress_bar()
    
    # Setup selection indicator
    _setup_selection_indicator()
    
    # Setup spawn points if this building can spawn units
    if can_spawn_units:
        _setup_spawn_points()
    
    # Start in construction state
    start_construction()

func _physics_process(delta: float) -> void:
    # Handle construction
    if not is_constructed:
        _update_construction(delta)
    
    # Handle unit spawning if applicable
    if is_constructed and can_spawn_units and not is_destroyed:
        _handle_spawning(delta)

# Start building construction
func start_construction() -> void:
    is_constructed = false
    construction_progress = 0.0
    
    # Set construction appearance
    if construction_texture:
        sprite.texture = construction_texture
    
    # Show progress bar
    if construction_progress_bar:
        construction_progress_bar.visible = true
        construction_progress_bar.value = 0
    
    # Play construction animation if available
    if animation_player and animation_player.has_animation("construction"):
        animation_player.play("construction")

# Update construction progress
func _update_construction(delta: float) -> void:
    if construction_progress < 100.0:
        var progress_increment = (delta / construction_time) * 100.0
        construction_progress += progress_increment
        
        if construction_progress_bar:
            construction_progress_bar.value = construction_progress
        
        emit_signal("construction_progress_changed", construction_progress)
        
        # Complete construction when progress reaches 100%
        if construction_progress >= 100.0:
            complete_construction()

# Complete building construction
func complete_construction() -> void:
    construction_progress = 100.0
    is_constructed = true
    
    # Hide progress bar
    if construction_progress_bar:
        construction_progress_bar.visible = false
    
    # Update appearance
    if completed_texture:
        sprite.texture = completed_texture
    else:
        push_error("Failed to load building texture for " + building_id)
        # Use a colored rectangle as fallback
        var placeholder = ColorRect.new()
        placeholder.rect_size = Vector2(64, 64)
        placeholder.rect_position = Vector2(-32, -32)
        placeholder.color = Color(0, 0, 1) if team == 0 else Color(1, 0, 0)
        add_child(placeholder)
    
    # Play completion animation if available
    if animation_player and animation_player.has_animation("construction_complete"):
        animation_player.play("construction_complete")
    
    # Start spawning if applicable
    if can_spawn_units:
        is_spawning = true
        spawn_timer = 0.0
    
    emit_signal("construction_completed")

# Setup construction progress bar
func _setup_progress_bar() -> void:
    construction_progress_bar = ProgressBar.new()
    construction_progress_bar.rect_size = Vector2(50, 10)
    construction_progress_bar.rect_position = Vector2(-25, -40)  # Position above building
    construction_progress_bar.min_value = 0
    construction_progress_bar.max_value = 100
    construction_progress_bar.percent_visible = false
    construction_progress_bar.visible = false
    add_child(construction_progress_bar)

# Setup selection indicator
func _setup_selection_indicator() -> void:
    selection_indicator = Node2D.new()
    selection_indicator.name = "SelectionIndicator"
    add_child(selection_indicator)
    
    # Create outline or other visual to indicate selection
    var outline = ColorRect.new()
    outline.rect_size = Vector2(size.x * grid_system.cell_size.x + 4, 
                                size.y * grid_system.cell_size.y + 4)
    outline.rect_position = Vector2(-outline.rect_size.x/2 - 2, -outline.rect_size.y/2 - 2)
    outline.color = Color(0, 1, 1, 0.3)  # Cyan semi-transparent
    selection_indicator.add_child(outline)
    
    # Hide by default
    selection_indicator.visible = false

# Show selection indicator
func select() -> void:
    selection_indicator.visible = true

# Hide selection indicator
func deselect() -> void:
    selection_indicator.visible = false

# Setup spawn points for units
func _setup_spawn_points() -> void:
    # Default implementation creates a single spawn point
    var spawn_point = Position2D.new()
    spawn_point.position = spawn_point_offset
    spawn_point.name = "SpawnPoint"
    add_child(spawn_point)
    spawn_points.append(spawn_point)
    
    # Derived buildings can override to create multiple spawn points

# Handle unit spawning logic
func _handle_spawning(delta: float) -> void:
    if not is_spawning or unit_types.empty():
        return
        
    spawn_timer += delta
    
    if spawn_timer >= spawn_interval:
        spawn_timer = 0
        _spawn_unit()

# Spawn a unit
func _spawn_unit() -> void:
    if unit_types.empty() or spawn_points.empty():
        return
        
    # Get unit type to spawn (could be random or based on some strategy)
    var unit_type = unit_types[0]  # For now, just use the first type
    
    # Choose a spawn point (could be random or based on some strategy)
    var spawn_point = spawn_points[0]  # For now, just use the first point
    
    # Request unit creation from factory
    var unit = unit_factory.create_unit(unit_type, global_position + spawn_point.position, team)
    
    if unit:
        emit_signal("unit_spawned", unit)

# Handle damage to the building
func take_damage(amount: float, attacker = null) -> void:
    if is_destroyed:
        return
        
    # Apply armor reduction
    var damage_after_armor = amount * (1.0 - (armor / 100.0))
    
    # Reduce health
    health -= damage_after_armor
    
    emit_signal("building_damaged", damage_after_armor, attacker)
    
    # Update visual appearance if damaged
    if health < max_health * 0.5 and damaged_texture:
        sprite.texture = damaged_texture
    
    # Check if building is destroyed
    if health <= 0:
        destroy()

# Handle building repair
func repair(amount: float) -> void:
    if is_destroyed:
        return
        
    # Increase health up to max
    var old_health = health
    health = min(health + amount, max_health)
    var actual_repair = health - old_health
    
    emit_signal("building_repaired", actual_repair)
    
    # Update visual appearance if repaired enough
    if health >= max_health * 0.5 and completed_texture:
        sprite.texture = completed_texture

# Destroy the building
func destroy() -> void:
    is_destroyed = true
    health = 0
    is_spawning = false
    
    # Update appearance
    if destroyed_texture:
        sprite.texture = destroyed_texture
    
    # Play destruction animation if available
    if animation_player and animation_player.has_animation("destroyed"):
        animation_player.play("destroyed")
    
    # Free up grid cells
    for x in range(size.x):
        for y in range(size.y):
            var cell_pos = grid_position + Vector2(x, y)
            grid_system.free_cell(cell_pos)
    
    emit_signal("building_destroyed")
    
    # Queue for removal (with delay if showing destruction animation)
    if animation_player and animation_player.has_animation("destroyed"):
        yield(animation_player, "animation_finished")
    
    queue_free()

# Set the grid position of this building
func set_grid_position(pos: Vector2) -> void:
    grid_position = pos

# Implement _to_string for debugging
func _to_string() -> String:
    return "%s (Team %d, HP: %.1f/%.1f)" % [display_name, team, health, max_health]
