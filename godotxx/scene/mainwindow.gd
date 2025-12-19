extends Control
@onready var chat: chat = $chat
@onready var xx_0: XX_0 = $XX_0
@onready var enter: enterword = $enter
# 番茄钟节点（动态创建）
var pomodoro_timer: Control = null

const NORMAL_WINDOW_SIZE: Vector2i = Vector2i(400, 410)  # 常态大小
const CHAT_WINDOW_SIZE: Vector2i = Vector2i(600, 900)   # 聊天状态大小
const QUICK_CHAT_WINDOW_SIZE: Vector2i = Vector2i(400, 500)   # 快速聊天状态大小
const POMODORO_WINDOW_SIZE: Vector2i = Vector2i(400, 500)   # 番茄钟状态大小
const WEATHER_WINDOW_SIZE: Vector2i = Vector2i(800, 600)   # 天气窗口大小

var chat_window: Control = null
var weather_window: Control = null
var weather_manager: SimpleWeatherManager = null

# 设置窗口大小并确保在屏幕内
func set_window_size(new_size: Vector2i) -> void:
	# 获取当前窗口位置
	var current_pos = DisplayServer.window_get_position()
	# 设置新大小
	DisplayServer.window_set_size(new_size)
	# 获取屏幕可用区域
	var screen_rect = DisplayServer.screen_get_usable_rect()
	# 确保窗口不会超出屏幕
	var clamped_x = clamp(current_pos.x, 0, screen_rect.size.x - new_size.x)
	var clamped_y = clamp(current_pos.y, 0, screen_rect.size.y - new_size.y)
	DisplayServer.window_set_position(Vector2i(clamped_x, clamped_y))

# 切换到常态窗口大小
func switch_to_normal_size() -> void:
	set_window_size(NORMAL_WINDOW_SIZE)

# 切换到聊天窗口大小
func switch_to_chat_size() -> void:
	set_window_size(CHAT_WINDOW_SIZE)
	
func switch_to_quick_chat_size() -> void:
	set_window_size(QUICK_CHAT_WINDOW_SIZE)

# 切换到番茄钟窗口大小
func switch_to_pomodoro_size() -> void:
	set_window_size(POMODORO_WINDOW_SIZE)

# 切换到天气窗口大小
func switch_to_weather_size() -> void:
	set_window_size(WEATHER_WINDOW_SIZE)

func _ready() -> void:
	get_tree().root.set_transparent_background(true)
	
	if enter.has_signal("text_submitted"):
		enter.text_submitted.connect(_on_enterword_submitted)
	
	# 初始化天气系统
	_initialize_weather_system()

func _on_enterword_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	
	if chat_window == null:
		chat_window = preload("res://scene/chat_window.tscn").instantiate()
		add_child(chat_window)
		chat_window.hide()
	
	# 添加用户输入到历史记录
	chat_window.add_message(text, true, "text")
	
	# 发送到 MaiBot
	if XxClient.is_mai_connected():
		XxClient.send_message("player_001", text)
		chat.text = "xx思考中..."
	else:
		# 离线时的随机回复
		var sentences = ["在这里输出一个句子", "在这里输出另一个句子", "在这里输出一个很长的句子"]
		var random_sentence = sentences.pick_random()
		chat.text = random_sentence
		chat.play_chat()
		chat_window.add_message(random_sentence, false, "text")
	
	enter.text = ""
	enter.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		clear_chat_history()
		get_tree().quit()

func _on_xx_0_reset() -> void:
	chat.reset()
	enter.hide()

func _on_xx_0_chatmode() -> void:
	# 显示输入框
	enter.show()
	enter.grab_focus()  # 自动聚焦以便输入

func _on_open_chat_window() -> void:
	switch_to_chat_size()
	if chat_window == null:
		chat_window = preload("res://scene/chat_window.tscn").instantiate()
		add_child(chat_window)
	
	chat_window.window_closed.connect(_on_chat_window_closed)
	chat_window.show()
	# 将窗口置于屏幕中央
	
	var screen_size = DisplayServer.screen_get_size()
	var window_pos = Vector2i(
		(screen_size.x - 600) / 2,
		(screen_size.y - 900) / 2
	)
	DisplayServer.window_set_position(window_pos)

func _on_chat_window_closed() -> void:
	switch_to_normal_size()
	# 恢复桌宠状态
	if xx_0.has_method("_switch_to_reset_animation"):
		xx_0._switch_to_reset_animation()
		
func clear_chat_history() -> void:
	# 删除历史文件
	if FileAccess.file_exists("user://chat_history.dat"):
		DirAccess.remove_absolute("user://chat_history.dat")
	# 清空内存中的历史（如果聊天窗口存在）
	if chat_window != null and is_instance_valid(chat_window):
		chat_window.chat_history.clear()
		chat_window.clear_display()

# 显示番茄钟
func show_pomodoro_timer() -> void:
	# 如果番茄钟节点不存在，动态创建
	if pomodoro_timer == null:
		print("动态加载番茄钟场景...")
		var pomodoro_scene = preload("res://scene/pomodoro/simple_pomodoro.tscn")
		pomodoro_timer = pomodoro_scene.instantiate()
		add_child(pomodoro_timer)
		
		# 连接信号
		if pomodoro_timer.has_signal("pomodoro_closed"):
			pomodoro_timer.pomodoro_closed.connect(_on_pomodoro_timer_closed)
	
	switch_to_pomodoro_size()
	pomodoro_timer.show()
	# 允许鼠标输入以支持拖动
	mouse_filter = Control.MOUSE_FILTER_PASS
	# 确保番茄钟控件也能接收鼠标事件
	pomodoro_timer.mouse_filter = Control.MOUSE_FILTER_PASS
	# 显示调试信息
	if pomodoro_timer.has_method("show_debug_info"):
		pomodoro_timer.show_debug_info()

# 隐藏番茄钟
func hide_pomodoro_timer() -> void:
	switch_to_normal_size()
	if pomodoro_timer != null:
		pomodoro_timer.hide()
		# 恢复鼠标过滤设置
		pomodoro_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# 番茄钟关闭事件
func _on_pomodoro_timer_closed() -> void:
	hide_pomodoro_timer()

# 初始化天气系统
func _initialize_weather_system() -> void:
	# 创建简单天气管理器
	weather_manager = SimpleWeatherManager.new()
	add_child(weather_manager)

# 显示天气窗口
func show_weather_window() -> void:
	switch_to_weather_size()
	
	if weather_window == null:
		weather_window = preload("res://scene/weather/weather_window.tscn").instantiate()
		add_child(weather_window)
		
		# 连接天气窗口信号
		weather_window.weather_window_closed.connect(_on_weather_window_closed)
		
		# 连接WeatherManager和WeatherUI
		_connect_weather_signals()
	
	weather_window.show()
	
	# 将窗口置于屏幕中央
	var screen_size = DisplayServer.screen_get_size()
	var window_pos = Vector2i(
		(screen_size.x - WEATHER_WINDOW_SIZE.x) / 2,
		(screen_size.y - WEATHER_WINDOW_SIZE.y) / 2
	)
	DisplayServer.window_set_position(window_pos)

# 隐藏天气窗口
func hide_weather_window() -> void:
	switch_to_normal_size()
	if weather_window != null:
		weather_window.hide()
	
	# 恢复桌宠状态
	if xx_0.has_method("_switch_to_reset_animation"):
		xx_0._switch_to_reset_animation()

# 天气窗口关闭事件
func _on_weather_window_closed() -> void:
	hide_weather_window()

# 连接天气管理器和UI的信号
func _connect_weather_signals() -> void:
	if weather_manager == null or weather_window == null:
		return
	
	# 简单的信号连接
	weather_manager.weather_updated.connect(weather_window.display_current_weather)
	weather_manager.error_occurred.connect(weather_window.show_error_message)

# 更新收藏城市显示
func _update_favorites_display() -> void:
	if weather_window != null and weather_manager != null:
		var favorites = weather_manager.get_favorite_cities()
		weather_window.update_favorites_list(favorites)
