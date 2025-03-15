# Camera Controller - Handles camera movement and boundaries
extends Camera2D

# Camera movement settings
export var pan_speed: float = 500.0
export var edge_size: int = 20
export var zoom_speed: float = 0.1
export var min_zoom: float = 0.5
export var max_zoom: float = 2.0
export var keyboard_pan_speed: float = 500.0

# Camera boundaries
export var boundary_left: float = -1000.0
export var boundary_right: float = 3000.0
export var boundary_top: float = -1000.0
export var boundary_bottom: float = 2000.0

func _ready() -> void:
    # Make sure camera is set to current
    current = true

func _process(delta: float) -> void:
    var viewport_size = get_viewport().size
    var mouse_position = get_viewport().get_mouse_position()
    var move_direction = Vector2.ZERO
    
    # Edge panning with mouse
    if mouse_position.x < edge_size:
        move_direction.x = -1
    elif mouse_position.x > viewport_size.x - edge_size:
        move_direction.x = 1
        
    if mouse_position.y < edge_size:
        move_direction.y = -1
    elif mouse_position.y > viewport_size.y - edge_size:
        move_direction.y = 1
    
    # Keyboard panning
    if Input.is_action_pressed("ui_right"):
        move_direction.x = 1
    if Input.is_action_pressed("ui_left"):
        move_direction.x = -1
    if Input.is_action_pressed("ui_down"):
        move_direction.y = 1
    if Input.is_action_pressed("ui_up"):
        move_direction.y = -1
    
    # Apply movement
    position += move_direction.normalized() * pan_speed * delta
    
    # Apply boundaries
    position.x = clamp(position.x, boundary_left, boundary_right)
    position.y = clamp(position.y, boundary_top, boundary_bottom)

func _input(event: InputEvent) -> void:
    # Handle zoom with scroll wheel
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_WHEEL_UP:
            zoom = Vector2(max(zoom.x - zoom_speed, min_zoom), max(zoom.y - zoom_speed, min_zoom))
        elif event.button_index == BUTTON_WHEEL_DOWN:
            zoom = Vector2(min(zoom.x + zoom_speed, max_zoom), min(zoom.y + zoom_speed, max_zoom))