# Fog of War System - Handles visibility of units and buildings for each team
# Path: scripts/core/fog_of_war.gd
class_name FogOfWar
extends Node2D

# Fog of War signals - ALL renamed to avoid conflict with parent class
signal fog_changed(position, team, is_visible) # Renamed from visibility_changed
signal fog_unit_revealed(unit, team) # Renamed from unit_revealed
signal fog_building_revealed(building, team) # Renamed from building_revealed

# Fog of War settings
export var cell_size: Vector2 = Vector2(32, 32) # Size of visibility grid cells
export var map_width: int = 80 # Width of map in cells
export var map_height: int = 60 # Height of map in cells
export var update_interval: float = 0.25 # Time between visibility updates (seconds)

# Visibility grid for each team
# Format: {team_id -> {grid_x_y -> visibility_level}}
# Visibility levels: 0 = never seen, 1 = previously seen, 2 = currently visible
var visibility_grid: Dictionary = {}

# Visible entities for each team
# Format: {team_id -> {entity_id -> entity_reference}}
var visible_units: Dictionary = {}
var visible_buildings: Dictionary = {}

# Unit and building tracking
var all_units: Dictionary = {} # unit_id -> unit
var all_buildings: Dictionary = {} # building_id -> building

# Update tracking
var update_timer: float = 0.0
var needs_full_update: bool = true

# Shader for fog rendering
var fog_material: ShaderMaterial
var fog_texture: ImageTexture

# Ready function
func _ready() -> void:
    print("Fog of War system initializing")
    # Initialize visibility grids
    _initialize_grids()
    
    # Connect signals from game manager to track units and buildings
    var game_manager = get_node_or_null("/root/GameManager")
    var building_manager = null
    
    if game_manager:
        building_manager = game_manager.get_node_or_null("BuildingManager")
    
    if building_manager:
        building_manager.connect("building_placed", self, "_on_building_placed")
        building_manager.connect("building_destroyed", self, "_on_building_destroyed")
    
    # Setup fog rendering
    _setup_fog_rendering()
    print("Fog of War system initialized")

# Process function
func _process(delta: float) -> void:
    update_timer += delta
    
    if update_timer >= update_interval or needs_full_update:
        update_timer = 0
        needs_full_update = false
        _update_visibility()

# Initialize visibility grids for teams
func _initialize_grids() -> void:
    # Team 0 (Team A)
    visibility_grid[0] = {}
    visible_units[0] = {}
    visible_buildings[0] = {}
    
    # Team 1 (Team B)
    visibility_grid[1] = {}
    visible_units[1] = {}
    visible_buildings[1] = {}
    
    # Initialize all grid cells to not visible (0)
    for x in range(map_width):
        for y in range(map_height):
            var cell_key = str(x) + "_" + str(y)
            visibility_grid[0][cell_key] = 0
            visibility_grid[1][cell_key] = 0
    
    # Mark needs full update
    needs_full_update = true

# Setup fog rendering using a shader
func _setup_fog_rendering() -> void:
    # Check if shader exists
    var shader_path = "res://shaders/fog_of_war.shader"
    var file = File.new()
    
    if !file.file_exists(shader_path):
        # Create directory if needed
        var dir = Directory.new()
        if !dir.dir_exists("res://shaders"):
            dir.make_dir("res://shaders")
        
        # Create a simple shader file
        file.open(shader_path, File.WRITE)
        file.store_string("""shader_type canvas_item;

// Fog of War shader for Castle Fight
// Simple implementation that takes two textures (one for each team)

uniform sampler2D team_a_fog;  // Texture for Team A's fog of war
uniform sampler2D team_b_fog;  // Texture for Team B's fog of war
uniform bool use_team_a = true;  // Which team's fog to display (set by the renderer)

void fragment() {
    // Get the fog value from the appropriate texture
    vec4 fog_value;
    if (use_team_a) {
        fog_value = texture(team_a_fog, UV);
    } else {
        fog_value = texture(team_b_fog, UV);
    }
    
    // Output the fog color
    // Alpha of 0 = fully visible
    // Alpha of 1 = completely hidden (black)
    COLOR = vec4(0.0, 0.0, 0.0, fog_value.a);
}""")
        file.close()
    
    # Create shader material
    fog_material = ShaderMaterial.new()
    
    # Load shader
    var shader_file = load(shader_path)
    if shader_file:
        fog_material.shader = shader_file
    else:
        # Create a simple shader as a fallback
        var shader = Shader.new()
        shader.code = """shader_type canvas_item;
void fragment() {
    COLOR = vec4(0.0, 0.0, 0.0, 0.5);
}"""
        fog_material.shader = shader
    
    # Create fog textures for each team
    _create_fog_textures()
    
    # Create fog sprites for visualization
    _create_fog_sprites()

# Create fog textures
func _create_fog_textures() -> void:
    # Create texture for Team A
    var team_a_image = Image.new()
    team_a_image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
    team_a_image.fill(Color(0, 0, 0, 1)) # Start with black (fog)
    
    var team_a_texture = ImageTexture.new()
    team_a_texture.create_from_image(team_a_image)
    
    # Create texture for Team B
    var team_b_image = Image.new()
    team_b_image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
    team_b_image.fill(Color(0, 0, 0, 1)) # Start with black (fog)
    
    var team_b_texture = ImageTexture.new()
    team_b_texture.create_from_image(team_b_image)
    
    # Store textures
    fog_material.set_shader_param("team_a_fog", team_a_texture)
    fog_material.set_shader_param("team_b_fog", team_b_texture)

# Create fog sprites for visualization
func _create_fog_sprites() -> void:
    # Ensure fog texture directory exists
    var dir = Directory.new()
    if !dir.dir_exists("res://assets/fog_of_war"):
        dir.make_dir_recursive("res://assets/fog_of_war")
    
    # Create a placeholder fog texture if it doesn't exist
    var fog_texture_path = "res://assets/fog_of_war/fog_texture.png"
    var file = File.new()
    
    if !file.file_exists(fog_texture_path):
        var image = Image.new()
        image.create(32, 32, false, Image.FORMAT_RGBA8)
        image.fill(Color(0, 0, 0, 1)) # Black
        image.save_png(fog_texture_path)
    
    # Try to load the texture
    var texture = ResourceLoader.load(fog_texture_path)
    if !texture:
        # Create a fallback texture
        var image = Image.new()
        image.create(32, 32, false, Image.FORMAT_RGBA8)
        image.fill(Color(0, 0, 0, 1))
        texture = ImageTexture.new()
        texture.create_from_image(image)
    
    # Create sprite for Team A fog (only visible to Team A)
    var team_a_sprite = Sprite.new()
    team_a_sprite.name = "TeamAFog"
    team_a_sprite.material = fog_material
    team_a_sprite.texture = texture
    team_a_sprite.position = Vector2(map_width * cell_size.x / 2, map_height * cell_size.y / 2)
    team_a_sprite.scale = Vector2(map_width * cell_size.x / 32, map_height * cell_size.y / 32)
    add_child(team_a_sprite)
    
    # Create sprite for Team B fog (only visible to Team B)
    var team_b_sprite = Sprite.new()
    team_b_sprite.name = "TeamBFog"
    team_b_sprite.material = fog_material
    team_b_sprite.texture = texture
    team_b_sprite.position = Vector2(map_width * cell_size.x / 2, map_height * cell_size.y / 2)
    team_b_sprite.scale = Vector2(map_width * cell_size.x / 32, map_height * cell_size.y / 32)
    add_child(team_b_sprite)

# Register a new unit
func register_unit(unit) -> void:
    var unit_id = unit.get_instance_id()
    all_units[unit_id] = unit
    
    print("Registered unit: " + str(unit))
    # Force visibility update
    needs_full_update = true

# Register a new building
func register_building(building) -> void:
    var building_id = building.get_instance_id()
    all_buildings[building_id] = building
    
    print("Registered building: " + str(building))
    # Force visibility update
    needs_full_update = true

    # Update fog textures
    _update_fog_textures()

# Update fog textures based on visibility grid
func _update_fog_textures() -> void:
    # Update Team A fog texture
    var team_a_image = Image.new()
    team_a_image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
    
    # Update Team B fog texture
    var team_b_image = Image.new()
    team_b_image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
    
    # Lock images before modifying
    team_a_image.lock()
    team_b_image.lock()
    
    # Fill images based on visibility grid
    for x in range(map_width):
        for y in range(map_height):
            var cell_key = str(x) + "_" + str(y)
            
            # Team A visibility
            if visibility_grid[0].has(cell_key) and visibility_grid[0][cell_key] == 2:
                team_a_image.set_pixel(x, y, Color(1, 1, 1, 0)) # Fully visible
            else:
                team_a_image.set_pixel(x, y, Color(0, 0, 0, 0.7)) # Partially visible
            
            # Team B visibility
            if visibility_grid[1].has(cell_key) and visibility_grid[1][cell_key] == 2:
                team_b_image.set_pixel(x, y, Color(1, 1, 1, 0)) # Fully visible
            else:
                team_b_image.set_pixel(x, y, Color(0, 0, 0, 0.7)) # Partially visible
    
    # Unlock images after modifying
    team_a_image.unlock()
    team_b_image.unlock()
    
    # Update textures
    var team_a_texture = ImageTexture.new()
    team_a_texture.create_from_image(team_a_image)
    
    var team_b_texture = ImageTexture.new()
    team_b_texture.create_from_image(team_b_image)
    
    fog_material.set_shader_param("team_a_fog", team_a_texture)
    fog_material.set_shader_param("team_b_fog", team_b_texture)

# Set current player team (for single-player or client-side view)
func set_current_player_team(team: int) -> void:
    # Show only the appropriate fog sprite for the client
    var team_a_sprite = get_node_or_null("TeamAFog")
    var team_b_sprite = get_node_or_null("TeamBFog")
    
    if team_a_sprite:
        team_a_sprite.visible = team == 0
    
    if team_b_sprite:
        team_b_sprite.visible = team == 1
        
# Custom methods to replace built-in signal usage
func notify_visibility_change(position, team, is_visible) -> void:
    emit_signal("fog_changed", position, team, is_visible)
    
func notify_unit_revealed(unit, team) -> void:
    emit_signal("fog_unit_revealed", unit, team)
    
func notify_building_revealed(building, team) -> void:
    emit_signal("fog_building_revealed", building, team)

# Update visibility based on unit and building positions
func _update_visibility() -> void:
    # Skip if no teams are initialized
    if visibility_grid.empty():
        return
    
    # Reset current visibility to "previously seen" (1)
    for team in visibility_grid.keys():
        for cell_key in visibility_grid[team].keys():
            if visibility_grid[team][cell_key] == 2: # If currently visible
                visibility_grid[team][cell_key] = 1 # Set to previously seen
    
    # Update visibility from units
    for unit_id in all_units.keys():
        var unit = all_units[unit_id]
        if not is_instance_valid(unit):
            # Remove invalid unit references
            var _erased = all_units.erase(unit_id)
            continue
            
        var unit_team = unit.team if "team" in unit else 0
        var unit_pos = unit.global_position
        var vision_range = unit.vision_range if "vision_range" in unit else 300.0
        
        # Make cells visible for this unit's team
        _update_cells_visibility(unit_team, unit_pos, vision_range)
        
    # Update visibility from buildings
    for building_id in all_buildings.keys():
        var building = all_buildings[building_id]
        if not is_instance_valid(building):
            # Remove invalid building references
            var _erased = all_buildings.erase(building_id)
            continue
            
        var building_team = building.team if "team" in building else 0
        var building_pos = building.global_position
        var vision_range = building.vision_range if "vision_range" in building else 300.0
        
        # Make cells visible for this building's team
        _update_cells_visibility(building_team, building_pos, vision_range)
    
    # Update fog textures after visibility changes
    _update_fog_textures()

# Update cells visibility within a vision range
func _update_cells_visibility(team: int, position: Vector2, vision_range: float) -> void:
    if not visibility_grid.has(team):
        return
        
    # Convert world position to grid cell
    var cell_x = int(position.x / cell_size.x)
    var cell_y = int(position.y / cell_size.y)
    
    # Calculate cell radius based on vision range
    var cell_radius = int(vision_range / cell_size.x)
    
    # Update all cells within the vision radius
    for x in range(cell_x - cell_radius, cell_x + cell_radius + 1):
        for y in range(cell_y - cell_radius, cell_y + cell_radius + 1):
            # Skip if out of bounds
            if x < 0 or y < 0 or x >= map_width or y >= map_height:
                continue
                
            # Calculate distance from center
            var distance = Vector2(x, y).distance_to(Vector2(cell_x, cell_y))
            if distance <= cell_radius:
                # Set cell to visible (2)
                var cell_key = str(x) + "_" + str(y)
                visibility_grid[team][cell_key] = 2

func initialize() -> void:
    print("FogOfWarManager: Initializing...")
    
    # Initialize visibility grids
    _initialize_grids()
    
    # Connect signals from game manager to track units and buildings
    var game_manager = get_node_or_null("/root/GameManager")
    var building_manager = null
    
    if game_manager:
        building_manager = game_manager.get_node_or_null("BuildingManager")
        if not building_manager:
            building_manager = get_node_or_null("/root/BuildingManager")
    
    if building_manager:
        if not building_manager.is_connected("building_placed", self, "_on_building_placed"):
            building_manager.connect("building_placed", self, "_on_building_placed")
        if not building_manager.is_connected("building_destroyed", self, "_on_building_destroyed"):
            building_manager.connect("building_destroyed", self, "_on_building_destroyed")
    
    # Setup fog rendering
    _setup_fog_rendering()
    
    print("FogOfWarManager: Initialization complete")
