# Economy Manager - Handles resources, income, and purchases
# Path: scripts/economy/economy_manager.gd
extends Node

# Economy signals
signal resources_changed(team, resource_type, amount)
signal income_changed(team, amount)
signal income_tick(team, amount)
signal purchase_made(team, item_type, cost)
signal purchase_failed(team, item_type, reason)
signal bounty_earned(team, amount, source)

# Resource constants
enum ResourceType {GOLD, WOOD, SUPPLY}

# Income settings
export var base_income: float = 10.0  # Base income per tick
export var income_interval: float = 10.0  # Seconds between income ticks

# Team resources
var team_resources: Dictionary = {
	0: {  # Team A
		ResourceType.GOLD: 100,
		ResourceType.WOOD: 50,
		ResourceType.SUPPLY: 10
	},
	1: {  # Team B
		ResourceType.GOLD: 100,
		ResourceType.WOOD: 50,
		ResourceType.SUPPLY: 10
	}
}

# Team income rates
var team_income: Dictionary = {
	0: base_income,  # Team A
	1: base_income   # Team B
}

# Costs for buildings, units, and items
var building_costs: Dictionary = {}
var item_costs: Dictionary = {}

# Income timer
var income_timer: float = 0.0

# References
var ui_manager

# Ready function
func _ready() -> void:
	# Try to get reference to UI manager for displaying income ticks
	ui_manager = get_node_or_null("/root/GameManager/UIManager")
	
	# Load cost data
	_load_cost_data()

# Process function for handling income ticks
func _process(delta: float) -> void:
	income_timer += delta
	
	if income_timer >= income_interval:
		income_timer -= income_interval
		_distribute_income()

# Load costs for buildings and items from data files
func _load_cost_data() -> void:
	# Load building costs
	_load_building_costs()
	
	# Load item costs
	_load_item_costs()

# Load building costs from data files
func _load_building_costs() -> void:
	var data_path = "res://data/buildings/"
	
	var dir = Directory.new()
	if dir.open(data_path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".json"):
				var building_id = file_name.get_basename()
				var file_path = data_path + file_name
				_load_building_cost_file(building_id, file_path)
			file_name = dir.get_next()
	else:
		push_error("Error: Could not open building data directory")

# Load a single building cost file
func _load_building_cost_file(building_id: String, file_path: String) -> void:
	var file = File.new()
	if file.open(file_path, File.READ) == OK:
		var text = file.get_as_text()
		file.close()
		
		var parse_result = JSON.parse(text)
		if parse_result.error == OK:
			var data = parse_result.result
			
			# Extract cost information
			var cost_data = {
				ResourceType.GOLD: data.gold_cost if data.has("gold_cost") else 0,
				ResourceType.WOOD: data.wood_cost if data.has("wood_cost") else 0,
				ResourceType.SUPPLY: data.supply_cost if data.has("supply_cost") else 0
			}
			
			building_costs[building_id] = cost_data
			print("Loaded building cost: ", building_id)
		else:
			push_error("Error parsing building data: " + file_path)
	else:
		push_error("Error opening building file: " + file_path)

# Load item costs from data files
func _load_item_costs() -> void:
	var data_path = "res://data/items/"
	
	var dir = Directory.new()
	if dir.open(data_path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".json"):
				var item_id = file_name.get_basename()
				var file_path = data_path + file_name
				_load_item_cost_file(item_id, file_path)
			file_name = dir.get_next()
	else:
		# Items might not exist yet, so just print a warning
		print("Warning: Could not open items data directory")

# Load a single item cost file
func _load_item_cost_file(item_id: String, file_path: String) -> void:
	var file = File.new()
	if file.open(file_path, File.READ) == OK:
		var text = file.get_as_text()
		file.close()
		
		var parse_result = JSON.parse(text)
		if parse_result.error == OK:
			var data = parse_result.result
			
			# Extract cost information
			var cost_data = {
				ResourceType.GOLD: data.gold_cost if data.has("gold_cost") else 0,
				ResourceType.WOOD: data.wood_cost if data.has("wood_cost") else 0,
				ResourceType.SUPPLY: data.supply_cost if data.has("supply_cost") else 0
			}
			
			item_costs[item_id] = cost_data
			print("Loaded item cost: ", item_id)
		else:
			push_error("Error parsing item data: " + file_path)
	else:
		push_error("Error opening item file: " + file_path)

# Distribute income to all teams
func _distribute_income() -> void:
	for team in team_income.keys():
		var income_amount = team_income[team]
		
		# Add gold to team resources
		add_resource(team, ResourceType.GOLD, income_amount)
		
		# Show income popup if UI manager exists
		if ui_manager:
			ui_manager.show_income_popup(team, income_amount)
		
		emit_signal("income_tick", team, income_amount)

# Add resources to a team
func add_resource(team: int, resource_type: int, amount: float) -> void:
	if not team_resources.has(team):
		# Initialize this team if it doesn't exist (to handle -1 case)
		team_resources[team] = {
			ResourceType.GOLD: 0,
			ResourceType.WOOD: 0,
			ResourceType.SUPPLY: 0
		}
	
	team_resources[team][resource_type] += amount
	emit_signal("resources_changed", team, resource_type, team_resources[team][resource_type])


# Get a team's resource amount
func get_resource(team: int, resource_type: int) -> float:
	if not team_resources.has(team):
		push_error("Invalid team: " + str(team))
		return 0.0
	
	if not team_resources[team].has(resource_type):
		push_error("Invalid resource type: " + str(resource_type))
		return 0.0
	
	return team_resources[team][resource_type]

# Add to a team's income
func add_income(team: int, amount: float) -> void:
	if not team_income.has(team):
		push_error("Invalid team: " + str(team))
		return
	
	team_income[team] += amount
	
	emit_signal("income_changed", team, team_income[team])

# Get a team's income rate
func get_income(team: int) -> float:
	if not team_income.has(team):
		push_error("Invalid team: " + str(team))
		return 0.0
	
	return team_income[team]

# Check if a team can afford a building
func can_afford_building(team: int, building_type: String) -> bool:
	if not building_costs.has(building_type):
		push_error("Unknown building type: " + building_type)
		return false
	
	var costs = building_costs[building_type]
	
	# Check each resource type
	for resource_type in costs.keys():
		if get_resource(team, resource_type) < costs[resource_type]:
			return false
	
	return true

# Purchase a building
func purchase_building(team: int, building_type: String) -> bool:
	if not can_afford_building(team, building_type):
		emit_signal("purchase_failed", team, building_type, "Not enough resources")
		return false
	
	var costs = building_costs[building_type]
	var total_cost = 0.0
	
	# Deduct each resource type
	for resource_type in costs.keys():
		var cost = costs[resource_type]
		add_resource(team, resource_type, -cost)
		
		if resource_type == ResourceType.GOLD:
			total_cost = cost  # For income calculations, we only care about gold
	
	emit_signal("purchase_made", team, building_type, total_cost)
	
	return true

# Check if a team can afford an item
func can_afford_item(team: int, item_type: String) -> bool:
	if not item_costs.has(item_type):
		push_error("Unknown item type: " + item_type)
		return false
	
	var costs = item_costs[item_type]
	
	# Check each resource type
	for resource_type in costs.keys():
		if get_resource(team, resource_type) < costs[resource_type]:
			return false
	
	return true

# Purchase an item
func purchase_item(team: int, item_type: String) -> bool:
	if not can_afford_item(team, item_type):
		emit_signal("purchase_failed", team, item_type, "Not enough resources")
		return false
	
	var costs = item_costs[item_type]
	var total_cost = 0.0
	
	# Deduct each resource type
	for resource_type in costs.keys():
		var cost = costs[resource_type]
		add_resource(team, resource_type, -cost)
		
		if resource_type == ResourceType.GOLD:
			total_cost = cost
	
	emit_signal("purchase_made", team, item_type, total_cost)
	
	return true

# Award a bounty for killing a unit
func award_unit_kill_bounty(team: int, unit_type: String, _killer_unit = null) -> void:
	# Find the building that spawns this unit type
	var spawning_building_type = _find_building_that_spawns_unit(unit_type)
	
	if spawning_building_type.empty():
		# Default bounty if we can't find the spawning building
		var default_bounty = 5.0
		_award_bounty(team, default_bounty, "Unit Kill: " + unit_type)
		return
	
	# Get building cost
	if not building_costs.has(spawning_building_type):
		return
	
	# Bounty is 10% of the gold cost of the building that spawns the unit
	var gold_cost = building_costs[spawning_building_type][ResourceType.GOLD]
	var bounty_amount = gold_cost * 0.1
	
	_award_bounty(team, bounty_amount, "Unit Kill: " + unit_type)

# Find which building spawns a given unit type
func _find_building_that_spawns_unit(unit_type: String) -> String:
	var data_path = "res://data/buildings/"
	
	var dir = Directory.new()
	if dir.open(data_path) != OK:
		return ""
	
	dir.list_dir_begin(true, true)
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var building_id = file_name.get_basename()
			var file_path = data_path + file_name
			
			var file = File.new()
			if file.open(file_path, File.READ) == OK:
				var text = file.get_as_text()
				file.close()
				
				var parse_result = JSON.parse(text)
				if parse_result.error == OK:
					var data = parse_result.result
					
					# Check if this building spawns the unit
					if data.has("unit_types") and data.unit_types is Array:
						for spawned_unit in data.unit_types:
							if spawned_unit == unit_type:
								return building_id
			
		file_name = dir.get_next()
	
	return ""

# Award a bounty to a team
func _award_bounty(team: int, amount: float, source: String) -> void:
	# Distribute bounty among team members (in a multiplayer game)
	# For now, just give it all to the single team
	add_resource(team, ResourceType.GOLD, amount)
	
	# Show bounty popup if UI manager exists
	if ui_manager:
		ui_manager.show_bounty_popup(team, amount, source)
	
	emit_signal("bounty_earned", team, amount, source)

# Convert a resource type enum to string
func resource_type_to_string(resource_type: int) -> String:
	match resource_type:
		ResourceType.GOLD:
			return "Gold"
		ResourceType.WOOD:
			return "Wood"
		ResourceType.SUPPLY:
			return "Supply"
		_:
			return "Unknown"

# Get the total gold cost of a building
func get_building_gold_cost(building_type: String) -> float:
	if not building_costs.has(building_type):
		return 0.0
	
	return building_costs[building_type][ResourceType.GOLD]

# Get the total gold cost of an item
func get_item_gold_cost(item_type: String) -> float:
	if not item_costs.has(item_type):
		return 0.0
	
	return item_costs[item_type][ResourceType.GOLD]

	# Allow directly setting a resource value (needed for network synchronization)
# Allow directly setting a resource value (needed for network synchronization)
func set_resource(team: int, resource_type: int, amount: float) -> void:
	if not team_resources.has(team):
		# Initialize this team if it doesn't exist
		team_resources[team] = {
			ResourceType.GOLD: 0,
			ResourceType.WOOD: 0,
			ResourceType.SUPPLY: 0
		}
		
		# Also initialize statistics tracking if needed
		if not total_resources_collected.has(team):
			total_resources_collected[team] = {
				ResourceType.GOLD: 0,
				ResourceType.WOOD: 0,
				ResourceType.SUPPLY: 0
			}
			
			total_resources_spent[team] = {
				ResourceType.GOLD: 0,
				ResourceType.WOOD: 0,
				ResourceType.SUPPLY: 0
			}
	
	# Update the resource value
	team_resources[team][resource_type] = amount
	
	# Emit signal for UI updates
	emit_signal("resources_changed", team, resource_type, amount)

# Get total income across game for a team
func get_total_income(team: int) -> float:
	if not total_resources_collected.has(team):
		return 0.0
	
	return total_resources_collected[team][ResourceType.GOLD]

# Register a player with a team
func register_player(player_id: int, team: int) -> void:
	player_teams[player_id] = team
	player_resources_spent[player_id] = {
		ResourceType.GOLD: 0,
		ResourceType.WOOD: 0,
		ResourceType.SUPPLY: 0
	}

# Track resource spending by player
func track_player_spending(player_id: int, resource_type: int, amount: float) -> void:
	if not player_resources_spent.has(player_id):
		player_resources_spent[player_id] = {
			ResourceType.GOLD: 0,
			ResourceType.WOOD: 0,
			ResourceType.SUPPLY: 0
		}
	
	player_resources_spent[player_id][resource_type] += amount

# Get total resources spent by a player
func get_total_resources_spent_by_player(player_id: int) -> float:
	if not player_resources_spent.has(player_id):
		return 0.0
	
	var total = 0.0
	for resource_type in player_resources_spent[player_id]:
		total += player_resources_spent[player_id][resource_type]
	
	return total

# Get total of a specific resource collected by a team
func get_total_resources_collected(team: int, resource_type: int) -> float:
	if not total_resources_collected.has(team) or 
	   not total_resources_collected[team].has(resource_type):
		return 0.0
	
	return total_resources_collected[team][resource_type]

# Modify add_resource to track total collections
# Modify add_resource to track total collections
func add_resource(team: int, resource_type: int, amount: float) -> void:
	if not team_resources.has(team):
		# Initialize this team if it doesn't exist
		team_resources[team] = {
			ResourceType.GOLD: 0,
			ResourceType.WOOD: 0,
			ResourceType.SUPPLY: 0
		}
		
		# Also initialize statistics tracking
		if not total_resources_collected.has(team):
			total_resources_collected[team] = {
				ResourceType.GOLD: 0,
				ResourceType.WOOD: 0,
				ResourceType.SUPPLY: 0
			}
			
			total_resources_spent[team] = {
				ResourceType.GOLD: 0,
				ResourceType.WOOD: 0,
				ResourceType.SUPPLY: 0
			}
	
	# Update current resources
	team_resources[team][resource_type] += amount
	
	# Track resource statistics
	if amount > 0:
		# Resource collected
		total_resources_collected[team][resource_type] += amount
	else:
		# Resource spent
		total_resources_spent[team][resource_type] -= amount  # Convert to positive
	
	emit_signal("resources_changed", team, resource_type, team_resources[team][resource_type])
