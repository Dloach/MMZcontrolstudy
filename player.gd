extends CharacterBody2D

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	DASH,
	WALLSLIDE,
	ATTACK,
	HURT,
	DIE,
	LOWSLIDE,
	SQUAT,
	
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

@export_category("Feel")
@export var jump_buffer_duration:= 0.15
@export var coyote_duration:= 0.12
@export var dash_buffer_duration:= 0.15

@export_category("Dash")
@export var dash_speed:= 850.0
@export var dash_duration:= 0.18
@export var dash_slide_deceleration:= 2400.0
@export var dash_stop_speed:= 50.0

@export_category("Lowslide")
@export var low_slide_speed: = 850.0

@export_category("WallSlide")
@export var wall_slide_speed:= 100.0
@export var wall_jump_push:= 220.0

@export_category("Hurt")
@export var hurt_back_x:= 150.0
@export var hurt_bounce:= -200.0
@export var hurt_duration:= 0.5
@export var hurt_immunity:= 0.8

@export_category("Squat")
@export var squat_move_speed:= 220.0


@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
const ANIMATION_OFFSETS: Dictionary = {
	&"idle": Vector2(7.23, -5.435),
	&"jump": Vector2(5.9, -2.32),
	&"run": Vector2(7.3, -4.88),
	&"dash": Vector2(8.82,-4.88),
	&"wallslide": Vector2(9.375, -2.445),
	&"lowslide": Vector2(8.4,-5.35),
	&"squat": Vector2(7.0,-5.0)
	
}


@onready var state_label: Label = $Label
const STATE_LABEL_COLOR: Dictionary = {
	State.IDLE: Color.AQUAMARINE,
	State.RUN: Color.ROYAL_BLUE,
	State.JUMP: Color.SEA_GREEN,
	State.FALL: Color.ORANGE,
	State.DASH: Color.YELLOW,
	State.WALLSLIDE: Color.DARK_ORCHID,
	State.HURT: Color.DARK_RED,
	State.DIE: Color.DIM_GRAY,
	State.LOWSLIDE: Color.HOT_PINK,
	State.SQUAT: Color.DARK_KHAKI,
	
}




var current_state = State.IDLE
var dash_direction:= 1.0
var dash_timer:= 0.0
var facing:= 1.0
var hurt_timer:= 0.0
var hurt_immunity_timer:= 0.0
var last_spike: Area2D
var jump_buffer_timer:= 0.0
var coyote_timer:= 0.0
var dash_buffer_timer:= 0.0



#===============================================================
#                          PROCESS
#===============================================================


func _ready() -> void:
	_enter_state(State.IDLE)
	_update_state_label()
	get_tree().debug_collisions_hint = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	_update_timers(delta)
	_update_facing(direction)
	_apply_gravity(delta)
	_process_state(direction, delta)	
	move_and_slide()
	
	hurt_immunity_timer = maxf(hurt_immunity_timer - delta, 0.0)
	
		
		
	
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
			_state_wallslide(direction)
		State.HURT:
			_state_hurt(direction)
		State.DIE:
			_state_die(direction)
		State.LOWSLIDE:
			_state_lowslide(direction, delta)
		State.SQUAT:
			_state_squat(direction, delta)
			
			
#===============================================================
#                          STATES
#===============================================================



func _state_idle(direction: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	
	if _can_lowslide():
		_change_state(State.SQUAT)
		return
	
	if _can_dash():
		_apply_dash(direction)
		return
	
	if not is_on_floor():
		_change_state(State.FALL)	
		return
	
	elif _can_jump():
		_change_state(State.JUMP)
		return
		
	elif not is_zero_approx(direction):
		_change_state(State.RUN)
		return
	
		
func _state_run(direction: float, delta: float) -> void:
	var target_speed: float = direction * move_speed
	
	velocity.x = move_toward(velocity.x, target_speed, ground_acceleration * delta)
	
	if _can_lowslide():
		_change_state(State.SQUAT)
		
	if _can_dash():
		_apply_dash(direction)
		return
		
	elif _can_jump():
		_change_state(State.JUMP)
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
	if _can_lowslide():
		_change_state(State.SQUAT)
	
	if _can_jump():
		_change_state(State.JUMP)
		return
	
	if _can_wall_slide(direction):
		_change_state(State.WALLSLIDE)
		return
	
	if is_on_floor():
		if is_zero_approx(direction):
			_change_state(State.IDLE)
		else:
			_change_state(State.RUN)
		return
	
	
	
	
func _state_dash(direction: float, delta:float) -> void:
	if _can_jump():
		_change_state(State.JUMP)
		return
		
	if _can_lowslide():
		_change_state(State.LOWSLIDE)
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


func _state_wallslide(direction: float) -> void:	
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
	
	
func _state_hurt(direction: float) -> void:
	
	if hurt_timer <= 0.0:
		if is_on_floor():
			if is_zero_approx(direction):
				_change_state(State.IDLE)
				return
			else:
				_change_state(State.RUN)
				return
		else:
			_change_state(State.FALL)
			
			
func _state_lowslide(direction: float, delta: float) -> void:
	if dash_timer > 0.0:
		velocity.x = dash_direction * dash_speed
		velocity.y = 0.0	
		dash_timer = maxf(dash_timer - delta, 0.0)
		return
		
	velocity.x = move_toward(velocity.x, 0.0, dash_slide_deceleration * delta)
	
	if is_zero_approx(direction):
		if abs(velocity.x) <= dash_stop_speed:
			velocity.x = 0.0
			_change_state(State.IDLE)
		return
	elif absf(velocity.x) <= move_speed:
		_change_state(State.RUN)
	
	
func _state_squat(direction: float, delta: float) -> void:
	if is_zero_approx(direction):
		_show_animation_frame(&"squat", 0)
		velocity.x = 0.0
	else:
		if not animated_sprite_2d.is_playing():
			_play_animation(&"squat")
		velocity.x = move_toward(velocity.x, direction * squat_move_speed, ground_acceleration * 1 * delta)
	
	#print("StandCheck: ",$StandCheck.is_colliding())
	print("StandCheck hit: ", $StandCheck.get_collider())   
	if Input.is_action_just_released("move_down") and not$StandCheck.is_colliding():
		if is_zero_approx(direction):
			_change_state(State.IDLE)
		else:
			_change_state(State.RUN)
			return
	
	
	
func _state_die(direction: float) -> void:
	pass



#===============================================================
#                          TOOLS
#===============================================================


func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return
		
	match current_state:
		State.LOWSLIDE:
			$CollisionShape2D.shape.height = 29.0
			$CollisionShape2D.position.y = 0.0
		State.SQUAT:
			$CollisionShape2D.shape.height = 29.0
			$CollisionShape2D.position.y = 0.0
	current_state = new_state
	_update_state_label()
	_enter_state(current_state)
	print("state changed to: ", State.keys()[current_state])
	
@onready var spike_areas: Array = get_tree().get_nodes_in_group("spikes")

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
		State.HURT:
			hurt_timer = hurt_duration
			velocity = Vector2.ZERO
			var knock_direction:= -facing
			if last_spike != null:
				knock_direction = signf(global_position.x - last_spike.global_position.x)
				if knock_direction == 0.0:
					knock_direction = -facing
			print("knock_dir: ", knock_direction)
			velocity = Vector2(knock_direction * hurt_back_x, hurt_bounce)
			_update_facing(-knock_direction)
			_play_animation(&"hurt")
		State.LOWSLIDE:
			$CollisionShape2D.shape.height = 16.0
			$CollisionShape2D.position.y = 13.0
			_play_animation(&"lowslide")
		State.SQUAT:
			$CollisionShape2D.shape.height = 16.0
			$CollisionShape2D.position.y = 13.0
			if is_zero_approx(velocity.x):
				_show_animation_frame(&"squat", 0)
				return
			else:
				_play_animation(&"squat")
			
			
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
	
func _show_animation_frame(animation_name: StringName, frame_index: int ) -> void:
	animated_sprite_2d.offset = ANIMATION_OFFSETS.get(animation_name, Vector2.ZERO)
	animated_sprite_2d.play(animation_name)
	animated_sprite_2d.pause()
	animated_sprite_2d.frame = frame_index


func _update_state_label() -> void:
	state_label.text = State.keys()[current_state]
	state_label.add_theme_color_override("font_color", STATE_LABEL_COLOR[current_state])
	
	
func _apply_air_movement(direction: float, delta: float)->void:
	var target_speed: float = direction * move_speed
	
	velocity.x = move_toward(velocity.x, target_speed, air_acceleration *delta)
	
	


func _on_spike_1_body_entered(body: Node2D) -> void:
	if body != self:
		return
	_change_state(State.HURT)
	return
	

func _check_spike_overlap() -> void:
	if hurt_immunity_timer > 0.0 or current_state == State.DIE:
		return
		
	for spike in spike_areas:
		if spike.get_overlapping_bodies().has(self):
			last_spike = spike
			hurt_immunity_timer = hurt_immunity
			_change_state(State.HURT)


func _update_timers(delta: float) -> void:
	_check_spike_overlap()
	hurt_timer = maxf(hurt_timer - delta, 0.0)	
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	dash_buffer_timer = maxf(dash_buffer_timer - delta, 0.0)
	
	if Input.is_action_just_pressed("dash"):
		dash_buffer_timer = dash_buffer_duration	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_duration
	if is_on_floor():
		coyote_timer = coyote_duration
		
func _can_jump()  -> bool:
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		return true	
	return false
	
func _can_dash() -> bool:
	if dash_buffer_timer > 0.0 and coyote_timer > 0.0:
		dash_buffer_timer = 0.0
		return true
	return false
	
func _can_lowslide() -> bool:
	if is_on_floor() and Input.is_action_just_pressed("move_down"):
		return true
	return false	
		


	
	
