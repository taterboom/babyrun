extends Node2D

@onready var bg: Sprite2D = get_node("BG")

const SPEED = 400
const ANGULAR_SPEED = PI

# Called when the node enters the scene tree for the first time.
func _ready():
	print(bg.modulate)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# rotation += ANGULAR_SPEED * delta
	# var velocity := Vector2.UP.rotated(rotation) * SPEED
	# position += velocity * delta
	pass
