# Unit Factory - Handles creation of unit instances from data
# Path: scripts/unit/unit_factory.gd
# Unit Factory - Handles creation of unit instances from data
# Path: scripts/unit/unit_factory.gd
extends Node

# Unit creation signals
signal unit_created(unit_instance, unit_type, team)
signal unit_creation_failed(unit_type, reason)

# Unit data cache
var unit_data: Dictionary = {}

# Ready function
func _ready() -> void:
	print("UnitFactory initialized")
	# Load all unit data
	_load_unit_data()

# Load unit data from configuration files
func _load_unit_data() -> void:
	var data_path = "res://data/units/"
	
	var dir = Directory.new()
	if dir.open(data_path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".json"):
				var unit_id = file_name.get_basename()
				var file_path = data_path + file_name
				_load_unit_file(unit_id, file_path)
			file_name = dir.get_next()
	else:
		print("Warning: Could not open units data directory")

# Load a single unit data file
func _load_unit_file(unit_id: String, file_path: String) -> void:
	var file = File.new()
	if file.open(file_path, File.READ) == OK:
		var text = file.get_as_text()
		file.close()
		
		var parse_result = JSON.parse(text)
		if parse_result.error == OK:
			var data = parse_result.result
			unit_data[unit_id] = data
			print("Loaded unit data: ", unit_id)
		else:
			print("Error parsing unit data: " + file_path)
	else:
		print("Error opening unit file: " + file_path)

# Create a unit instance
func create_unit(unit_type: String, position: Vector2, team: int):
	# Check if unit type exists
	if not unit_data.has(unit_type):
		print("Unknown unit type: " + unit_type)
		emit_signal("unit_creation_failed", unit_type, "Unknown unit type")
		return null
	
	# Get unit data
	var data = unit_data[unit_type]
	
	unit.add_child(unit_sprite)
	
	# Add collision
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 16.0
	collision.shape = shape
	unit.add_child(collision)
	
	# Set position
	unit.position = position
	
	# Add to scene
	var scene = get_tree().current_scene
	if scene:
		scene.add_child(unit)
	
	# Try to load unit texture
	var texture_path = "res://assets/units/" + unit_type + "/idle/idle.png"
	var texture = load(texture_path)
	if texture:
		unit_sprite.texture = texture
	else:
		push_error("CRITICAL: Unit texture failed to load for " + unit_type)
		get_tree().quit()
	
	print("Created unit: " + unit_type)
	emit_signal("unit_created", unit, unit_type, team)
	
	return unit
	
# Configure a unit instance with data
func _configure_unit(unit: Unit, unit_type: String, data: Dictionary, team: int) -> void:
	# Set basic properties
	unit.unit_id = unit_type
	unit.display_name = data.display_name if data.has("display_name") else unit_type
	unit.team = team
	
	# Set stats
	if data.has("health"):
		unit.health = data.health
		unit.max_health = data.health
	
	if data.has("armor"):
		unit.armor = data.armor
	
	if data.has("armor_type"):
		unit.armor_type = data.armor_type
	
	if data.has("attack_damage"):
		unit.attack_damage = data.attack_damage
	
	if data.has("attack_type"):
		unit.attack_type = data.attack_type
	
	if data.has("attack_range"):
		unit.attack_range = data.attack_range
	
	if data.has("attack_speed"):
		unit.attack_speed = data.attack_speed
	
	if data.has("movement_speed"):
		unit.movement_speed = data.movement_speed
	
	if data.has("collision_radius"):
		unit.collision_radius = data.collision_radius
		
		# Update collision shape if it exists
		if unit.has_node("CollisionShape2D"):
			var collision_shape = unit.get_node("CollisionShape2D")
			var circle = CircleShape2D.new()
			circle.radius = unit.collision_radius
			collision_shape.shape = circle
	
	if data.has("vision_range"):
		unit.vision_range = data.vision_range
	
	if data.has("health_regen"):
		unit.health_regen = data.health_regen
	
	# Configure mana if unit uses it
	if data.has("has_mana"):
		unit.has_mana = data.has_mana
		
		if unit.has_mana:
			if data.has("mana"):
				unit.mana = data.mana
				unit.max_mana = data.mana
			
			if data.has("max_mana"):
				unit.max_mana = data.max_mana
			
			if data.has("mana_regen"):
				unit.mana_regen = data.mana_regen
	
	# Configure abilities if any
	if data.has("abilities") and data.abilities is Array:
		for ability_data in data.abilities:
			if ability_data is Dictionary and ability_data.has("name"):
				unit.add_ability(ability_data.name, ability_data)

# Get unit data
func get_unit_data(unit_type: String) -> Dictionary:
	if unit_data.has(unit_type):
		return unit_data[unit_type]
	return {}

# Get all available unit types
func get_all_unit_types() -> Array:
	return unit_data.keys()

# Get units for a specific race/team
func get_unit_types_for_race(race: String) -> Array:
	var types = []
	
	for unit_type in unit_data.keys():
		var data = unit_data[unit_type]
		if data.has("race") and data.race == race:
			types.append(unit_type)
	
	return types

# Get effective DPS of a unit type against a specific armor type
func get_unit_effective_dps(unit_type: String, armor_type: String) -> float:
	if not unit_data.has(unit_type):
		return 0.0
	
	var data = unit_data[unit_type]
	var attack_damage = data.attack_damage if data.has("attack_damage") else 10.0
	var attack_type = data.attack_type if data.has("attack_type") else "normal"
	var attack_speed = data.attack_speed if data.has("attack_speed") else 1.0
	
	var combat_system = get_node("/root/GameManager/CombatSystem")
	if combat_system:
		var type_modifier = combat_system.get_attack_type_modifier(attack_type, armor_type)
		return attack_damage * type_modifier * attack_speed
	
	return attack_damage * attack_speed
