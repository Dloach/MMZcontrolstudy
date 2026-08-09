extends CharacterBody2D

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	DASH,
	WALLSLIDE,
}



@export_category("Movement")
@export var move_speed:= 300.0
@export var ground_acceleration:= 1800.0
@export var ground_deceleration:= 2200.0
@export var gravity:= 980.0

@export_category("Jump")
@export var jump_velocity:= -500.0
@export var air_acceleration:= 900.0
@export var max_fall_speed:= 1400.0
@export var fall_gravity_multiplier:= 1.5
@export var jump_cut_multiplier:= 0.5

@export_category("Dash")
@export var dash_speed:= 850.0
@export var dash_duration:= 0.18
@export var dash_slide_deceleration:= 2400.0
@export var dash_stop_speed:= 50.0

@export_category("WallSlide")
@export var wall_slide_speed:= 100.0
@export var wall_jump_push:= 220.0



@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
const ANIMATION_OFFSETS: Dictionary = {
	&"idle": Vector2(7.23, -5.435),
	&"jump": Vector2(5.9, -2.32),
	&"run": Vector2(7.3, -4.88),
	&"dash": Vector2(8.82,-4.88),
	&"wallslide": Vector2(9.375, -2.445),
	
}


@onready var state_label: Label = $Label
const STATE_LABEL_COLOR: Dictionary = {
	State.IDLE: Color.AQUAMARINE,
	State.RUN: Color.ROYAL_BLUE,
	State.JUMP: Color.SEA_GREEN,
	State.FALL: Color.ORANGE,
	State.DASH: Color.YELLOW,
	State.WALLSLIDE: Color.DARK_ORCHID,
	
}


var current_state = State.IDLE
var dash_direction:= 1.0
var dash_timer:= 0.0
var facing:= 1.0



#===============================================================
#                          PROCESS
#===============================================================


func _ready() -> void:
	_enter_state(State.IDLE)
	_update_state_label()


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
		State.WALLSLIDE:
			_state_wallslide(direction, delta)
		
			
			
#===============================================================
#                          STATES
#===============================================================



func _state_idle(direction: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	
	
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_change_state(State.JUMP)
		return
		
	elif Input.is_action_just_pressed("dash") and is_on_floor():
		_apply_dash(direction)
		return
		
	elif not is_on_floor():
		_change_state(State.FALL)	
		return
		
	elif not is_zero_approx(direction):
		_change_state(State.RUN)
		return
	
		
func _state_run(direction: float, delta: float) -> void:
	var target_speed: float = direction * move_speed
	
	velocity.x = move_toward(velocity.x, target_speed, ground_acceleration * delta)
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_change_state(State.JUMP)
		return
		
	elif Input.is_action_just_pressed("dash") and is_on_floor():
		_apply_dash(direction)
		return
		
	elif not is_on_floor():
		_change_state(State.FALL)	
		return
	
	elif is_zero_approx(direction):
		_change_state(State.IDLE)
		return
		
		
func _state_jump(direction: float, delta: float) -> void:
	_apply_air_movement(direction, delta)
	
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
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
		return
	
	if _can_wall_slide(direction):
		_change_state(State.WALLSLIDE)
		return
	
	
func _state_dash(direction: float, delta:float) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_change_state(State.JUMP)
		return
	
	if dash_timer > 0.0:
		velocity.x = dash_direction * dash_speed
		velocity.y = 0.0	
		dash_timer = maxf(dash_timer - delta, 0.0)
		return
		
	velocity.x = move_toward(velocity.x, 0.0, dash_slide_deceleration * delta)
	if not is_on_floor():
		_change_state(State.FALL)
		return
	
	if is_zero_approx(direction):
		if abs(velocity.x) <= dash_stop_speed:
			velocity.x = 0.0
			_change_state(State.IDLE)
		return
	elif absf(velocity.x) <= move_speed:
		_change_state(State.RUN)		


func _state_wallslide(direction: float, delta: float) -> void:	
	if is_on_floor():
		if is_zero_approx(direction):
			_change_state(State.IDLE)
		else:
			_change_state(State.RUN)
		return	
			
	if not _can_wall_slide(direction):
		_change_state(State.FALL)
		return
		
	if Input.is_action_just_pressed("jump"):
		velocity.x = get_wall_normal().x * wall_jump_push
		_change_state(State.JUMP)
		return
		
	velocity.x = direction * move_speed
	
	velocity.y = minf(velocity.y, wall_slide_speed)





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
		State.DASH:
			dash_timer = dash_duration
			velocity.x = dash_direction * dash_speed
			_play_animation(&"dash")
		State.WALLSLIDE:
			_play_animation(&"wallslide")
			
			
func _update_facing(direction: float) -> void:
	if is_zero_approx(direction):
		return
		
	if direction < 0.0:
		animated_sprite_2d.scale.x = -2.0
		facing = -1.0
	else:
		animated_sprite_2d.scale.x = 2.0
		facing = 1.0
	
func _apply_dash(direction: float) -> void:
	if is_zero_approx(direction):
		dash_direction = facing
	else:
		dash_direction = signf(direction)
		
	_change_state(State.DASH)
	
func _can_wall_slide(direction: float) -> bool:
	if is_on_floor():
		return	false
	
	if not is_on_wall():
		return false
	
	if is_zero_approx(direction):
		return false
	
	return direction * get_wall_normal().x < 0.0
	


func _play_animation(animation_name: StringName) -> void:
	animated_sprite_2d.offset = ANIMATION_OFFSETS.get(animation_name, Vector2.ZERO)
	
	animated_sprite_2d.play(animation_name)


func _update_state_label() -> void:
	state_label.text = State.keys()[current_state]
	state_label.add_theme_color_override("font_color", STATE_LABEL_COLOR[current_state])
	
	
func _apply_air_movement(direction: float, delta: float)->void:
	var target_speed: float = direction * move_speed
	
	velocity.x = move_toward(velocity.x, target_speed, air_acceleration *delta)
	
	
	
			
