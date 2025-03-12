# File Checker - Ensures all required scripts and scenes exist
# Run with: godot -s file_checker.gd
extends SceneTree

func _init():
	print("Starting file checker...")
	
	# Required script paths
	var required_scripts = [
		"res://scripts/worker/worker.gd",
		"res://scripts/ui/building_menu.gd",
		"res://scripts/ui/simple_ui_manager.gd",
		"res://scripts/game/game_scene.gd"
	]
	
	# Required scene paths
	var required_scenes = [
		"res://scenes/units/worker.tscn",
		"res://scenes/ui/building_menu.tscn",
		"res://scenes/game/game.tscn"
	]
	
	# Check and create scripts
	for script_path in required_scripts:
		ensure_script_exists(script_path)
	
	# Check and create scenes
	for scene_path in required_scenes:
		ensure_scene_exists(scene_path)
	
	print("File check complete!")
	quit()

# Ensure a script exists, create it if it doesn't
func ensure_script_exists(script_path: String) -> void:
	var file = File.new()
	if file.file_exists(script_path):
		print("Script exists: " + script_path)
		return
	
	print("Script doesn't exist, creating: " + script_path)
	
	# Create directory if needed
	var dir = Directory.new()
	var dir_path = script_path.get_base_dir()
	if not dir.dir_exists(dir_path):
		dir.make_dir_recursive(dir_path)
	
	# Create script with basic template
	file.open(script_path, File.WRITE)
	
	# Determine script content based on path
	var script_content = ""
	
	if script_path == "res://scripts/worker/worker.gd":
		script_content = create_worker_script()
	elif script_path == "res://scripts/ui/building_menu.gd":
		script_content = create_building_menu_script()
	elif script_path == "res://scripts/ui/simple_ui_manager.gd":
		script_content = create_simple_ui_manager_script()
	elif script_path == "res://scripts/game/game_scene.gd":
		script_content = create_game_scene_script()
	else:
		script_content = """extends Node

# Template for ${script_name}
# Path: ${script_path}

func _ready():
	print("${script_name} initialized")
"""
		script_content = script_content.replace("${script_name}", script_path.get_file().get_basename())
		script_content = script_content.replace("${script_path}", script_path)
	
	file.store_string(script_content)
	file.close()

# Ensure a scene exists, create it if it doesn't
func ensure_scene_exists(scene_path: String) -> void:
	var file = File.new()
	if file.file_exists(scene_path):
		print("Scene exists: " + scene_path)
		return
	
	print("Scene doesn't exist, creating: " + scene_path)
	
	# Create directory if needed
	var dir = Directory.new()
	var dir_path = scene_
