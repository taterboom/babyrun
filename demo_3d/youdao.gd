extends CharacterBody3D
class_name Player

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var left_foot: Marker3D = $Left
@onready var right_foot: Marker3D = $Right
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var left_foot_ray_cast: RayCast3D = $Left/RayCast3D
@onready var right_foot_ray_cast: RayCast3D = $Right/RayCast3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var particle_left: GPUParticles3D = $Left/GPUParticles3D
@onready var particle_right: GPUParticles3D = $Right/GPUParticles3D


var idle_state = IdleState.new(self)
var left_state = LeftState.new(self)
var right_state = RightState.new(self)
var jump_state = JumpState.new(self)
var jump_prepare_state = JumpPrepareState.new(self)
var jump_prepare_max_state = JumpPrepareMaxState.new(self)

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
# there are some unused frames at the end of the animation
const END_CUT = 0.0
const ANIMATION_SPEED_SCALE = 1.5
const MAX_JUMP_PREPARATION_DURATION = 1.0 
const MIN_JUMP_PREPARATION_DURATION = 0.4
const MIN_MOVING_LENGTH = 0.1
@export var angular_speed := 1.2 * PI
@export var jump_impulse_up := 5
@export var jump_impulse_forward := 3
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var cur_state: State = idle_state
var prev_state: State = idle_state
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
	if destination:
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
	cur_state.update(delta)
	if prev_state != cur_state:
		prev_state.leave()
		cur_state.enter()
		prev_state = cur_state

	_update_animation()
	move_and_slide()
	
	if not _is_foot_on_floor():
		_game_over()
	
func _update_animation():
	animation_tree.set("parameters/StateMachine/conditions/idle", cur_state == idle_state)
	animation_tree.set("parameters/StateMachine/conditions/moving_left", cur_state == left_state)
	animation_tree.set("parameters/StateMachine/conditions/moving_right", cur_state == right_state)
	animation_tree.set("parameters/StateMachine/conditions/jump_prepare", cur_state == jump_prepare_state)
	animation_tree.set("parameters/StateMachine/conditions/shake", cur_state == jump_prepare_max_state)
	animation_tree.set("parameters/StateMachine/conditions/jump", cur_state == jump_state)

	
func _is_foot_on_floor():
	if cur_state == left_state:
		return right_foot_ray_cast.is_colliding()
	elif cur_state == right_state:
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

# State ⬇️

class State:
	var player: Player
	func _init(player: Player):
		self.player = player
	func update(delta: float):
		pass
	func enter():
		pass
	func leave():
		pass
		
class IdleState extends State:
	func update(delta):
		if Input.is_action_just_pressed("left") && Input.is_action_just_pressed("right"):
			player.cur_state = player.jump_prepare_state
		elif Input.is_action_just_pressed("left"):
			player.cur_state = player.left_state
		elif Input.is_action_just_pressed("right"):
			player.cur_state = player.right_state

class LeftState extends State:
	func update(delta):
		if Input.is_action_pressed("left") && Input.is_action_just_pressed("right"):
			player.cur_state = player.jump_prepare_state
		elif Input.is_action_just_pressed("right"):
			player.cur_state = player.right_state
		elif !Input.is_action_pressed("left") || player.moving_length > player.animation_left_length:
			player.cur_state = player.idle_state
		else:
			player.moving_length += delta
			var direction := -1 if Input.is_action_pressed("reverse_direction") else 1
			# 左脚围绕右脚转动
			# 这个 tick 下的旋转角度
			var angle = player.angular_speed * delta * direction
			# 本地坐标系下
			# 右脚到原点的向量
			var originBasedRight := Vector3.ZERO - player.right_foot.position
			# 围绕右脚旋转向量
			var rotatedOriginBasedRight := originBasedRight.rotated(Vector3(0,1,0), -angle)
			# 旋转后的点到原点的向量
			var deltaPosition = rotatedOriginBasedRight - originBasedRight
			# 转换为世界坐标系
			var globalDeltaPosition = player.transform.basis * deltaPosition
			player.position += globalDeltaPosition
			player.rotate_y(-angle)
	func enter():
		player.moving_length = 0
	func leave():
		if player.moving_length > player.MIN_MOVING_LENGTH:
			# https://www.reddit.com/r/godot/comments/otr7uq/comment/h6y8uid/?utm_source=share&utm_medium=web2x&context=3		
			player.particle_left.restart()

class RightState extends State:
	func update(delta):
		if Input.is_action_just_pressed("left") && Input.is_action_pressed("right"):
			player.cur_state = player.jump_prepare_state
		elif Input.is_action_just_pressed("left"):
			player.cur_state = player.left_state
		elif !Input.is_action_pressed("right") || player.moving_length > player.animation_right_length:
			player.cur_state = player.idle_state
		else:
			player.moving_length += delta
			var direction := -1 if Input.is_action_pressed("reverse_direction") else 1
			# 右脚围绕左脚转动
			# 这个 tick 下的旋转角度
			var angle = player.angular_speed * delta * direction
			# 本地坐标系下
			# 左脚到原点的向量
			var originBasedLeft := Vector3.ZERO - player.left_foot.position
			# 围绕左脚旋转向量
			var rotatedOriginBasedLeft := originBasedLeft.rotated(Vector3(0,1,0), angle)
			# 旋转后的点到原点的向量
			var deltaPosition = rotatedOriginBasedLeft - originBasedLeft
			# 转换为世界坐标系
			var globalDeltaPosition = player.transform.basis * deltaPosition
			player.position += globalDeltaPosition
			player.rotate_y(angle)
	func enter():
		player.moving_length = 0
	func leave():
		if player.moving_length > player.MIN_MOVING_LENGTH:
			player.particle_right.restart()

class JumpState extends State:
	func update(delta):
		if player.is_on_floor():
			player.velocity = Vector3.ZERO
			player.jump_preparation_duration = 0
			player.animation_tree.set("parameters/OneShot_Landing/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			player.cur_state = player.idle_state
	func enter():
		player.velocity = player.transform.basis * Vector3(0, player.jump_impulse_up * player.jump_preparation_duration, -player.jump_impulse_forward * player.jump_preparation_duration)
		player.particle_left.restart()
		player.particle_right.restart()
	func leave():
		player.particle_left.restart()
		player.particle_right.restart()

class JumpPrepareState extends State:
	func update(delta):
		if Input.is_action_pressed("left") && Input.is_action_pressed("right"):
			if player.jump_preparation_duration >= player.MAX_JUMP_PREPARATION_DURATION:
				player.cur_state = player.jump_prepare_max_state
			else:
				player.jump_preparation_duration += delta
				if player.jump_preparation_duration > player.MAX_JUMP_PREPARATION_DURATION:
					player.jump_preparation_duration = player.MAX_JUMP_PREPARATION_DURATION
		elif !(Input.is_action_pressed("left") && Input.is_action_pressed("right")) && player.jump_preparation_duration >= player.MIN_JUMP_PREPARATION_DURATION:
			player.cur_state = player.jump_state
		elif Input.is_action_pressed("left"):
			player.cur_state = player.left_state
		elif Input.is_action_pressed("right"):
			player.cur_state = player.right_state
		else:
			player.cur_state = player.idle_state
	func enter():
		player.jump_preparation_duration = 0

class JumpPrepareMaxState extends State:
	func update(delta):
		if not (Input.is_action_pressed("left") && Input.is_action_pressed("right")):
			player.cur_state = player.jump_state
