# Headquarters Building - The main building for each team
# Path: scripts/building/hq_building.gd
class_name HQBuilding
extends Building

# HQ signals
signal income_bonus_changed(new_bonus)

# HQ properties
export var base_income_bonus: float = 10.0  # Starting income for the team
export var income_upgrade_cost: float = 100.0  # Cost to upgrade income
export var income_upgrade_increment: float = 5.0  # Amount income increases per upgrade
export var max_income_upgrades: int = 5  # Maximum number of income upgrades

# State tracking
var current_income_bonus: float = 0.0
var income_upgrade_level: int = 0
var is_under_attack: bool = false
var last_damage_time: float = 0.0
var attack_warning_cooldown: float = 10.0  # Time between "under attack" warnings

# Ready function
func _ready() -> void:
	# Call parent ready function
	._ready()
	
	# Set initial income bonus
	current_income_bonus = base_income_bonus
	
	# HQ is a special building with different settings
	building_id = "hq"
	display_name = "Headquarters"
	max_health = 1000.0
	health = max_health
	armor = 5.0
	armor_type = "fortified"
	size = Vector2(3, 3)
	
	# Immediately grant income bonus when constructed
	_apply_income_bonus()

# Process function
func _process(delta: float) -> void:
	# Call parent process function
	if has_method("_physics_process"):
		._physics_process(delta)
	
	# Check "under attack" status
	if is_under_attack:
		last_damage_time += delta
		
		if last_damage_time >= attack_warning_cooldown:
			is_under_attack = false

# Override take_damage to provide "under attack" warning
func take_damage(amount: float, attacker = null) -> void:
	# Call parent take_damage
	.take_damage(amount, attacker)
	
	# Update "under attack" status
	if not is_under_attack and is_constructed:
		is_under_attack = true
		last_damage_time = 0.0
		
		# Notify of attack
		_notify_under_attack()

# Apply income bonus to the team
func _apply_income_bonus() -> void:
	var economy_manager = get_node("/root/GameManager/EconomyManager")
	if economy_manager:
		economy_manager.add_income(team, current_income_bonus)
		emit_signal("income_bonus_changed", current_income_bonus)

# Upgrade income generation
func upgrade_income() -> bool:
	if income_upgrade_level >= max_income_upgrades:
		return false
	
	var economy_manager = get_node("/root/GameManager/EconomyManager")
	if not economy_manager:
		return false
	
	# Check if team can afford the upgrade
	if not economy_manager.can_afford_building(team, "income_upgrade"):
		return false
	
	# Purchase the upgrade
	if not economy_manager.purchase_building(team, "income_upgrade"):
		return false
	
	# Apply the upgrade
	income_upgrade_level += 1
	var new_bonus = income_upgrade_increment
	current_income_bonus += new_bonus
	
	# Update team income
	economy_manager.add_income(team, new_bonus)
	
	emit_signal("income_bonus_changed", current_income_bonus)
	
	return true

# Override complete_construction to add initial income
func complete_construction() -> void:
	# Call parent complete_construction
	.complete_construction()
	
	# Apply income bonus if not already applied
	_apply_income_bonus()

# Notify that HQ is under attack
func _notify_under_attack() -> void:
	var team_name = "Blue" if team == 0 else "Red"
	print("%s team headquarters under attack!" % team_name)
	
	# Show notification to team members
	var ui_manager = get_node("/root/GameManager/UIManager")
	if ui_manager:
		# Get the position to show the warning
		var screen_pos = get_viewport().get_camera().unproject_position(global_position)
		
		# Create warning label
		var warning_label = Label.new()
		warning_label.text = "HQ UNDER ATTACK!"
		warning_label.align = Label.ALIGN_CENTER
		warning_label.valign = Label.VALIGN_CENTER
		warning_label.modulate = Color(1, 0, 0)  # Red color
		warning_label.rect_position = screen_pos - Vector2(100, 50)
		
		# Add to UI
		ui_manager.floating_text_container.add_child(warning_label)
		
		# Animate warning
		var tween = Tween.new()
		warning_label.add_child(tween)
		
		tween.interpolate_property(warning_label, "rect_scale",
			Vector2(1.5, 1.5), Vector2(1, 1),
			0.5, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
		
		tween.interpolate_property(warning_label, "modulate",
			Color(1, 0, 0, 1), Color(1, 0, 0, 0),
			2.0, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
		
		tween.start()
		
		# Remove after animation
		yield(tween, "tween_all_completed")
		warning_label.queue_free()

# Get income bonus
func get_income_bonus() -> float:
	return current_income_bonus

# Get current upgrade level
func get_upgrade_level() -> int:
	return income_upgrade_level

# Get cost for next upgrade
func get_next_upgrade_cost() -> float:
	if income_upgrade_level >= max_income_upgrades:
		return 0.0
	
	return income_upgrade_cost * (income_upgrade_level + 1)

# Get maximum upgrade level
func get_max_upgrade_level() -> int:
	return max_income_upgrades