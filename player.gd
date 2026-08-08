extends CharacterBody2D

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
}

@export_category("Movement")
@export var move_speed:= 300.0
@export var ground_acceleration:= 1800.0
@export var ground_deceleration:= 2200.0
@export var gravity:= 980.0

@export_category("Jump")
@export var jump_velocity:= -500.0
@export var air_acceleration:= 900.0
@export var max_fall_speed:= 900.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


var current_state = State.IDLE


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")

	_apply_gravity(delta)
	_process_state(direction, delta)
	
	move_and_slide()
	
	
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		
		
func _process_state(direction: float, delta: float) ->void:
	match current_state:
		State.IDLE:
			_state_idle(direction, delta)
		State.RUN:
			_state_run(direction, delta)
		State.JUMP:
			_state_jump(direction, delta)
		State.FALL:
			_state_fall(direction, delta)
			
			
#===============================================================
#                          STATES
#===============================================================



func _state_idle(direction: float, delta: float)->void:
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	
	animated_sprite_2d.play("idle")
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_change_state(State.JUMP)
		
	elif not is_on_floor():
		_change_state(State.FALL)	
	
	elif not is_zero_approx(direction):
		_change_state(State.RUN)
		
	
		
func _state_run(direction: float, delta: float)->void:
	var target_speed: float = direction * move_speed
	
	velocity.x = move_toward(velocity.x, target_speed, ground_acceleration * delta)
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_change_state(State.JUMP)
		
	elif not is_on_floor():
		_change_state(State.FALL)	
	
	elif is_zero_approx(direction):
		_change_state(State.IDLE)
		
		
func _state_jump(direction: float, delta: float)->void:
	_apply_air_movement(direction, delta)
	
	if velocity.y >= 0.0:
		_change_state(State.FALL)
		
		
func _state_fall(direction: float, delta: float)->void:
	_apply_air_movement(direction, delta)
	
	if is_on_floor():
		if is_zero_approx(direction):
			_change_state(State.IDLE)
		else:
			_change_state(State.RUN)
	
	
	


#===============================================================
#                          TOOLS
#===============================================================


func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return
		
	current_state = new_state
	
	match current_state:
		State.JUMP:
			velocity.y = jump_velocity
	print("state changed to: ", State.keys()[current_state])
	
	
func _apply_air_movement(direction: float, delta: float)->void:
	var target_speed: float = direction * move_speed
	
	velocity.x = move_toward(velocity.x, target_speed, air_acceleration *delta)
	
	
	
			
