# Base class for all combat units
# Path: scripts/unit/unit_base.gd
class_name Unit
extends KinematicBody2D

# Unit signals
signal unit_spawned
signal unit_damaged(amount, attacker)
signal unit_healed(amount)
signal unit_died(killer)
signal attack_performed(target, damage)
signal ability_used(ability_name, target)

# Unit properties
export var unit_id: String = "base_unit"
export var display_name: String = "Unit"
export var health: float = 100.0
export var max_health: float = 100.0
export var armor: float = 0.0
export var armor_type: String = "medium" # light, medium, heavy, etc.
export var attack_damage: float = 10.0
export var attack_type: String = "normal" # normal, piercing, siege, etc.
export var attack_range: float = 60.0
export var attack_speed: float = 1.0 # Attacks per second
export var movement_speed: float = 100.0
export var team: int = 0 # 0 = Team A, 1 = Team B
export var collision_radius: float = 16.0
export var vision_range: float = 300.0
export var health_regen: float = 0.25 # Health per second
export var mana_regen: float = 0.25 # Mana per second
export var has_mana: bool = false
export var mana: float = 50.0
export var max_mana: float = 100.0

# State tracking
enum UnitState {IDLE, MOVING, ATTACKING, CASTING, STUNNED, DEAD}
var current_state: int = UnitState.IDLE
var target = null # Current attack target
var attack_timer: float = 0.0
var regen_timer: float = 0.0
var stun_duration: float = 0.0
var is_visible_to_enemy: bool = false
var speed_modifiers: Array = [] # Array of {value, duration} dictionaries
var damage_modifiers: Array = [] # Array of {value, duration} dictionaries

# Pathing and movement
var path: Array = []
var velocity: Vector2 = Vector2.ZERO
var enemy_hq_position: Vector2 = Vector2.ZERO
var navigation_node
var should_attack_move: bool = true

# Visual and effects
var sprite: Sprite
var animation_player: AnimationPlayer
var health_bar: ProgressBar
var effects_node: Node2D # For visual effects
var current_animation: String = "idle"

# Abilities and buffs
var abilities: Array = []
var buffs: Array = []
var debuffs: Array = []

# References
var combat_manager
var target_finder
var grid_system

# Initialization
func _ready() -> void:
    _initialize_core_systems()
    _setup_core_components()
    _configure_default_behavior()

func _initialize_core_systems() -> void:
    # Get references to managers
    combat_manager = get_node_or_null("/root/CombatSystem")
    grid_system = get_node_or_null("/root/GridSystem")
    
    # Set up core components if needed
    if not has_node("CollisionShape2D"):
        var collision = CollisionShape2D.new()
        var shape = CircleShape2D.new()
        shape.radius = collision_radius
        collision.shape = shape
        add_child(collision)

# Process function
func _physics_process(delta: float) -> void:
    # Skip processing if dead
    if current_state == UnitState.DEAD:
        return
    
    # Handle regeneration
    _handle_regeneration(delta)
    
    # Handle stun duration
    if current_state == UnitState.STUNNED:
        stun_duration -= delta
        if stun_duration <= 0:
            current_state = UnitState.IDLE
    
    # Process based on current state
    match current_state:
        UnitState.IDLE:
            _process_idle(delta)
        UnitState.MOVING:
            _process_movement(delta)
        UnitState.ATTACKING:
            _process_attacking(delta)
        UnitState.CASTING:
            _process_casting(delta)
    
    # Update modifiers
    _update_modifiers(delta)
    
    # Update animation
    _update_animation()

# Setup health bar
func _setup_health_bar() -> void:
    health_bar = ProgressBar.new()
    health_bar.rect_size = Vector2(32, 5)
    health_bar.rect_position = Vector2(-16, -25) # Position above unit
    health_bar.min_value = 0
    health_bar.max_value = max_health
    health_bar.value = health
    health_bar.percent_visible = false
    health_bar.modulate = Color(0.2, 1.0, 0.2) # Green
    add_child(health_bar)

# Get enemy HQ position
func _get_enemy_hq_position() -> void:
    var game_manager = get_node("/root/GameManager")
    var enemy_team = 1 if team == 0 else 0
    
    # Check if game manager has headquarters positions
    if game_manager.has_method("get_headquarters_position"):
        enemy_hq_position = game_manager.get_headquarters_position(enemy_team)
    else:
        # Default positions if not available
        enemy_hq_position = Vector2(1500, 400) if team == 0 else Vector2(100, 400)

# Start attack-move toward enemy base
func _start_attack_move() -> void:
    set_target_position(enemy_hq_position)
    current_state = UnitState.MOVING

# Process idle state
func _process_idle(_delta: float) -> void:
    # Look for targets
    var potential_target = find_target()
    
    if potential_target:
        # Found a target, attack it
        target = potential_target
        current_state = UnitState.ATTACKING
    else:
        # No target, resume attack-move
        if should_attack_move:
            set_target_position(enemy_hq_position)
            current_state = UnitState.MOVING

# Process movement state
func _process_movement(_delta: float) -> void:
    if path.empty():
        current_state = UnitState.IDLE
        return
    
    var next_point = path[0]
    var distance_to_next = global_position.distance_to(next_point)
    
    if distance_to_next < 10:
        path.remove(0)
        
        if path.empty():
            current_state = UnitState.IDLE
            return
        
        next_point = path[0]
    
    # Enhanced movement with state management
    var direction = global_position.direction_to(next_point)
    var modified_speed = movement_speed * _get_speed_modifier()
    
    velocity = direction * modified_speed
    velocity = move_and_slide(velocity)

# Process attacking state
func _process_attacking(delta: float) -> void:
    # Check if target is still valid
    if not is_instance_valid(target) or target.current_state == UnitState.DEAD:
        target = null
        current_state = UnitState.IDLE
        return

    # Check if target is in range  
    var distance_to_target = global_position.distance_to(target.global_position)

    if distance_to_target > attack_range:
        # Move toward target
        set_target_position(target.global_position)
        current_state = UnitState.MOVING
        return

    # Look at target
    var direction = global_position.direction_to(target.global_position)
    if direction.x < 0:
        sprite.flip_h = true
    else:
        sprite.flip_h = false
    
    # Attack timer
    attack_timer += delta

    if attack_timer >= 1.0 / attack_speed:
        attack_timer = 0
        _perform_attack()

# Process casting state
func _process_casting(_delta: float) -> void:
    # This will be handled by specific unit implementations
    pass

# Perform an attack on the current target
func _perform_attack() -> void:
    if not is_instance_valid(target) or target.current_state == UnitState.DEAD:
        target = null
        current_state = UnitState.IDLE
        return
    
    # Calculate damage with modifiers
    var base_damage = attack_damage * _get_damage_modifier()
    
    # Apply damage to target
    var actual_damage = combat_manager.calculate_damage(base_damage, attack_type, target.armor, target.armor_type)
    target.take_damage(actual_damage, self)
    
    emit_signal("attack_performed", target, actual_damage)
    
    # Play attack animation
    if animation_player and animation_player.has_animation("attack"):
        animation_player.play("attack")
        current_animation = "attack"

func find_best_target(targeting_strategy: String = "closest") -> Object:
    match targeting_strategy:
        "closest":
            return _find_closest_target()
        "lowest_health":
            return _find_lowest_health_target()
        "highest_threat":
            return _find_highest_threat_target()
        _:
            return _find_closest_target()

func _find_closest_target() -> Object:
    # Existing closest target logic
    var closest_distance = INF
    var closest_target = null
    
    # Your existing target finding logic here
    return closest_target

func _find_lowest_health_target() -> Object:
    # New method to find target with lowest health
    var lowest_health_target = null
    var lowest_health = INF
    
    # Implement logic to find lowest health target
    return lowest_health_target

func _find_highest_threat_target() -> Object:
    # New method to find most threatening target
    var highest_threat_target = null
    var highest_threat_value = - INF
    
    # Implement logic to find highest threat target
    return highest_threat_target

# Set a target position to move to
func set_target_position(position: Vector2) -> void:
    if navigation_node:
        # Use navigation system for pathfinding
        path = navigation_node.get_simple_path(global_position, position, false)
    else:
        # Simple direct path if no navigation system
        path = [position]
    
    current_state = UnitState.MOVING

# Take damage from an attacker
func take_damage(amount: float, attacker = null) -> void:
    if current_state == UnitState.DEAD:
        return
    
    # Apply armor reduction (handled by combat manager)
    
    # Reduce health
    health -= amount
    
    # Update health bar
    health_bar.value = health
    
    emit_signal("unit_damaged", amount, attacker)
    
    # Check if dead
    if health <= 0:
        _die(attacker)
    else:
        # Play hurt animation
        if animation_player and animation_player.has_animation("hurt"):
            animation_player.play("hurt")
            current_animation = "hurt"
        
        # If attacked and not already attacking someone, attack the attacker
        if attacker and current_state != UnitState.ATTACKING and attacker.team != team:
            target = attacker
            current_state = UnitState.ATTACKING

# Heal the unit
func heal(amount: float) -> void:
    if current_state == UnitState.DEAD:
        return
    
    var old_health = health
    health = min(health + amount, max_health)
    var actual_heal = health - old_health
    
    # Update health bar
    health_bar.value = health
    
    emit_signal("unit_healed", actual_heal)

# Die
func _die(killer = null) -> void:
    current_state = UnitState.DEAD
    health = 0
    
    # Update health bar
    health_bar.value = 0
    
    # Stop all movement
    velocity = Vector2.ZERO
    path.clear()
    
    # Play death animation
    if animation_player and animation_player.has_animation("death"):
        animation_player.play("death")
        current_animation = "death"
    
    emit_signal("unit_died", killer)
    
    # Award bounty to killer's team if applicable
    if killer and killer.has_method("get_team"):
        var killer_team = killer.get_team()
        var economy_manager = get_node("/root/GameManager/EconomyManager")
        if economy_manager:
            economy_manager.award_unit_kill_bounty(killer_team, unit_id, killer)
    
    # Remove collision
    $CollisionShape2D.disabled = true
    
    # Queue for removal (with delay if showing death animation)
    if animation_player and animation_player.has_animation("death"):
        yield (animation_player, "animation_finished")
    
    queue_free()

# Apply a stun effect
func apply_stun(duration: float) -> void:
    if current_state == UnitState.DEAD:
        return
    
    current_state = UnitState.STUNNED
    stun_duration = max(stun_duration, duration) # Use the longer duration
    
    # Play stun animation or effect
    # Add visual stun effect to effects_node

# Apply a speed modifier
func apply_speed_modifier(value: float, duration: float) -> void:
    speed_modifiers.append({
        "value": value,
        "duration": duration
    })

# Apply a damage modifier
func apply_damage_modifier(value: float, duration: float) -> void:
    damage_modifiers.append({
        "value": value,
        "duration": duration
    })

# Get current speed modifier (multiplicative)
func _get_speed_modifier() -> float:
    var modifier = 1.0
    
    for mod in speed_modifiers:
        modifier *= mod.value
    
    return modifier

# Get current damage modifier (multiplicative)
func _get_damage_modifier() -> float:
    var modifier = 1.0
    
    for mod in damage_modifiers:
        modifier *= mod.value
    
    return modifier

# Update modifiers (reduce duration, remove expired)
func _update_modifiers(delta: float) -> void:
    # Update speed modifiers
    var i = 0
    while i < speed_modifiers.size():
        speed_modifiers[i].duration -= delta
        
        if speed_modifiers[i].duration <= 0:
            speed_modifiers.remove(i)
        else:
            i += 1
    
    # Update damage modifiers
    i = 0
    while i < damage_modifiers.size():
        damage_modifiers[i].duration -= delta
        
        if damage_modifiers[i].duration <= 0:
            damage_modifiers.remove(i)
        else:
            i += 1

# Handle health and mana regeneration
func _handle_regeneration(delta: float) -> void:
    regen_timer += delta
    
    if regen_timer >= 1.0: # Apply regen every second
        regen_timer -= 1.0
        
        # Health regen
        if health < max_health:
            heal(health_regen)
        
        # Mana regen
        if has_mana and mana < max_mana:
            var old_mana = mana
            mana = min(mana + mana_regen, max_mana)
            var _mana_gained = mana - old_mana
            
            # Could emit a signal for mana changes if needed

# Update animation based on current state
func _update_animation() -> void:
    if animation_player == null:
        return
    
    # Don't interrupt death or attack animations
    if current_animation == "death" or current_animation == "attack" or current_animation == "hurt":
        if not animation_player.is_playing():
            current_animation = "" # Allow changing animation once finished
        else:
            return
    
    var new_animation = "idle"
    
    match current_state:
        UnitState.MOVING:
            new_animation = "move"
            
            # Set facing direction based on movement
            if velocity.x < 0:
                sprite.flip_h = true
            else:
                sprite.flip_h = false
        UnitState.ATTACKING:
            new_animation = "idle" # Will be switched to attack when actually attacking
        UnitState.CASTING:
            new_animation = "cast"
        UnitState.STUNNED:
            new_animation = "stun"
    
    # Play animation if it's different and not already playing
    if new_animation != current_animation and animation_player.has_animation(new_animation):
        animation_player.play(new_animation)
        current_animation = new_animation

# Get unit's team
func get_team() -> int:
    return team

# Add an ability to the unit
func add_ability(ability_name: String, ability_data: Dictionary) -> void:
    abilities.append({
        "name": ability_name,
        "data": ability_data,
        "cooldown": 0.0
    })

# Use an ability
func use_ability(ability_index: int, other_target = null) -> bool:
    if ability_index < 0 or ability_index >= abilities.size():
        return false
    
    var ability = abilities[ability_index]
    
    if ability.cooldown > 0:
        return false
    
    if has_mana and ability.data.has("mana_cost") and mana < ability.data.mana_cost:
        return false
    
    # Apply ability effects (this would be specific to each ability)
    # This is a basic framework, actual implementation would depend on ability types
    
    # Reduce mana if applicable
    if has_mana and ability.data.has("mana_cost"):
        mana -= ability.data.mana_cost
    
    # Set cooldown
    if ability.data.has("cooldown"):
        ability.cooldown = ability.data.cooldown
    
    # Play cast animation
    if animation_player and animation_player.has_animation("cast"):
        animation_player.play("cast")
        current_animation = "cast"
    
    emit_signal("ability_used", ability.name, other_target)
    
    return true

# Apply a buff to the unit
func apply_buff(buff_name: String, buff_data: Dictionary) -> void:
    # Add buff to active buffs
    buffs.append({
        "name": buff_name,
        "data": buff_data,
        "duration": buff_data.duration if buff_data.has("duration") else 5.0
    })
    
    # Apply immediate buff effects
    if buff_data.has("speed_modifier"):
        apply_speed_modifier(buff_data.speed_modifier, buff_data.duration)
    
    if buff_data.has("damage_modifier"):
        apply_damage_modifier(buff_data.damage_modifier, buff_data.duration)
    
    # Add visual effect if applicable
    if buff_data.has("visual_effect"):
        var effect_scene = load(buff_data.visual_effect)
        if effect_scene:
            var effect = effect_scene.instance()
            effects_node.add_child(effect)

# Apply a debuff to the unit
func apply_debuff(debuff_name: String, debuff_data: Dictionary) -> void:
    # Add debuff to active debuffs
    debuffs.append({
        "name": debuff_name,
        "data": debuff_data,
        "duration": debuff_data.duration if debuff_data.has("duration") else 5.0
    })
    
    # Apply immediate debuff effects
    if debuff_data.has("speed_modifier"):
        apply_speed_modifier(debuff_data.speed_modifier, debuff_data.duration)
    
    if debuff_data.has("damage_modifier"):
        apply_damage_modifier(debuff_data.damage_modifier, debuff_data.duration)
    
    # Apply stun if applicable
    if debuff_data.has("stun") and debuff_data.stun:
        apply_stun(debuff_data.duration)
    
    # Add visual effect if applicable
    if debuff_data.has("visual_effect"):
        var effect_scene = load(debuff_data.visual_effect)
        if effect_scene:
            var effect = effect_scene.instance()
            effects_node.add_child(effect)

# Add to unit_base.gd
func _setup_core_components() -> void:
    # Set up collision shape
    if not has_node("CollisionShape2D"):
        var collision = CollisionShape2D.new()
        collision.name = "CollisionShape2D"
        var shape = CircleShape2D.new()
        shape.radius = collision_radius
        collision.shape = shape
        add_child(collision)
    
    # Set up sprite
    if not has_node("Sprite"):
        sprite = Sprite.new()
        sprite.name = "Sprite"
        add_child(sprite)
    else:
        sprite = get_node("Sprite")
    
    # Set up health bar
    _setup_health_bar()

func _configure_default_behavior() -> void:
    # Get enemy HQ position for attack-move
    _get_enemy_hq_position()
    
    # Set up effect node for visual effects if needed
    if not effects_node:
        effects_node = Node2D.new()
        effects_node.name = "Effects"
        add_child(effects_node)
        
    # Start auto-attack behavior if this is a combat unit
    if should_attack_move:
        _start_attack_move()
        
    # Initialize abilities
    for ability in abilities:
        if ability.has("cooldown") and ability.has("data") and ability.data.has("initial_cooldown"):
            ability.cooldown = ability.data.initial_cooldown

func find_target() -> Object:
    # This is a simple implementation that calls the more specific find_best_target method
    # with a default targeting strategy
    return find_best_target("closest")
