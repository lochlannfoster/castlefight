# Tech Tree Manager - Handles loading and managing tech trees
# Path: scripts/core/tech_tree_manager.gd
class_name TechTreeManager
extends Node

# Tech tree signals
signal tech_tree_loaded(race_id)
signal tech_unlocked(team, tech_id)
signal upgrade_researched(team, upgrade_id)

# Tech tree data
var tech_trees: Dictionary = {}
var team_tech_trees: Dictionary = {
	0: "",  # Team A tech tree race
	1: ""   # Team B tech tree race
}
var team_unlocked_buildings: Dictionary = {
	0: [],  # Team A unlocked buildings
	1: []   # Team B unlocked buildings
}
var team_unlocked_units: Dictionary = {
	0: [],  # Team A unlocked units
	1: []   # Team B unlocked units
}
var team_researched_upgrades: Dictionary = {
	0: [],  # Team A researched upgrades
	1: []   # Team B researched upgrades
}

# Ready function
func _ready() -> void:
	# Load all tech trees
	_load_tech_trees()
	
	# Connect signals
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.connect("game_started", self, "_on_game_started")
		game_manager.connect("game_ended", self, "_on_game_ended")

# Load all tech tree data from files
func _load_tech_trees() -> void:
	var data_path = "res://data/tech_trees/"
	
	var dir = Directory.new()
	if dir.open(data_path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".json"):
				var race_id = file_name.get_basename().replace("_tech", "")
				var file_path = data_path + file_name
				_load_tech_tree_file(race_id, file_path)
			file_name = dir.get_next()
	else:
		push_error("Error: Could not open tech tree data directory")

# Load a single tech tree file
func _load_tech_tree_file(race_id: String, file_path: String) -> void:
	var file = File.new()
	if file.open(file_path, File.READ) == OK:
		var text = file.get_as_text()
		file.close()
		
		var parse_result = JSON.parse(text)
		if parse_result.error == OK:
			var data = parse_result.result
			tech_trees[race_id] = data
			print("Loaded tech tree: " + race_id)
			emit_signal("tech_tree_loaded", race_id)
		else:
			push_error("Error parsing tech tree: " + file_path)
	else:
		push_error("Error opening tech tree file: " + file_path)

# Set a team's tech tree
func set_team_tech_tree(team: int, race: String) -> void:
	if not tech_trees.has(race):
		push_error("Unknown race: " + race)
		return
	
	team_tech_trees[team] = race
	_initialize_team_tech(team)

# Initialize a team's tech tree with starting buildings
func _initialize_team_tech(team: int) -> void:
	var race = team_tech_trees[team]
	if race.empty() or not tech_trees.has(race):
		return
	
	var race_data = tech_trees[race]
	
	# Clear current unlocks
	team_unlocked_buildings[team].clear()
	team_unlocked_units[team].clear()
	team_researched_upgrades[team].clear()
	
	# Add starting buildings
	for building_id in race_data.starting_buildings:
		unlock_building(team, building_id)

# Check if a building is unlocked for a team
func is_building_unlocked(team: int, building_id: String) -> bool:
	return team_unlocked_buildings[team].has(building_id)

# Check if a unit is unlocked for a team
func is_unit_unlocked(team: int, unit_id: String) -> bool:
	return team_unlocked_units[team].has(unit_id)

# Check if an upgrade is researched for a team
func is_upgrade_researched(team: int, upgrade_id: String) -> bool:
	return team_researched_upgrades[team].has(upgrade_id)

# Unlock a building for a team
func unlock_building(team: int, building_id: String) -> void:
	if team_unlocked_buildings[team].has(building_id):
		return
	
	var race = team_tech_trees[team]
	if race.empty() or not tech_trees.has(race):
		return
	
	var race_data = tech_trees[race]
	
	# Find building data
	var building_data = null
	for building in race_data.buildings:
		if building.id == building_id:
			building_data = building
			break
	
	if not building_data:
		push_error("Unknown building: " + building_id + " for race: " + race)
		return
	
	# Add to unlocked buildings
	team_unlocked_buildings[team].append(building_id)
	
	# Unlock units that this building enables
	for unit in race_data.units:
		if unit.building == building_id:
			if not team_unlocked_units[team].has(unit.id):
				team_unlocked_units[team].append(unit.id)
	
	# Unlock further buildings and upgrades
	if building_data.has("unlocks"):
		for unlock_id in building_data.unlocks:
			# Check if this is a building
			var is_building = false
			for building in race_data.buildings:
				if building.id == unlock_id:
					is_building = true
					break
			
			if is_building:
				# Don't automatically unlock buildings, just make them available for construction
				pass
			else:
				# Check if this is a unit
				var is_unit = false
				for unit in race_data.units:
					if unit.id == unlock_id:
						is_unit = true
						if not team_unlocked_units[team].has(unit.id):
							team_unlocked_units[team].append(unit.id)
						break
				
				if not is_unit:
					# Might be an upgrade or technology, just store it as unlocked
					if not team_unlocked_buildings[team].has(unlock_id):
						team_unlocked_buildings[team].append(unlock_id)
	
	emit_signal("tech_unlocked", team, building_id)

# Research an upgrade for a team
func research_upgrade(team: int, upgrade_id: String) -> bool:
	if team_researched_upgrades[team].has(upgrade_id):
		return false
	
	var race = team_tech_trees[team]
	if race.empty() or not tech_trees.has(race):
		return false
	
	var race_data = tech_trees[race]
	
	# Find upgrade data
	var upgrade_data = null
	for upgrade in race_data.upgrades:
		if upgrade.id == upgrade_id:
			upgrade_data = upgrade
			break
	
	if not upgrade_data:
		push_error("Unknown upgrade: " + upgrade_id + " for race: " + race)
		return false
	
	# Check requirements
	var building_id = upgrade_data.building
	if not team_unlocked_buildings[team].has(building_id):
		return false
	
	# Add to researched upgrades
	team_researched_upgrades[team].append(upgrade_id)
	
	emit_signal("upgrade_researched", team, upgrade_id)
	return true

# Get available buildings for a team
func get_available_buildings(team: int) -> Array:
	var available = []
	
	var race = team_tech_trees[team]
	if race.empty() or not tech_trees.has(race):
		return available
	
	var race_data = tech_trees[race]
	
	for building in race_data.buildings:
		# Skip already unlocked buildings
		if team_unlocked_buildings[team].has(building.id):
			continue
		
		# Check if requirements are met
		var requirements_met = true
		for req in building.requirements:
			if not team_unlocked_buildings[team].has(req):
				requirements_met = false
				break
		
		if requirements_met:
			available.append({
				"id": building.id,
				"name": building.name,
				"tier": building.tier,
				"description": building.description
			})
	
	return available

# Get available upgrades for a team
func get_available_upgrades(team: int) -> Array:
	var available = []
	
	var race = team_tech_trees[team]
	if race.empty() or not tech_trees.has(race):
		return available
	
	var race_data = tech_trees[race]
	
	for upgrade in race_data.upgrades:
		# Skip already researched upgrades
		if team_researched_upgrades[team].has(upgrade.id):
			continue
		
		# Check if building requirement is met
		if team_unlocked_buildings[team].has(upgrade.building):
			available.append({
				"id": upgrade.id,
				"name": upgrade.name,
				"tier": upgrade.tier,
				"description": upgrade.description,
				"building": upgrade.building
			})
	
	return available

# Get available units for a team
func get_available_units(team: int) -> Array:
	return team_unlocked_units[team]

# Apply upgrade effects to a unit
func apply_upgrade_effects(team: int, unit) -> void:
	var race = team_tech_trees[team]
	if race.empty() or not tech_trees.has(race):
		return
	
	var race_data = tech_trees[race]
	
	# Check each researched upgrade
	for upgrade_id in team_researched_upgrades[team]:
		var upgrade_data = null
		for upgrade in race_data.upgrades:
			if upgrade.id == upgrade_id:
				upgrade_data = upgrade
				break
		
		if not upgrade_data or not upgrade_data.has("effects"):
			continue
		
		# Apply effects that target this unit
		for effect in upgrade_data.effects:
			if effect.has("target"):
				var targets = effect.target
				
				# Check if this unit is targeted
				var is_targeted = false
				if targets == "all":
					is_targeted = true
				elif targets is Array:
					if targets.has(unit.unit_id) or targets.has("all"):
						is_targeted = true
				
				if is_targeted:
					_apply_effect_to_unit(unit, effect)

# Apply a specific effect to a unit
func _apply_effect_to_unit(unit, effect: Dictionary) -> void:
	if not effect.has("type") or not effect.has("value"):
		return
	
	match effect.type:
		"attack_damage":
			if effect.has("operation") and effect.operation == "multiply":
				unit.attack_damage *= (1.0 + effect.value)
			else:
				unit.attack_damage += effect.value
		
		"armor":
			if effect.has("operation") and effect.operation == "multiply":
				unit.armor *= (1.0 + effect.value)
			else:
				unit.armor += effect.value
		
		"health":
			if effect.has("operation") and effect.operation == "multiply":
				unit.max_health *= (1.0 + effect.value)
				unit.health = unit.max_health
			else:
				unit.max_health += effect.value
				unit.health = unit.max_health
		
		"attack_speed":
			if effect.has("operation") and effect.operation == "multiply":
				unit.attack_speed *= (1.0 + effect.value)
			else:
				unit.attack_speed += effect.value
		
		"movement_speed":
			if effect.has("operation") and effect.operation == "multiply":
				unit.movement_speed *= (1.0 + effect.value)
			else:
				unit.movement_speed += effect.value
		
		"max_mana":
			if unit.has_mana:
				if effect.has("operation") and effect.operation == "multiply":
					unit.max_mana *= (1.0 + effect.value)
					unit.mana = unit.max_mana
				else:
					unit.max_mana += effect.value
					unit.mana = unit.max_mana
		
		"mana_regen":
			if unit.has_mana:
				if effect.has("operation") and effect.operation == "multiply":
					unit.mana_regen *= (1.0 + effect.value)
				else:
					unit.mana_regen += effect.value
		
		"special_ability":
			# Add special ability to unit
			if unit.has_method("add_ability"):
				unit.add_ability(effect.value, {})

# Get tech tree data for a race
func get_tech_tree(race: String) -> Dictionary:
	if tech_trees.has(race):
		return tech_trees[race]
	return {}

# Get building data for a race and building ID
func get_building_data(race: String, building_id: String) -> Dictionary:
	if not tech_trees.has(race):
		return {}
	
	var race_data = tech_trees[race]
	
	for building in race_data.buildings:
		if building.id == building_id:
			return building
	
	return {}

# Get unit data for a race and unit ID
func get_unit_data(race: String, unit_id: String) -> Dictionary:
	if not tech_trees.has(race):
		return {}
	
	var race_data = tech_trees[race]
	
	for unit in race_data.units:
		if unit.id == unit_id:
			return unit
	
	return {}

# Get upgrade data for a race and upgrade ID
func get_upgrade_data(race: String, upgrade_id: String) -> Dictionary:
	if not tech_trees.has(race):
		return {}
	
	var race_data = tech_trees[race]
	
	for upgrade in race_data.upgrades:
		if upgrade.id == upgrade_id:
			return upgrade
	
	return {}

# Signal handlers
func _on_game_started() -> void:
	# Reset team tech
	for team in team_unlocked_buildings.keys():
		_initialize_team_tech(team)

func _on_game_ended(winning_team: int) -> void:
	# Reset tech trees when game ends
	for team in team_unlocked_buildings.keys():
		team_unlocked_buildings[team].clear()
		team_unlocked_units[team].clear()
		team_researched_upgrades[team].clear()