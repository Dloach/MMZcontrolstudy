# Godot 2D 角色状态机：离线学习路线

这套文档基于当前项目 `G:\Projects\260806` 编写，目标不是一次抄完一个大脚本，而是逐章理解并验证角色控制器。

当前已经完成的基础状态：

- `IDLE`：地面待机。
- `RUN`：地面移动。
- `JUMP`：上升阶段。
- `FALL`：下降阶段。
- 基础重力、地面加减速和空中移动。

## 推荐学习顺序

1. [01 当前检查点、动画与朝向](01-current-animation-facing.md)
2. [02 改善跳跃手感](02-jump-feel.md)
3. [03 跳跃缓冲与土狼时间](03-jump-buffer-coyote.md)
4. [04 冲刺状态](04-dash.md)
5. [05 墙滑与墙跳](05-wall-slide-jump.md)
6. [06 受伤、重生与碰撞层](06-hurt-respawn-collision.md)
7. [07 调参和排错手册](07-debugging-tuning.md)
8. [08 最终参考脚本](08-final-reference.md)

不要直接跳到最终参考脚本照抄。每完成一章，先达到该章的测试目标，再进入下一章。最终脚本用于对照、查漏和排错。

## 每章的学习方法

建议按下面的循环学习：

1. 先阅读这一章的“为什么”。
2. 自己输入代码，不要整段复制。
3. 每写完一个函数就运行一次项目。
4. 观察 Output 面板中的状态变化。
5. 达到测试目标后做一次 Git 提交或复制备份。
6. 再进入下一章。

如果出现错误，先记录三个信息：

- Output 面板中的完整报错。
- 报错指向的脚本行号。
- 出错前最后一次修改了什么。

## 必须长期遵守的物理单位

| 参数 | 含义 | 常用单位 | 是否乘 `delta` |
|---|---|---:|---|
| `move_speed` | 目标移动速度 | px/s | 否 |
| `jump_velocity` | 起跳瞬间速度 | px/s | 否 |
| `gravity` | 每秒增加的下落速度 | px/s² | 是 |
| `acceleration` | 每秒改变的水平速度 | px/s² | 是 |
| `duration` | 持续时间 | s | 用 `timer -= delta` |

正确示例：

```gdscript
velocity.x = move_toward(
	velocity.x,
	direction * move_speed,
	ground_acceleration * delta
)

velocity.y += gravity * delta
```

不要给目标速度额外乘 `delta`：

```gdscript
# 错误：目标速度会缩小约 60 倍
var target_speed := direction * move_speed * delta
```

`move_and_slide()` 内部已经按物理帧处理移动，不要向它传入 `delta`。

## 状态机的核心约定

状态代码分为两类：

- 状态持续行为：写在 `_state_idle()`、`_state_jump()` 等函数中，每个物理帧执行。
- 状态进入行为：写在 `_enter_state()` 中，只在进入状态时执行一次。

例如设置跳跃初速度属于进入行为：

```gdscript
func _enter_state(new_state: State) -> void:
	match new_state:
		State.JUMP:
			velocity.y = jump_velocity
```

如果把它放进每帧执行的 `_state_jump()`，Y 速度会不断被重置，角色将无法到达跳跃最高点。

## 离线学习提示

这些文档和代码不依赖网络。Godot 编辑器自带类参考；选中函数名称后可以使用编辑器的“查找文档”功能查看 `CharacterBody2D`、`move_and_slide()`、`is_on_floor()` 等 API。

