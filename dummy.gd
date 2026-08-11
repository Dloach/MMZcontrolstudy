extends CharacterBody2D

@export var gravity:= 980.0
@export var knock_back_deceleration:= 500.0
#@export var knock_back_speed:= 0.0

@onready var player_collision: CollisionShape2D = $"../Player/CollisionShape2D"


func _ready() -> void:
	set_meta("take_damage", true)


func _physics_process(delta: float) -> void:
	#配置重力
	_apply_gravity(delta)	
	velocity.x = move_toward(velocity.x, 0.0, knock_back_deceleration * delta)
	move_and_slide()
	

func take_damage(amount: int, knock_back_direction: float, knock_back_speed: float) -> void:	
	velocity.x = knock_back_direction * knock_back_speed
	velocity.y = -0.5 * absf(knock_back_speed)
	
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
