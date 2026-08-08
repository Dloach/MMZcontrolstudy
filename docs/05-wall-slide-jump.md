# 05 墙滑与墙跳

本章目标：角色在空中按向墙壁时进入 `WALL_SLIDE`，按跳跃后沿墙法线反方向弹开。

## 1. 增加状态与参数

枚举中加入：

```gdscript
WALL_SLIDE,
```

新增参数：

```gdscript
@export_category("Wall")
@export var wall_slide_speed: float = 140.0
@export var wall_slide_acceleration: float = 4000.0
@export var wall_jump_push: float = 450.0
```

## 2. 判断角色是否主动贴墙

```gdscript
func _can_wall_slide(direction: float) -> bool:
	if is_on_floor():
		return false

	if not is_on_wall():
		return false

	if is_zero_approx(direction):
		return false

	return direction * get_wall_normal().x < 0.0
```

`get_wall_normal()` 是墙面指向角色的法线：

- 角色右侧贴墙时，法线通常指向左，`x=-1`。
- 角色左侧贴墙时，法线通常指向右，`x=1`。

玩家必须按向墙壁才进入墙滑。例如右侧有墙：

```text
direction = 1
wall_normal.x = -1
1 × -1 < 0
```

条件成立。

## 3. 从 FALL 进入墙滑

修改 `FALL`：

```gdscript
func _state_fall(direction: float, delta: float) -> void:
	_apply_air_movement(direction, delta)

	if _try_start_jump():
		return

	if is_on_floor():
		_transition_to_ground_state(direction)
		return

	if _can_wall_slide(direction):
		_change_state(State.WALL_SLIDE)
```

将落地判断提取为：

```gdscript
func _transition_to_ground_state(direction: float) -> void:
	if is_zero_approx(direction):
		_change_state(State.IDLE)
	else:
		_change_state(State.RUN)
```

## 4. WALL_SLIDE 状态

在 `_process_state()` 中加入分发，然后创建：

```gdscript
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
```

墙跳使用已经存在的跳跃缓冲，因此玩家稍早按跳跃也能触发。

## 5. 为什么墙跳要清空跳跃缓冲

墙跳成功后：

```gdscript
jump_buffer_timer = 0.0
coyote_timer = 0.0
```

如果不清空，角色离开墙壁后，同一次按键可能继续留在缓冲时间内，随后又被地面跳跃逻辑消费。

## 6. 墙跳水平速度可能立即被空中控制抵消

墙跳后设置：

```gdscript
velocity.x = get_wall_normal().x * wall_jump_push
```

下一帧 `_apply_air_movement()` 会开始把速度拉向玩家输入方向。如果 `air_acceleration` 很高，玩家持续按向墙壁时，弹开效果会迅速消失。

基础版本可以先降低 `air_acceleration`。更进一步的版本可以增加一个短暂的 `wall_jump_control_lock_timer`，但在基础墙跳稳定前不要添加。

## 7. 动画与朝向

当前没有专门墙滑动画，可以暂时播放 `idle`。如果希望角色面对墙壁，可在进入墙滑时根据墙法线设置：

```gdscript
animated_sprite_2d.flip_h = get_wall_normal().x > 0.0
```

具体判断可能因为素材默认朝向而相反，以画面为准。

## 本章测试目标

- 角色只有在空中、接触墙面并按向墙壁时才墙滑。
- 松开方向键会退出墙滑并进入 `FALL`。
- 墙滑速度不会无限增加。
- 墙跳方向始终离开墙壁。
- 一次墙跳输入不会触发两次跳跃。
