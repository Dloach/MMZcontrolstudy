# 02 改善跳跃手感

本章目标：理解跳跃高度由什么决定，并加入“按住跳得高、松开跳得低”的可变跳跃。

## 1. 跳跃高度的三个主要参数

基础跳跃由以下参数决定：

```gdscript
@export var jump_velocity: float = -500.0
@export var gravity: float = 980.0
@export var max_fall_speed: float = 900.0
```

- `jump_velocity` 越负，起跳越快、越高。
- `gravity` 越大，上升时间越短、下落越快。
- `max_fall_speed` 只限制最终下落速度，不直接决定起跳高度。

忽略其他效果时，近似跳跃高度为：

```text
高度 ≈ jump_velocity² ÷ (2 × gravity)
```

`-500` 和 `980` 大约得到 128 像素的高度。不要为了修复公式错误把跳跃速度调成 `-1500`；公式正确后，它会跳到约 1148 像素。

## 2. 为下降阶段增加重力倍率

很多平台游戏上升稍慢、下降稍快。新增参数：

```gdscript
@export var fall_gravity_multiplier: float = 1.5
```

修改重力函数：

```gdscript
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	var gravity_multiplier: float = 1.0

	if velocity.y > 0.0:
		gravity_multiplier = fall_gravity_multiplier

	velocity.y = minf(
		velocity.y + gravity * gravity_multiplier * delta,
		max_fall_speed
	)
```

这里的判断：

```gdscript
velocity.y > 0.0
```

表示角色正在向下，因为 Godot 2D 的 Y 轴正方向向下。

## 3. 加入可变跳跃高度

新增：

```gdscript
@export var jump_cut_multiplier: float = 0.5
```

修改 `JUMP` 状态：

```gdscript
func _state_jump(direction: float, delta: float) -> void:
	_apply_air_movement(direction, delta)

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	if velocity.y >= 0.0:
		_change_state(State.FALL)
```

假设松开跳跃键时：

```text
velocity.y = -400
jump_cut_multiplier = 0.5
```

执行后变成 `-200`，剩余上升速度减少，因此角色更早到达最高点。

`jump_cut_multiplier` 的常见范围：

- `0.3`：轻点时跳得明显更低。
- `0.5`：较自然的起点。
- `0.8`：轻点和长按差异较小。

## 4. 空中控制的含义

当前空中移动：

```gdscript
func _apply_air_movement(direction: float, delta: float) -> void:
	var target_speed: float = direction * move_speed

	velocity.x = move_toward(
		velocity.x,
		target_speed,
		air_acceleration * delta
	)
```

`air_acceleration` 决定角色在空中改变水平速度的能力：

- 数值小：惯性强，空中难以转向。
- 数值大：空中控制灵活。
- 如果松开方向后不希望空中迅速停止，可为无输入单独使用较小的空气阻力。

可选写法：

```gdscript
@export var air_deceleration: float = 300.0

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
```

## 推荐起始参数

```gdscript
@export var jump_velocity: float = -500.0
@export var gravity: float = 980.0
@export var fall_gravity_multiplier: float = 1.5
@export var jump_cut_multiplier: float = 0.5
@export var max_fall_speed: float = 900.0
@export var air_acceleration: float = 900.0
```

## 本章测试目标

- 长按跳跃键比轻点跳得高。
- 上升阶段是 `JUMP`，Y 速度达到零后是 `FALL`。
- 下降速度明显但不过度突然。
- 从平台边缘走下去会进入 `FALL`。
- 改变游戏帧率时，跳跃高度基本一致。

