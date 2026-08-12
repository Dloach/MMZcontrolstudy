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
@export var knock_back_deceleration:= 3200.0
@export_range(1.0, 3.0, 0.1) var idle_min_duration: float = 1.0
@export_range(2.0, 5.0, 0.1) var idle_max_duration: float = 3.0
@export_range(2.1, 5.0, 0.1) var patrol_min_duration: float = 3.5
@export_range(5.1, 8.0, 0.1) var patrol_max_duration: float = 6.5
@export var patrol_speed:= 80.0
@export var patrol_acceleration:= 80

@onready var player_collision: CollisionShape2D = $"../Player/CollisionShape2D"
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var Player_collision: CollisionShape2D = $"../Player/CollisionShape2D"


var current_state = State.IDLE
var idle_timer:= 0.0
var patrol_timer:= 0.0
var facing:= 1.0


func _ready() -> void:
	_enter_state(State.IDLE) 


func _physics_process(delta: float) -> void:
	#配置重力
	_apply_gravity(delta)	
	_process_state(delta)
	_update_timer(delta)
	move_and_slide()
	#print("idle_timer: ", idle_timer)
	#print("patrol_timer: ", patrol_timer)
	
func _process_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle()
		State.PATROL:
			_state_patrol(delta)
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
			velocity.x = 0.0
			_play_animation(&"idle")
			idle_timer = randf_range(idle_min_duration, idle_max_duration)
		State.PATROL:
			_revers_facing()
			_play_animation(&"patrol")
			patrol_timer = randf_range(patrol_min_duration, patrol_max_duration)
		State.HURT:
			_play_animation(&"hurt")
	
func _exit_state(old_state: State, new_state: State) -> void:
	pass
	
func _revers_facing() -> void:
	facing *= -1
	_update_facing()
	
func _update_facing() -> void:
	animated_sprite_2d.flip_h = facing < 0.0
	
	
func _update_timer(delta: float) -> void:
	match current_state:
		State.IDLE:
			idle_timer = maxf(idle_timer - delta, 0.0)
		State.PATROL:
			patrol_timer = maxf(patrol_timer- delta, 0.0)
		
func take_damage(amount: int, knock_back_direction: float, knock_back_speed: Vector2) -> void:	
	velocity = Vector2.ZERO
	velocity.x = knock_back_direction * knock_back_speed[0]
	velocity.y = -1 * absf(knock_back_speed[1])
	_change_state(State.HURT)
	
func _play_animation(animation_name: StringName) -> void:
	animated_sprite_2d.play(animation_name)
	
	
func _apply_partol(delta: float) -> void:
	print("facing: ", facing)
	print("scale.x: ", scale.x)
	velocity.x = move_toward(velocity.x, patrol_speed * facing, patrol_acceleration * delta)
	



func _state_idle() -> void:
	if idle_timer <= 0.0:
		_change_state(State.PATROL)
		return
	
func _state_patrol(delta: float) -> void:
	if patrol_timer > 0.0:		
		_apply_partol(delta)
		return
	else:	
		_change_state(State.IDLE)
	return
func _state_chase(delta: float) -> void:
	pass
	
func _state_attack_melee(delta: float) -> void:
	pass
	
func _state_attack_ranged(delta: float) -> void:
	pass
	
func _state_hurt(delta: float) -> void:	
	var player_direction = signf(player_collision.global_position.x - global_position.x)
	facing = player_direction
	_update_facing()
	velocity.x = move_toward(velocity.x, 0.0, knock_back_deceleration* 0.5 * delta)
	if not animated_sprite_2d.is_playing():
		_change_state(State.IDLE)
	
func _state_die(delta: float) -> void:
	pass


func _on_contact_damage_body_entered(body: Node2D) -> void:
	if body.has_method("take_contact_damage"):
		body.take_contact_damage(global_position)
