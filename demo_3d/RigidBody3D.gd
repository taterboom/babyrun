extends RigidBody3D

var dir := 1

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if position.z == 5:
		dir = -1
	if position.z == -5:
		dir = 1
	position = position.move_toward(Vector3(0, 0, 5) if dir == 1 else Vector3(0, 0, -5), 3 * delta)
