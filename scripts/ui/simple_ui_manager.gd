# Simple UI Manager - For testing basic functionality
# Path: scripts/ui/simple_ui_manager.gd
extends CanvasLayer

# Signals
signal building_selected(building_type)
signal worker_command_issued(command_type, params)

# References
var game_manager
var grid_system
var building_manager
var economy_manager

# UI elements
var building_menu
var resource_display
var selected_worker

# Constants
const BUILDING_MENU_SCENE = "res://scenes/ui/building_menu.tscn"

# Ready function
func _ready() -> void:
	# Get references
	game_manager = get_node_or_null("/root/GameManager")
	grid_system = get_node_or_null("/root/GridSystem")
	
	if game_manager:
		building_manager = game_manager.building_manager
		economy_manager = game_manager.economy_manager
	
	# Create UI elements
	_create_building_menu()
	_create_resource_display()
	
	# Connect signals
	if building_menu:
		building_menu.connect("building_selected", self, "_on_building_selected")
	
	# Set up input handling
	set_process_input(true)
	
	print("Simple UI Manager initialized")

# Input handling
func _input(event: InputEvent) -> void:
	# Toggle building menu with 'B' key
	if event is InputEventKey and event.pressed and event.scancode == KEY_B:
		if building_menu and not building_menu.visible and selected_worker:
			var team = selected_worker.team if selected_worker else 0
			building_menu.show_menu(team)
		elif building_menu and building_menu.visible:
			building_menu.hide_menu()
	
	# Toggle auto-repair with 'R' key
	if event is InputEventKey and event.pressed and event.scancode == KEY_R:
		if selected_worker and selected_worker.has_method("toggle_auto_repair"):
			selected_worker.toggle_auto_repair()
	
	# Select unit with left mouse button
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		if building_menu and building_menu.visible:
			# Ignore clicks while building menu is open
			return
			
		# Check if we clicked on a worker
		var units = get_tree().get_nodes_in_group("workers")
		var mouse_pos = event.global_position
		
		var found_worker = false
		for unit in units:
			var unit_pos = unit.global_position
			var unit_rect = Rect2(unit_pos - Vector2(16, 16), Vector2(32, 32))
			
			if unit_rect.has_point(mouse_pos):
				select_worker(unit)
				found_worker = true
				break
		
		# If not clicking a worker, deselect current worker
		if not found_worker and selected_worker:
			deselect_worker()

# Create building menu
func _create_building_menu() -> void:
	# Try to load the building menu scene
	var building_menu_scene = load(BUILDING_MENU_SCENE)
	
	if building_menu_scene:
		building_menu = building_menu_scene.instance()
		add_child(building_menu)
		print("Building menu loaded")
	else:
		print("Building menu scene not found, creating it dynamically")
		
		# Create a simple building menu directly
		building_menu = Control.new()
		building_menu.name = "BuildingMenu"
		building_menu.anchor_right = 1.0
		building_menu.anchor_bottom = 1.0
		building_menu.margin_right = -800  # Leave space on the right
		building_menu.margin_bottom = -500  # Leave space at the bottom
		building_menu.visible = false
		
		# Load or create script
		var script = load("res://scripts/ui/building_menu.gd")
		if script:
			building_menu.set_script(script)
		
		add_child(building_menu)
		
		# Create panel
		var panel = Panel.new()
		panel.name = "Panel"
		panel.rect_position = Vector2(10, 10)
		panel.rect_size = Vector2(400, 300)
		building_menu.add_child(panel)
		
		# Create title label
		var title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.rect_position = Vector2(10, 10)
		title_label.rect_size = Vector2(380, 30)
		title_label.text = "Available Buildings"
		title_label.align = Label.ALIGN_CENTER
		panel.add_child(title_label)
		
		# Create grid container for building buttons
		var grid = GridContainer.new()
		grid.name = "BuildingGrid"
		grid.columns = 3
		grid.rect_position = Vector2(10, 50)
		grid.rect_size = Vector2(380, 230)
		panel.add_child(grid)
		
		# Create close button
		var close_button = Button.new()
		close_button.name = "CloseButton"
		close_button.text = "X"
		close_button.rect_position = Vector2(370, 10)
		close_button.rect_size = Vector2(20, 20)
		panel.add_child(close_button)
		
		print("Building menu created dynamically")

# Create resource display
func _create_resource_display() -> void:
	resource_display = Control.new()
	resource_display.name = "ResourceDisplay"
	resource_display.anchor_right = 1.0
	resource_display.margin_bottom = 60
	add_child(resource_display)
	
	# Create panel
	var panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_right = 1.0
	panel.margin_right = -800
	panel.margin_bottom = 60
	resource_display.add_child(panel)
	
	# Create gold label
	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.rect_position = Vector2(10, 10)
	gold_label.text = "Gold: 100"
	panel.add_child(gold_label)
	
	# Create wood label
	var wood_label = Label.new()
	wood_label.name = "WoodLabel"
	wood_label.rect_position = Vector2(10, 30)
	wood_label.text = "Wood: 50"
	panel.add_child(wood_label)
	
	# Create "Press B for building menu" help text
	var help_label = Label.new()
	help_label.name = "HelpLabel"
	help_label.rect_position = Vector2(150, 20)
	help_label.text = "Press B to open building menu"
	panel.add_child(help_label)
	
	print("Resource display created")

# Update resource display
func update_resources() -> void:
	if not resource_display or not economy_manager:
		return
	
	var gold_label = resource_display.get_node_or_null("Panel/GoldLabel")
	var wood_label = resource_display.get_node_or_null("Panel/WoodLabel")
	
	if gold_label and selected_worker:
		var gold = economy_manager.get_resource(selected_worker.team, economy_manager.ResourceType.GOLD)
		gold_label.text = "Gold: " + str(int(gold))
	
	if wood_label and selected_worker:
		var wood = economy_manager.get_resource(selected_worker.team, economy_manager.ResourceType.WOOD)
		wood_label.text = "Wood: " + str(int(wood))

# Signal handlers
func _on_building_selected(building_type: String) -> void:
	print("Building selected: ", building_type)
	
	if selected_worker and selected_worker.has_method("start_building_placement"):
		var size = Vector2(2, 2)  # Default size
		
		# Try to get actual size from building manager
		if building_manager and building_manager.has_method("get_building_data"):
			var building_data = building_manager.get_building_data(building_type)
			if building_data.has("size_x") and building_data.has("size_y"):
				size = Vector2(building_data.size_x, building_data.size_y)
		
		selected_worker.start_building_placement(building_type, size)
	
	emit_signal("building_selected", building_type)

# Select a worker
func select_worker(worker) -> void:
	if selected_worker:
		selected_worker.deselect()
	
	selected_worker = worker
	if selected_worker:
		selected_worker.select()
		
		# Add to workers group if not already in it
		if not selected_worker.is_in_group("workers"):
			selected_worker.add_to_group("workers")
	
	# Update resource display
	update_resources()
	
	print("Worker selected: ", worker)

# Deselect the current worker
func deselect_worker() -> void:
	if selected_worker:
		selected_worker.deselect()
		selected_worker = null
	
	print("Worker deselected")

# Process function for regular updates
func _process(delta: float) -> void:
	# Update resources display
	if selected_worker and economy_manager:
		update_resources()