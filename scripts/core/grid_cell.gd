extends Reference
class_name GridCell

var grid_position: Vector2
var world_position: Vector2
var occupied: bool = false
var walkable: bool = true
var building = null
var team_territory: int = -1 # -1 = neutral, 0 = Team A, 1 = Team B
var lane: int = 0
var terrain_type: String = "neutral"

func _init(pos: Vector2, world_pos: Vector2) -> void:
    grid_position = pos
    world_position = world_pos