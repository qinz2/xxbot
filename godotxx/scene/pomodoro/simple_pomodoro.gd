extends Control

# UI引用
@onready var title_bar: Panel = $VBox/TitleBar
@onready var time_display: Label = $VBox/TimeDisplay
@onready var status_label: Label = $VBox/StatusLabel
@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var start_btn: Button = $VBox/Buttons/StartBtn
@onready var pause_btn: Button = $VBox/Buttons/PauseBtn
@onready var stop_btn: Button = $VBox/Buttons/StopBtn
@onready var session_count: Label = $VBox/SessionCount
@onready var debug_label: Label = $VBox/DebugLabel
@onready var smooth_btn: Button = $VBox/SmoothBtn

# 计时器状态
enum State { STOPPED, RUNNING, PAUSED }
var current_state: State = State.STOPPED
var remaining_time: float = 25 * 60  # 25分钟
var total_time: float = 25 * 60
var completed_sessions: int = 0

# 设置
var work_duration: int = 25 * 60
var short_break_duration: int = 5 * 60
var long_break_duration: int = 15 * 60
var is_work_session: bool = true

# 计时器
var timer: Timer

# 拖动相关变量
var is_dragging: bool = false
var drag_offset: Vector2
var target_position: Vector2i
var smooth_dragging: bool = true
var drag_speed: float = 20.0  # 平滑拖动速度
var window_tween: Tween
var last_move_time: float = 0.0
var move_interval: float = 0.05  # 低频移动间隔（20FPS）

# 信号
signal pomodoro_closed()

func _ready():
	# 创建计时器
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_on_timer_tick)
	add_child(timer)
	
	# 创建窗口移动的 Tween（暂时注释掉以避免错误）
	# window_tween = Tween.new()
	# add_child(window_tween)
	
	# 设置鼠标过滤器以接收输入事件
	mouse_filter = Control.MOUSE_FILTER_PASS
	print("番茄钟初始化，鼠标过滤器设置为: ", mouse_filter)
	
	# 连接标题栏的拖动事件
	title_bar.gui_input.connect(_on_title_bar_input)
	title_bar.mouse_entered.connect(_on_title_bar_mouse_entered)
	title_bar.mouse_exited.connect(_on_title_bar_mouse_exited)
	print("标题栏事件已连接")
	
	# 连接背景的拖动事件
	var background = $Background
	background.gui_input.connect(_on_background_input)
	print("背景事件已连接")
	
	# 连接整个控件的输入事件
	gui_input.connect(_on_gui_input)
	print("GUI输入事件已连接")
	
	# 初始化UI
	_update_display()
	_update_buttons()
	debug_label.text = "就绪 - 右键拖动窗口"

func _on_timer_tick():
	remaining_time -= 1.0
	_update_display()
	
	if remaining_time <= 0:
		_complete_session()

func _complete_session():
	timer.stop()
	current_state = State.STOPPED
	
	if is_work_session:
		completed_sessions += 1
		is_work_session = false
		# 切换到休息时间
		if completed_sessions % 4 == 0:
			remaining_time = long_break_duration
			total_time = long_break_duration
			status_label.text = "长休息"
		else:
			remaining_time = short_break_duration
			total_time = short_break_duration
			status_label.text = "短休息"
	else:
		is_work_session = true
		remaining_time = work_duration
		total_time = work_duration
		status_label.text = "工作时间"
	
	_update_display()
	_update_buttons()

func _update_display():
	var minutes = int(remaining_time) / 60
	var seconds = int(remaining_time) % 60
	time_display.text = "%02d:%02d" % [minutes, seconds]
	
	var progress = (total_time - remaining_time) / total_time * 100.0
	progress_bar.value = progress
	
	session_count.text = "完成会话: %d" % completed_sessions

func _update_buttons():
	match current_state:
		State.STOPPED:
			start_btn.disabled = false
			pause_btn.disabled = true
			stop_btn.disabled = true
			start_btn.text = "开始"
		State.RUNNING:
			start_btn.disabled = true
			pause_btn.disabled = false
			stop_btn.disabled = false
			pause_btn.text = "暂停"
		State.PAUSED:
			start_btn.disabled = true
			pause_btn.disabled = false
			stop_btn.disabled = false
			pause_btn.text = "继续"

func _on_start_pressed():
	current_state = State.RUNNING
	timer.start()
	_update_buttons()

func _on_pause_pressed():
	if current_state == State.RUNNING:
		current_state = State.PAUSED
		timer.stop()
	elif current_state == State.PAUSED:
		current_state = State.RUNNING
		timer.start()
	_update_buttons()

func _on_stop_pressed():
	current_state = State.STOPPED
	timer.stop()
	
	# 重置时间
	if is_work_session:
		remaining_time = work_duration
		total_time = work_duration
	else:
		remaining_time = short_break_duration if completed_sessions % 4 != 0 else long_break_duration
		total_time = remaining_time
	
	_update_display()
	_update_buttons()

func _on_settings_pressed():
	# 简单的设置对话框
	var dialog = AcceptDialog.new()
	dialog.title = "设置"
	
	var vbox = VBoxContainer.new()
	
	var work_label = Label.new()
	work_label.text = "工作时间 (分钟):"
	vbox.add_child(work_label)
	
	var work_input = SpinBox.new()
	work_input.min_value = 5
	work_input.max_value = 60
	work_input.value = work_duration / 60
	vbox.add_child(work_input)
	
	var break_label = Label.new()
	break_label.text = "短休息时间 (分钟):"
	vbox.add_child(break_label)
	
	var break_input = SpinBox.new()
	break_input.min_value = 1
	break_input.max_value = 15
	break_input.value = short_break_duration / 60
	vbox.add_child(break_input)
	
	dialog.add_child(vbox)
	add_child(dialog)
	
	dialog.confirmed.connect(func(): _on_settings_confirmed(work_input, break_input, dialog))
	
	dialog.popup_centered()

func _on_settings_confirmed(work_input: SpinBox, break_input: SpinBox, dialog: AcceptDialog):
	work_duration = int(work_input.value * 60)
	short_break_duration = int(break_input.value * 60)
	
	# 如果当前是停止状态，更新时间
	if current_state == State.STOPPED and is_work_session:
		remaining_time = work_duration
		total_time = work_duration
		_update_display()
	
	dialog.queue_free()

func _on_close_pressed():
	pomodoro_closed.emit()
	hide()

# 显示调试信息
func show_debug_info():
	print("=== 番茄钟调试信息 ===")
	print("控件可见: ", visible)
	print("鼠标过滤器: ", mouse_filter)
	print("标题栏鼠标过滤器: ", title_bar.mouse_filter)
	print("背景鼠标过滤器: ", $Background.mouse_filter)
	print("窗口位置: ", DisplayServer.window_get_position())
	print("窗口大小: ", DisplayServer.window_get_size())
	print("====================")

# 测试按钮处理
func _on_test_pressed():
	print("测试按钮被点击")
	var current_pos = DisplayServer.window_get_position()
	var new_pos = Vector2i(current_pos.x + 50, current_pos.y + 50)
	DisplayServer.window_set_position(new_pos)
	print("窗口移动到: ", new_pos)
	show_debug_info()

# 切换拖动模式
var drag_mode: int = 0  # 0=平滑, 1=直接, 2=低频
func _on_smooth_btn_pressed():
	drag_mode = (drag_mode + 1) % 3
	var mode_names = ["平滑", "直接", "低频"]
	var mode_full_names = ["平滑移动", "直接移动", "低频移动"]
	print("拖动模式切换为: ", mode_full_names[drag_mode])
	debug_label.text = "模式: %s - 右键拖动" % mode_full_names[drag_mode]
	smooth_btn.text = "拖动模式: %s" % mode_names[drag_mode]
	
	# 根据模式调整设置
	match drag_mode:
		0:  # 平滑移动
			smooth_dragging = true
			drag_speed = 20.0
		1:  # 直接移动
			smooth_dragging = false
		2:  # 低频移动
			smooth_dragging = false

# 实时更新调试信息和平滑拖动
var debug_update_timer: float = 0.0
func _process(delta):
	if visible:
		# 平滑拖动处理（仅在模式0时使用）
		if is_dragging and drag_mode == 0:
			var current_pos = Vector2(DisplayServer.window_get_position())
			var target_pos = Vector2(target_position)
			var distance = current_pos.distance_to(target_pos)
			
			if distance > 1.0:  # 只有当距离大于1像素时才移动
				var new_pos = current_pos.lerp(target_pos, drag_speed * delta)
				DisplayServer.window_set_position(Vector2i(new_pos))
		
		# 降低调试信息更新频率
		debug_update_timer += delta
		if debug_update_timer >= 0.2:  # 进一步降低到每0.2秒
			debug_update_timer = 0.0
			if not is_dragging:  # 拖动时不更新调试信息
				var mouse_pos = get_global_mouse_position()
				var window_pos = DisplayServer.window_get_position()
				debug_label.text = "鼠标: %s 窗口: %s 就绪" % [mouse_pos, window_pos]

# 统一的拖动处理函数
func start_dragging():
	is_dragging = true
	drag_offset = get_global_mouse_position() - Vector2(DisplayServer.window_get_position())
	target_position = DisplayServer.window_get_position()
	print("开始拖动")
	# 改变标题栏颜色作为视觉反馈
	title_bar.modulate = Color.YELLOW
	debug_label.text = "拖动中..."
	
	# 尝试优化窗口渲染以减少残影（暂时注释掉）
	# get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

func stop_dragging():
	is_dragging = false
	print("停止拖动")
	# 恢复标题栏颜色
	title_bar.modulate = Color.WHITE
	debug_label.text = "就绪 - 右键拖动窗口"
	
	# 恢复窗口渲染设置（暂时注释掉）
	# get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

# 标题栏拖动功能
func _on_title_bar_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			print("标题栏开始拖动")
			start_dragging()
		else:
			print("标题栏停止拖动")
			stop_dragging()

func _input(event: InputEvent):
	# 只有当番茄钟可见时才处理输入
	if not visible:
		return
		
	# 只打印重要事件，不打印鼠标移动事件
	if not (event is InputEventMouseMotion):
		print("_input 接收到事件: ", event)
		
	# 测试键盘移动窗口（用于调试）
	if event is InputEventKey and event.pressed:
		var current_pos = DisplayServer.window_get_position()
		var new_pos = current_pos
		
		match event.keycode:
			KEY_LEFT:
				new_pos.x -= 10
				DisplayServer.window_set_position(new_pos)
				print("键盘向左移动窗口到: ", new_pos)
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				new_pos.x += 10
				DisplayServer.window_set_position(new_pos)
				print("键盘向右移动窗口到: ", new_pos)
				get_viewport().set_input_as_handled()
			KEY_UP:
				new_pos.y -= 10
				DisplayServer.window_set_position(new_pos)
				print("键盘向上移动窗口到: ", new_pos)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				new_pos.y += 10
				DisplayServer.window_set_position(new_pos)
				print("键盘向下移动窗口到: ", new_pos)
				get_viewport().set_input_as_handled()
	
	# 处理鼠标点击开始拖动 - 使用右键来避免与按钮冲突
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			print("右键开始拖动")
			start_dragging()
			get_viewport().set_input_as_handled()
		else:
			print("右键停止拖动")
			stop_dragging()
			get_viewport().set_input_as_handled()
	
	# 处理全局输入事件以支持拖动（使用多种方法减少残影）
	if is_dragging and event is InputEventMouseMotion:
		var mouse_pos = get_global_mouse_position()
		var new_position = mouse_pos - drag_offset
		
		# 限制窗口位置在屏幕内
		var screen_rect = DisplayServer.screen_get_usable_rect()
		var window_size = DisplayServer.window_get_size()
		
		new_position.x = clamp(new_position.x, 0, screen_rect.size.x - window_size.x)
		new_position.y = clamp(new_position.y, 0, screen_rect.size.y - window_size.y)
		
		match drag_mode:
			0:  # 平滑移动 - 使用 _process 中的 lerp
				target_position = Vector2i(new_position)
			1:  # 直接移动
				DisplayServer.window_set_position(Vector2i(new_position))
			2:  # 低频移动 - 限制更新频率
				var current_time = Time.get_ticks_msec() / 1000.0
				if current_time - last_move_time >= move_interval:
					last_move_time = current_time
					DisplayServer.window_set_position(Vector2i(new_position))
		
		get_viewport().set_input_as_handled()

# 鼠标悬停效果
func _on_title_bar_mouse_entered():
	Input.set_default_cursor_shape(Input.CURSOR_MOVE)

func _on_title_bar_mouse_exited():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

# 背景拖动功能
func _on_background_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			print("背景开始拖动")
			start_dragging()
		else:
			print("背景停止拖动")
			stop_dragging()

# 整个控件的GUI输入处理
func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			print("GUI开始拖动")
			start_dragging()
		else:
			print("GUI停止拖动")
			stop_dragging()
