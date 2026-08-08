extends CharacterBody2D


#STATES
enum State {
	IDLE,
	WALK,
	JUMP,
	FALL,
	LAND,
	HURT,
	DASH,
	WLSL,
}

# CONSTANTS
const SPEED: float = 350.0
const JUMP_VELOCITY: float = -650.0
const JUMP_BUFFER_TIME: float = 0.15
const GRVITY: float = 980.0
const FALL_MULTIPLIER: float = 1.6
const HURT_DURATION: float = 0.6
const LAND_DURATION: float = 0.15
const RESPAWN_POS: Vector2 = Vector2(100.0, 400.0)
const DASH_SPEED: float = 700.0
const DASH_DURATION: float = 0.25
const WALL_SLIDE_MULTIPLIER: float = 0.2
const WALL_JUMP_PUSH: float = 800.0
const JUMP_DECLE: float = 10.0
const DASH_SLIDE_DECEL: float = 0.008
const AIR_ACCEL: float = 0.1

# STATE COLORS
const STATE_COLORS: Dictionary = {
	State.IDLE: Color.CORNFLOWER_BLUE,
	State.WALK: Color.LIME_GREEN,
	State.JUMP: Color.YELLOW,
	State.FALL: Color.DARK_ORANGE,
	State.LAND: Color.SADDLE_BROWN,
	State.HURT: Color.RED,
	State.DASH: Color.ROYAL_BLUE,
	State.WLSL: Color.DARK_MAGENTA
}


# VARIABLES
var current_state:State = State.IDLE
var previou_state:State = State.IDLE
var facing: float = 1.0
var last_direction: float = 1.0
var hurt_timer: float = 0.0
var land_timer: float = 0.0
var dash_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_dash_jump = false
var is_wall_sliding = false


#NODE REFERENCE
@onready var body_visual: Polygon2D = $BodyVisual
@onready var state_lable: Label = $StateLable


func _physics_process(delta: float) -> void:
	_update_jump_buffer(delta)
	_apply_gravity(delta)
	_process_state(current_state)
	move_and_slide()
	_update_visuals()
	
	
func _apply_gravity(delta: float) -> void:
	#Only apply airborne
	if not is_on_floor():
		if is_wall_sliding:
			velocity.y += GRVITY * FALL_MULTIPLIER * WALL_SLIDE_MULTIPLIER * delta
		else:
			velocity.y += GRVITY * FALL_MULTIPLIER * delta
		
func _update_facing(direction: float) -> void:
	if direction != 0.0:
		facing = 1.0 if direction > 0 else -1.0
	body_visual.scale.x = facing
	
func _process_state(delta: float) -> void:
	match current_state: 
		State.IDLE: _state_idle()
		State.WALK: _state_walk()
		State.JUMP: _state_jump()
		State.FALL: _state_fall(delta)
		State.LAND: _state_land(delta)
		State.HURT: _state_hurt(delta)
		State.DASH: _state_dash(delta)
		State.WLSL: _state_wlsl(delta)
		
#========================================================================
#                        STATES
#========================================================================
		
func _state_idle() -> void:
	velocity.x = move_toward(velocity.x, 0.0, SPEED)
	
	#Changing the state
	var direction: float = Input.get_axis("move_left", "move_right")
	if _consume_jump_buffer():
		_change_state(State.JUMP)
	elif direction != 0:
		_change_state(State.WALK)
	elif Input.is_action_just_pressed("dash"):
		_change_state(State.DASH)
	elif not is_on_floor():
		_change_state(State.FALL)
		
	
func _state_walk() -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED
	
	#FLip the sprite
	_update_facing(direction)
	
	 #Changing the state
	if _consume_jump_buffer():
		_change_state(State.JUMP)
	elif direction == 0.0:
		_change_state(State.IDLE)
	elif Input.is_action_just_pressed("dash"):
		_change_state(State.DASH)
	elif not is_on_floor():
		_change_state(State.FALL)
		
		
func _state_jump() -> void:
	is_dash_jump = false
	velocity.y = JUMP_VELOCITY
	if previou_state == State.DASH:
		is_dash_jump = true
	_change_state(State.FALL)
	
func _state_fall(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	if _can_wall_state_fall():
		_change_state(State.WLSL)
		return
	if is_dash_jump:
		if direction != 0.0:
			velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * DASH_SLIDE_DECEL * delta)
		elif direction == 0.0:
			velocity.x = 0.0
		#elif direction != 0.0:
			#velocity.x = direction * SPEED
		elif is_on_wall():
			velocity.x = 0.0
			velocity.x = direction * SPEED
		#这个朝向判断注释里的是我的老版本，目前采用的是ai给的优化方式
		#elif direction != facing:
		elif signf(velocity.x) != signf(direction):
			velocity.x = -velocity.x
			
	else:
		velocity.x = direction * SPEED
	
	
	#FLip the sprite
	_update_facing(direction)
		
	if is_on_floor():
		is_dash_jump = false
		_change_state(State.LAND)
	
func _state_land(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, SPEED * 3)
	land_timer -= delta 
	is_wall_sliding = false
	
	if _consume_jump_buffer():
		_change_state(State.JUMP)
		return
	
	#Tansistions
	if land_timer <= 0.0:
		var direction: float = Input.get_axis("move_left", "move_right")
		if direction != 0.0:
			_change_state(State.WALK)
		elif direction == 0.0:
			_change_state(State.IDLE)

func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, SPEED * 3)
	hurt_timer -= delta
	
	#Tansistions
	if hurt_timer <= 0.0:
		global_position = RESPAWN_POS
		velocity = Vector2.ZERO
		_change_state(State.IDLE)

func _state_dash(delta: float) -> void:
	if dash_timer > 0.0:
		velocity.x = last_direction * DASH_SPEED
		dash_timer = maxf(dash_timer - delta, 0.0)
		if _consume_jump_buffer():
			_change_state(State.JUMP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DASH_SPEED * DASH_SLIDE_DECEL * delta)
		var direction: float = Input.get_axis("move_left", "move_right")
		if _consume_jump_buffer():
			_change_state(State.JUMP)
		elif abs(velocity.x) <= 50 and direction == 0.0:
			_change_state(State.IDLE)
		elif abs(velocity.x) <= 250 and direction != 0.0:
			_change_state(State.WALK)
	
	
func _state_wlsl(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	is_wall_sliding = true
	if velocity.y < 0.0:
		velocity.y = move_toward(velocity.y, 0.0, JUMP_DECLE * delta)
	
	if Input.is_action_just_pressed("jump") and is_wall_sliding:
		velocity.x = get_wall_normal().x * WALL_JUMP_PUSH
		is_wall_sliding = false
		_change_state(State.JUMP)
		return
	if not is_on_wall() or direction == 0.0:
		is_wall_sliding = false
		_change_state(State.FALL)
		
	if is_on_floor():
		is_wall_sliding = false
		_change_state(State.IDLE)

#========================================================================
#                       MISC
#========================================================================



func _can_wall_state_fall() -> bool:
	var direction: float = Input.get_axis("move_left", "move_right")
	if is_on_wall() and not is_on_floor() and direction != 0.0 and direction * get_wall_normal().x < 0.0:
		return(true)
	else:
		return(false)


func _update_jump_buffer(delta: float) -> void:
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
		
func _consume_jump_buffer() -> bool:
	if jump_buffer_timer > 0.0 and is_on_floor():
		jump_buffer_timer = 0.0
		return	true
	return false


func _change_state(new_state: State) -> void:
	#Don't re-enter the same stete
	if new_state == current_state:
		return
	previou_state = current_state
	#Entry ACtions
	match new_state:
		State.LAND:
			land_timer = LAND_DURATION
	match new_state:
		State.HURT:
			hurt_timer = HURT_DURATION	
	match new_state:
		State.DASH:
			dash_timer = DASH_DURATION
			last_direction = facing
			
	current_state = new_state 		
 

func _update_visuals() -> void:
	body_visual.color = STATE_COLORS[current_state]
	state_lable.text = State.keys()[current_state]


func _on_spike_body_entered(body: Node2D) -> void:
	if current_state != State.HURT:
		_change_state(State.HURT)
