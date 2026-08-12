extends CharacterBody2D
enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK_MELEE,
	ATTACK_RANGED,
	HURT,
	DIE,
}


@export var gravity:= 980.0
@export var knock_back_deceleration:= 500.0
@export_range(1.0, 3.0, 0.1) var idle_min_duration: float = 1.0
@export_range(2.0, 5.0, 0.1) var idle_max_duration: float = 3.0
@export_range(2.1, 5.0, 0.1) var patrol_min_duration: float = 3.5
@export_range(5.1, 8.0, 0.1) var patrol_max_duration: float = 6.5
@export var patrol_speed:= 180.0

@onready var player_collision: CollisionShape2D = $"../Player/CollisionShape2D"
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var dummy: CharacterBody2D = $"."


var current_state = State.IDLE
var idle_timer:= 0.0
var patrol_timer:= 0.0



func _ready() -> void:
	_enter_state(State.IDLE)
	idle_timer = 2.0
	patrol_timer= 4.5


func _physics_process(delta: float) -> void:
	var direction = signf(dummy.scale.x)
	#配置重力
	_apply_gravity(delta)	
	velocity.x = move_toward(velocity.x, 0.0, knock_back_deceleration * delta)
	_process_state(direction, delta)
	_update_timer(delta)
	move_and_slide()
	print("idle_timer: ", idle_timer)
	print("patrol_timer: ", patrol_timer)
	
func _process_state(direction: float, delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle(direction, delta)
		State.PATROL:
			_state_patrol(direction,delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK_MELEE:
			_state_attack_melee(delta)
		State.ATTACK_RANGED:
			_state_attack_ranged(delta)
		State.HURT:
			_state_hurt(delta)
		State.DIE:
			_state_die(delta)
	
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		
func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return
	var old_state = current_state
	_exit_state(old_state, new_state)
	current_state = new_state
	_enter_state(current_state)
	print("state changed to: ", State.keys()[current_state])

func _enter_state(new_state: State) -> void:
	match new_state:
		State.IDLE:
			_play_animation(&"idle")
			idle_timer = randf_range(idle_min_duration, idle_max_duration)
		State.PATROL:
			_play_animation(&"patrol")
			patrol_timer = randf_range(patrol_min_duration, patrol_max_duration)
	
func _exit_state(old_state: State, new_state: State) -> void:
	pass	
	
func _update_facing(direction: float) -> void:
	dummy.scale.x = -dummy.scale.x
	
	
	
func _update_timer(delta: float) -> void:
	match current_state:
		State.IDLE:
			idle_timer = maxf(idle_timer - delta, 0.0)
		State.PATROL:
			patrol_timer = maxf(patrol_timer- delta, 0.0)
		
func take_damage(amount: int, knock_back_direction: float, knock_back_speed: float) -> void:	
	velocity.x = knock_back_direction * knock_back_speed
	velocity.y = -0.5 * absf(knock_back_speed)
	
func _play_animation(animation_name: StringName) -> void:
	animated_sprite_2d.play(animation_name)
	
	
func _apply_partol(direction: float,delta: float) -> void:
	velocity.x = patrol_speed * direction * delta
	



func _state_idle(direction: float,delta: float) -> void:
	if idle_timer <= 0.0:
		_change_state(State.PATROL)
	
	
func _state_patrol(direction: float,delta: float) -> void:
	if patrol_timer > 0.0:
		_apply_partol(direction, delta)
	else:
	
		_change_state(State.IDLE)
		
func _state_chase(delta: float) -> void:
	pass
	
func _state_attack_melee(delta: float) -> void:
	pass
	
func _state_attack_ranged(delta: float) -> void:
	pass
	
func _state_hurt(delta: float) -> void:
	pass
	
func _state_die(delta: float) -> void:
	pass
