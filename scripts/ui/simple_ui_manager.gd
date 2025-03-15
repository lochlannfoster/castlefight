# Simple UI Manager - Basic implementation of UI manager
# Path: scripts/ui/simple_ui_manager.gd
extends CanvasLayer

# UI elements
var resource_display
var floating_text_container
var popup_container
var building_menu_instance
var selected_worker = null
var current_team = 0

# References to game systems
var game_manager
var building_manager
var economy_manager

func _ready():
	# Get references to game systems
	game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		building_manager = game_manager.building_manager
		economy_manager = game_manager.economy_manager
	
	# Create UI containers
	_create_containers()
	
	# Create resource display
	_create_resource_display()
	
	# Load building menu scene
	var building_menu_scene = load("res://scenes/ui/building_menu.tscn")
	if building_menu_scene:
		building_menu_instance = building_menu_scene.instance()
		add_child(building_menu_instance)
		building_menu_instance.visible = false
		
		# Connect building menu signals
		if building_menu_instance.has_signal("building_selected"):
			building_menu_instance.connect("building_selected", self, "_on_building_selected")
	
	# Update resource display initially
	update_resource_display()

# Create UI containers
func _create_containers():
	# Create floating text container
	floating_text_container = Control.new()
	floating_text_container.name = "FloatingTextContainer"
	floating_text_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_text_container.anchor_right = 1.0
	floating_text_container.anchor_bottom = 1.0
	add_child(floating_text_container)
	
	# Create popup container
	popup_container = Control.new()
	popup_container.name = "PopupContainer"
	popup_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_container.anchor_right = 1.0
	popup_container.anchor_bottom = 1.0
	add_child(popup_container)

# Create resource display
func _create_resource_display():
	resource_display = Control.new()
	resource_display.name = "ResourceDisplay"
	resource_display.anchor_left = 0.0
	resource_display.anchor_top = 0.0
	resource_display.anchor_right = 0.0
	resource_display.anchor_bottom = 0.0
	resource_display.margin_left = 10
	resource_display.margin_top = 10
	resource_display.margin_right = 200
	resource_display.margin_bottom = 100
	add_child(resource_display)
	
	# Add labels for resources
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	resource_display.add_child(vbox)
	
	# Gold label
	var gold_hbox = HBoxContainer.new()
	vbox.add_child(gold_hbox)
	
	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "Gold: 100"
	gold_hbox.add_child(gold_label)
	
	# Wood label
	var wood_hbox = HBoxContainer.new()
	vbox.add_child(wood_hbox)
	
	var wood_label = Label.new()
	wood_label.name = "WoodLabel"
	wood_label.text = "Wood: 50"
	wood_hbox.add_child(wood_label)
	
	# Supply label
	var supply_hbox = HBoxContainer.new()
	vbox.add_child(supply_hbox)
	
	var supply_label = Label.new()
	supply_label.name = "SupplyLabel"
	supply_label.text = "Supply: 10/20"
	supply_hbox.add_child(supply_label)
	
	# Income label
	var income_hbox = HBoxContainer.new()
	vbox.add_child(income_hbox)
	
	var income_label = Label.new()
	income_label.name = "IncomeLabel"
	income_label.text = "Income: +10/tick"
	income_hbox.add_child(income_label)

# Update resource display with current values
func update_resource_display():
	if not economy_manager:
		return
	
	var gold_label = resource_display.get_node_or_null("VBoxContainer/HBoxContainer/GoldLabel")
	var wood_label = resource_display.get_node_or_null("VBoxContainer/HBoxContainer2/WoodLabel")
	var supply_label = resource_display.get_node_or_null("VBoxContainer/HBoxContainer3/SupplyLabel")
	var income_label = resource_display.get_node_or_null("VBoxContainer/HBoxContainer4/IncomeLabel")
	
	if gold_label:
		gold_label.text = "Gold: " + str(int(economy_manager.get_resource(current_team, 0)))
	
	if wood_label:
		wood_label.text = "Wood: " + str(int(economy_manager.get_resource(current_team, 1)))
	
	if supply_label:
		var current_supply = int(economy_manager.get_resource(current_team, 2))
		var max_supply = 20  # Default max supply
		supply_label.text = "Supply: " + str(current_supply) + "/" + str(max_supply)
	
	if income_label:
		income_label.text = "Income: +" + str(int(economy_manager.get_income(current_team))) + "/tick"

# Show a floating message
func show_floating_message(message: String, position: Vector2, color: Color = Color.white, duration: float = 2.0):
	var label = Label.new()
	label.text = message
	label.add_color_override("font_color", color)
	label.rect_position = position
	
	floating_text_container.add_child(label)
	
	# Create tween for animation
	var tween = Tween.new()
	label.add_child(tween)
	
	# Move upward and fade out
	tween.interpolate_property(label, "rect_position", 
		label.rect_position, label.rect_position - Vector2(0, 50),
		duration, Tween.TRANS_SINE, Tween.EASE_OUT)
	
	tween.interpolate_property(label, "modulate",
		Color(color.r, color.g, color.b, 1.0), Color(color.r, color.g, color.b, 0.0),
		duration, Tween.TRANS_SINE, Tween.EASE_OUT)
	
	tween.start()
	
	# Remove after tween completes
	yield(tween, "tween_all_completed")
	label.queue_free()

# Show reconnected message
func show_reconnected_message():
	var message = "RECONNECTED TO SERVER"
	var viewport_rect = get_viewport().get_visible_rect()
	var position = Vector2(viewport_rect.size.x / 2, viewport_rect.size.y / 2)
	
	show_floating_message(message, position, Color.green, 3.0)

# Show match preparation screen
func show_match_preparation():
	var label = Label.new()
	label.text = "Preparing Match..."
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	
	var viewport_rect = get_viewport().get_visible_rect()
	label.rect_position = Vector2(viewport_rect.size.x / 2 - 100, viewport_rect.size.y / 2 - 25)
	label.rect_size = Vector2(200, 50)
	
	popup_container.add_child(label)
	
	# Remove after delay
	yield(get_tree().create_timer(2.0), "timeout")
	label.queue_free()

# Prepare match UI
func prepare_match_ui():
	# Clear all popups
	for child in popup_container.get_children():
		child.queue_free()
	
	# Update resource display
	update_resource_display()

# Show end game screen
func show_end_game_screen(winner: int, reason: String):
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
	
	popup_container.add_child(panel)

# Toggle building menu visibility
func toggle_building_menu():
	if not building_menu_instance:
		return
	
	building_menu_instance.visible = !building_menu_instance.visible
	
	if building_menu_instance.visible:
		# Populate building menu
		if building_menu_instance.has_method("populate_buildings"):
			building_menu_instance.populate_buildings(current_team)
		elif building_menu_instance.has_method("show_menu"):
			building_menu_instance.show_menu(current_team)

# Building selected handler
func _on_building_selected(building_type):
	# If we have a selected worker, tell it to start building
	if selected_worker and selected_worker.has_method("start_building_placement"):
		var size = Vector2(2, 2)  # Default size
		
		# Try to get actual size from building manager
		if building_manager and building_manager.has_method("get_building_data"):
			var building_data = building_manager.get_building_data(building_type)
			if building_data.has("size_x") and building_data.has("size_y"):
				size = Vector2(building_data.size_x, building_data.size_y)
		
		selected_worker.start_building_placement(building_type, size)

# End game continue button handler
func _on_end_game_continue():
	# Switch back to lobby scene
	var _err = get_tree().change_scene("res://scenes/lobby/lobby.tscn")

# Select a worker
func select_worker(worker):
	if selected_worker == worker:
		return
	
	# Deselect previous worker
	if selected_worker:
		selected_worker.deselect()
	
	selected_worker = worker
	
	if selected_worker:
		selected_worker.select()
