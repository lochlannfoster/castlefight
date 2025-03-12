extends "res://addons/gut/test.gd"

var EconomyManager = preload("res://scripts/economy/economy_manager.gd")
var economy_manager

func before_each():
    economy_manager = EconomyManager.new()
    add_child(economy_manager)
    
    # Mock the building costs
    economy_manager.building_costs = {
        "barracks": {
            economy_manager.ResourceType.GOLD: 100,
            economy_manager.ResourceType.WOOD: 50,
            economy_manager.ResourceType.SUPPLY: 0
        },
        "farm": {
            economy_manager.ResourceType.GOLD: 50,
            economy_manager.ResourceType.WOOD: 30,
            economy_manager.ResourceType.SUPPLY: 0
        }
    }
    
    # Mock the item costs
    economy_manager.item_costs = {
        "health_potion": {
            economy_manager.ResourceType.GOLD: 25,
            economy_manager.ResourceType.WOOD: 0,
            economy_manager.ResourceType.SUPPLY: 0
        },
        "damage_scroll": {
            economy_manager.ResourceType.GOLD: 75,
            economy_manager.ResourceType.WOOD: 0,
            economy_manager.ResourceType.SUPPLY: 0
        }
    }

func after_each():
    economy_manager.queue_free()
    economy_manager = null

func test_initial_resources():
    for team in [0, 1]:
        assert_true(economy_manager.get_resource(team, economy_manager.ResourceType.GOLD) > 0)
        assert_true(economy_manager.get_resource(team, economy_manager.ResourceType.WOOD) > 0)
        assert_true(economy_manager.get_resource(team, economy_manager.ResourceType.SUPPLY) > 0)

func test_add_resource():
    var team = 0
    var initial_gold = economy_manager.get_resource(team, economy_manager.ResourceType.GOLD)
    
    # Add gold
    var amount = 50
    economy_manager.add_resource(team, economy_manager.ResourceType.GOLD, amount)
    
    # Check new value
    var new_gold = economy_manager.get_resource(team, economy_manager.ResourceType.GOLD)
    assert_eq(new_gold, initial_gold + amount)

func test_can_afford_building():
    var team = 0
    
    # Make sure we have enough resources
    economy_manager.add_resource(team, economy_manager.ResourceType.GOLD, 1000)
    economy_manager.add_resource(team, economy_manager.ResourceType.WOOD, 1000)
    
    # Should be able to afford both buildings
    assert_true(economy_manager.can_afford_building(team, "barracks"))
    assert_true(economy_manager.can_afford_building(team, "farm"))
    
    # Reduce resources to exact cost of barracks
    economy_manager.team_resources[team][economy_manager.ResourceType.GOLD] = 100
    economy_manager.team_resources[team][economy_manager.ResourceType.WOOD] = 50
    
    # Should be able to afford barracks but not farm (not enough wood)
    assert_true(economy_manager.can_afford_building(team, "barracks"))
    assert_false(economy_manager.can_afford_building(team, "farm"))

func test_purchase_building():
	var team = 0
	
	# Make sure we have enough resources
	economy_manager.add_resource(team, economy_manager.ResourceType.GOLD, 1000)
	economy_manager.add_resource(team, economy_manager.ResourceType.WOOD, 1000)
	
	var initial_gold = economy_manager.get_resource(team, economy_manager.ResourceType.GOLD)
	var initial_wood = economy_manager.get_resource(team, economy_manager.ResourceType.WOOD)
	
	# Purchase barracks
	var result = economy_manager.purchase_building(team, "barracks")
	assert_true(result)
	
	# Check resources after purchase
	var new_gold = economy_manager.get_resource(team, economy_manager.ResourceType.GOLD)
	var new_wood = economy_manager.get_resource(team, economy_manager.ResourceType.WOOD)
	
	assert_eq(new_gold, initial_gold - 100)
	assert_eq(new_wood, initial_wood - 50)
	
	# Try to purchase with insufficient resources
	economy_manager.team_resources[team][economy_manager.ResourceType.GOLD] = 10
	result = economy_manager.purchase_building(team, "barracks")
	assert_false(result)

func test_can_afford_item():
	var team = 0
	
	# Make sure we have enough resources
	economy_manager.add_resource(team, economy_manager.ResourceType.GOLD, 1000)
	
	# Should be able to afford both items
	assert_true(economy_manager.can_afford_item(team, "health_potion"))
	assert_true(economy_manager.can_afford_item(team, "damage_scroll"))
	
	# Reduce resources to exact cost of health potion
	economy_manager.team_resources[team][economy_manager.ResourceType.GOLD] = 25
	
	# Should be able to afford health potion but not damage scroll
	assert_true(economy_manager.can_afford_item(team, "health_potion"))
	assert_false(economy_manager.can_afford_item(team, "damage_scroll"))
	
	# Reduce gold
	economy_manager.team_resources[team][economy_manager.ResourceType.GOLD] = 24
	
	# Now can't afford health potion
	assert_false(economy_manager.can_afford_item(team, "health_potion"))

func test_purchase_item():
	var team = 0
	
	# Make sure we have enough resources
	economy_manager.add_resource(team, economy_manager.ResourceType.GOLD, 1000)
	
	var initial_gold = economy_manager.get_resource(team, economy_manager.ResourceType.GOLD)
	
	# Purchase health potion
	var result = economy_manager.purchase_item(team, "health_potion")
	assert_true(result)
	
	# Check resources after purchase
	var new_gold = economy_manager.get_resource(team, economy_manager.ResourceType.GOLD)
	
	assert_eq(new_gold, initial_gold - 25)
	
	# Try to purchase with insufficient resources
	economy_manager.team_resources[team][economy_manager.ResourceType.GOLD] = 10
	result = economy_manager.purchase_item(team, "health_potion")
	assert_false(result)

func test_award_unit_kill_bounty():
	var team = 0
	var initial_gold = economy_manager.get_resource(team, economy_manager.ResourceType.GOLD)
	
	# Mock finding a building that spawns the unit
	economy_manager._find_building_that_spawns_unit = func(unit_type): return "barracks"
	
	# Award bounty (10% of barracks gold cost = 10)
	economy_manager.award_unit_kill_bounty(team, "footman")
	
	var new_gold = economy_manager.get_resource(team, economy_manager.ResourceType.GOLD)
	assert_eq(new_gold, initial_gold + 10)