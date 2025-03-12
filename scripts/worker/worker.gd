# Simplified version of scripts/worker/worker.gd for testing
extends KinematicBody2D

export var speed: float = 200.0
export var team: int = 0  # 0 = Team A, 1 = Team B

func _ready():
	# Set up a basic sprite if none exists
	if not has_node("Sprite"):
		var sprite = Sprite.new()
		sprite.name = "Sprite"
		add_child(sprite)
		
	# Set color based on team
	var sprite = $Sprite
	if team == 0:
		sprite.modulate = Color(0, 0, 1)  # Blue for Team A
	else:
		sprite.modulate = Color(1, 0, 0)  # Red for Team B
	
	# If no texture is set, create a placeholder
	if not sprite.texture:
		var image = Image.new()
		image.create(32, 32, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 1, 1))
		var texture = ImageTexture.new()
		texture.create_from_image(image)
		sprite.texture = texture
	
	print("Worker initialized for team " + str(team))

func _physics_process(delta):
	var velocity = Vector2.ZERO
	
	# Simple movement controls
	if Input.is_action_pressed("ui_right"):
		velocity.x += 1
	if Input.is_action_pressed("ui_left"):
		velocity.x -= 1
	if Input.is_action_pressed("ui_down"):
		velocity.y += 1
	if Input.is_action_pressed("ui_up"):
		velocity.y -= 1
	
	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
	
	# Apply movement
	move_and_slide(velocity)
