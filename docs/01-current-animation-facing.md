# 01 当前检查点、动画与朝向

本章目标：确认基础状态正确，为每个状态集中播放动画，并让角色面向移动方向。

## 1. 当前必须正确的重力公式

重力必须在原有速度上累加：

```gdscript
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(
			velocity.y + gravity * delta,
			max_fall_speed
		)
```

不能写成：

```gdscript
# 错误：每一帧都把速度重置为大约 16
velocity.y = minf(gravity * delta, max_fall_speed)
```

以 60 FPS 为例，正确的下落速度大致会是 `16、32、49、65……`，直到达到 `max_fall_speed`。

## 2. 检查同一状态函数中的判断顺序

一组互斥的状态切换应该使用 `if / elif / elif`：

```gdscript
if Input.is_action_just_pressed("jump") and is_on_floor():
	_change_state(State.JUMP)
elif not is_on_floor():
	_change_state(State.FALL)
elif not is_zero_approx(direction):
	_change_state(State.RUN)
```

如果最后一个条件重新使用 `if`，同一物理帧可能先进入 `JUMP`，随后又进入 `RUN`。

需要提前结束函数时，也可以使用 `return`：

```gdscript
if Input.is_action_just_pressed("jump") and is_on_floor():
	_change_state(State.JUMP)
	return
```

## 3. 正确切割当前动画素材

项目里的素材尺寸如下：

| 素材 | 图片尺寸 | 横向帧数 | 单帧尺寸 |
|---|---:|---:|---:|
| `Lancer_Idle.png` | 3840×320 | 12 | 320×320 |
| `Lancer_Run.png` | 1920×320 | 6 | 320×320 |

在 `AnimatedSprite2D` 的 SpriteFrames 面板中：

1. 创建或选择 `idle` 动画。
2. 删除错误或重复的旧帧。
3. 选择“从精灵表添加帧”。
4. Horizontal 设为 `12`，Vertical 设为 `1`。
5. 添加全部帧，速度可先设为 5 FPS。
6. 创建 `run` 动画。
7. `Lancer_Run.png` 设置 Horizontal 为 `6`，Vertical 为 `1`。
8. 添加全部帧，速度可先设为 8 FPS。

如果切帧宽度不是 320，角色图像会在固定碰撞体内左右漂移。要区分：

- `Player.global_position` 变化：角色物理节点真的移动。
- `Player.global_position` 不变、图像在晃：动画帧的切割或素材对齐问题。

## 4. 为什么动画适合放在状态入口

动画通常只需要在进入状态时选择一次：

```gdscript
func _enter_state(new_state: State) -> void:
	match new_state:
		State.IDLE:
			animated_sprite_2d.play("idle")
		State.RUN:
			animated_sprite_2d.play("run")
		State.JUMP, State.FALL:
			animated_sprite_2d.play("idle")
```

当前没有专门的跳跃和下落素材，所以暂时复用 `idle`。以后有素材时再替换。

先加入 `_ready()`，让初始状态也执行一次进入动作：

```gdscript
func _ready() -> void:
	_enter_state(current_state)
```

将状态切换函数整理为：

```gdscript
func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return

	current_state = new_state
	_enter_state(current_state)

	print("State changed to: ", State.keys()[current_state])
```

进入状态的函数：

```gdscript
func _enter_state(new_state: State) -> void:
	match new_state:
		State.IDLE:
			animated_sprite_2d.play("idle")

		State.RUN:
			animated_sprite_2d.play("run")

		State.JUMP:
			velocity.y = jump_velocity
			animated_sprite_2d.play("idle")

		State.FALL:
			animated_sprite_2d.play("idle")
```

完成后，可以删除 `_state_idle()` 中每帧执行的：

```gdscript
animated_sprite_2d.play("idle")
```

## 5. 添加朝向翻转

创建函数：

```gdscript
func _update_facing(direction: float) -> void:
	if is_zero_approx(direction):
		return

	animated_sprite_2d.flip_h = direction < 0.0
```

在 `_physics_process()` 中调用：

```gdscript
func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")

	_apply_gravity(delta)
	_process_state(direction, delta)
	_update_facing(direction)

	move_and_slide()
```

`flip_h` 只翻转图像，不会翻转碰撞体，因此碰撞形状保持稳定。

如果素材默认朝左，应反转判断：

```gdscript
animated_sprite_2d.flip_h = direction > 0.0
```

## 本章测试目标

- `idle` 只有 12 帧，`run` 只有 6 帧。
- 待机动画不再出现明显横向漂移。
- `IDLE` 播放 `idle`，`RUN` 播放 `run`。
- 按左右键时图像朝向正确。
- 翻转图像时碰撞体不移动。
- 跳跃状态不会在同一帧被 `RUN` 或 `IDLE` 覆盖。

