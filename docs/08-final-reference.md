# 08 最终参考脚本

这份脚本用于完成各章后的对照和排错，不建议现在直接替换当前脚本。按章节自己实现，才能理解每个变量和状态存在的原因。

使用前提：

- Player 是 `CharacterBody2D`。
- 子节点名为 `AnimatedSprite2D`。
- Input Map 中存在 `move_left`、`move_right`、`jump`、`dash`。
- SpriteFrames 至少存在 `idle` 和 `run` 动画。
- 墙壁和地面拥有正确的碰撞形状。

```gdscript
extends CharacterBody2D


enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	DASH,
	WALL_SLIDE,
	HURT,
}


@export_category("Movement")
@export var move_speed: float = 300.0
@export var ground_acceleration: float = 1800.0
@export var ground_deceleration: float = 2200.0
@export var air_acceleration: float = 900.0
@export var air_deceleration: float = 300.0

@export_category("Jump")
@export var jump_velocity: float = -500.0
@export var gravity: float = 980.0
@export var fall_gravity_multiplier: float = 1.5
@export var jump_cut_multiplier: float = 0.5
@export var max_fall_speed: float = 900.0

@export_category("Jump Assistance")
@export var jump_buffer_time: float = 0.12
@export var coyote_time: float = 0.12

@export_category("Dash")
@export var dash_speed: float = 650.0
@export var dash_duration: float = 0.12

@export_category("Wall")
@export var wall_slide_speed: float = 140.0
@export var wall_slide_acceleration: float = 4000.0
@export var wall_jump_push: float = 450.0

@export_category("Hurt")
@export var hurt_duration: float = 0.6
@export var respawn_position: Vector2 = Vector2(262.0, 370.0)


@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


var current_state: State = State.FALL
var previous_state: State = State.FALL

var facing: float = 1.0
var dash_direction: float = 1.0

var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
var dash_timer: float = 0.0
var hurt_timer: float = 0.0


func _ready() -> void:
	_enter_state(current_state)


func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")

	_update_jump_timers(delta)
	_apply_gravity(delta)
	_process_state(direction, delta)
	_update_facing(direction)

	move_and_slide()


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
		State.WALL_SLIDE:
			_state_wall_slide(direction, delta)
		State.HURT:
			_state_hurt(delta)


# ============================================================================
# STATES
# ============================================================================


func _state_idle(direction: float, delta: float) -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		ground_deceleration * delta
	)

	if _try_start_jump():
		return

	if _try_start_dash(direction):
		return

	if not is_on_floor():
		_change_state(State.FALL)
	elif not is_zero_approx(direction):
		_change_state(State.RUN)


func _state_run(direction: float, delta: float) -> void:
	var target_speed: float = direction * move_speed

	velocity.x = move_toward(
		velocity.x,
		target_speed,
		ground_acceleration * delta
	)

	if _try_start_jump():
		return

	if _try_start_dash(direction):
		return

	if not is_on_floor():
		_change_state(State.FALL)
	elif is_zero_approx(direction):
		_change_state(State.IDLE)


func _state_jump(direction: float, delta: float) -> void:
	_apply_air_movement(direction, delta)

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	if velocity.y >= 0.0:
		_change_state(State.FALL)


func _state_fall(direction: float, delta: float) -> void:
	_apply_air_movement(direction, delta)

	if _try_start_jump():
		return

	if is_on_floor():
		_transition_to_ground_state(direction)
		return

	if _can_wall_slide(direction):
		_change_state(State.WALL_SLIDE)


func _state_dash(direction: float, delta: float) -> void:
	velocity.x = dash_direction * dash_speed
	velocity.y = 0.0
	dash_timer = maxf(dash_timer - delta, 0.0)

	if dash_timer > 0.0:
		return

	if not is_on_floor():
		_change_state(State.FALL)
	else:
		_transition_to_ground_state(direction)


func _state_wall_slide(direction: float, delta: float) -> void:
	if is_on_floor():
		_transition_to_ground_state(direction)
		return

	if jump_buffer_timer > 0.0:
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		velocity.x = get_wall_normal().x * wall_jump_push
		_change_state(State.JUMP)
		return

	if not _can_wall_slide(direction):
		_change_state(State.FALL)
		return

	velocity.y = move_toward(
		velocity.y,
		wall_slide_speed,
		wall_slide_acceleration * delta
	)


func _state_hurt(delta: float) -> void:
	hurt_timer = maxf(hurt_timer - delta, 0.0)

	if hurt_timer > 0.0:
		return

	global_position = respawn_position
	velocity = Vector2.ZERO
	_change_state(State.FALL)


# ============================================================================
# MOVEMENT HELPERS
# ============================================================================


func _apply_gravity(delta: float) -> void:
	if current_state == State.DASH or current_state == State.HURT:
		return

	if is_on_floor():
		return

	var gravity_multiplier: float = 1.0

	if velocity.y > 0.0:
		gravity_multiplier = fall_gravity_multiplier

	velocity.y = minf(
		velocity.y + gravity * gravity_multiplier * delta,
		max_fall_speed
	)


func _apply_air_movement(direction: float, delta: float) -> void:
	var target_speed: float = direction * move_speed
	var acceleration: float = air_acceleration

	if is_zero_approx(direction):
		acceleration = air_deceleration

	velocity.x = move_toward(
		velocity.x,
		target_speed,
		acceleration * delta
	)


func _update_facing(direction: float) -> void:
	if is_zero_approx(direction):
		return

	if current_state == State.DASH or current_state == State.HURT:
		return

	facing = signf(direction)
	animated_sprite_2d.flip_h = facing < 0.0


# ============================================================================
# ACTION WINDOWS AND CONDITIONS
# ============================================================================


func _update_jump_timers(delta: float) -> void:
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)


func _try_start_jump() -> bool:
	if jump_buffer_timer <= 0.0:
		return false

	if not is_on_floor() and coyote_timer <= 0.0:
		return false

	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	_change_state(State.JUMP)
	return true


func _try_start_dash(direction: float) -> bool:
	if not Input.is_action_just_pressed("dash"):
		return false

	if not is_on_floor():
		return false

	if is_zero_approx(direction):
		dash_direction = facing
	else:
		dash_direction = signf(direction)

	_change_state(State.DASH)
	return true


func _can_wall_slide(direction: float) -> bool:
	if is_on_floor():
		return false

	if not is_on_wall():
		return false

	if is_zero_approx(direction):
		return false

	return direction * get_wall_normal().x < 0.0


func _transition_to_ground_state(direction: float) -> void:
	if is_zero_approx(direction):
		_change_state(State.IDLE)
	else:
		_change_state(State.RUN)


# ============================================================================
# STATE TRANSITIONS AND PRESENTATION
# ============================================================================


func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return

	previous_state = current_state
	current_state = new_state
	_enter_state(current_state)

	print(
		State.keys()[previous_state],
		" -> ",
		State.keys()[current_state]
	)


func _enter_state(new_state: State) -> void:
	match new_state:
		State.IDLE:
			_play_animation(&"idle")

		State.RUN:
			_play_animation(&"run")

		State.JUMP:
			velocity.y = jump_velocity
			_play_animation(&"idle")

		State.FALL:
			_play_animation(&"idle")

		State.DASH:
			dash_timer = dash_duration
			velocity = Vector2(dash_direction * dash_speed, 0.0)
			_play_animation(&"run")

		State.WALL_SLIDE:
			_play_animation(&"idle")

		State.HURT:
			hurt_timer = hurt_duration
			velocity = Vector2.ZERO
			_play_animation(&"idle")


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite_2d.sprite_frames.has_animation(animation_name):
		animated_sprite_2d.play(animation_name)


func _on_spike_body_entered(body: Node2D) -> void:
	if body != self:
		return

	if current_state != State.HURT:
		_change_state(State.HURT)
```

## 阅读这份脚本时的检查问题

不要只看代码能否运行，尝试回答：

1. 为什么 `_update_jump_timers()` 必须每帧调用？
2. 为什么 `_try_start_jump()` 返回 `bool`？
3. 为什么成功开始跳跃或冲刺后要 `return`？
4. 为什么跳跃初速度放在 `_enter_state()`？
5. 为什么目标速度不乘 `delta`，加速度却要乘？
6. 为什么墙跳需要清空跳跃缓冲？
7. 为什么尖刺回调仍然判断 `body == self`？
8. 为什么重生后进入 `FALL`，而不是直接进入 `IDLE`？

能够用自己的话回答这些问题，说明你已经理解了这套状态机的主体，而不是只完成了代码复制。

## 后续可以继续研究的方向

基础版本稳定后，再选择一个方向继续：

- 独立 Player 场景与脚本。
- 状态退出函数 `_exit_state()`。
- 动画结束信号驱动攻击或落地状态。
- 攻击状态与受击无敌时间。
- 空中冲刺次数和冲刺冷却。
- 墙跳后的短暂方向控制锁定。
- 将每个状态拆为独立脚本的节点式状态机。

当前角色规模不需要立刻把每个状态拆成独立文件。单脚本状态机更适合学习和调试；当状态数量、共享逻辑和角色种类明显增加时，再考虑节点式状态机。
