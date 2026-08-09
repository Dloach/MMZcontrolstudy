extends CharacterBody2D

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	DASH,
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
@export var fall_gravity_multiplier:= 1.5
@export var jump_cut_multiplier:= 0.5

@export_category("Dash")
@export var dash_speed:= 1200.0



@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
const ANIMATION_OFFSETS: Dictionary = {
	&"idle": Vector2(7.23, -5.435),
	&"jump": Vector2(5.9, -2.32),
	&"run": Vector2(7.3, -4.88)
	
}


@onready var state_label: Label = $Label
const STATE_LABLE_COLOR: Dictionary = {
	State.IDLE: Color.AQUAMARINE,
	State.RUN: Color.ROYAL_BLUE,
	State.JUMP: Color.SEA_GREEN,
	State.FALL: Color.ORANGE,
	State.DASH: Color.YELLOW,
	
}


var current_state = State.IDLE


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	_update_facing(direction)
	_apply_gravity(delta)
	_process_state(direction, delta)
	
	move_and_slide()
	
	
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity_mod:= 1.0
		if velocity.y > 0.0:
			gravity_mod = fall_gravity_multiplier
			
		velocity.y = minf(velocity.y + gravity * gravity_mod * delta, max_fall_speed)
		
		
func _process_state(direction: float, delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle(direction, delta)
		State.RUN:
			_state_run(direction, delta)
		State.JUMP:
			_state_jump(direction, delta)
		State.FALL:
			_state_fall(direction, delta)
		State.DASH:
			_state_dash(direction, delta)
		
			
			
#===============================================================
#                          STATES
#===============================================================



func _state_idle(direction: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	
	
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_change_state(State.JUMP)
		
	elif Input.is_action_just_pressed("dash"):
		_change_state(State.DASH)	
			
	elif not is_on_floor():
		_change_state(State.FALL)	
	
	elif not is_zero_approx(direction):
		_change_state(State.RUN)
		
	
		
func _state_run(direction: float, delta: float) -> void:
	var target_speed: float = direction * move_speed
	
	velocity.x = move_toward(velocity.x, target_speed, ground_acceleration * delta)
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_change_state(State.JUMP)
		
	elif Input.is_action_just_pressed("dash"):
		_change_state(State.DASH)
		
	elif not is_on_floor():
		_change_state(State.FALL)	
	
	elif is_zero_approx(direction):
		_change_state(State.IDLE)
		
		
func _state_jump(direction: float, delta: float) -> void:
	_apply_air_movement(direction, delta)
	
	if Input.is_action_just_released("jump"):
		velocity.y *= jump_cut_multiplier
		
	if velocity.y >= 0.0:
		_change_state(State.FALL)
		
		
func _state_fall(direction: float, delta: float) -> void:
	_apply_air_movement(direction, delta)
	
	if is_on_floor():
		if is_zero_approx(direction):
			_change_state(State.IDLE)
		else:
			_change_state(State.RUN)
	
	
func _state_dash(direction: float, delta: float) -> void:
	_apply_dash(direction)
	
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_change_state(State.JUMP)
	elif velocity.x <= 50:
		if not is_on_floor():
			_change_state(State.FALL)
		elif is_zero_approx(direction):
			_change_state(State.IDLE)
		else: _change_state(State.RUN)
		
		


#===============================================================
#                          TOOLS
#===============================================================


func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return
		
	current_state = new_state
	_update_state_label()
	_enter_state(current_state)
	print("state changed to: ", State.keys()[current_state])
	


func _enter_state(new_state:State) -> void:
	match new_state:
		State.IDLE:
			_play_animation(&"idle")
		State.RUN:
			_play_animation(&"run")
		State.JUMP:
			velocity.y = jump_velocity
			_play_animation(&"jump")
			
func _update_facing(direction: float) -> void:
	if is_zero_approx(direction):
		return
		
	if direction < 0.0:
		animated_sprite_2d.scale.x = -2.0
	else:
		animated_sprite_2d.scale.x = 2.0
	
func _apply_dash(direction: float) -> void:
	velocity.x = direction * dash_speed
	

func _play_animation(animation_name: StringName) -> void:
	animated_sprite_2d.offset = ANIMATION_OFFSETS.get(animation_name, Vector2.ZERO)
	
	animated_sprite_2d.play(animation_name)


func _update_state_label() -> void:
	state_label.text = State.keys()[current_state]
	state_label.add_theme_color_override("font_color", STATE_LABLE_COLOR[current_state])
	
	
func _apply_air_movement(direction: float, delta: float)->void:
	var target_speed: float = direction * move_speed
	
	velocity.x = move_toward(velocity.x, target_speed, air_acceleration *delta)
	
	
	
			
