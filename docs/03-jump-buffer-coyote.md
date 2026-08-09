# 03 跳跃缓冲与土狼时间

本章目标：让玩家稍早按跳跃或稍晚按跳跃时，角色仍然能够响应。

## 1. 两个时间窗口

跳跃缓冲（Jump Buffer）：

> 玩家落地前稍早按下跳跃，系统暂存这次输入，落地后立即起跳。

土狼时间（Coyote Time）：

> 玩家刚离开平台边缘的一小段时间内，仍允许起跳。

新增参数和计时器：

```gdscript
@export_category("Jump Assistance")
@export var jump_buffer_time: float = 0.12
@export var coyote_time: float = 0.12

var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
```

## 2. 每帧更新时间窗口

```gdscript
func _update_jump_timers(delta: float) -> void:
    jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

    if Input.is_action_just_pressed("jump"):
        jump_buffer_timer = jump_buffer_time

    if is_on_floor():
        coyote_timer = coyote_time
    else:
        coyote_timer = maxf(coyote_timer - delta, 0.0)
```

在 `_physics_process()` 最前面调用：

```gdscript
func _physics_process(delta: float) -> void:
    var direction: float = Input.get_axis("move_left", "move_right")

    _update_jump_timers(delta)
    _apply_gravity(delta)
    _process_state(direction, delta)
    _update_facing(direction)

    move_and_slide()
```

## 3. 集中判断并消费跳跃

创建函数：

```gdscript
func _try_start_jump() -> bool:
    if jump_buffer_timer <= 0.0:
        return false

    var can_ground_jump: bool = is_on_floor() or coyote_timer > 0.0

    if not can_ground_jump:
        return false

    jump_buffer_timer = 0.0
    coyote_timer = 0.0
    _change_state(State.JUMP)
    return true
```

“消费”表示一次输入成功使用后必须清零，否则同一次按键可能再次触发跳跃。

## 4. 修改地面状态

`IDLE`：

```gdscript
func _state_idle(direction: float, delta: float) -> void:
    velocity.x = move_toward(
        velocity.x,
        0.0,
        ground_deceleration * delta
    )

    if _try_start_jump():
        return

    if not is_on_floor():
        _change_state(State.FALL)
    elif not is_zero_approx(direction):
        _change_state(State.RUN)
```

`RUN`：

```gdscript
func _state_run(direction: float, delta: float) -> void:
    var target_speed: float = direction * move_speed

    velocity.x = move_toward(
        velocity.x,
        target_speed,
        ground_acceleration * delta
    )

    if _try_start_jump():
        return

    if not is_on_floor():
        _change_state(State.FALL)
    elif is_zero_approx(direction):
        _change_state(State.IDLE)
```

## 5. FALL 必须尝试消费跳跃

土狼时间和落地前输入都发生在空中，所以 `FALL` 必须调用 `_try_start_jump()`：

```gdscript
func _state_fall(direction: float, delta: float) -> void:
    _apply_air_movement(direction, delta)

    if _try_start_jump():
        return

    if is_on_floor():
        if is_zero_approx(direction):
            _change_state(State.IDLE)
        else:
            _change_state(State.RUN)
```

如果只在 `IDLE` 和 `RUN` 中判断跳跃，土狼时间不会生效。

## 6. 为什么这里使用计时器而不是布尔值

布尔值只能表达“可以或不可以”：

```gdscript
var can_jump := true
```

计时器能够表达“还可以持续多少秒”：

```gdscript
coyote_timer = maxf(coyote_timer - delta, 0.0)
```

这样窗口与帧率无关，也可以直接在 Inspector 中调整时间。

## 本章测试目标

- 离开平台边缘约 0.12 秒内按跳跃仍能起跳。
- 落地前约 0.12 秒按跳跃，落地后立即再次起跳。
- 一次按键只触发一次跳跃。
- 站在地面长按跳跃不会自动连续起跳。
- 将两个时间参数临时改成 `0.5` 时效果明显，改回 `0.12` 后自然。
