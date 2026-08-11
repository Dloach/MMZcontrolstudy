extends CharacterBody2D

# Player 使用有限状态机（Finite State Machine，简称 FSM）管理行为。
# 同一时刻只会有一个 current_state 生效，_process_state() 会把控制权
# 分发给对应的 _state_xxx() 函数。
enum State {
	# 地面静止。
	IDLE,
	# 地面跑动。
	RUN,
	# 向上跳跃阶段。
	JUMP,
	# 下落阶段。
	FALL,
	# 冲刺以及冲刺后的刹车阶段。
	DASH,
	# 贴墙缓慢下滑。
	WALLSLIDE,
	# 预留的攻击状态；目前尚未在 _process_state() 中处理。
	ATTACK,
	# 受到伤害并被击退。
	HURT,
	# 预留的死亡状态。
	DIE,
	# 冲刺中按下“下”之后进入的低姿态滑行。
	LOWSLIDE,
	# 蹲下或蹲着移动。
	SQUAT,
	# 蹲下受伤状态。
	SQUATHURT,
	
}



# @export_category 只负责在 Inspector 中给导出变量分组，不参与游戏逻辑。
@export_category("Movement")
# 正常地面移动所能达到的最大水平速度。
@export var move_speed:= 400.0
# 地面上接近目标速度的速率；越大，起步和转向越快。
@export var ground_acceleration:= 2600.0
# 松开方向后，水平速度接近 0 的速率。
@export var ground_deceleration:= 2800.0
# 每秒施加的基础重力加速度。
@export var gravity:= 980.0


@export_category("Jump")
# Godot 2D 中 y 轴向下为正，因此负数代表向上的起跳速度。
@export var jump_velocity:= -500.0
# 空中调整水平速度的速率。
@export var air_acceleration:= 1600.0
# 限制最大向下速度，避免角色无限加速。
@export var max_fall_speed:= 1400.0
# 下落时的重力倍率，让上升和下降可以拥有不同手感。
@export var fall_gravity_multiplier:= 1.5
# 提前松开跳跃键时保留多少向上速度；数值越小，短跳越明显。
@export var jump_cut_multiplier:= 0.5
# 冲跳减速放缓，提升冲调速度感和滑翔距离
@export var dash_jump_decleration:= 350.0


@export_category("Feel")
# 跳跃缓冲：落地前稍早按下跳跃，输入仍可保留的时间。
@export var jump_buffer_duration:= 0.15
# 土狼时间：离开平台后仍允许地面跳跃的时间。
@export var coyote_duration:= 0.12
# 冲刺缓冲：冲刺输入可以被保留的时间。
@export var dash_buffer_duration:= 0.15


@export_category("Dash")
# 冲刺高速阶段的水平速度。
@export var dash_speed:= 950.0
# 冲刺保持恒定高速的时长，单位为秒。
@export var dash_duration:= 0.18
# 高速阶段结束后的水平减速度。
@export var dash_slide_deceleration:= 2400.0
# 无方向输入时，速度低于该值便视作完全停止。
@export var dash_stop_speed:= 50.0


@export_category("WallSlide")
# 滑墙时允许的最大向下速度。
@export var wall_slide_speed:= 100.0
# 墙跳时离开墙面的水平推力。
@export var wall_jump_push:= 400.0


@export_category("Hurt")
# 受伤击退的水平速度。
@export var hurt_back_x:= 150.0
# 受伤时向上的弹起速度，所以这里也是负数。
@export var hurt_bounce:= -200.0
# HURT 状态持续时间。
@export var hurt_duration:= 0.5
# 受伤后免疫再次受伤的时间。
@export var hurt_immunity:= 0.8


@export_category("Squat")
# 蹲着移动时的目标水平速度。
@export var squat_move_speed:= 220.0

@export_category("Attack")
# 攻击按键缓存
@export var attack_buffer:= 1.5


# @onready 表示等节点进入场景树、子节点已经可用后再取得引用。
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
# 不同动画素材的视觉中心不同，因此播放动画前应用各自的 offset。
# &"idle" 是 StringName，适合反复作为动画名和字典键使用。
const ANIMATION_OFFSETS: Dictionary = {
	&"idle": Vector2(7.23, -5.435),
	&"jump": Vector2(5.9, -2.32),
	&"run": Vector2(7.3, -4.88),
	&"dash": Vector2(8.82,-4.88),
	&"wallslide": Vector2(9.375, -2.445),
	&"lowslide": Vector2(8.4,-5.35),
	&"squat": Vector2(7.0,-5.0),
	&"hurt": Vector2(4.0,-4.0),
	&"attack1": Vector2(7.0, -4.0),
	&"attack2": Vector2(7.0, -4.0),
	&"attack3": Vector2(7.0, -4.0),
	
}


# 用于在角色头顶显示当前状态，方便学习和调试状态切换。
@onready var state_label: Label = $Label
# 每个状态对应一种调试文字颜色。
const STATE_LABEL_COLOR: Dictionary = {
	State.IDLE: Color.AQUAMARINE,
	State.RUN: Color.ROYAL_BLUE,
	State.JUMP: Color.SEA_GREEN,
	State.FALL: Color.ORANGE,
	State.DASH: Color.YELLOW,
	State.WALLSLIDE: Color.DARK_ORCHID,
	State.HURT: Color.DARK_RED,
	State.DIE: Color.DIM_GRAY,
	State.LOWSLIDE: Color.HOT_PINK,
	State.SQUAT: Color.DARK_KHAKI,
	State.ATTACK: Color.RED,
	
}




# 当前唯一生效的状态。游戏开始时设为 IDLE。
var current_state = State.IDLE
# 冲刺方向只保存 -1 或 1；没有方向输入时会使用 facing。
var dash_direction:= 1.0
# DASH/LOWSLIDE 高速阶段剩余的时间。
var dash_timer:= 0.0
# 角色当前朝向：1 表示右，-1 表示左。
var facing:= 1.0
# HURT 状态剩余时间。
var hurt_timer:= 0.0
# 受伤无敌时间的剩余值。
var hurt_immunity_timer:= 0.0
# 最近碰到的尖刺，用于计算击退方向。
var last_spike: Area2D
# 跳跃、土狼时间、冲刺输入各自的剩余缓冲时间。
var jump_buffer_timer:= 0.0
var coyote_timer:= 0.0
var dash_buffer_timer:= 0.0
# 空中变速速度容器
var air_speed_changer:= 0.0

# 攻击按键缓存
var attack_buffer_timer:= 0.0
# 连招窗口
var combo_window_timer:= 0.0
# 连段序号
var attack_step: int = 0
var next_attack_queue:= false



#===================================================================================================
#                          PROCESS
#===================================================================================================


# _ready() 只在节点进入场景树并准备完成时调用一次。
func _ready() -> void:
	# current_state 虽然已经是 IDLE，但仍需执行一次 IDLE 的进入行为，
	# 这样开局就会播放正确动画。
	_enter_state(State.IDLE)
	_update_state_label()


# 物理帧主循环。delta 是距离上一个物理帧经过的秒数。
# 所有“每秒变化量”乘以 delta 后，才不会受到帧率影响。
func _physics_process(delta: float) -> void:
	# get_axis() 把左/右输入合成为 -1、0、1 之间的数值。
	var direction = Input.get_axis("move_left", "move_right")
	# 先更新输入缓冲和计时器，再让本帧状态读取它们。
	_update_timers(delta)
	# 朝向只由水平输入更新；没有输入时保持原朝向。
	# 增加条件，防止滑墙时反方向的操作显示错误动画朝向
	if current_state != State.WALLSLIDE:
		_update_facing(direction)
	# 所有状态共用重力，状态函数只处理各自额外的行为。
	_apply_gravity(delta)
	# 根据 current_state 执行一个状态函数。
	_process_state(direction, delta)	
	# CharacterBody2D 真正根据 velocity 移动并更新地面、墙面碰撞信息。
	move_and_slide()
	
	# 免疫计时器永远不会减成负数。
	hurt_immunity_timer = maxf(hurt_immunity_timer - delta, 0.0)
	
		
		
	
# 统一处理竖直重力。
func _apply_gravity(delta: float) -> void:
	# 站在地面时不继续累积向下速度。
	if not is_on_floor():
		var gravity_mod:= 1.0
		# velocity.y > 0 表示正在下落，此时使用更大的重力倍率。
		if velocity.y > 0.0:
			gravity_mod = fall_gravity_multiplier
	
		# minf() 把向下速度限制在 max_fall_speed 以内。
		velocity.y = minf(velocity.y + gravity * gravity_mod * delta, max_fall_speed)
			
		
		
# 状态分发器：每个物理帧只根据 current_state 调用对应函数。
# 状态函数可以通过 _change_state() 改变下一步行为。
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
		State.WALLSLIDE:
			_state_wallslide(direction)
		State.HURT:
			_state_hurt(direction)
		State.DIE:
			_state_die(direction)
		State.LOWSLIDE:
			_state_lowslide(direction, delta)
		State.SQUAT:
			_state_squat(direction, delta)
		State.SQUATHURT:
			_state_squathurt()
		State.ATTACK:
			_state_attack(direction)
			
			
#===================================================================================================
#                          STATES
#===================================================================================================



# IDLE：没有水平输入时逐渐刹车，并监听蹲下、冲刺、下落、跳跃和跑动。
func _state_idle(direction: float, delta: float) -> void:
	# 即使进入 IDLE 时还残留少量速度，也会平滑减到 0。
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	if _can_attack():
		_change_state(State.ATTACK)
		return
	# 地面按下“下”时进入普通蹲伏。
	if _can_lowslide():
		_change_state(State.SQUAT)
		return
	
	# _can_dash() 会读取冲刺缓冲和土狼计时器。
	if _can_dash():
		_apply_dash(direction)
		return
	
	# 先检查是否已经离开地面。
	if not is_on_floor():
		_change_state(State.FALL)	
		return
	
	# elif 表示前面的离地条件不成立时，才继续检查跳跃与跑动。
	elif _can_jump():
		_change_state(State.JUMP)
		return
		
	elif not is_zero_approx(direction):
		_change_state(State.RUN)
		return
	
		
# RUN：把水平速度逐渐推向 direction * move_speed，并监听状态切换。
func _state_run(direction: float, delta: float) -> void:
	# target_speed 把“输入方向”和“最大移动速度”组合为本帧目标速度。
	var target_speed: float = direction * move_speed
	
	# move_toward() 每帧只靠近一部分，形成加速和转向过程。
	velocity.x = move_toward(velocity.x, target_speed, ground_acceleration * delta)
	
	if _can_attack():
		_change_state(State.ATTACK)
		return
		
	if _can_lowslide():
		_change_state(State.SQUAT)
		return
		# 当前这里没有 return，所以同一物理帧仍会继续检查下面的 DASH、JUMP 等条件。
		# 已修复
		
	if _can_dash():
		_apply_dash(direction)
		return
		
	elif _can_jump():
		_change_state(State.JUMP)
		return
			
	elif not is_on_floor():
		_change_state(State.FALL)	
		return
	
	elif is_zero_approx(direction):
		_change_state(State.IDLE)
		return
		
		
# JUMP：负责上升阶段的空中水平操作、短跳以及转入 FALL。
func _state_jump(direction: float, delta: float) -> void:
	_apply_air_movement(direction, delta)
	
	# 上升时提前松开跳跃键，会削减向上速度，形成可控的短跳。
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
		
	# y 速度从负数变成 0 或正数，说明到达最高点并开始下落。
	if velocity.y >= 0.0:
		_change_state(State.FALL)
		
		
# FALL：负责下落阶段的空中移动，以及落地、缓冲跳和滑墙判断。
func _state_fall(direction: float, delta: float) -> void:
	_apply_air_movement(direction, delta)
	# 如果角色落地的同一时间刚按下“下”，会进入蹲伏。
	if _can_lowslide():
		_change_state(State.SQUAT)
		return
		# 当前这里没有 return，所以同一物理帧仍会继续检查下面的跳跃、滑墙和落地条件。
		# 已修复
		
	# 这里会消费跳跃缓冲和土狼时间，所以能实现提前按键或离地后补跳。
	if _can_jump():
		_change_state(State.JUMP)
		return
	
	# 只有在空中、贴墙且输入方向朝向墙面时才能滑墙。
	if _can_wall_slide(direction):
		_change_state(State.WALLSLIDE)
		return
	
	# 落地后，根据是否有方向输入进入 IDLE 或 RUN。
	if is_on_floor():
		if is_zero_approx(direction):
			_change_state(State.IDLE)
		else:
			_change_state(State.RUN)
		return
	
	
	
	
# DASH 分为两个阶段：dash_timer 控制恒速高速阶段，之后进入减速阶段。
func _state_dash(direction: float, delta:float) -> void:
	# 冲刺期间允许地面缓冲跳优先打断冲刺。
	if _can_jump():
		_change_state(State.JUMP)
		return
		
	# 冲刺期间按下“下”，会使用矮碰撞体转入 LOWSLIDE。
	if _can_lowslide():
		_change_state(State.LOWSLIDE)
		return
		
	# 高速阶段不断锁定水平速度，并冻结竖直速度。
	if dash_timer > 0.0:
		velocity.x = dash_direction * dash_speed
		velocity.y = 0.0	
		dash_timer = maxf(dash_timer - delta, 0.0)
		return
		
	# 计时结束后不立刻清空速度，而是逐渐刹车，让冲刺有滑行余韵。
	velocity.x = move_toward(velocity.x, 0.0, dash_slide_deceleration * delta)
	# 冲刺离开地面后转为普通下落。
	if not is_on_floor():
		_change_state(State.FALL)
		return
	
	
	
	# 没有方向输入时，等速度足够低才进入 IDLE。
	if is_zero_approx(direction):
		if abs(velocity.x) <= dash_stop_speed:
			velocity.x = 0.0
			_change_state(State.IDLE)
		return
	# 有方向输入时，速度降到普通移动速度范围后进入 RUN。
	elif absf(velocity.x) <= move_speed:
		_change_state(State.RUN)		


# WALLSLIDE：限制下落速度，并检查落地、离墙和墙跳。
func _state_wallslide(direction: float) -> void:	
	# 先处理落地；落地后不应继续执行滑墙逻辑。
	if is_on_floor():
		if is_zero_approx(direction):
			_change_state(State.IDLE)
		else:
			_change_state(State.RUN)
		return	
			
	# 不再满足贴墙条件时回到 FALL。
	if not _can_wall_slide(direction):
		_change_state(State.FALL)
		return
		
	# get_wall_normal() 指向离开墙面的方向，乘推力得到墙跳水平速度。
	if Input.is_action_just_pressed("jump"):
		velocity.x = get_wall_normal().x * wall_jump_push
		_change_state(State.JUMP)
		return
		
	# 贴墙时仍保留朝墙方向的水平速度。
	velocity.x = direction * move_speed
	
	# minf() 保证向下速度不会超过 wall_slide_speed。
	velocity.y = minf(velocity.y, wall_slide_speed)
	
	
# HURT：击退速度在进入状态时设置；这里等待受伤计时结束再恢复控制。
func _state_hurt(direction: float) -> void:
	
	if hurt_timer <= 0.0:
		# 计时结束时，根据位置和输入选择地面或空中状态。
		if is_on_floor():
			if is_zero_approx(direction):
				_change_state(State.IDLE)
				return
			else:
				_change_state(State.RUN)
				return
		else:
			_change_state(State.FALL)
			
			
# LOWSLIDE：与 DASH 共用剩余高速时间，随后使用矮碰撞体减速滑行。
func _state_lowslide(direction: float, delta: float) -> void:
	# 从 DASH 转入时 dash_timer 不会重置，因此高速阶段可以自然接续。
	if dash_timer > 0.0:
		velocity.x = dash_direction * dash_speed
		velocity.y = 0.0	
		dash_timer = maxf(dash_timer - delta, 0.0)
		return
		
	# 高速时间结束后逐渐减速。
	velocity.x = move_toward(velocity.x, 0.0, dash_slide_deceleration * delta)
	
	if not is_on_floor():
		_change_state(State.FALL)
		return
	# 立即刷新射线，确保读取的是当前物理帧的头顶检测结果。
	$StandCheck.force_raycast_update()
	
	# 玩家仍按着“下”，或者头顶有障碍时，都不能恢复站立状态。
	var must_stay_squat: bool = (
		Input.is_action_pressed("move_down") or $StandCheck.is_colliding()
	)
	
	# 没有方向输入时，等待速度降到停止阈值。
	if is_zero_approx(direction):
		if abs(velocity.x) <= dash_stop_speed:
			velocity.x = 0.0	
			# 需要保持低姿态则进入 SQUAT，否则进入 IDLE。
			if must_stay_squat:
				_change_state(State.SQUAT)
			else:
				_change_state(State.IDLE)
		return
	
	# 有方向输入时，在速度仍高于普通跑速期间继续保持 LOWSLIDE 动画。
	if abs(velocity.x) > move_speed:
		return
		
	# 速度回到普通移动范围后，根据能否站立进入 SQUAT 或 RUN。
	if must_stay_squat:
		_change_state(State.SQUAT)
	else:
		_change_state(State.RUN)
	
	
# SQUAT：使用矮碰撞体，可以原地蹲下或低速蹲行。
func _state_squat(direction: float, delta: float) -> void:
	# 没有方向时固定显示蹲伏动画第 0 帧，并立即停止水平移动。
	if is_zero_approx(direction):
		_show_animation_frame(&"squat", 0)
		velocity.x = 0.0
	else:
		if not is_on_floor():
			_change_state(State.FALL)
			return
		# 原地蹲伏会暂停动画；开始移动时需要重新播放。
		if not animated_sprite_2d.is_playing():
			_play_animation(&"squat")
		# 蹲行仍使用地面加速度，但目标速度改为 squat_move_speed。
		velocity.x = move_toward(velocity.x, direction * squat_move_speed, ground_acceleration * delta)
	
	# 只要玩家继续按住“下”，就保持蹲伏，不尝试站起。
	if Input.is_action_pressed("move_down"):
		return
		
	# 松开“下”后，立即刷新头顶检测。
	$StandCheck.force_raycast_update()
	
	# 头顶仍有障碍时保持矮碰撞体，避免站起后嵌入场景。
	if $StandCheck.is_colliding():
		return
		
	
	# 可以安全站起时，根据水平输入进入 IDLE 或 RUN。
	if is_zero_approx(direction):
		_change_state(State.IDLE)
	else:
		_change_state(State.RUN)
		return
	
func _state_squathurt() -> void:
	pass

func _state_attack(direction: float) -> void:
	velocity.x = 0.0
	print("attack_step: ", attack_step)
	print("attack_frame: ", animated_sprite_2d.frame)
	print("attack_buffer: ", attack_buffer)
	if _is_combo_window_open():
		if _can_attack():
			attack_step += 1
			match attack_step:
				2:
					animated_sprite_2d.play("attack2")
				3:
					animated_sprite_2d.play("attack3")
				4:
					attack_step = 0
					return
			return	
		else:
			if animated_sprite_2d.is_playing():
				return	
			elif is_on_floor():
				if is_zero_approx(direction):
					_change_state(State.IDLE)
					return
				else:
					_change_state(State.RUN)
					return
			else:
				_change_state(State.FALL)
		
		
	
		
	
# DIE：死亡状态目前只是占位，尚未实现行为。
func _state_die(direction: float) -> void:
	pass



#===================================================================================================
#                          TOOLS
#===================================================================================================


# 状态切换的唯一入口。
# 顺序是：拒绝重复切换 → 执行旧状态退出处理 → 修改 current_state
# → 更新调试标签 → 执行新状态进入处理。
func _change_state(new_state: State) -> void:
	# 避免重复进入同一状态，从而重复播放动画或重置计时器。
	if new_state == current_state:
		return
	var old_state = current_state
	
	_exit_state(old_state, new_state)
	# 从这一行开始，current_state 才真正成为新状态。
	current_state = new_state
	_update_state_label()
	# 执行只需要在进入新状态瞬间发生一次的行为。
	_enter_state(current_state)
	# 在输出面板记录状态变化，方便检查状态机运行过程。
	print("state changed to: ", State.keys()[current_state])
	
# 缓存 spikes 分组内的所有节点，供重叠检测使用。
@onready var spike_areas: Array = get_tree().get_nodes_in_group("spikes")

# 状态进入函数：这里只放“进入瞬间执行一次”的初始化，
# 持续执行的移动和判断应留在各自的 _state_xxx() 中。
func _enter_state(new_state:State) -> void:
	match new_state:
		State.IDLE:
			_play_animation(&"idle")
		State.RUN:
			_play_animation(&"run")
		State.JUMP:
			# 起跳速度只在进入 JUMP 的瞬间设置一次。
			velocity.y = jump_velocity
			_play_animation(&"jump")
		State.DASH:
			# 每次进入 DASH 都重新开始冲刺计时并立即给予冲刺速度。
			dash_timer = dash_duration
			velocity.x = dash_direction * dash_speed
			_play_animation(&"dash")
		State.WALLSLIDE:
			_play_animation(&"wallslide")
		State.HURT:
			# 进入 HURT 时冻结原速度，然后计算远离尖刺的击退方向。
			hurt_timer = hurt_duration
			velocity = Vector2.ZERO
			var knock_direction:= -facing
			if last_spike != null:
				# 角色在尖刺右边时得到正方向，左边时得到负方向。
				knock_direction = signf(global_position.x - last_spike.global_position.x)
				# 两者 x 坐标相同时无法判断左右，退回到朝向的反方向。
				if knock_direction == 0.0:
					knock_direction = -facing
			print("knock_dir: ", knock_direction)
			velocity = Vector2(knock_direction * hurt_back_x, hurt_bounce)
			_update_facing(-knock_direction)
			_play_animation(&"hurt")
		State.LOWSLIDE:
			$CollisionShape2D.shape.height = 16.0
			$CollisionShape2D.position.y = 13.0
			_play_animation(&"lowslide")
		State.SQUAT:
			# SQUAT 与 LOWSLIDE 使用相同的矮碰撞体尺寸。
			$CollisionShape2D.shape.height = 16.0
			$CollisionShape2D.position.y = 13.0
			# 静止进入蹲伏时只显示指定帧；带速度进入时播放完整动画。
			if is_zero_approx(velocity.x):
				_show_animation_frame(&"squat", 0)
				return
			else:
				_play_animation(&"squat")
		State.ATTACK:
			attack_step = 1
			_play_animation(&"attack1")
			
			
func _exit_state(old_state: State, new_state: State) -> void:
	match old_state:
		State.LOWSLIDE:
			# 恢复站立碰撞体。
			$CollisionShape2D.shape.height = 29.0
			$CollisionShape2D.position.y = 0.0
		State.SQUAT:
			# 恢复站立碰撞体。
			$CollisionShape2D.shape.height = 29.0
			$CollisionShape2D.position.y = 0.0
		State.DASH:
			if new_state == State.JUMP:
				air_speed_changer = dash_jump_decleration
			else:
				air_speed_changer = air_acceleration
		State.FALL:
			air_speed_changer = air_acceleration
		
			
			
# 根据水平输入更新视觉朝向和 facing 记录。
func _update_facing(direction: float) -> void:
	# is_zero_approx() 用于安全判断浮点数是否“足够接近 0”。
	if is_zero_approx(direction):
		return
		
	if direction < 0.0:
		# x 缩放为负数会水平翻转 AnimatedSprite2D。
		animated_sprite_2d.scale.x = -2.0
		facing = -1.0
	else:
		animated_sprite_2d.scale.x = 2.0
		facing = 1.0
	
# 确定本次冲刺方向，然后统一进入 DASH。
func _apply_dash(direction: float) -> void:
	# 没按方向时沿当前朝向冲刺。
	if is_zero_approx(direction):
		dash_direction = facing
	else:
		# signf() 只保留输入的正负号，得到 -1 或 1。
		dash_direction = signf(direction)
		
	_change_state(State.DASH)
	
# 集中判断当前是否满足滑墙条件。
func _can_wall_slide(direction: float) -> bool:
	# 地面、没有贴墙、没有水平输入，任一情况成立都不能滑墙。
	if is_on_floor():
		return	false
	
	if not is_on_wall():
		return false
	
	if is_zero_approx(direction):
		return false
	
	# 墙面法线指向墙外；乘积小于 0 表示玩家正在按向墙面的方向。
	return direction * get_wall_normal().x < 0.0
	


# 播放动画前先应用该动画对应的视觉偏移。
func _play_animation(animation_name: StringName) -> void:
	# 如果字典中没有这个动画名，就使用 Vector2.ZERO 作为安全默认值。
	animated_sprite_2d.offset = ANIMATION_OFFSETS.get(animation_name, Vector2.ZERO)
	
	animated_sprite_2d.play(animation_name)
	
# 显示动画中的某个固定帧，适合原地蹲伏等静态姿势。
func _show_animation_frame(animation_name: StringName, frame_index: int ) -> void:
	var already_show_animation_frame: bool = (
		animated_sprite_2d.animation == animation_name
		and animated_sprite_2d.frame == frame_index
	)
	
	if already_show_animation_frame:
		return
	
	
	animated_sprite_2d.offset = ANIMATION_OFFSETS.get(animation_name, Vector2.ZERO)
	# 先 play() 切换动画，再 pause()，最后指定要显示的帧。
	animated_sprite_2d.play(animation_name)
	animated_sprite_2d.pause()
	animated_sprite_2d.frame = frame_index


# 更新角色头顶的调试标签内容和颜色。
func _update_state_label() -> void:
	# State.keys() 返回枚举名称数组，可用枚举整数取得可读名称。
	state_label.text = State.keys()[current_state]
	state_label.add_theme_color_override("font_color", STATE_LABEL_COLOR[current_state])
	
	
# JUMP 和 FALL 共用的空中水平控制。
func _apply_air_movement(direction: float, delta: float)->void:
	var target_speed: float = direction * move_speed
	
	# 空中使用 air_acceleration，因此手感可以与地面加速度分开调节。
	velocity.x = move_toward(velocity.x, target_speed, air_speed_changer * delta)
	#print("air_speed_changer: ", air_speed_changer)
	
# 每个物理帧主动检查玩家是否仍与任意尖刺重叠。
# 这样角色在持续接触尖刺时，无敌时间结束后仍能再次受伤。
func _check_spike_overlap() -> void:
	# 无敌期间或死亡后跳过伤害检测。
	if hurt_immunity_timer > 0.0 or current_state == State.DIE:
		return
		
	for spike in spike_areas:
		# Area2D 的重叠列表中包含 self，说明玩家正在接触该尖刺。
		if spike.get_overlapping_bodies().has(self):
			last_spike = spike
			hurt_immunity_timer = hurt_immunity
			_change_state(State.HURT)


# 统一更新持续时间、输入缓冲和土狼时间。
func _update_timers(delta: float) -> void:
	_check_spike_overlap()
	# maxf(..., 0.0) 防止计时器下降到负数。
	hurt_timer = maxf(hurt_timer - delta, 0.0)	
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	dash_buffer_timer = maxf(dash_buffer_timer - delta, 0.0)
	attack_buffer_timer = maxf(attack_buffer_timer - delta, 0.0)
	
	# just_pressed 只在按下的第一帧成立；这里把一次输入保存为短计时器。
	if Input.is_action_just_pressed("dash"):
		dash_buffer_timer = dash_buffer_duration	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_duration
	# 每个站在地面的物理帧都会刷新土狼时间；离地后才开始倒数。
	if is_on_floor():
		coyote_timer = coyote_duration
	# 攻击按键缓存计时开始。
	if Input.is_action_just_pressed("attack"):
		attack_buffer_timer = attack_buffer
		
		
# 跳跃缓冲和土狼时间同时有效时，允许开始一次跳跃。
func _can_jump()  -> bool:
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		# 成功使用后立即清空，避免同一次输入触发多次跳跃。
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		return true	
	return false
	
# 冲刺缓冲和土狼时间同时有效时，允许开始一次地面冲刺。
func _can_dash() -> bool:
	if dash_buffer_timer > 0.0 and coyote_timer > 0.0:
		# 消费冲刺缓冲；这里没有清空 coyote_timer。
		dash_buffer_timer = 0.0
		return true
	return false
	
# 当前函数名沿用了 LOWSLIDE，但它实际判断的是：
# “角色在地面，并且刚按下 move_down”。调用者决定进入 SQUAT 还是 LOWSLIDE。
func _can_lowslide() -> bool:
	if is_on_floor() and Input.is_action_just_pressed("move_down"):
		return true
	return false	
		

func _can_attack() -> bool:
	if (Input.is_action_just_pressed("attack") 
	and is_on_floor() 
	and (current_state == State.IDLE or current_state == State.RUN or current_state == State.ATTACK)
	and attack_buffer > 0.0
	):
		return true
	return false

func _is_combo_window_open() -> bool:
	match attack_step:
		1:
			return animated_sprite_2d.frame >5
		2:
			return animated_sprite_2d.frame > 1
		3:
			return	 false
	
	return false
	
