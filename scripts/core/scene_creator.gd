# Scene Creator - Helper utility to create missing scene files
# Path: scripts/core/scene_creator.gd
extends Node

# List of required scenes and their basic structures
var required_scenes = {
	"res://scenes/ui/building_menu.tscn": {
		"root_type": "Control",
		"root_name": "BuildingMenu",
		"script_path": "res://scripts/ui/building_menu.gd",
		"children": [
			{
				"type": "Panel",
				"name": "Panel",
				"position": Vector2(10, 10),
				"size": Vector2(400, 300),
				"children": [
					{
						"type": "Label",
						"name": "TitleLabel",
						"position": Vector2(10, 10),
						"size": Vector2(380, 30),
						"text": "Available Buildings",
						"align": Label.ALIGN_CENTER
					},
					{
						"type": "GridContainer",
						"name": "BuildingGrid",
						"position": Vector2(10, 50),
						"size": Vector2(380, 230),
						"columns": 3
					},
					{
						"type": "Button",
						"name": "CloseButton",
						"position": Vector2(370, 10),
						"size": Vector2(20, 20),
						"text": "X"
					}
				]
			}
		]
	},
	"res://scenes/units/worker.tscn": {
		"root_type": "KinematicBody2D",
		"root_name": "Worker",
		"script_path": "res://scripts/worker/worker.gd",
		"children": [
			{
				"type": "Sprite",
				"name": "Sprite",
				"position": Vector2(0, 0)
			},
			{
				"type": "CollisionShape2D",
				"name": "CollisionShape2D",
				"shape_type": "CircleShape2D",
				"radius": 16.0
			}
		]
	}
}

# Called when added to the scene tree
func _ready():
	# Check and create all required scenes
	for scene_path in required_scenes.keys():
		ensure_scene_exists(scene_path)
	
	# Remove ourselves from the tree as we're no longer needed
	queue_free()

# Check if a scene exists and create it if not
func ensure_scene_exists(scene_path: String) -> void:
	var file = File.new()
	if file.file_exists(scene_path):
		print("Scene exists: " + scene_path)
		return
	
	print("Scene doesn't exist, creating: " + scene_path)
	
	# Create directory structure if needed
	var dir = Directory.new()
	var dir_path = scene_path.get_base_dir()
	if not dir.dir_exists(dir_path):
		dir.make_dir_recursive(dir_path)
	
	# Get scene definition
	var scene_def = required_scenes[scene_path]
	
	# Create root node
	var root_node = create_node_from_def(scene_def)
	
	# Pack and save the scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(root_node)
	
	var save_result = ResourceSaver.save(scene_path, packed_scene)
	if save_result == OK:
		print("Successfully created scene at: " + scene_path)
	else:
		push_error("Failed to save scene with error: " + str(save_result))

# Create a node from definition
func create_node_from_def(node_def: Dictionary) -> Node:
	# Create node of specified type
	var node
	
	match node_def.root_type:
		"Control":
			node = Control.new()
		"Panel":
			node = Panel.new()
		"Label":
			node = Label.new()
		"Button":
			node = Button.new()
		"GridContainer":
			node = GridContainer.new()
		"KinematicBody2D":
			node = KinematicBody2D.new()
		"Sprite":
			node = Sprite.new()
		"CollisionShape2D":
			node = CollisionShape2D.new()
			# Create shape
			if node_def.has("shape_type"):
				var shape
				match node_def.shape_type:
					"CircleShape2D":
						shape = CircleShape2D.new()
						shape.radius = node_def.radius if node_def.has("radius") else 16.0
				
				node.shape = shape
		_:
			node = Node.new()
	
	# Set node name
	node.name = node_def.root_name if node_def.has("root_name") else node_def.name
	
	# Apply script if specified
	if node_def.has("script_path"):
		var script = load(node_def.script_path)
		if script:
			node.set_script(script)
	
	# Apply properties
	if node_def.has("position"):
		if node is Control:
			node.rect_position = node_def.position
		else:
			node.position = node_def.position
	
	if node_def.has("size") and node is Control:
		node.rect_size = node_def.size
	
	if node_def.has("text") and node is Label or node is Button:
		node.text = node_def.text
	
	if node_def.has("align") and node is Label:
		node.align = node_def.align
	
	if node_def.has("columns") and node is GridContainer:
		node.columns = node_def.columns
	
	# Create children
	if node_def.has("children"):
		for child_def in node_def.children:
			var child_node = create_node_from_def(child_def)
			node.add_child(child_node)
			child_node.owner = node
	
	return node