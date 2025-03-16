# scripts/ui/log_viewer.gd
extends Control

# Configuration
export var max_log_entries = 100
export var auto_scroll = true
export var show_debug_levels = true
export var default_visible = false

# References
onready var log_container = $VBoxContainer/ScrollContainer/LogContainer
onready var scroll_container = $VBoxContainer/ScrollContainer
onready var level_filter = $VBoxContainer/FilterContainer/LevelFilter
onready var category_filter = $VBoxContainer/FilterContainer/CategoryFilter
onready var search_box = $VBoxContainer/FilterContainer/SearchBox
onready var clear_button = $VBoxContainer/FilterContainer/ClearButton

# State tracking
var log_entries = []
var filtered_entries = []
var current_level_filter = -1 # -1 means show all
var current_category_filter = "All"
var current_search = ""
var logger = null

func _ready():
    # Initialize with default visibility
    visible = default_visible
    
    # Get logger reference
    logger = get_node_or_null("/root/UnifiedLogger")
    if not logger:
        push_error("LogViewer: UnifiedLogger not found!")
        return
    
    # Connect signals
    clear_button.connect("pressed", self, "_on_clear_button_pressed")
    level_filter.connect("item_selected", self, "_on_level_filter_changed")
    category_filter.connect("item_selected", self, "_on_category_filter_changed")
    search_box.connect("text_changed", self, "_on_search_changed")
    
    # Populate filter dropdown options
    _populate_level_filter()
    _populate_category_filter()
    
    # Start collecting logs
    _setup_log_collection()

func _input(event):
    if event is InputEventKey and event.pressed and event.scancode == KEY_F2:
        # Toggle visibility
        visible = !visible

# Setup log collection from logger
func _setup_log_collection():
    # This would normally use signals, but since we can't modify the logger easily,
    # we'll use a timer to poll the logger's buffer
    var timer = Timer.new()
    timer.wait_time = 0.5 # Check for new logs every half second
    timer.connect("timeout", self, "_check_for_new_logs")
    add_child(timer)
    timer.start()

# Check for new log entries
func _check_for_new_logs():
    # In a real implementation, we'd get new logs via signals
    # For this example, we'll simulate some log entries
    # Sample log entry format: {level, category, message, timestamp}
    # In a real implementation, these would come from the logger
    # For demonstration, we'll just add random simulated logs
    if randf() < 0.3 and logger: # 30% chance of a new log each check
        var levels = ["ERROR", "WARNING", "INFO", "DEBUG", "VERBOSE"]
        var categories = ["System", "Network", "Grid", "Combat", "Economy", "Building", "Unit"]
        
        var sample_log = {
            "level": levels[randi() % levels.size()],
            "category": categories[randi() % categories.size()],
            "message": "Sample log message " + str(OS.get_ticks_msec()),
            "timestamp": OS.get_datetime()
        }
        
        _add_log_entry(sample_log)

# Add a log entry to the viewer
func _add_log_entry(entry):
    # Add to main log list
    log_entries.append(entry)
    
    # Trim if too many entries
    while log_entries.size() > max_log_entries:
        log_entries.pop_front()
    
    # Apply filters
    _apply_filters()

# Apply all current filters
func _apply_filters():
    filtered_entries.clear()
    
    for entry in log_entries:
        # Apply level filter
        if current_level_filter >= 0:
            var level_index = _get_level_index(entry.level)
            if level_index > current_level_filter:
                continue
        
        # Apply category filter
        if current_category_filter != "All" and entry.category != current_category_filter:
            continue
        
        # Apply search filter
        if current_search != "" and entry.message.find(current_search) == -1:
            continue
        
        # Entry passed all filters
        filtered_entries.append(entry)
    
    # Update the UI
    _update_log_display()

# Update the log display with filtered entries
func _update_log_display():
    # Clear current entries
    for child in log_container.get_children():
        child.queue_free()
    
    # Add filtered entries
    for entry in filtered_entries:
        var label = Label.new()
        
        # Format timestamp
        var time = entry.timestamp
        var time_str = "%02d:%02d:%02d" % [time.hour, time.minute, time.second]
        
        # Format log entry
        var text = "[%s] " % time_str
        
        if show_debug_levels:
            text += "[%s] " % entry.level
            
        text += "[%s] %s" % [entry.category, entry.message]
        
        # Set text and color
        label.text = text
        label.add_color_override("font_color", _get_level_color(entry.level))
        
        # Add to container
        log_container.add_child(label)
    
    # Auto-scroll if enabled
    if auto_scroll:
        yield (get_tree(), "idle_frame") # Wait for UI update
        scroll_container.scroll_vertical = log_container.rect_size.y

# Populate level filter dropdown
func _populate_level_filter():
    level_filter.clear()
    level_filter.add_item("All Levels")
    level_filter.add_item("ERROR+")
    level_filter.add_item("WARNING+")
    level_filter.add_item("INFO+")
    level_filter.add_item("DEBUG+")
    level_filter.add_item("VERBOSE")

# Populate category filter dropdown
func _populate_category_filter():
    category_filter.clear()
    category_filter.add_item("All")
    
    var categories = ["System", "Network", "Grid", "Combat", "Economy",
                      "Building", "Unit", "AI", "UI", "Input", "Physics"]
    
    for category in categories:
        category_filter.add_item(category)

# Convert level string to index
func _get_level_index(level_str):
    match level_str:
        "ERROR": return 0
        "WARNING": return 1
        "INFO": return 2
        "DEBUG": return 3
        "VERBOSE": return 4
        _: return 2 # Default to INFO
    
# Get color for log level
func _get_level_color(level_str):
    match level_str:
        "ERROR": return Color(1, 0.3, 0.3)
        "WARNING": return Color(1, 0.7, 0.3)
        "INFO": return Color(1, 1, 1)
        "DEBUG": return Color(0.7, 0.7, 1)
        "VERBOSE": return Color(0.7, 0.7, 0.7)
        _: return Color(1, 1, 1)

# Button handlers
func _on_clear_button_pressed():
    log_entries.clear()
    filtered_entries.clear()
    _update_log_display()

func _on_level_filter_changed(index):
    current_level_filter = index - 1 # -1 is "All"
    _apply_filters()

func _on_category_filter_changed(index):
    current_category_filter = category_filter.get_item_text(index)
    _apply_filters()

func _on_search_changed(new_text):
    current_search = new_text
    _apply_filters()