# scripts/core/entity_configurator.gd
extends Node

# Configure any entity with JSON data
func configure_from_json(entity, data: Dictionary) -> void:
    # Loop through all data properties
    for key in data.keys():
        if key == "stats":
            _configure_stats(entity, data.stats)
        elif key == "abilities" and data.abilities is Array:
            _configure_abilities(entity, data.abilities)
        elif key == "animations" and data.animations is Dictionary:
            _configure_animations(entity, data.animations)
        elif key == "sounds" and data.sounds is Dictionary:
            _configure_sounds(entity, data.sounds)
        elif entity.get(key) != null:
            # Only set properties that already exist on the entity
            entity.set(key, data[key])

# Configure entity stats
func _configure_stats(entity, stats: Dictionary) -> void:
    for stat_name in stats:
        if entity.get(stat_name) != null:
            entity.set(stat_name, stats[stat_name])

# Configure abilities
func _configure_abilities(entity, abilities: Array) -> void:
    if entity.has_method("add_ability"):
        for ability_data in abilities:
            if ability_data is Dictionary and ability_data.has("name"):
                entity.add_ability(ability_data.name, ability_data)

# Configure animations
func _configure_animations(_entity, _animations: Dictionary) -> void:
    # Add implementation based on your animation system
    pass

# Configure sounds
func _configure_sounds(_entity, _sounds: Dictionary) -> void:
    # Add implementation based on your sound system
    pass