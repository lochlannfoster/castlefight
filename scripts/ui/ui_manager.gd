# UI Manager - Handles all in-game UI elements and interactions
# Path: scripts/ui/ui_manager.gd
class_name UIManager
extends CanvasLayer

# UI signals
signal building_selected(building_type)
signal building_placement_cancelled
signal worker_command_issued(command_type, params)
signal pause_toggled(is_paused)

# UI elements
var resource_display: Control
var building_menu: Control
var unit_info_panel: Control
var game_status_panel: Control
var minimap: Control
var floating_text_container: Control
var tooltip: Control

# Current UI state
var is_building_menu_open: bool = false
var is_game_paused: bool = false
var selected_worker = null
var selected_building = null
var current_team: int = 0

# References to game systems
var economy_manager
var building_manager
var game_manager

# Debug elements
var debug_overlay: Control = null
var is_debug_overlay_visible: bool = false

# Ready function
func _ready() -> void:
	# Get references to game systems
	game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		economy_manager = game_manager.economy_manager
		building_manager = game_manager.building_manager
	else:
		economy_manager = get_node_or_null("/root/EconomyManager")
		building_manager = get_node_or_null("/root/BuildingManager")
	
	# Create UI elements
	_create_ui_elements()
	
	# Connect signals
	_connect_signals()
	
	# Setup input handling
	set_process_input(true)

# Create all UI elements
func _create_ui_elements() -> void:
	# Create resource display
	_create_resource_display()
	
	# Create building menu
	_create_building_menu()
	
	# Create unit info panel
	_create_unit_info_panel()
	
	# Create game status panel
	_create_game_status_panel()
	
	# Create minimap
	_create_minimap()
	
	# Create floating text container
	_create_floating_text_container()
	
	# Create tooltip
	_create_tooltip()
	
	# Create debug mode indicator
	_create_debug_indicator()
	
	# Create debug overlay
	_create_debug_overlay()

# Create debug mode indicator
func _create_debug_indicator() -> void:
	var debug_indicator = Label.new()
	debug_indicator.name = "DebugIndicator"
	debug_indicator.text = "DEBUG MODE ACTIVE - All workers controllable"
	debug_indicator.set_anchors_preset(Control.PRESET_TOP_LEFT)
	debug_indicator.margin_left = 10
	debug_indicator.margin_top = 150
	debug_indicator.margin_right = 300
	debug_indicator.margin_bottom = 170
	debug_indicator.add_color_override("font_color", Color(1, 0.5, 0, 1))  # Orange color
	debug_indicator.visible = false
	add_child(debug_indicator)
	
	# Check if debug mode is active
	var network_manager = get_node_or_null("/root/GameManager/NetworkManager")
	if network_manager and network_manager.debug_mode:
		debug_indicator.visible = true

# Create resource display
func _create_resource_display() -> void:
	resource_display = Control.new()
	resource_display.name = "ResourceDisplay"
	resource_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	resource_display.margin_left = 10
	resource_display.margin_top = 10
	resource_display.margin_right = 200
	resource_display.margin_bottom = 50
	add_child(resource_display)
	
	# Gold display
	var gold_container = HBoxContainer.new()
	gold_container.name = "GoldContainer"
	resource_display.add_child(gold_container)
	
	var gold_icon = TextureRect.new()
	gold_icon.texture = preload("res://assets/ui/icons/gold_icon.png")
	gold_icon.rect_min_size = Vector2(24, 24)
	gold_container.add_child(gold_icon)
	
	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "100"
	gold_container.add_child(gold_label)
	
	# Wood display
	var wood_container = HBoxContainer.new()
	wood_container.name = "WoodContainer"
	wood_container.rect_position.y = 30
	resource_display.add_child(wood_container)
	
	var wood_icon = TextureRect.new()
	wood_icon.texture = preload("res://assets/ui/icons/wood_icon.png")
	wood_icon.rect_min_size = Vector2(24, 24)
	wood_container.add_child(wood_icon)
	
	var wood_label = Label.new()
	wood_label.name = "WoodLabel"
	wood_label.text = "50"
	wood_container.add_child(wood_label)
	
	# Supply display
	var supply_container = HBoxContainer.new()
	supply_container.name = "SupplyContainer"
	supply_container.rect_position.y = 60
	resource_display.add_child(supply_container)
	
	var supply_icon = TextureRect.new()
	supply_icon.texture = preload("res://assets/ui/icons/supply_icon.png")
	supply_icon.rect_min_size = Vector2(24, 24)
	supply_container.add_child(supply_icon)
	
	var supply_label = Label.new()
	supply_label.name = "SupplyLabel"
	supply_label.text = "10/20"
	supply_container.add_child(supply_label)
	
	# Income display
	var income_container = HBoxContainer.new()
	income_container.name = "IncomeContainer"
	income_container.rect_position.y = 90
	resource_display.add_child(income_container)
	
	var income_icon = TextureRect.new()
	income_icon.texture = preload("res://assets/ui/icons/income_icon.png")
	income_icon.rect_min_size = Vector2(24, 24)
	income_container.add_child(income_icon)
	
	var income_label = Label.new()
	income_label.name = "IncomeLabel"
	income_label.text = "+10/tick"
	income_container.add_child(income_label)

# Create building menu
func _create_building_menu() -> void:
	# Try to load the building menu scene
	var building_menu_scene = load("res://scenes/ui/building_menu.tscn")
	if building_menu_scene:
		building_menu = building_menu_scene.instance()
		add_child(building_menu)
		
		# Connect signals
		var close_button = building_menu.get_node_or_null("Panel/CloseButton")
		if close_button:
			close_button.connect("pressed", self, "_on_building_menu_close")
	else:
		# Create a fallback building menu
		building_menu = Control.new()
		building_menu.name = "BuildingMenu"
		building_menu.visible = false
		add_child(building_menu)
		
		# Create background panel
		var panel = Panel.new()
		panel.name = "Panel"
		panel.rect_min_size = Vector2(400, 300)
		panel.rect_position = Vector2(50, 50)
		building_menu.add_child(panel)
		
		# Title label
		var title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.text = "Building Menu"
		title_label.rect_position = Vector2(10, 10)
		title_label.rect_size = Vector2(380, 30)
		title_label.align = Label.ALIGN_CENTER
		panel.add_child(title_label)
		
		# Create a grid container for buildings
		var grid = GridContainer.new()
		grid.name = "BuildingGrid"
		grid.columns = 3
		grid.rect_position = Vector2(10, 50)
		grid.rect_size = Vector2(380, 230)
		panel.add_child(grid)
		
		# Close button
		var close_button = Button.new()
		close_button.name = "CloseButton"
		close_button.text = "X"
		close_button.rect_position = Vector2(370, 10)
		close_button.rect_size = Vector2(20, 20)
		close_button.connect("pressed", self, "_on_building_menu_close")
		panel.add_child(close_button)

# Create unit info panel
func _create_unit_info_panel() -> void:
	unit_info_panel = Control.new()
	unit_info_panel.name = "UnitInfoPanel"
	unit_info_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	unit_info_panel.margin_left = -210
	unit_info_panel.margin_top = -110
	unit_info_panel.margin_right = -10
	unit_info_panel.margin_bottom = -10
	unit_info_panel.visible = false
	add_child(unit_info_panel)
	
	# Create background panel
	var panel = Panel.new()
	panel.name = "Panel"
	panel.rect_min_size = Vector2(200, 100)
	unit_info_panel.add_child(panel)
	
	# Unit name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.rect_position = Vector2(10, 10)
	name_label.rect_size = Vector2(180, 20)
	name_label.text = "Unit Name"
	panel.add_child(name_label)
	
	# Unit stats
	var stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	stats_container.rect_position = Vector2(10, 35)
	stats_container.rect_size = Vector2(180, 65)
	panel.add_child(stats_container)
	
	var health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = "Health: 100/100"
	stats_container.add_child(health_label)
	
	var attack_label = Label.new()
	attack_label.name = "AttackLabel"
	attack_label.text = "Attack: 10 (Normal)"
	stats_container.add_child(attack_label)
	
	var armor_label = Label.new()
	armor_label.name = "ArmorLabel"
	armor_label.text = "Armor: 0 (Medium)"
	stats_container.add_child(armor_label)

# Create game status panel
func _create_game_status_panel() -> void:
	game_status_panel = Control.new()
	game_status_panel.name = "GameStatusPanel"
	game_status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	game_status_panel.margin_left = -210
	game_status_panel.margin_top = 10
	game_status_panel.margin_right = -10
	game_status_panel.margin_bottom = 50
	add_child(game_status_panel)
	
	# Create background panel
	var panel = Panel.new()
	panel.name = "Panel"
	panel.rect_min_size = Vector2(200, 40)
	game_status_panel.add_child(panel)
	
	# Game time
	var time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.rect_position = Vector2(10, 10)
	time_label.rect_size = Vector2(180, 20)
	time_label.text = "Time: 00:00"
	panel.add_child(time_label)
	
	# Pause button
	var pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.rect_position = Vector2(150, 5)
	pause_button.rect_size = Vector2(40, 30)
	pause_button.text = "II"
	pause_button.connect("pressed", self, "_on_pause_button_pressed")
	panel.add_child(pause_button)

# Create minimap
func _create_minimap() -> void:
	minimap = Control.new()
	minimap.name = "Minimap"
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.margin_left = -210
	minimap.margin_top = -220
	minimap.margin_right = -10
	minimap.margin_bottom = -120
	add_child(minimap)
	
	# Create background panel
	var panel = Panel.new()
	panel.name = "Panel"
	panel.rect_min_size = Vector2(200, 100)
	minimap.add_child(panel)
	
	# Minimap texture rect
	var minimap_rect = TextureRect.new()
	minimap_rect.name = "MinimapRect"
	minimap_rect.rect_position = Vector2(10, 10)
	minimap_rect.rect_size = Vector2(180, 80)
	minimap_rect.expand = true
	minimap_rect.texture = preload("res://assets/ui/icons/minimap_placeholder.png")
	panel.add_child(minimap_rect)

# Create floating text container
func _create_floating_text_container() -> void:
	floating_text_container = Control.new()
	floating_text_container.name = "FloatingTextContainer"
	floating_text_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_text_container.anchor_right = 1.0
	floating_text_container.anchor_bottom = 1.0
	add_child(floating_text_container)

# Create tooltip
func _create_tooltip() -> void:
	tooltip = Control.new()
	tooltip.name = "Tooltip"
	tooltip.visible = false
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tooltip)
	
	var panel = Panel.new()
	panel.name = "Panel"
	panel.rect_min_size = Vector2(200, 80)
	tooltip.add_child(panel)
	
	var label = Label.new()
	label.name = "Label"
	label.rect_position = Vector2(10, 10)
	label.rect_size = Vector2(180, 60)
	label.autowrap = true
	panel.add_child(label)

# Create debug overlay
func _create_debug_overlay() -> void:
	debug_overlay = Control.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.anchor_right = 1.0
	debug_overlay.anchor_bottom = 1.0
	
	var panel = Panel.new()
	panel.name = "Panel"
	panel.modulate = Color(0, 0, 0, 0.7) # Semi-transparent black
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	debug_overlay.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "Stats"
	vbox.margin_left = 10
	vbox.margin_top = 10
	vbox.margin_right = 300
	vbox.margin_bottom = 300
	panel.add_child(vbox)
	
	# Add labels for different stat types
	var fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.text = "FPS: 0"
	vbox.add_child(fps_label)
	
	var memory_label = Label.new()
	memory_label.name = "MemoryLabel"
	memory_label.text = "Memory: 0 MB"
	vbox.add_child(memory_label)
	
	var object_count_label = Label.new()
	object_count_label.name = "ObjectCountLabel"
	object_count_label.text = "Objects: 0"
	vbox.add_child(object_count_label)
	
	var building_count_label = Label.new()
	building_count_label.name = "BuildingCountLabel"
	building_count_label.text = "Buildings: 0"
	vbox.add_child(building_count_label)
	
	var unit_count_label = Label.new()
	unit_count_label.name = "UnitCountLabel"
	unit_count_label.text = "Units: 0"
	vbox.add_child(unit_count_label)
	
	# Add to scene but hide by default
	add_child(debug_overlay)
	debug_overlay.visible = false

# Connect signals
func _connect_signals() -> void:
	# Connect to Economy Manager
	if economy_manager:
		if not economy_manager.is_connected("resources_changed", self, "_on_resources_changed"):
			economy_manager.connect("resources_changed", self, "_on_resources_changed")
		if not economy_manager.is_connected("income_changed", self, "_on_income_changed"):
			economy_manager.connect("income_changed", self, "_on_income_changed")
		if not economy_manager.is_connected("income_tick", self, "_on_income_tick"):
			economy_manager.connect("income_tick", self, "_on_income_tick")
		if not economy_manager.is_connected("bounty_earned", self, "_on_bounty_earned"):
			economy_manager.connect("bounty_earned", self, "_on_bounty_earned")
	
	# Connect to Building Manager
	if building_manager:
		if not building_manager.is_connected("building_selected", self, "_on_building_selected"):
			building_manager.connect("building_selected", self, "_on_building_selected")
		if not building_manager.is_connected("building_deselected", self, "_on_building_deselected"):
			building_manager.connect("building_deselected", self, "_on_building_deselected")
	
	# Connect to Game Manager
	if game_manager:
		if not game_manager.is_connected("game_started", self, "_on_game_started"):
			game_manager.connect("game_started", self, "_on_game_started")
		if not game_manager.is_connected("game_ended", self, "_on_game_ended"):
			game_manager.connect("game_ended", self, "_on_game_ended")
		if not game_manager.is_connected("match_countdown_updated", self, "_on_match_countdown_updated"):
			game_manager.connect("match_countdown_updated", self, "_on_match_countdown_updated")
	
	# Connect our own worker_command_issued signal to _emit_worker_command
	if not self.is_connected("worker_command_issued", self, "_emit_worker_command"):
		connect("worker_command_issued", self, "_emit_worker_command")

# Input handling
func _input(event) -> void:
	# Handle key shortcuts
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_F3:
			is_debug_overlay_visible = !is_debug_overlay_visible
			if debug_overlay:
				debug_overlay.visible = is_debug_overlay_visible
		
		match event.scancode:
			KEY_ESCAPE:
				if is_building_menu_open:
					_on_building_menu_close()
				else:
					_on_pause_button_pressed()
			KEY_B:
				# Toggle building menu
				toggle_building_menu()
			KEY_R:
				# Toggle auto-repair for selected worker
				if selected_worker != null and selected_worker.has_method("toggle_auto_repair"):
					selected_worker.toggle_auto_repair()
	
	# Handle mouse movement for tooltip
	if event is InputEventMouseMotion:
		# Update tooltip position
		if tooltip.visible:
			tooltip.rect_position = event.position + Vector2(15, 15)
	
	# Handle mouse button clicks
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_RIGHT:
			# Right-click to cancel building placement
			if selected_worker and selected_worker.is_placing_building:
				selected_worker.cancel_building_placement()
				emit_signal("building_placement_cancelled")

# Process function to update game time and debug info
func _process(delta: float) -> void:
	if game_manager and game_manager.current_state == game_manager.GameState.PLAYING:
		update_game_time(game_manager.match_timer)
	
	if is_debug_overlay_visible and debug_overlay:
		var fps_label = debug_overlay.get_node_or_null("Panel/Stats/FPSLabel")
		if fps_label:
			fps_label.text = "FPS: " + str(Engine.get_frames_per_second())
		
		var memory_label = debug_overlay.get_node_or_null("Panel/Stats/MemoryLabel")
		if memory_label:
			var mem_mb = OS.get_static_memory_usage() / 1048576.0
			memory_label.text = "Memory: %.2f MB" % mem_mb
		
		var object_count_label = debug_overlay.get_node_or_null("Panel/Stats/ObjectCountLabel")
		if object_count_label:
			object_count_label.text = "Objects: " + str(Performance.get_monitor(Performance.OBJECT_COUNT))
		
		var building_count_label = debug_overlay.get_node_or_null("Panel/Stats/BuildingCountLabel")
		if building_count_label and building_manager:
			building_count_label.text = "Buildings: " + str(building_manager.buildings.size())
		
		var unit_count_label = debug_overlay.get_node_or_null("Panel/Stats/UnitCountLabel")
		if unit_count_label:
			var units = get_tree().get_nodes_in_group("units")
			unit_count_label.text = "Units: " + str(units.size())

# Toggle building menu
func toggle_building_menu() -> void:
	is_building_menu_open = !is_building_menu_open
	building_menu.visible = is_building_menu_open
	
	if is_building_menu_open:
		_populate_building_menu()

# Populate building menu with available buildings
func _populate_building_menu() -> void:
	if not building_manager:
		return
	
	var grid = building_menu.get_node_or_null("Panel/BuildingGrid")
	if not grid:
		return
	
	# Clear existing buttons
	for child in grid.get_children():
		child.queue_free()
	
	# Get available buildings for current team
	var available_buildings = building_manager.get_available_buildings(current_team)
	
	# Create buttons for each building
	for building_data in available_buildings:
		var button = Button.new()
		button.text = building_data.name
		button.hint_tooltip = "%s\nCost: %d gold" % [building_data.description, building_data.cost]
		button.rect_min_size = Vector2(70, 70)
		
		# Connect button press
		button.connect("pressed", self, "_on_building_button_pressed", [building_data.id])
		
		grid.add_child(button)

# Update resource display
func update_resource_display() -> void:
	if not is_instance_valid(resource_display) or not economy_manager:
		return
	
	var gold_label = resource_display.get_node_or_null("GoldContainer/GoldLabel")
	var wood_label = resource_display.get_node_or_null("WoodContainer/WoodLabel")
	var supply_label = resource_display.get_node_or_null("SupplyContainer/SupplyLabel")
	
	if gold_label:
		gold_label.text = str(int(economy_manager.get_resource(current_team, economy_manager.ResourceType.GOLD)))
	
	if wood_label:
		wood_label.text = str(int(economy_manager.get_resource(current_team, economy_manager.ResourceType.WOOD)))
	
	if supply_label:
		var current_supply = int(economy_manager.get_resource(current_team, economy_manager.ResourceType.SUPPLY))
		var max_supply = 20  # This should be calculated based on buildings
		supply_label.text = str(current_supply) + "/" + str(max_supply)

# Update income display
func update_income_display() -> void:
	if not is_instance_valid(resource_display) or not economy_manager:
		return
	
	var income_label = resource_display.get_node_or_null("IncomeContainer/IncomeLabel")
	
	if income_label:
		var income = economy_manager.get_income(current_team)
		income_label.text = "+" + str(int(income)) + "/tick"

# Update game time display
func update_game_time(time_seconds: float) -> void:
	if not is_instance_valid(game_status_panel):
		return
	
	var time_label = game_status_panel.get_node_or_null("Panel/TimeLabel")
	
	if time_label:
		var minutes = int(time_seconds / 60)
		var seconds = int(time_seconds) % 60
		time_label.text = "Time: %02d:%02d" % [minutes, seconds]

# Show unit info panel for a unit
func show_unit_info(unit) -> void:
	if not is_instance_valid(unit_info_panel):
		return
	
	unit_info_panel.visible = true
	
	var name_label = unit_info_panel.get_node_or_null("Panel/NameLabel")
	var health_label = unit_info_panel.get_node_or_null("Panel/StatsContainer/HealthLabel")
	var attack_label = unit_info_panel.get_node_or_null("Panel/StatsContainer/AttackLabel")
	var armor_label = unit_info_panel.get_node_or_null("Panel/StatsContainer/ArmorLabel")
	
	if name_label:
		name_label.text = unit.display_name if "display_name" in unit else "Worker"
	
	if health_label:
		health_label.text = "Health: %.1f/%.1f" % [unit.health, unit.max_health] if "health" in unit else "Health: N/A"
	
	if attack_label:
		attack_label.text = "Attack: %.1f (%s)" % [unit.attack_damage, unit.attack_type] if "attack_damage" in unit else "Attack: N/A"
	
	if armor_label:
		armor_label.text = "Armor: %.1f (%s)" % [unit.armor, unit.armor_type] if "armor" in unit else "Armor: N/A"

# Hide unit info panel
func hide_unit_info() -> void:
	if not is_instance_valid(unit_info_panel):
		return
	
	unit_info_panel.visible = false

# Show income popup
func show_income_popup(team: int, amount: float) -> void:
	if team != current_team:
		return
	
	var popup = Label.new()
	popup.text = "+%d gold" % int(amount)
	popup.modulate = Color(1, 0.843, 0)  # Gold color
	popup.rect_position = Vector2(150, 300)
	
	floating_text_container.add_child(popup)
	
	# Animate popup
	var tween = Tween.new()
	popup.add_child(tween)
	
	tween.interpolate_property(popup, "rect_position",
		popup.rect_position, popup.rect_position + Vector2(0, -50),
		1.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	
	tween.interpolate_property(popup, "modulate",
		popup.modulate, Color(1, 0.843, 0, 0),
		1.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	
	tween.start()
	
	# Remove after animation
	yield(tween, "tween_all_completed")
	popup.queue_free()

# Show bounty popup
func show_bounty_popup(team: int, amount: float, source: String) -> void:
	if team != current_team:
		return
	
	var popup = Label.new()
	popup.text = "+%d gold (%s)" % [int(amount), source]
	popup.modulate = Color(1, 0.843, 0)  # Gold color
	
	# Position near center screen
	popup.rect_position = Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2)
	
	floating_text_container.add_child(popup)
	
	# Animate popup
	var tween = Tween.new()
	popup.add_child(tween)
	
	tween.interpolate_property(popup, "rect_position",
		popup.rect_position, popup.rect_position + Vector2(0, -50),
		1.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	
	tween.interpolate_property(popup, "modulate",
		popup.modulate, Color(1, 0.843, 0, 0),
		1.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	
	tween.start()
	
	# Remove after animation
	yield(tween, "tween_all_completed")
	popup.queue_free()

# Show tooltip
func show_tooltip(text: String, position: Vector2) -> void:
	var label = tooltip.get_node_or_null("Panel/Label")
	
	if label:
		label.text = text
	
	tooltip.rect_position = position + Vector2(15, 15)
	tooltip.visible = true

# Hide tooltip
func hide_tooltip() -> void:
	tooltip.visible = false

# Set current player team
func set_current_team(team: int) -> void:
	current_team = team
	
	# Update displays
	update_resource_display()
	update_income_display()

# Select a worker
func select_worker(worker) -> void:
	if selected_worker == worker:
		return
		
	# Check if this worker should be selectable in non-debug mode
	var network_manager = get_node_or_null("/root/GameManager/NetworkManager")
	var is_debug_mode = network_manager and network_manager.debug_mode
	
	if not is_debug_mode:
		# In normal mode, only allow selecting workers of your team
		if worker.team != current_team:
			return
	
	# Deselect previous worker if any
	if selected_worker != null:
		selected_worker.deselect()
	
	selected_worker = worker
	
	if selected_worker != null:
		selected_worker.select()
		show_unit_info(selected_worker)
	else:
		hide_unit_info()

# Show match preparation
func show_match_preparation() -> void:
	# Show match preparation screen
	var label = Label.new()
	label.text = "Preparing Match..."
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	
	var viewport_rect = get_viewport().get_visible_rect()
	label.rect_position = Vector2(viewport_rect.size.x / 2 - 100, viewport_rect.size.y / 2 - 25)
	label.rect_size = Vector2(200, 50)
	
	floating_text_container.add_child(label)
	
	# Remove after delay
	yield(get_tree().create_timer(2.0), "timeout")
	label.queue_free()

# Show end game screen
func show_end_game_screen(winner: int, reason: String) -> void:
	var panel = Panel.new()
	panel.rect_size = Vector2(300, 200)
	
	var viewport_rect = get_viewport().get_visible_rect()
	panel.rect_position = Vector2(viewport_rect.size.x / 2 - 150, viewport_rect.size.y / 2 - 100)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.margin_left = 20
	vbox.margin_top = 20
	vbox.margin_right = -20
	vbox.margin_bottom = -20
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Game Over"
	title.align = Label.ALIGN_CENTER
	vbox.add_child(title)
	
	var winner_label = Label.new()
	winner_label.text = "Team " + ("A" if winner == 0 else "B") + " Wins!"
	winner_label.align = Label.ALIGN_CENTER
	vbox.add_child(winner_label)
	
	var reason_label = Label.new()
	reason_label.text = "Reason: " + reason
	reason_label.align = Label.ALIGN_CENTER
	vbox.add_child(reason_label)
	
	var button = Button.new()
	button.text = "Continue"
	button.connect("pressed", self, "_on_end_game_continue")
	vbox.add_child(button)
	
	floating_text_container.add_child(panel)

# End game continue button handler
func _on_end_game_continue() -> void:
	# Switch back to lobby scene
	var _err = get_tree().change_scene("res://scenes/lobby/lobby.tscn")

# Signal handlers
func _on_resources_changed(team: int, _resource_type: int, _amount: float) -> void:
	if team == current_team:
		update_resource_display()

func _on_income_changed(team: int, _amount: float) -> void:
	if team == current_team:
		update_income_display()

func _on_income_tick(team: int, amount: float) -> void:
	show_income_popup(team, amount)
	update_resource_display()

func _on_bounty_earned(team: int, amount: float, source: String) -> void:
	show_bounty_popup(team, amount, source)
	update_resource_display()

func _on_building_selected(building) -> void:
	selected_building = building
	
	# Hide unit info if showing
	hide_unit_info()

func _on_building_deselected(building) -> void:
	if selected_building == building:
		selected_building = null

func _on_building_menu_close() -> void:
	is_building_menu_open = false
	building_menu.visible = false

func _on_building_button_pressed(building_type: String) -> void:
	# Close menu
	_on_building_menu_close()
	
	# Emit signal for selected building
	emit_signal("building_selected", building_type)
	
	# Start building placement if we have a selected worker
	if selected_worker != null:
		var building_data = building_manager.get_building_data(building_type)
		var size = Vector2(
			building_data.size_x if building_data.has("size_x") else 1,
			building_data.size_y if building_data.has("size_y") else 1
		)
		
		if selected_worker.has_method("start_building_placement"):
			selected_worker.start_building_placement(building_type, size)
		
		# Emit the worker_command_issued signal
		emit_signal("worker_command_issued", "build", {"building_type": building_type, "size": size})

func _on_pause_button_pressed() -> void:
	is_game_paused = !is_game_paused
	
	# Update button text
	var pause_button = game_status_panel.get_node_or_null("Panel/PauseButton")
	if pause_button:
		pause_button.text = "▶" if is_game_paused else "II"
	
	emit_signal("pause_toggled", is_game_paused)
	
	# Tell game manager to pause/unpause
	if game_manager:
		game_manager.toggle_pause()

func _on_game_started() -> void:
	# Reset UI elements for game start
	
	# Show debug indicator if in debug mode
	var debug_indicator = get_node_or_null("DebugIndicator")
	if debug_indicator:
		var network_manager = get_node_or_null("/root/GameManager/NetworkManager")
		if network_manager and network_manager.debug_mode:
			debug_indicator.visible = true
		else:
			debug_indicator.visible = false

func _on_game_ended(winning_team: int) -> void:
	# Show game over screen
	var game_over = Label.new()
	game_over.text = "Game Over\nTeam %d Wins!" % winning_team
	game_over.align = Label.ALIGN_CENTER
	game_over.valign = Label.VALIGN_CENTER
	game_over.rect_min_size = Vector2(300, 100)
	game_over.set_anchors_preset(Control.PRESET_CENTER)
	
	var panel = Panel.new()
	panel.rect_min_size = Vector2(300, 100)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.add_child(game_over)
	
	add_child(panel)

func _on_match_countdown_updated(time_remaining: float) -> void:
	# Update countdown display
	var countdown = Label.new()
	countdown.text = "Match starting in: %d" % int(time_remaining)
	countdown.align = Label.ALIGN_CENTER
	countdown.valign = Label.VALIGN_CENTER
	countdown.rect_min_size = Vector2(300, 100)
	countdown.set_anchors_preset(Control.PRESET_CENTER)
	
	# Replace existing countdown label if any
	var existing = get_node_or_null("CountdownLabel")
	if existing:
		existing.queue_free()
	
	countdown.name = "CountdownLabel"
	add_child(countdown)
	
	# Remove when time expires
	if time_remaining <= 0:
		countdown.queue_free()

# Implement worker command functionality
func _emit_worker_command(command_type, params: Dictionary = {}) -> void:
	# If we have a selected worker, send the command directly to it
	if selected_worker != null:
		# Convert string command type to enum if worker has a CommandType enum
		var cmd_type = command_type
		if "CommandType" in selected_worker:
			match command_type:
				"move":
					cmd_type = selected_worker.CommandType.MOVE
				"build":
					cmd_type = selected_worker.CommandType.BUILD
				"repair":
					cmd_type = selected_worker.CommandType.REPAIR
				"stop":
					cmd_type = selected_worker.CommandType.STOP
		
		# Call handle_command if it exists
		if selected_worker.has_method("handle_command"):
			selected_worker.handle_command(cmd_type, params)

# Log debug messages
func log_debug(message: String, level: String = "debug", context: String = "") -> void:
	if Engine.has_singleton("DebugLogger"):
		var debug_logger = Engine.get_singleton("DebugLogger")
		match level.to_lower():
			"error":
				debug_logger.error(message, context)
			"warning":
				debug_logger.warning(message, context)
			"info":
				debug_logger.info(message, context)
			"verbose":
				debug_logger.verbose(message, context)
			_: # Default to debug level
				debug_logger.debug(message, context)
	else:
		# Fallback to print if DebugLogger is not available
		print(level.to_upper() + " [" + context + "]: " + message)
