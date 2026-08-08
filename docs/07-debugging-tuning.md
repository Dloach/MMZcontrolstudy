# 07 调参和排错手册

## 1. 推荐调参顺序

不要同时调整全部参数。按下面顺序：

1. 地面最高速度 `move_speed`。
2. 达到最高速度所需时间，即 `ground_acceleration`。
3. 松手停止时间，即 `ground_deceleration`。
4. 跳跃最高点和上升时间。
5. 下落速度。
6. 空中转向能力。
7. 跳跃缓冲与土狼时间。
8. 冲刺距离和持续时间。
9. 墙滑与墙跳。

后面的机制依赖前面的基础手感。

## 2. 用目标时间计算加速度

从静止加速到 300 px/s，希望用时 0.15 秒：

```text
加速度 = 速度变化 ÷ 时间
       = 300 ÷ 0.15
       = 2000 px/s²
```

因此：

```gdscript
@export var ground_acceleration: float = 2000.0
```

从 300 px/s 停止，希望用时 0.1 秒：

```text
减速度 = 300 ÷ 0.1 = 3000 px/s²
```

这种方法比不断猜 `0.008` 一类的小数更可靠。

## 3. 常见 `delta` 错误

### 把状态编号传给需要 delta 的函数

```gdscript
# 错误
_process_state(current_state)

# 正确
_process_state(delta)
```

### 重置速度而不是累加重力

```gdscript
# 错误
velocity.y = gravity * delta

# 正确
velocity.y += gravity * delta
```

### 给目标速度乘 delta

```gdscript
# 错误
var target_speed := direction * move_speed * delta

# 正确
var target_speed := direction * move_speed
```

### 给减速度重复乘速度

如果 `dash_deceleration` 已经表示 px/s²：

```gdscript
# 错误
DASH_SPEED * dash_deceleration * delta

# 正确
dash_deceleration * delta
```

## 4. 状态在同一帧被覆盖

错误示例：

```gdscript
if jump_pressed:
	_change_state(State.JUMP)

if direction != 0.0:
	_change_state(State.RUN)
```

同时移动和跳跃时会先进入 `JUMP`，随后进入 `RUN`。

解决方法：

- 使用 `elif` 表达互斥优先级。
- 成功切换后立即 `return`。

```gdscript
if _try_start_jump():
	return

if _try_start_dash(direction):
	return
```

## 5. 状态进入行为被每帧执行

如果在 `_state_jump()` 中每帧设置：

```gdscript
velocity.y = jump_velocity
```

角色可能一直向上飞。跳跃冲量、计时器初始化和一次性动画选择应该放在 `_enter_state()`。

## 6. 动画漂移排查

先打印或观察 Player 的位置：

```gdscript
print(global_position)
```

- 位置变化：检查 `velocity`、根运动或碰撞。
- 位置不变但图像变化：检查 Sprite Sheet 切帧宽度、各帧人物站位和 AnimatedSprite2D 的 offset。

当前 Lancer 素材每帧固定为 `320×320`：

- Idle：12 帧。
- Run：6 帧。

不要将同一批帧重复添加到一个动画中。

## 7. 检查状态流

只在状态真正变化时打印：

```gdscript
func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return

	var old_state := current_state
	current_state = new_state

	print(
		State.keys()[old_state],
		" -> ",
		State.keys()[current_state]
	)
```

正常跳跃应该类似：

```text
IDLE -> JUMP
JUMP -> FALL
FALL -> IDLE
```

同一帧看到：

```text
IDLE -> JUMP
JUMP -> RUN
```

说明互斥条件或 `return` 有问题。

## 8. 检查碰撞查询时机

`is_on_floor()` 和 `is_on_wall()` 表示最近一次 `move_and_slide()` 的碰撞结果。当前结构在状态处理后才调用 `move_and_slide()`，所以落地状态变化可能比真正接触地面晚一个物理帧。

对基础角色控制通常可以接受。不要为了消除这一帧延迟立刻重构整个循环；先保证状态流正确。以后可以将“移动前逻辑”和“移动后碰撞状态解析”分开。

## 9. 每章完成后的回归测试

每增加一个功能，都重新检查：

- 静止、起步、转向、停止。
- 原地跳、移动跳、平台边缘跳。
- 轻点跳跃和长按跳跃。
- 提前按跳跃和离开平台后按跳跃。
- 冲刺结束时有无输入。
- 贴墙、松开墙壁、墙跳。
- 受伤时按住各种输入。
- 重生点是否安全。

## 10. 建议的本地版本节点

即使没有网络，Git 仍然可以在本地提交。建议完成每章后创建一次提交，例如：

```text
player: add animation and facing
player: improve jump feel
player: add jump buffer and coyote time
player: add ground dash
player: add wall slide and wall jump
player: add hurt and respawn
```

这样某章出现问题时，可以对照前一个稳定版本，而不必全面重置项目。

