extends Node2D

@export var SPEED := 50
@export var JUMP_SPEED := 200
@export var WALK_SPEED := PI / 2

@onready var player1: Node2D = $Player1
@onready var player2: Node2D = $Player2

var is_jump_ready: bool = false
var jump_start_time: float = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	print("Hello World!")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# move back every frame
	player1.position.y += SPEED * delta
	player2.position.y += SPEED * delta

	var left_pressed: bool = Input.is_action_pressed("left")
	var right_pressed: bool = Input.is_action_pressed("right")

	if left_pressed && right_pressed:
		if !is_jump_ready:
			is_jump_ready = true
			jump_start_time = Time.get_ticks_msec()
		return

	if is_jump_ready:
		var jump_time: float = Time.get_ticks_msec() - jump_start_time
		if jump_time > 100:
			var jump_distance: float = JUMP_SPEED * jump_time / 1000
			var jump_vector: Vector2 = Vector2(0, -jump_distance)
			var tween = get_tree().create_tween()
			tween.parallel().tween_property(player1, 'position', player1.position + jump_vector, jump_time / 1000 / 10)
			tween.parallel().tween_property(player2, 'position', player2.position + jump_vector, jump_time / 1000 / 10)
		is_jump_ready = false
		return
	
	if left_pressed: 
		var distance_vector: Vector2 = player1.position - player2.position
		var rotated_distance_vector := distance_vector.rotated(WALK_SPEED * delta)
		var new_position := player2.position + rotated_distance_vector
		player1.position = new_position

	if right_pressed:
		var distance_vector: Vector2 = player2.position - player1.position
		var rotated_distance_vector := distance_vector.rotated(-WALK_SPEED * delta)
		var new_position := player1.position + rotated_distance_vector
		player2.position = new_position
	



