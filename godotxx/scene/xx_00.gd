extends Node2D
class_name XX_0
@onready var mainwindow: Control = $".."

# 信号定义
signal chatmode
signal reset
signal open_chat_window

# 状态管理
enum State { IDLE, DRAGGING, MOVING, CHATTING }
var state: State = State.IDLE

# 计时器
var idle_timer: Timer
var left_click_move_timer: Timer
var double_click_timer: Timer
var long_press_timer: Timer

@onready var context_menu: PopupMenu = preload("res://scene/contextmenu.tscn").instantiate()

# 配置常量
var stay_animations: Array[String] = ["stay2", "stay1", "stay3"]
var screen_rect: Rect2
var window_size: Vector2i = Vector2i.ZERO

# 时间配置（统一管理）
const LONG_PRESS_TIME: float = 0.1  # 长按判定时间
const DOUBLE_CLICK_TIME: float = 0.2  # 双击判定时间
const AUTO_MOVE_TIME: float = 2.0  # 自动移动时间
const IDLE_MIN_TIME: float = 4.0  # 闲置动画最小间隔
const IDLE_MAX_TIME: float = 8.0  # 闲置动画最大间隔

# 其他变量
var click_count: int = 0
var mouse_position: Vector2
var is_double_click_detected: bool = false
var was_chat_mode_before_drag: bool = false
var is_waiting_for_long_press: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# 初始化计时器
	idle_timer = _create_timer(1.0, true, _play_random_stay_anim)
	left_click_move_timer = _create_timer(AUTO_MOVE_TIME, true, _stop_left_click_move)
	double_click_timer = _create_timer(DOUBLE_CLICK_TIME, true, _on_double_click_timeout)
	long_press_timer = _create_timer(LONG_PRESS_TIME, true, _on_long_press_timeout)
	_init_context_menu()
	screen_rect = DisplayServer.screen_get_usable_rect()
	window_size = DisplayServer.window_get_size()
	_reset_idle_timer()

func _init_context_menu() -> void:
	add_child(context_menu)
	context_menu.add_item("进入聊天", 0)
	context_menu.add_item("天气预报", 1)  # 预留功能,之后再加
	context_menu.add_separator()
	context_menu.add_item("关闭", 2)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)



func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0:  # 进入聊天
			open_chat_window.emit()  # 发射信号
		1:  # 天气预报（预留）之后再加
			print("天气预报功能待实现")
		2:  # 关闭
			if mainwindow.has_method("clear_chat_history"):
				mainwindow.clear_chat_history() 
			get_tree().quit()

# 辅助函数：创建计时器
func _create_timer(wait_time: float, one_shot: bool, callback: Callable) -> Timer:
	var timer: Timer = Timer.new()
	timer.wait_time = wait_time
	timer.one_shot = one_shot
	timer.timeout.connect(callback)
	add_child(timer)
	return timer

# 闲置计时器重置
func _reset_idle_timer() -> void:
	var random_time = randf_range(IDLE_MIN_TIME, IDLE_MAX_TIME)
	idle_timer.wait_time = random_time
	idle_timer.start()

# 播放随机闲置动画
func _play_random_stay_anim() -> void:
	if state == State.IDLE and not is_waiting_for_long_press:
		var random_anim = stay_animations[randi() % stay_animations.size()]
		animation_player.play(random_anim)
	_reset_idle_timer()

# 停止移动
func _stop_left_click_move() -> void:
	if state == State.MOVING:
		state = State.IDLE
		animation_player.stop()
		animation_player.play("RESET")
		_reset_idle_timer()

# 双击计时器超时处理
func _on_double_click_timeout() -> void:
	if click_count == 1 and not is_waiting_for_long_press:
		_handle_single_click()
	click_count = 0
	is_double_click_detected = false

# 长按计时器超时处理
func _on_long_press_timeout() -> void:
	is_waiting_for_long_press = false
	# 允许从移动状态切换到拖动状态
	if state != State.CHATTING and state != State.DRAGGING:
		_start_left_click_drag()

# 开始拖动
func _start_left_click_drag() -> void:
	# 停止任何正在进行的移动
	if state == State.MOVING:
		left_click_move_timer.stop()
		animation_player.stop()
	
	was_chat_mode_before_drag = (state == State.CHATTING)
	state = State.DRAGGING
	animation_player.play("takeup")
	mouse_position = get_global_mouse_position()
	_reset_idle_timer()
	
	if was_chat_mode_before_drag:
		_force_reset_animation()

# 停止拖动
func _stop_left_click_drag() -> void:
	if state == State.DRAGGING:
		state = State.IDLE
		animation_player.play("putdown")
		_reset_idle_timer()

# 处理单击事件
func _handle_single_click() -> void:
	# 只有在空闲状态才处理单击移动
	if state == State.IDLE:
		state = State.MOVING
		animation_player.play("walk")
		left_click_move_timer.start()
		_reset_idle_timer()

# 切换到聊天模式
func _switch_to_chat_animation() -> void:
	state = State.CHATTING
	animation_player.play("chat")
	chatmode.emit()
	
	# 停止所有计时器和移动
	left_click_move_timer.stop()
	long_press_timer.stop()
	double_click_timer.stop()
	is_waiting_for_long_press = false
	_reset_idle_timer()

# 切换到重置状态
func _switch_to_reset_animation() -> void:
	state = State.IDLE
	animation_player.play("RESET")
	reset.emit()
	
	# 停止所有计时器和移动
	left_click_move_timer.stop()
	long_press_timer.stop()
	double_click_timer.stop()
	is_waiting_for_long_press = false
	_reset_idle_timer()

# 强制重置动画
func _force_reset_animation():
	if state == State.CHATTING:
		state = State.IDLE
		reset.emit()

# 切换聊天模式
func _toggle_chat_mode() -> void:
	if state == State.CHATTING:
		_switch_to_reset_animation()
	else:
		_switch_to_chat_animation()

# 检测双击
func _check_double_click() -> void:
	click_count += 1
	
	if click_count == 1:
		is_waiting_for_long_press = true
		long_press_timer.start()
		double_click_timer.start()
	elif click_count == 2:
		is_double_click_detected = true
		double_click_timer.stop()
		long_press_timer.stop()
		is_waiting_for_long_press = false
		
		_toggle_chat_mode()
		click_count = 0

# 窗口位置限制
func _clamp_window_position(pos: Vector2i) -> Vector2i:
	var max_x: float = screen_rect.size.x - window_size.x + 190
	var max_y: float = screen_rect.size.y - window_size.y + 530
	var clamped_x = clamp(pos.x, 0, max_x)
	var clamped_y = clamp(pos.y, 0, max_y)
	return Vector2i(clamped_x, clamped_y)

# 帧更新
func _process(delta: float) -> void:
	# 只有在移动状态且没有等待长按判断时才执行自动移动
	if state == State.MOVING and not is_waiting_for_long_press:
		var current_window_pos = DisplayServer.window_get_position()
		var new_pos = Vector2i(
			current_window_pos.x - 100 * delta,
			current_window_pos.y
		)
		new_pos = _clamp_window_position(new_pos)
		DisplayServer.window_set_position(new_pos)

# 输入事件处理
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 在鼠标位置显示菜单
			var mouse_pos = event.position
			context_menu.set_position(mouse_pos)
			# 弹出菜单
			context_menu.popup()
			return  # 不处理后续逻辑
		if event.pressed:
			# 在移动状态下也允许检测长按
			_check_double_click()
		else:
			# 左键释放时的处理
			if is_waiting_for_long_press and long_press_timer.time_left > 0:
				# 如果是短按，停止长按计时器
				long_press_timer.stop()
				is_waiting_for_long_press = false
			
			if state == State.DRAGGING:
				_stop_left_click_drag()
	
	# 拖动时的鼠标移动处理
	if state == State.DRAGGING and event is InputEventMouseMotion:
		var new_pos = DisplayServer.mouse_get_position() - Vector2i(mouse_position)
		new_pos = _clamp_window_position(new_pos)
		DisplayServer.window_set_position(new_pos)
		
		if animation_player.current_animation != "takeup" and not animation_player.is_playing():
			animation_player.play("move")
	
	# 其他移动释放处理
	if event.is_action_released("move") and animation_player.current_animation != "putdown" and state != State.CHATTING:
		animation_player.play("RESET")
