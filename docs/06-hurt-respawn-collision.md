# 06 受伤、重生与碰撞层

本章目标：让尖刺只伤害 Player，进入 `HURT` 后等待一段时间，再重生到安全位置。

## 1. 先理解信号参数

如果尖刺的 `body_entered` 信号连接到 Player 脚本：

```gdscript
func _on_spike_body_entered(body: Node2D) -> void:
	pass
```

`body` 表示进入尖刺 Area2D 的物体，不保证一定是 Player。处理函数写在 Player 脚本里，也不代表 `body` 自动等于 Player。

最低限度必须判断：

```gdscript
func _on_spike_body_entered(body: Node2D) -> void:
	if body != self:
		return

	if current_state != State.HURT:
		_change_state(State.HURT)
```

## 2. 为什么尖刺可能在开局触发

如果尖刺 Area2D 的碰撞遮罩会检测地面，而尖刺碰撞形状又与地面接触，游戏初始化时可能发送：

```text
body_entered(Ground)
```

如果回调忽略 `body`，Player 就会在开局进入 `HURT`。

调试时可以打印：

```gdscript
print("Spike detected: ", body.name)
```

## 3. 推荐碰撞层规划

可以在 Project Settings 中为层命名：

| 层 | 名称 | 数值 |
|---|---|---:|
| 1 | World | 1 |
| 2 | Player | 2 |
| 3 | Hazard | 4 |

推荐设置：

- 地面：`collision_layer = World`。
- Player：`collision_layer = Player`，`collision_mask = World`。
- 尖刺 Area2D：`collision_layer = Hazard`，`collision_mask = Player`。

这样尖刺只监测 Player，不监测地面。即使已经正确设置层，回调中的 `body == self` 仍建议保留，形成第二层保护。

## 4. 增加 HURT 状态

枚举中加入：

```gdscript
HURT,
```

新增：

```gdscript
@export_category("Hurt")
@export var hurt_duration: float = 0.6
@export var respawn_position: Vector2 = Vector2(262.0, 370.0)

var hurt_timer: float = 0.0
```

## 5. 进入 HURT

在 `_enter_state()` 中加入：

```gdscript
State.HURT:
	hurt_timer = hurt_duration
	velocity = Vector2.ZERO
	animated_sprite_2d.play("idle")
```

重力函数中暂时冻结受伤角色：

```gdscript
if current_state == State.DASH or current_state == State.HURT:
	return
```

## 6. HURT 的持续行为

在状态分发中加入后，创建：

```gdscript
func _state_hurt(delta: float) -> void:
	hurt_timer = maxf(hurt_timer - delta, 0.0)

	if hurt_timer > 0.0:
		return

	global_position = respawn_position
	velocity = Vector2.ZERO
	_change_state(State.FALL)
```

重生后进入 `FALL`，因为重生位置未必刚好在地面上。下一次物理移动会让角色自然落地。

## 7. 受伤期间输入应该无效

`HURT` 状态函数不处理左右、跳跃和冲刺输入，因此输入自然被屏蔽。不要另外创建多个 `can_move`、`can_jump` 布尔值，否则状态和布尔值可能互相矛盾。

状态本身已经表达了控制权限：

```text
HURT → 不读取移动动作
```

## 本章测试目标

- 开局不会无故进入 `HURT`。
- 在尖刺回调中打印时，只出现 `Player`。
- 进入尖刺后状态变为 `HURT`。
- 受伤期间无法移动或跳跃。
- 经过 `hurt_duration` 后移动到 `respawn_position`。
- 重生位置不会与墙壁或地面碰撞体重叠。

