extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
@export var ANGULAR_SPEED := 2 * PI
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var left_foot: Marker3D = $Left
@onready var right_foot: Marker3D = $Right
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var left_foot_ray_cast: RayCast3D = $Left/RayCast3D
@onready var right_foot_ray_cast: RayCast3D = $Right/RayCast3D

enum State { LEFT, RIGHT, IDLE }
var state := State.LEFT
var left_foot_on_ground := true
var is_game_over := false


func _ready():
	# https://docs.godotengine.org/en/stable/classes/class_raycast3d.html#description
	# For an immediate raycast, or if you want to configure a RayCast3D multiple times within the same physics frame, use force_raycast_update.
	# Updates the collision information for the ray. Use this method to update the collision information immediately instead of waiting for the next _physics_process call, for example if the ray or its parent has changed state.
	left_foot_ray_cast.force_raycast_update()
	right_foot_ray_cast.force_raycast_update()
#
#	var space_state = get_world_3d().direct_space_state
#	var origin = left_foot.global_position
#	origin.y = 1
#	var end = Vector3(origin.x, -1, origin.z)
#	var raycast_query = PhysicsRayQueryParameters3D.create(origin, end)
#	print(origin, end)
#	var raycast_query_result = space_state.intersect_ray(raycast_query)
#	print('reuslt', raycast_query_result)


func _physics_process(delta):
	# Add the gravity.
	if is_game_over:
		velocity.y -= gravity * delta
	collision_shape.disabled = true

	# move(delta)
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
	if Input.is_action_pressed("left"):
		state = State.LEFT
	elif Input.is_action_pressed("right"):
		state = State.RIGHT
	else:
		state = State.IDLE

	# Rotate base on state
	if state == State.LEFT:
		# 左脚围绕右脚转动
		# 这个 tick 下的旋转角度
		var angle = ANGULAR_SPEED * delta
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
		if not _is_foot_on_floor(State.LEFT):
			_game_over()
	elif state == State.RIGHT:
		# 右脚围绕左脚转动
		# 这个 tick 下的旋转角度
		var angle = ANGULAR_SPEED * delta
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
		if not _is_foot_on_floor(State.RIGHT):
			_game_over()
	else:
		if not _is_foot_on_floor(State.IDLE):
			_game_over()


	move_and_slide()
	
func _is_foot_on_floor(state: State):
	if state == State.LEFT:
		return right_foot_ray_cast.is_colliding()
	elif state == State.RIGHT:
		return left_foot_ray_cast.is_colliding()
	else:
		return left_foot_ray_cast.is_colliding() && right_foot_ray_cast.is_colliding()
		
func _game_over():
	print('game over')
	is_game_over = true
#	collision_shape.disabled = true
