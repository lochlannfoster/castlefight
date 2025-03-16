# UI Manager - Handles all in-game UI elements and interactions
# Path: scripts/ui/ui_manager.gd
extends CanvasLayer

var service_name: String = "UIManager"

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

var _last_scene_change_time = 0
var _scene_change_debounce_ms = 100 # Minimum time between scene change processing
var _ui_initialized = false # Has UI been initialized yet?
var _scene_change_lock = false # Prevent recursive scene change handling


enum SceneType {
    MAIN_MENU,
    LOBBY,
    GAME,
    NONE
}
var current_scene_type = SceneType.NONE
var is_creating_ui: bool = false

func _ready() -> void:
    # Set pause mode to ensure UI can be managed during game state changes
    pause_mode = Node.PAUSE_MODE_PROCESS
    
    # Connect to the scene change signal only once
    if not get_tree().is_connected("tree_changed", self, "_on_scene_changed"):
        get_tree().connect("tree_changed", self, "_on_scene_changed")
    
    # Initialize managers to prevent circular dependency issues
    economy_manager = get_node_or_null("/root/EconomyManager")
    building_manager = get_node_or_null("/root/BuildingManager")
    
    # Initial scene detection
    _scene_change_lock = true # Lock to prevent recursive calls
    var current_scene = get_tree().current_scene
    if current_scene:
        var scene_name = current_scene.name.to_lower()
        
        # Set initial scene type
        if "mainmenu" in scene_name:
            current_scene_type = SceneType.MAIN_MENU
            visible = false
        elif "lobby" in scene_name:
            current_scene_type = SceneType.LOBBY
            visible = true
        elif "game" in scene_name:
            current_scene_type = SceneType.GAME
            visible = true
            
            # Initialize UI when starting directly in game scene
            if not _ui_initialized:
                call_deferred("_initialize_ui_once")
    _scene_change_lock = false # Release lock

func _create_ui_elements() -> void:
    # Double-check to avoid re-entrancy
    if is_creating_ui:
        debug_log("UI creation already in progress. Skipping.", "warning", "UIManager")
        return
    
    # Set flag to prevent re-entrancy
    is_creating_ui = true
    debug_log("Starting UI element creation for scene type: " + str(current_scene_type), "info", "UIManager")
    
    # Only create UI elements for game scenes
    if current_scene_type != SceneType.GAME:
        is_creating_ui = false
        debug_log("Skipping UI creation for non-game scene", "info", "UIManager")
        return
    
    # Create UI elements in a safe manner
    var creation_successful = true
    
    # Try to create each element, but don't try again if they fail
    if not has_node("ResourceDisplay"):
        if not _safe_create_resource_display():
            creation_successful = false
    
    if not has_node("BuildingMenu"):
        if not _safe_create_building_menu():
            creation_successful = false
    
    # Add additional UI elements as needed
    
    debug_log("UI element creation " +
              ("completed successfully" if creation_successful else "completed with some failures"),
              "info", "UIManager")
    
    # Always reset creation flag when done
    is_creating_ui = false

# Safe node creation method to prevent crashes
func _safe_create_node(method_name: String) -> bool:
    # Check if the method exists
    if not has_method(method_name):
        debug_log("Method " + method_name + " not found", "error", "UIManager")
        return false
    
    # Call the method using call()
    var result = call(method_name)
    
    # Basic error checking
    if result == null:
        debug_log("Node creation method " + method_name + " returned null", "warning", "UIManager")
        return false
    
    return true

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
    debug_indicator.add_color_override("font_color", Color(1, 0.5, 0, 1)) # Orange color
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

func _create_building_menu() -> void:
    # Only try to create if it doesn't already exist
    if has_node("BuildingMenu"):
        return
    
    var building_menu_scene = load("res://scenes/ui/building_menu.tscn")
    if building_menu_scene:
        building_menu = building_menu_scene.instance()
        add_child(building_menu)
        
        # Connect signals
        var close_button = building_menu.get_node_or_null("Panel/CloseButton")
        if close_button:
            if not close_button.is_connected("pressed", self, "_on_building_menu_close"):
                close_button.connect("pressed", self, "_on_building_menu_close")
        
        # Hide by default
        building_menu.visible = false
        debug_log("Building menu created successfully", "info")


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

# Create minimap with actual game map rendering
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
    
    # Minimap viewport - will show a scaled-down version of the actual game map
    var minimap_viewport = Viewport.new()
    minimap_viewport.name = "MinimapViewport"
    minimap_viewport.size = Vector2(180, 80)
    minimap_viewport.transparent_bg = true
    minimap_viewport.render_target_v_flip = true
    minimap_viewport.render_target_update_mode = Viewport.UPDATE_WHEN_VISIBLE
    minimap.add_child(minimap_viewport)
    
    # Setup minimap camera
    var minimap_camera = Camera2D.new()
    minimap_camera.name = "MinimapCamera"
    minimap_camera.current = true
    minimap_camera.zoom = Vector2(5, 5) # Zoomed out to see more of the map
    minimap_viewport.add_child(minimap_camera)
    
    # Create viewport texture
    var minimap_texture = ViewportTexture.new()
    minimap_texture.viewport_path = minimap_viewport.get_path()
    
    # Create texture rect to display minimap
    var minimap_rect = TextureRect.new()
    minimap_rect.name = "MinimapRect"
    minimap_rect.rect_position = Vector2(10, 10)
    minimap_rect.rect_size = Vector2(180, 80)
    minimap_rect.expand = true
    minimap_rect.texture = minimap_texture
    panel.add_child(minimap_rect)
    
    # Add click handler to enable map navigation
    minimap_rect.connect("gui_input", self, "_on_minimap_clicked")
    
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
    # Check if we already have a tooltip
    if has_node("Tooltip"):
        tooltip = get_node("Tooltip")
        return
        
    # Create the tooltip if it doesn't exist
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

func _connect_signals() -> void:
    # Connect to Economy Manager
    if economy_manager:
        # Check if not already connected before connecting
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
        var _connect_result = connect("worker_command_issued", self, "_emit_worker_command")

func _input(event) -> void:
    # Ensure tooltip exists before accessing
    if tooltip == null:
        _create_tooltip()
    if not is_inside_tree():
        return

    # Handle key shortcuts
    if event is InputEventKey and event.pressed:
        if event.scancode == KEY_F3:
            is_debug_overlay_visible = !is_debug_overlay_visible
            
            # Add null check before accessing visible property
            if debug_overlay != null:
                debug_overlay.visible = is_debug_overlay_visible
            else:
                print("Debug overlay not initialized")

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
        # Add null check for tooltip
        if tooltip != null and tooltip.has_method("is_visible"):
            if tooltip.visible:
                tooltip.rect_position = event.position + Vector2(15, 15)
        else:
            print("Tooltip not initialized")

    # Handle mouse button clicks
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == BUTTON_RIGHT:
            # Right-click to cancel building placement
            if selected_worker and selected_worker.is_placing_building:
                selected_worker.cancel_building_placement()
                emit_signal("building_placement_cancelled")

    if event is InputEventMouseMotion:
        # Safe tooltip position update
        if tooltip != null and tooltip.has_method("is_visible"):
            if tooltip.visible:
                tooltip.rect_position = event.position + Vector2(15, 15)

# Process function to update game time and debug info
func _process(_delta: float) -> void:
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
        var max_supply = 20 # This should be calculated based on buildings
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
    popup.modulate = Color(1, 0.843, 0) # Gold color
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
    yield (tween, "tween_all_completed")
    popup.queue_free()

# Show bounty popup
func show_bounty_popup(team: int, amount: float, source: String) -> void:
    if team != current_team:
        return
    
    var popup = Label.new()
    popup.text = "+%d gold (%s)" % [int(amount), source]
    popup.modulate = Color(1, 0.843, 0) # Gold color
    
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
    yield (tween, "tween_all_completed")
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

# Show full-featured match preparation screen with team information
func show_match_preparation() -> void:
    # Create container for preparation UI
    var prep_container = Control.new()
    prep_container.name = "MatchPreparation"
    prep_container.set_anchors_preset(Control.PRESET_FULL_RECT)
    
    # Add semi-transparent background
    var bg = ColorRect.new()
    bg.name = "Background"
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0, 0, 0, 0.7)
    prep_container.add_child(bg)
    
    # Add title
    var title = Label.new()
    title.name = "Title"
    title.text = "PREPARING MATCH"
    title.set_anchors_preset(Control.PRESET_TOP_WIDE)
    title.margin_top = 100
    title.margin_bottom = 150
    title.align = Label.ALIGN_CENTER
    title.valign = Label.VALIGN_CENTER
    prep_container.add_child(title)
    
    # Get team information from network manager
    var network_manager = get_node_or_null("/root/NetworkManager")
    var team_a_players = []
    var team_b_players = []
    
    if network_manager and network_manager.player_info.size() > 0:
        for player_id in network_manager.player_info:
            var player_data = network_manager.player_info[player_id]
            if player_data.has("team"):
                if player_data.team == 0:
                    team_a_players.append(player_data.get("name", "Player " + str(player_id)))
                elif player_data.team == 1:
                    team_b_players.append(player_data.get("name", "Player " + str(player_id)))
    
    # Create team displays
    var team_container = HBoxContainer.new()
    team_container.name = "TeamContainer"
    team_container.set_anchors_preset(Control.PRESET_CENTER)
    team_container.margin_left = -400
    team_container.margin_right = 400
    team_container.margin_top = -100
    team_container.margin_bottom = 100
    team_container.alignment = BoxContainer.ALIGN_CENTER
    prep_container.add_child(team_container)
    
    # Create Team A panel
    var team_a_panel = Panel.new()
    team_a_panel.name = "TeamAPanel"
    team_a_panel.rect_min_size = Vector2(350, 200)
    team_container.add_child(team_a_panel)
    
    var team_a_label = Label.new()
    team_a_label.name = "TeamALabel"
    team_a_label.text = "TEAM A (BLUE)"
    team_a_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    team_a_label.margin_top = 10
    team_a_label.margin_bottom = 40
    team_a_label.align = Label.ALIGN_CENTER
    team_a_label.add_color_override("font_color", Color(0, 0.5, 1))
    team_a_panel.add_child(team_a_label)
    
    var team_a_players_list = VBoxContainer.new()
    team_a_players_list.name = "PlayersList"
    team_a_players_list.set_anchors_preset(Control.PRESET_FULL_RECT)
    team_a_players_list.margin_left = 20
    team_a_players_list.margin_top = 50
    team_a_players_list.margin_right = -20
    team_a_players_list.margin_bottom = -20
    team_a_panel.add_child(team_a_players_list)
    
    for player_name in team_a_players:
        var player_label = Label.new()
        player_label.text = player_name
        team_a_players_list.add_child(player_label)
    
    # Add spacer between teams
    var spacer = Control.new()
    spacer.rect_min_size = Vector2(50, 0)
    team_container.add_child(spacer)
    
    # Create Team B panel (similar to Team A)
    var team_b_panel = Panel.new()
    team_b_panel.name = "TeamBPanel"
    team_b_panel.rect_min_size = Vector2(350, 200)
    team_container.add_child(team_b_panel)
    
    var team_b_label = Label.new()
    team_b_label.name = "TeamBLabel"
    team_b_label.text = "TEAM B (RED)"
    team_b_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    team_b_label.margin_top = 10
    team_b_label.margin_bottom = 40
    team_b_label.align = Label.ALIGN_CENTER
    team_b_label.add_color_override("font_color", Color(1, 0, 0))
    team_b_panel.add_child(team_b_label)
    
    var team_b_players_list = VBoxContainer.new()
    team_b_players_list.name = "PlayersList"
    team_b_players_list.set_anchors_preset(Control.PRESET_FULL_RECT)
    team_b_players_list.margin_left = 20
    team_b_players_list.margin_top = 50
    team_b_players_list.margin_right = -20
    team_b_players_list.margin_bottom = -20
    team_b_panel.add_child(team_b_players_list)
    
    for player_name in team_b_players:
        var player_label = Label.new()
        player_label.text = player_name
        team_b_players_list.add_child(player_label)
    
    # Add loading indicator
    var loading_container = VBoxContainer.new()
    loading_container.name = "LoadingContainer"
    loading_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    loading_container.margin_top = -100
    loading_container.margin_bottom = -50
    prep_container.add_child(loading_container)
    
    var loading_label = Label.new()
    loading_label.name = "LoadingLabel"
    loading_label.text = "Loading match..."
    loading_label.align = Label.ALIGN_CENTER
    loading_container.add_child(loading_label)
    
    var loading_bar = ProgressBar.new()
    loading_bar.name = "LoadingBar"
    loading_bar.rect_size = Vector2(400, 20)
    loading_bar.rect_min_size = Vector2(400, 20)
    loading_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    loading_bar.max_value = 100
    loading_bar.value = 0
    loading_container.add_child(loading_bar)
    
    # Add to floating text container
    floating_text_container.add_child(prep_container)
    
    # Animate loading bar
    var tween = Tween.new()
    prep_container.add_child(tween)
    tween.interpolate_property(loading_bar, "value", 0, 100, 5.0, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
    tween.start()
    
    # Remove after delay or on signal
    var timer = Timer.new()
    timer.one_shot = true
    timer.wait_time = 5.0
    timer.connect("timeout", self, "_on_prep_screen_timeout", [prep_container])
    prep_container.add_child(timer)
    timer.start()

# Handle preparation screen timeout
func _on_prep_screen_timeout(prep_container: Node) -> void:
    # Fade out preparation screen
    var tween = Tween.new()
    prep_container.add_child(tween)
    tween.interpolate_property(prep_container, "modulate",
        Color(1, 1, 1, 1), Color(1, 1, 1, 0),
        1.0, Tween.TRANS_CUBIC, Tween.EASE_IN)
    tween.start()
    
    # Remove when done
    yield (tween, "tween_all_completed")
    prep_container.queue_free()
    
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
    var _current_game_manager = get_node_or_null("/root/GameManager")
    if game_manager and game_manager.has_method("change_scene"):
        game_manager.change_scene("res://scenes/lobby/lobby.tscn")
    else:
        # Fallback if not available
        var _result = get_tree().change_scene("res://scenes/lobby/lobby.tscn")

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

func _on_scene_changed() -> void:
    # Break recursive scene change calls
    if _scene_change_lock:
        return
    
    # Set lock to prevent recursion
    _scene_change_lock = true
    
    # Identify current scene
    var current_scene = get_tree().current_scene
    if current_scene:
        var scene_name = current_scene.name.to_lower()
        
        # Determine scene type
        var new_scene_type = SceneType.NONE
        if "mainmenu" in scene_name:
            new_scene_type = SceneType.MAIN_MENU
        elif "lobby" in scene_name:
            new_scene_type = SceneType.LOBBY
        elif "game" in scene_name:
            new_scene_type = SceneType.GAME
        
        # Handle scene type change
        if new_scene_type != current_scene_type:
            debug_log("Scene changed from " + str(current_scene_type) + " to " + str(new_scene_type), "info")
            current_scene_type = new_scene_type
            
            # Set UI visibility based on scene type
            if current_scene_type == SceneType.MAIN_MENU:
                visible = false
            else:
                visible = true
                
                # Initialize UI once when entering game scene
                if current_scene_type == SceneType.GAME and not _ui_initialized:
                    _initialize_ui_once()
    
    # Release the lock
    _scene_change_lock = false

var _ui_created = false

func initialize() -> void:
    print("UIManager: Initializing...")
    
    # Only create UI once
    if not _ui_created:
        _create_ui_elements()
        _ui_created = true
    
    # Get references to managers
    economy_manager = get_node_or_null("/root/EconomyManager")
    building_manager = get_node_or_null("/root/BuildingManager")
    
    # Connect signals
    _connect_signals()
    
    print("UIManager: Initialization complete")

func set_ui_visibility(is_visible: bool) -> void:
    # Prevent recursive calls
    if is_creating_ui:
        return
    
    # Single, controlled print statement
    print("UI Manager visibility: " + str(is_visible))
    
    # Simple, direct visibility management
    var elements_to_toggle = [
        "ResourceDisplay",
        "BuildingMenu",
        "UnitInfoPanel",
        "GameStatusPanel",
        "Minimap",
        "FloatingTextContainer"
    ]
    
    for element_name in elements_to_toggle:
        var element = get_node_or_null(element_name)
        if element and "visible" in element:
            element.visible = is_visible

func _exit_tree() -> void:
    # Disconnect from signals when leaving the tree
    if get_tree() and get_tree().is_connected("tree_changed", self, "_on_scene_changed"):
        get_tree().disconnect("tree_changed", self, "_on_scene_changed")

func _initialize_ui_once() -> void:
    if _ui_initialized:
        return
    
    debug_log("Initializing UI elements (one-time initialization)", "info")
    
    # Create UI elements properly from their scenes
    _create_building_menu()
    _create_resource_display()
    _create_unit_info_panel()
    _create_game_status_panel()
    
    # Mark as initialized
    _ui_initialized = true
    debug_log("UI initialization complete", "info")