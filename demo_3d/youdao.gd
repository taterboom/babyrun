extends CharacterBody3D


@onready var animation_tree: AnimationTree = $AnimationTree
@onready var left_foot: Marker3D = $Left
@onready var right_foot: Marker3D = $Right
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var left_foot_ray_cast: RayCast3D = $Left/RayCast3D
@onready var right_foot_ray_cast: RayCast3D = $Right/RayCast3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
# there are some unused frames at the end of the animation
const END_CUT = 0.0
const ANIMATION_SPEED_SCALE = 1.5
const MAX_JUMP_PREPARATION_DURATION = 1.0 
const MIN_JUMP_PREPARATION_DURATION = 0.4
@export var angular_speed := 1.2 * PI
@export var jump_impulse_up := 5
@export var jump_impulse_forward := 3
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
enum State { IDLE, LEFT, RIGHT, JUMP_PREPARE, JUMP_PREPARE_MAX, JUMP }
var state := State.IDLE
var prev_state := State.IDLE
var is_game_over := false
var animation_left_length := 0.0
var animation_right_length := 0.0
var moving_length := 0.0
var is_ready := false
var jump_preparation_duration := 0.0

var success_label: Label

func _ready():
	# https://docs.godotengine.org/en/stable/classes/class_raycast3d.html#description
	# For an immediate raycast, or if you want to configure a RayCast3D multiple times within the same physics frame, use force_raycast_update.
	# Updates the collision information for the ray. Use this method to update the collision information immediately instead of waiting for the next _physics_process call, for example if the ray or its parent has changed state.
	left_foot_ray_cast.force_raycast_update()
	right_foot_ray_cast.force_raycast_update()
#	collision_shape.disabled = true
	animation_tree.active = true
	animation_tree.set("parameters/TimeScale/scale", ANIMATION_SPEED_SCALE)
	animation_left_length = (animation_player.get_animation('lift_left').length - END_CUT) / ANIMATION_SPEED_SCALE
	animation_right_length = (animation_player.get_animation('lift_right').length - END_CUT) / ANIMATION_SPEED_SCALE
	
	var destination: Area3D = get_tree().get_first_node_in_group('Destination')
	destination.connect('body_entered', _on_destination_entered)
	success_label = get_tree().get_first_node_in_group('SuccessLabel')
	
	# Collision between GridMap and RayCast not work at first
	# https://github.com/godotengine/godot/issues/76349
	await get_tree().process_frame
	is_ready = true


func _physics_process(delta):

	if is_ready:
		# move(delta)
		# Add the gravity.
		if is_game_over || !is_on_floor():
			velocity.y -= gravity * delta
		rock(delta)

	
func move(delta: float):
	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		# print(input_dir, '|', direction, '|', velocity, '|', transform.basis, '|')
		# print(position, global_position,'|',left_foot.position, left_foot.global_position,)
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	# move_and_collide(velocity * delta)
	move_and_slide()

func rock(delta: float):
	if state != State.JUMP && Input.is_action_pressed("left") && Input.is_action_pressed("right"):
		if jump_preparation_duration >= MAX_JUMP_PREPARATION_DURATION:
			state = State.JUMP_PREPARE_MAX
		else:
			state = State.JUMP_PREPARE
	elif jump_preparation_duration > MIN_JUMP_PREPARATION_DURATION:
		state = State.JUMP 
	elif Input.is_action_pressed("left"):
		state = State.LEFT
	elif Input.is_action_pressed("right"):
		state = State.RIGHT
	else:
		state = State.IDLE

	_update_animation()

	var direction := -1 if Input.is_action_pressed("reverse_direction") else 1
	
	if state == State.JUMP_PREPARE:
		if prev_state == state:
			jump_preparation_duration += delta
			if jump_preparation_duration >= MAX_JUMP_PREPARATION_DURATION:
				jump_preparation_duration = MAX_JUMP_PREPARATION_DURATION
		else:
			jump_preparation_duration = delta
	elif state == State.JUMP_PREPARE_MAX:
		pass
	elif state == State.JUMP:
		if prev_state == state:
			if is_on_floor():
				velocity = Vector3.ZERO
				jump_preparation_duration = 0
				animation_tree.set("parameters/OneShot_Landing/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		else:
			velocity.y = jump_impulse_up * jump_preparation_duration
			velocity.z = -jump_impulse_forward * jump_preparation_duration
	elif state == State.LEFT:
		if prev_state == state:
			moving_length += delta
		else:
			moving_length = 0
		if moving_length >= animation_left_length:
			return
		# 左脚围绕右脚转动
		# 这个 tick 下的旋转角度
		var angle = angular_speed * delta * direction
		# 本地坐标系下
		# 右脚到原点的向量
		var originBasedRight := Vector3.ZERO - right_foot.position
		# 围绕右脚旋转向量
		var rotatedOriginBasedRight := originBasedRight.rotated(Vector3(0,1,0), -angle)
		# 旋转后的点到原点的向量
		var deltaPosition = rotatedOriginBasedRight - originBasedRight
		# 转换为世界坐标系
		var globalDeltaPosition = transform.basis * deltaPosition
		position += globalDeltaPosition
		rotate_y(-angle)
	elif state == State.RIGHT:
		if prev_state == state:
			moving_length += delta
		else:
			moving_length = 0
		if moving_length >= animation_right_length:
			return
		# 右脚围绕左脚转动
		# 这个 tick 下的旋转角度
		var angle = angular_speed * delta * direction
		# 本地坐标系下
		# 左脚到原点的向量
		var originBasedLeft := Vector3.ZERO - left_foot.position
		# 围绕左脚旋转向量
		var rotatedOriginBasedLeft := originBasedLeft.rotated(Vector3(0,1,0), angle)
		# 旋转后的点到原点的向量
		var deltaPosition = rotatedOriginBasedLeft - originBasedLeft
		# 转换为世界坐标系
		var globalDeltaPosition = transform.basis * deltaPosition
		position += globalDeltaPosition
		rotate_y(angle)
	
	prev_state = state
	move_and_slide()
	
	if not _is_foot_on_floor():
		_game_over()
	
func _update_animation():
	animation_tree.set("parameters/StateMachine/conditions/idle", state == State.IDLE)
	animation_tree.set("parameters/StateMachine/conditions/moving_left", state == State.LEFT)
	animation_tree.set("parameters/StateMachine/conditions/moving_right", state == State.RIGHT)
	animation_tree.set("parameters/StateMachine/conditions/jump_prepare", state == State.JUMP_PREPARE)
	animation_tree.set("parameters/StateMachine/conditions/shake", state == State.JUMP_PREPARE_MAX)
	animation_tree.set("parameters/StateMachine/conditions/jump", state == State.JUMP)

	
func _is_foot_on_floor():
	if state == State.LEFT:
		return right_foot_ray_cast.is_colliding()
	elif state == State.RIGHT:
		return left_foot_ray_cast.is_colliding()
	else:
		return left_foot_ray_cast.is_colliding() && right_foot_ray_cast.is_colliding()
		
func _game_over():
	print('1game over')
	is_game_over = true
	collision_shape.disabled = true
	

func _on_destination_entered(body: Node3D):
	if body == self:
		print('成功啦！ 🚀🚀🚀')
		success_label.visible = true
	
