extends StaticBody3D

@export var speed := 0.5
var count := 0.0
var dir := 1
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if count > 1:
		dir = -1
	elif count < -1:
		dir = 1
	count += dir * delta * speed
	
	position.x = count
	
