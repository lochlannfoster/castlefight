extends GutTest

var combat_system = null

func before_each():
	combat_system = CombatSystem.new()
	add_child(combat_system)
	
	# Ensure damage table is loaded
	combat_system._load_damage_tables()

func after_each():
	combat_system.queue_free()
	combat_system = null

func test_damage_type_effectiveness():
	# Test normal vs various armor types
	assert_eq(combat_system.get_attack_type_modifier("normal", "light"), 1.0)
	assert_eq(combat_system.get_attack_type_modifier("normal", "medium"), 1.0)
	assert_eq(combat_system.get_attack_type_modifier("normal", "heavy"), 1.0)
	assert_eq(combat_system.get_attack_type_modifier("normal", "fortified"), 0.5)
	
	# Test piercing vs various armor types
	assert_eq(combat_system.get_attack_type_modifier("piercing", "light"), 1.5)
	assert_eq(combat_system.get_attack_type_modifier("piercing", "medium"), 0.75)
	assert_eq(combat_system.get_attack_type_modifier("piercing", "heavy"), 1.0)
	assert_eq(combat_system.get_attack_type_modifier("piercing", "fortified"), 0.35)
	
	# Test siege vs various armor types
	assert_eq(combat_system.get_attack_type_modifier("siege", "light"), 1.0)
	assert_eq(combat_system.get_attack_type_modifier("siege", "medium"), 0.5)
	assert_eq(combat_system.get_attack_type_modifier("siege", "heavy"), 1.0)
	assert_eq(combat_system.get_attack_type_modifier("siege", "fortified"), 1.5)
	
	# Test magic vs various armor types
	assert_eq(combat_system.get_attack_type_modifier("magic", "light"), 1.25)
	assert_eq(combat_system.get_attack_type_modifier("magic", "medium"), 0.75)
	assert_eq(combat_system.get_attack_type_modifier("magic", "heavy"), 0.4)
	assert_eq(combat_system.get_attack_type_modifier("magic", "fortified"), 1.0)
	
	# Test chaos (should be 1.0 for all armor types)
	assert_eq(combat_system.get_attack_type_modifier("chaos", "light"), 1.0)
	assert_eq(combat_system.get_attack_type_modifier("chaos", "medium"), 1.0)
	assert_eq(combat_system.get_attack_type_modifier("chaos", "heavy"), 1.0)
	assert_eq(combat_system.get_attack_type_modifier("chaos", "fortified"), 1.0)

func test_damage_calculation():
	# Define test cases: attack_type, armor_type, base_damage, armor_value, expected_damage
	var test_cases = [
		["normal", "medium", 100.0, 0.0, 100.0],  # No armor reduction
		["normal", "medium", 100.0, 20.0, 50.0],  # 50% reduction from 20 armor
		["normal", "fortified", 100.0, 0.0, 50.0],  # 50% type modifier
		["normal", "fortified", 100.0, 20.0, 25.0],  # Combined reductions
		["piercing", "light", 100.0, 0.0, 150.0],  # 150% type modifier
		["piercing", "light", 100.0, 20.0, 75.0],  # Type modifier with armor
		["siege", "fortified", 100.0, 0.0, 150.0],  # Siege vs fortified
		["siege", "fortified", 100.0, 20.0, 75.0]  # Siege vs fortified with armor
	]
	
	for case in test_cases:
		var attack_type = case[0]
		var armor_type = case[1]
		var base_damage = case[2]
		var armor_value = case[3]
		var expected_damage = case[4]
		
		var actual_damage = combat_system.calculate_damage(base_damage, attack_type, armor_value, armor_type)
		assert_almost_eq(actual_damage, expected_damage, 0.1, "Failed on case: %s" % case)

func test_minimum_damage():
	# Even with high armor and unfavorable type matching, damage should never be less than 1
	var damage = combat_system.calculate_damage(10.0, "normal", 100.0, "fortified")
	assert_true(damage >= 1.0)

func test_invalid_attack_armor_types():
	# Test with invalid attack type
	var damage = combat_system.calculate_damage(100.0, "invalid_type", 0.0, "medium")
	assert_eq(damage, 100.0)  # Should default to normal attack type
	
	# Test with invalid armor type
	damage = combat_system.calculate_damage(100.0, "normal", 0.0, "invalid_armor")
	assert_eq(damage, 100.0)  # Should default to medium armor type

func test_effective_dps_calculation():
	# Test normal attack, light armor
	var dps = combat_system.calculate_effective_dps({
		"attack_damage": 50.0,
		"attack_type": "normal",
		"attack_speed": 1.0
	}, "light")
	assert_eq(dps, 50.0)
	
	# Test piercing attack, light armor (1.5x modifier)
	dps = combat_system.calculate_effective_dps({
		"attack_damage": 50.0,
		"attack_type": "piercing",
		"attack_speed": 1.0
	}, "light")
	assert_eq(dps, 75.0)
	
	# Test with higher attack speed
	dps = combat_system.calculate_effective_dps({
		"attack_damage": 50.0,
		"attack_type": "normal",
		"attack_speed": 2.0
	}, "light")
	assert_eq(dps, 100.0)

func test_is_effective_against():
	# Positive cases
	assert_true(combat_system.is_effective_against("piercing", "light"))
	assert_true(combat_system.is_effective_against("siege", "fortified"))
	assert_true(combat_system.is_effective_against("magic", "light"))
	assert_true(combat_system.is_effective_against("magic", "unarmored"))
	
	# Negative cases
	assert_false(combat_system.is_effective_against("piercing", "fortified"))
	assert_false(combat_system.is_effective_against("siege", "medium"))
	assert_false(combat_system.is_effective_against("magic", "heavy"))

func test_apply_status_effect():
	# Create test unit
	var unit = Object.new()
	unit.applied_effects = []
	
	# Mock apply_buff and apply_debuff methods
	unit.apply_buff = func(effect_name, effect_data): applied_effects.append(effect_name)
	unit.apply_debuff = func(effect_name, effect_data): applied_effects.append(effect_name)
	unit.apply_stun = func(duration): applied_effects.append("stun")
	
	# Apply some status effects
	combat_system.apply_status_effect(unit, "speed_boost", 5.0, 0.2)
	assert_true("speed_boost" in unit.applied_effects)
	
	combat_system.apply_status_effect(unit, "stun", 3.0)
	assert_true("stun" in unit.applied_effects)
	
	combat_system.apply_status_effect(unit, "damage_reduction", 5.0, 0.25)
	assert_true("damage_reduction" in unit.applied_effects)
	
	unit.free()