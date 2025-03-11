# Fog of War System - Handles visibility of units and buildings for each team
# Path: scripts/core/fog_of_war.gd
class_name FogOfWar
extends Node2D

<<<<<<< HEAD
=======

>>>>>>> 96ca7c9 (added missing files)
# Fog of War signals
signal visibility_changed(position, team, is_visible)
signal unit_revealed(unit, team)
signal building_revealed(building, team)

# Fog of War settings
export var cell_size: Vector2 = Vector2(32, 32)  # Size of visibility grid cells
export var map_width: int = 80  # Width of map in cells
export var map_height: int = 60  # Height of map in cells
export var update_interval: float = 0.25  # Time between visibility updates (seconds)

# Visibility grid for each team
# Format: {team_id -> {grid_x_y -> visibility_level}}
# Visibility levels: 0 = never seen, 1 = previously seen, 2 = currently visible
var visibility_grid: Dictionary = {}

# Visible entities for each team
# Format: {team_id -> {entity_id -> entity_reference}}
var visible_units: Dictionary = {}
var visible_buildings: Dictionary = {}

# Unit and building tracking
var all_units: Dictionary = {}  # unit_id -> unit
var all_buildings: Dictionary = {}  # building_id -> building

# Update tracking
var update_timer: float = 0.0
var needs_full_update: bool = true

# Shader for fog rendering
var fog_material: ShaderMaterial
var fog_texture: ImageTexture

# Ready function
func _ready() -> void:
	# Initialize visibility grids
	_initialize_grids()
	
	# Connect signals from game manager to track units and buildings
	var game_manager = get_node("/root/GameManager")
	var building_manager = get_node_or_null("/root/GameManager/BuildingManager")
	
	if building_manager:
		building_manager.connect("building_placed", self, "_on_building_placed")
		building_manager.connect("building_destroyed", self, "_on_building_destroyed")
	
	# Setup fog rendering
	_setup_fog_rendering()

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
	# Create shader material
	fog_material = ShaderMaterial.new()
	fog_material.shader = preload("res://shaders/fog_of_war.shader")
	
	# Create fog texture for each team
	_create_fog_textures()
	
	# Create fog sprites for visualization
	_create_fog_sprites()

# Create fog textures
func _create_fog_textures() -> void:
	# Create texture for Team A
	var team_a_image = Image.new()
	team_a_image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	team_a_image.fill(Color(0, 0, 0, 1))  # Start with black (fog)
	
	var team_a_texture = ImageTexture.new()
	team_a_texture.create_from_image(team_a_image)
	
	# Create texture for Team B
	var team_b_image = Image.new()
	team_b_image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	team_b_image.fill(Color(0, 0, 0, 1))  # Start with black (fog)
	
	var team_b_texture = ImageTexture.new()
	team_b_texture.create_from_image(team_b_image)
	
	# Store textures
	fog_material.set_shader_param("team_a_fog", team_a_texture)
	fog_material.set_shader_param("team_b_fog", team_b_texture)

# Create fog sprites for visualization
func _create_fog_sprites() -> void:
	# Create sprite for Team A fog (only visible to Team A)
	var team_a_sprite = Sprite.new()
	team_a_sprite.name = "TeamAFog"
	team_a_sprite.material = fog_material
	team_a_sprite.texture = preload("res://assets/fog_of_war/fog_texture.png")
	team_a_sprite.position = Vector2(map_width * cell_size.x / 2, map_height * cell_size.y / 2)
	team_a_sprite.scale = Vector2(map_width * cell_size.x / team_a_sprite.texture.get_width(),
								  map_height * cell_size.y / team_a_sprite.texture.get_height())
	add_child(team_a_sprite)
	
	# Create sprite for Team B fog (only visible to Team B)
	var team_b_sprite = Sprite.new()
	team_b_sprite.name = "TeamBFog"
	team_b_sprite.material = fog_material
	team_b_sprite.texture = preload("res://assets/fog_of_war/fog_texture.png")
	team_b_sprite.position = Vector2(map_width * cell_size.x / 2, map_height * cell_size.y / 2)
	team_b_sprite.scale = Vector2(map_width * cell_size.x / team_b_sprite.texture.get_width(),
								  map_height * cell_size.y / team_b_sprite.texture.get_height())
	add_child(team_b_sprite)

# Update visibility grid
func _update_visibility() -> void:
	# Reset currently visible cells to previously seen
	_reset_visibility()
	
	# Update visibility from units
	_update_unit_visibility()
	
	# Update visibility from buildings
	_update_building_visibility()
	
	# Update fog textures
	_update_fog_textures()
	
	# Update entity visibility
	_update_entity_visibility()

# Reset current visibility
func _reset_visibility() -> void:
	# For each team
	for team in visibility_grid.keys():
		# For each cell that is currently visible
		for cell_key in visibility_grid[team].keys():
			if visibility_grid[team][cell_key] == 2:  # Currently visible
				visibility_grid[team][cell_key] = 1  # Set to previously seen
	
	# Clear visible entities
	for team in visible_units.keys():
		visible_units[team].clear()
		visible_buildings[team].clear()

# Update visibility from units
func _update_unit_visibility() -> void:
	# Update from all units
	for unit_id in all_units.keys():
		var unit = all_units[unit_id]
		
		if not is_instance_valid(unit) or unit.current_state == unit.UnitState.DEAD:
			# Remove invalid/dead units
			all_units.erase(unit_id)
			continue
		
		var unit_team = unit.team
		var vision_range = unit.vision_range
		
		# Make unit visible to its own team
		_add_to_visible_units(unit, unit_team)
		
		# Get unit's grid position
		var unit_pos = unit.global_position
		var grid_x = int(unit_pos.x / cell_size.x)
		var grid_y = int(unit_pos.y / cell_size.y)
		
		# Update visibility in a circle around unit
		var vision_cells = int(vision_range / min(cell_size.x, cell_size.y))
		
		for x in range(grid_x - vision_cells, grid_x + vision_cells + 1):
			for y in range(grid_y - vision_cells, grid_y + vision_cells + 1):
				if x < 0 or x >= map_width or y < 0 or y >= map_height:
					continue
				
				var distance = Vector2(grid_x, grid_y).distance_to(Vector2(x, y))
				if distance <= vision_cells:
					var cell_key = str(x) + "_" + str(y)
					visibility_grid[unit_team][cell_key] = 2  # Currently visible
					
					# Check for enemy entities in this cell
					_check_cell_for_entities(Vector2(x, y), unit_team)

# Update visibility from buildings
func _update_building_visibility() -> void:
	# Update from all buildings
	for building_id in all_buildings.keys():
		var building = all_buildings[building_id]
		
		if not is_instance_valid(building) or building.is_destroyed:
			# Remove invalid/destroyed buildings
			all_buildings.erase(building_id)
			continue
		
		var building_team = building.team
		var vision_range = 200.0  # Default building vision range
		
		# Make building visible to its own team
		_add_to_visible_buildings(building, building_team)
		
		# Get building's grid position
		var building_pos = building.global_position
		var grid_x = int(building_pos.x / cell_size.x)
		var grid_y = int(building_pos.y / cell_size.y)
		
		# Update visibility in a circle around building
		var vision_cells = int(vision_range / min(cell_size.x, cell_size.y))
		
		for x in range(grid_x - vision_cells, grid_x + vision_cells + 1):
			for y in range(grid_y - vision_cells, grid_y + vision_cells + 1):
				if x < 0 or x >= map_width or y < 0 or y >= map_height:
					continue
				
				var distance = Vector2(grid_x, grid_y).distance_to(Vector2(x, y))
				if distance <= vision_cells:
					var cell_key = str(x) + "_" + str(y)
					visibility_grid[building_team][cell_key] = 2  # Currently visible
					
					# Check for enemy entities in this cell
					_check_cell_for_entities(Vector2(x, y), building_team)

# Check for entities in a cell and update visibility
func _check_cell_for_entities(cell_pos: Vector2, team: int) -> void:
	# Convert cell position to world position
	var world_pos = cell_pos * cell_size
	
	# Check for units and buildings in this cell
	var space_state = get_world_2d().direct_space_state
	var rect_shape = RectangleShape2D.new()
	rect_shape.extents = cell_size / 2
	
	var query = Physics2DShapeQueryParameters.new()
	query.set_shape(rect_shape)
	query.transform = Transform2D(0, world_pos + cell_size / 2)  # Center of cell
	query.collide_with_bodies = true
	query.collision_layer = 2 | 4  # Buildings on layer 2, units on layer 4
	
	var result = space_state.intersect_shape(query)
	
	for collision in result:
		var collider = collision.collider
		
		# Add to visible entities if it's a unit or building
		if collider is Unit:
			_add_to_visible_units(collider, team)
		elif collider is Building:
			_add_to_visible_buildings(collider, team)

# Add a unit to visible units for a team
func _add_to_visible_units(unit, team: int) -> void:
	if not visible_units[team].has(unit.get_instance_id()):
		visible_units[team][unit.get_instance_id()] = unit
		emit_signal("unit_revealed", unit, team)

# Add a building to visible buildings for a team
func _add_to_visible_buildings(building, team: int) -> void:
	if not visible_buildings[team].has(building.get_instance_id()):
		visible_buildings[team][building.get_instance_id()] = building
		emit_signal("building_revealed", building, team)

# Update fog textures based on visibility grid
func _update_fog_textures() -> void:
	# Update Team A fog texture
	var team_a_image = Image.new()
	team_a_image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	
	# Update Team B fog texture
	var team_b_image = Image.new()
	team_b_image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	
	# Fill images based on visibility grid
	for x in range(map_width):
		for y in range(map_height):
			var cell_key = str(x) + "_" + str(y)
			
			# Team A visibility
			if visibility_grid[0][cell_key] == 2:
				team_a_image.set_pixel(x, y, Color(1, 1, 1, 0))  # Fully visible
			elif visibility_grid[0][cell_key] == 1:
				team_a_image.set_pixel(x, y, Color(0.5, 0.5, 0.5, 0.5))  # Partially visible
			else:
				team_a_image.set_pixel(x, y, Color(0, 0, 0, 1))  # Not visible
			
			# Team B visibility
			if visibility_grid[1][cell_key] == 2:
				team_b_image.set_pixel(x, y, Color(1, 1, 1, 0))  # Fully visible
			elif visibility_grid[1][cell_key] == 1:
				team_b_image.set_pixel(x, y, Color(0.5, 0.5, 0.5, 0.5))  # Partially visible
			else:
				team_b_image.set_pixel(x, y, Color(0, 0, 0, 1))  # Not visible
	
	# Update textures
	var team_a_texture = ImageTexture.new()
	team_a_texture.create_from_image(team_a_image)
	
	var team_b_texture = ImageTexture.new()
	team_b_texture.create_from_image(team_b_image)
	
	fog_material.set_shader_param("team_a_fog", team_a_texture)
	fog_material.set_shader_param("team_b_fog", team_b_texture)

# Update entity visibility based on fog
func _update_entity_visibility() -> void:
	# Update unit visibility
	for unit_id in all_units.keys():
		var unit = all_units[unit_id]
		
		if not is_instance_valid(unit) or unit.current_state == unit.UnitState.DEAD:
			continue
		
		var unit_team = unit.team
		var enemy_team = 1 if unit_team == 0 else 0
		
		# Check if unit is visible to enemy team
		var is_visible_to_enemy = visible_units[enemy_team].has(unit.get_instance_id())
		
		# Update unit's visibility flag
		unit.is_visible_to_enemy = is_visible_to_enemy
		
		# Set visual visibility
		if unit.has_method("set_visible_to_team"):
			unit.set_visible_to_team(0, true)  # Always visible to Team A
			unit.set_visible_to_team(1, true)  # Always visible to Team B
		else:
			# Use visibility property if method doesn't exist
			unit.visible = true
	
	# Update building visibility
	for building_id in all_buildings.keys():
		var building = all_buildings[building_id]
		
		if not is_instance_valid(building) or building.is_destroyed:
			continue
		
		var building_team = building.team
		var enemy_team = 1 if building_team == 0 else 0
		
		# Check if building is visible to enemy team
		var is_visible_to_enemy = visible_buildings[enemy_team].has(building.get_instance_id())
		
		# Set visual visibility
		if building.has_method("set_visible_to_team"):
			building.set_visible_to_team(0, true)  # Always visible to Team A
			building.set_visible_to_team(1, true)  # Always visible to Team B
		else:
			# Use visibility property if method doesn't exist
			building.visible = true

# Register a new unit
func register_unit(unit) -> void:
	var unit_id = unit.get_instance_id()
	all_units[unit_id] = unit
	
	# Connect signals
	if not unit.is_connected("unit_spawned", self, "_on_unit_spawned"):
		unit.connect("unit_spawned", self, "_on_unit_spawned", [unit])
	
	if not unit.is_connected("unit_died", self, "_on_unit_died"):
		unit.connect("unit_died", self, "_on_unit_died", [unit])
	
	# Force visibility update
	needs_full_update = true

# Register a new building
func register_building(building) -> void:
	var building_id = building.get_instance_id()
	all_buildings[building_id] = building
	
	# Connect signals
	if not building.is_connected("building_destroyed", self, "_on_building_destroyed"):
		building.connect("building_destroyed", self, "_on_building_destroyed", [building])
	
	# Force visibility update
	needs_full_update = true

# Signal handlers
func _on_unit_spawned(unit) -> void:
	register_unit(unit)

func _on_unit_died(killer, unit) -> void:
	var unit_id = unit.get_instance_id()
	all_units.erase(unit_id)
	
	for team in visible_units.keys():
		visible_units[team].erase(unit_id)

func _on_building_placed(building_type, position, team) -> void:
	# The building will be registered when it's fully constructed
	pass

func _on_building_destroyed(building) -> void:
	var building_id = building.get_instance_id()
	all_buildings.erase(building_id)
	
	for team in visible_buildings.keys():
		visible_buildings[team].erase(building_id)

# Check if a position is visible to a team
func is_position_visible(position: Vector2, team: int) -> bool:
	var grid_x = int(position.x / cell_size.x)
	var grid_y = int(position.y / cell_size.y)
	
	if grid_x < 0 or grid_x >= map_width or grid_y < 0 or grid_y >= map_height:
		return false
	
	var cell_key = str(grid_x) + "_" + str(grid_y)
	
	return visibility_grid[team][cell_key] == 2  # Currently visible

# Check if a position has been previously seen by a team
func is_position_explored(position: Vector2, team: int) -> bool:
	var grid_x = int(position.x / cell_size.x)
	var grid_y = int(position.y / cell_size.y)
	
	if grid_x < 0 or grid_x >= map_width or grid_y < 0 or grid_y >= map_height:
		return false
	
	var cell_key = str(grid_x) + "_" + str(grid_y)
	
	return visibility_grid[team][cell_key] > 0  # Either previously seen or currently visible

# Check if a unit is visible to a specific team
func is_unit_visible(unit, team: int) -> bool:
	var unit_id = unit.get_instance_id()
	return visible_units[team].has(unit_id)

# Check if a building is visible to a specific team
func is_building_visible(building, team: int) -> bool:
	var building_id = building.get_instance_id()
	return visible_buildings[team].has(building_id)

# Set current player team (for single-player or client-side view)
func set_current_player_team(team: int) -> void:
	# Show only the appropriate fog sprite for the client
	var team_a_sprite = get_node_or_null("TeamAFog")
	var team_b_sprite = get_node_or_null("TeamBFog")
	
	if team_a_sprite:
		team_a_sprite.visible = team == 0
	
	if team_b_sprite:
		team_b_sprite.visible = team == 1