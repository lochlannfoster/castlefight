#extends GameService

# Signal for when combat events occur
signal combat_event(attacker, target, damage, attack_type)

# Damage type effectiveness table (similar to Warcraft 3)
# Format: attack_type -> armor_type -> modifier
var damage_table = {
    "normal": {
        "light": 1.0,
        "medium": 1.0,
        "heavy": 1.0,
        "fortified": 0.5,
        "hero": 1.0,
        "unarmored": 1.0
    },
    "piercing": {
        "light": 1.5,
        "medium": 0.75,
        "heavy": 1.0,
        "fortified": 0.35,
        "hero": 0.5,
        "unarmored": 1.0
    },
    # ... (rest of the damage table)
}

func _init() -> void:
    service_name = "CombatSystem"
    required_services = []

func debug_log(message: String, level: String = "info", context: String = "") -> void:
    var logger = get_node_or_null("/root/Logger")
    if logger:
        match level.to_lower():
            "error":
                logger.error(message, context if context else service_name)
            "warning":
                logger.warning(message, context if context else service_name)
            "debug":
                logger.debug(message, context if context else service_name)
            "verbose":
                logger.debug(message, context if context else service_name)
            _:
                logger.info(message, context if context else service_name)
    else:
        # Fallback to print
        var prefix = "[" + level.to_upper() + "]"
        if context:
            prefix += "[" + context + "]"
        elif service_name:
            prefix += "[" + service_name + "]"
        print(prefix + " " + message)

func _initialize_impl() -> void:
    # Load custom damage tables if needed
    _load_damage_tables()
    
    debug_log("Combat system initialized", "info")

# Load custom damage tables from configuration
func _load_damage_tables() -> void:
    var config_path = "res://data/combat/damage_table.json"
    var file = File.new()
    
    if file.file_exists(config_path):
        if file.open(config_path, File.READ) == OK:
            var text = file.get_as_text()
            file.close()
            
            var parse_result = JSON.parse(text)
            if parse_result.error == OK:
                var data = parse_result.result
                
                # Merge with existing table
                for attack_type in data.keys():
                    if not damage_table.has(attack_type):
                        damage_table[attack_type] = {}
                    
                    for armor_type in data[attack_type].keys():
                        damage_table[attack_type][armor_type] = data[attack_type][armor_type]
                
                print("Loaded custom damage table")
            else:
                push_error("Error parsing damage table: " + config_path)
        else:
            push_error("Error opening damage table file: " + config_path)

# Calculate damage based on attack type and armor type
func calculate_damage(base_damage: float, attack_type: String, armor_value: float, armor_type: String) -> float:
    # Get type modifier
    var type_modifier = damage_table[attack_type][armor_type]
    
    # Apply armor reduction (each point of armor reduces damage by ~5%)
    var armor_reduction = 1.0 - (armor_value / (armor_value + 20.0)) # This formula gives diminishing returns
    
    # Calculate final damage
    var final_damage = base_damage * type_modifier * armor_reduction
    
    # Ensure minimum damage (at least 1 damage)
    final_damage = max(1.0, final_damage)
    
    return final_damage

# Process an attack between two entities
func process_attack(attacker, target, attack_damage = null, attack_type = null) -> float:
    # If no specific damage/type provided, use attacker's values
    if attack_damage == null and attacker.has_method("get_attack_damage"):
        attack_damage = attacker.get_attack_damage()
    elif attack_damage == null:
        attack_damage = attacker.attack_damage if "attack_damage" in attacker else 10.0
    
    if attack_type == null and attacker.has_method("get_attack_type"):
        attack_type = attacker.get_attack_type()
    elif attack_type == null:
        attack_type = attacker.attack_type if "attack_type" in attacker else "normal"
    
    # Get target's armor
    var armor_value = 0.0
    var armor_type = "medium"
    
    if target.has_method("get_armor"):
        armor_value = target.get_armor()
    else:
        armor_value = target.armor if "armor" in target else 0.0
    
    if target.has_method("get_armor_type"):
        armor_type = target.get_armor_type()
    else:
        armor_type = target.armor_type if "armor_type" in target else "medium"
    
    # Calculate damage
    var damage = calculate_damage(attack_damage, attack_type, armor_value, armor_type)
    
    # Apply damage to target
    if target.has_method("take_damage"):
        target.take_damage(damage, attacker)
    
    # Emit signal
    emit_signal("combat_event", attacker, target, damage, attack_type)
    
    return damage

# Get attack type modifier against an armor type
func get_attack_type_modifier(attack_type: String, armor_type: String) -> float:
    if not damage_table.has(attack_type):
        attack_type = "normal"
    
    if not damage_table[attack_type].has(armor_type):
        armor_type = "medium"
    
    return damage_table[attack_type][armor_type]

# Calculate the effective DPS (damage per second) for a unit against an armor type
func calculate_effective_dps(unit, armor_type: String) -> float:
    var attack_damage = unit.attack_damage if "attack_damage" in unit else 10.0
    var attack_type = unit.attack_type if "attack_type" in unit else "normal"
    var attack_speed = unit.attack_speed if "attack_speed" in unit else 1.0
    
    var type_modifier = get_attack_type_modifier(attack_type, armor_type)
    
    return attack_damage * type_modifier * attack_speed

# Process a spell cast from a unit to a target or area
func process_spell(_caster, spell_id: String, _target = null, _position: Vector2 = Vector2.ZERO) -> void:
    # This would need to be implemented based on your spell system
    # For now, just a placeholder function
    print("Spell cast: " + spell_id)

# Apply a status effect to a target
func apply_status_effect(target, effect_type: String, duration: float, value: float = 0.0, source = null) -> void:
    # Check if target can receive status effects
    if not target.has_method("apply_buff") and not target.has_method("apply_debuff"):
        return
    
    # Prepare effect data
    var effect_data = {
        "duration": duration,
        "value": value,
        "source": source
    }
    
    # Apply based on effect type
    match effect_type:
        "stun":
            if target.has_method("apply_stun"):
                target.apply_stun(duration)
        "speed_boost":
            effect_data["speed_modifier"] = 1.0 + value # Increase speed by value%
            if target.has_method("apply_buff"):
                target.apply_buff("speed_boost", effect_data)
        "speed_slow":
            effect_data["speed_modifier"] = 1.0 - value # Decrease speed by value%
            if target.has_method("apply_debuff"):
                target.apply_debuff("speed_slow", effect_data)
        "damage_boost":
            effect_data["damage_modifier"] = 1.0 + value # Increase damage by value%
            if target.has_method("apply_buff"):
                target.apply_buff("damage_boost", effect_data)
        "damage_reduction":
            effect_data["damage_modifier"] = 1.0 - value # Decrease damage by value%
            if target.has_method("apply_debuff"):
                target.apply_debuff("damage_reduction", effect_data)
        "heal_over_time":
            # This would need custom handling in the target's _process function
            effect_data["heal_per_second"] = value
            if target.has_method("apply_buff"):
                target.apply_buff("regeneration", effect_data)
        "damage_over_time":
            # This would need custom handling in the target's _process function
            effect_data["damage_per_second"] = value
            if target.has_method("apply_debuff"):
                target.apply_debuff("damage_over_time", effect_data)

# Check if an attack would be effective against a particular armor type
func is_effective_against(attack_type: String, armor_type: String) -> bool:
    return get_attack_type_modifier(attack_type, armor_type) > 1.0

# Get a list of all registered attack types
func get_attack_types() -> Array:
    return damage_table.keys()

# Get a list of all registered armor types
func get_armor_types() -> Array:
    var types = []
    
    # Collect unique armor types from the damage table
    for attack_type in damage_table.keys():
        for armor_type in damage_table[attack_type].keys():
            if not types.has(armor_type):
                types.append(armor_type)
    
    return types

func initialize() -> void:
    print("CombatSystem: Initializing...")
    
    # Load damage tables if needed
    _load_damage_tables()
    
    # Add references to other systems
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager:
        if game_manager.has_method("get_system"):
            # Use the get_system helper if available
            var building_manager = game_manager.get_system("BuildingManager")
            # Note: We're prefixing with underscore to indicate intentionally unused variable
            var _unit_factory = game_manager.get_system("UnitFactory")
            
            # Connect signals if needed
            if building_manager and not building_manager.is_connected("building_destroyed", self, "_on_building_destroyed"):
                building_manager.connect("building_destroyed", self, "_on_building_destroyed")
    
    print("CombatSystem: Initialization complete")
