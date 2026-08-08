# 04 冲刺状态

本章先实现“仅地面冲刺”。等地面版本稳定后，再考虑空中冲刺次数和冷却。

## 1. 增加状态和参数

在枚举中加入：

```gdscript
DASH,
```

新增：

```gdscript
@export_category("Dash")
@export var dash_speed: float = 650.0
@export var dash_duration: float = 0.12

var dash_timer: float = 0.0
var dash_direction: float = 1.0
var facing: float = 1.0
```

冲刺距离可以近似计算：

```text
冲刺距离 = dash_speed × dash_duration
650 × 0.12 = 78 像素
```

## 2. 记录朝向

修改朝向函数：

```gdscript
func _update_facing(direction: float) -> void:
	if is_zero_approx(direction):
		return

	if current_state == State.DASH:
		return

	facing = signf(direction)
	animated_sprite_2d.flip_h = facing < 0.0
```

冲刺期间不允许输入改变视觉朝向，避免图像朝左但角色仍向右冲刺。

## 3. 创建冲刺请求函数

```gdscript
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
```

无方向输入时沿角色当前朝向冲刺；有方向输入时沿输入方向冲刺。

## 4. 在地面状态中尝试冲刺

`IDLE` 和 `RUN` 中，在跳跃判断之后加入：

```gdscript
if _try_start_jump():
	return

if _try_start_dash(direction):
	return
```

这里明确规定了动作优先级：同一帧同时按跳跃和冲刺时，跳跃优先。

## 5. 进入 DASH 时初始化

在 `_enter_state()` 中加入：

```gdscript
State.DASH:
	dash_timer = dash_duration
	velocity = Vector2(dash_direction * dash_speed, 0.0)
	animated_sprite_2d.play("run")
```

计时器和冲刺初速度只在进入状态时设置一次。

## 6. 编写 DASH 的持续行为

在 `_process_state()` 中分发：

```gdscript
State.DASH:
	_state_dash(direction, delta)
```

状态函数：

```gdscript
func _state_dash(direction: float, delta: float) -> void:
	velocity.x = dash_direction * dash_speed
	velocity.y = 0.0
	dash_timer = maxf(dash_timer - delta, 0.0)

	if dash_timer > 0.0:
		return

	if not is_on_floor():
		_change_state(State.FALL)
	elif is_zero_approx(direction):
		_change_state(State.IDLE)
	else:
		_change_state(State.RUN)
```

## 7. 冲刺期间暂停重力

修改重力函数开头：

```gdscript
func _apply_gravity(delta: float) -> void:
	if current_state == State.DASH:
		return

	if is_on_floor():
		return

	# 后面保持原有重力代码
```

虽然当前冲刺只允许从地面开始，但角色可能冲出平台边缘。暂停重力能够让这段冲刺保持水平。

## 8. 为什么先不做“冲刺滑行”

冲刺滑行还需要定义：

- 冲刺结束后多久停下。
- 玩家反向输入时如何减速。
- 冲出平台后是否保留惯性。
- 滑行阶段属于 `DASH` 还是普通移动。

先让固定时长冲刺稳定，再新增这些设计。否则多个手感参数会互相影响，难以判断错误来自哪里。

## 本章测试目标

- 站立不输入方向时，沿当前朝向冲刺。
- 按住反方向冲刺时，立即沿新方向冲刺。
- 冲刺持续时间与帧率无关。
- 冲刺结束后正确回到 `IDLE`、`RUN` 或 `FALL`。
- 空中按冲刺暂时没有效果，这是本章的预期设计。

