extends Control

@onready var messages_scroll: ScrollContainer = $MessagesScroll
@onready var drag_handle: Panel = $DragHandle
@onready var messages_container: VBoxContainer = $MessagesScroll/MessagesContainer
@onready var input_field: LineEdit = $InputArea/InputField
@onready var send_button: Button = $InputArea/SendButton
@onready var close_button: Button = $CloseButton
@onready var screenshot_button: Button = $InputArea/ScreenshotButton
@onready var image_button: Button = $InputArea/ImageButton
@onready var image_file_dialog: FileDialog = $ImageFileDialog
@onready var status_label: Label = $StatusLabel

signal window_closed
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# 对话历史数组，最多保存50轮
var chat_history: Array[Dictionary] = []
const MAX_HISTORY: int = 50

# Screenshot manager instance
var screenshot_manager: ScreenCaptureManager = null

# Screenshot confirm dialog
var screenshot_confirm_dialog: Window = null

func _ready() -> void:
	print("✅ ChatWindow UI 初始化")
	
	# ✅ 连接 XxClient 信号
	if XxClient.message_received.is_connected(_on_mai_response):
		XxClient.message_received.disconnect(_on_mai_response)
		print("🔄 已断开旧信号连接")
	
	XxClient.message_received.connect(_on_mai_response)
	XxClient.connection_changed.connect(_on_connection_changed)
	
	# 连接 UI 信号
	send_button.pressed.connect(_on_send_pressed)
	input_field.text_submitted.connect(_on_text_submitted)
	close_button.pressed.connect(_on_close_pressed) 
	image_button.pressed.connect(_on_image_button_pressed)
	image_file_dialog.file_selected.connect(_on_image_file_selected)
	screenshot_button.pressed.connect(_on_screenshot_button_pressed)
	drag_handle.set_process_input(true)
	
	# 初始化 ScreenCaptureManager
	screenshot_manager = ScreenCaptureManager.new()
	add_child(screenshot_manager)
	_connect_screenshot_signals()
	
	# 初始化 Screenshot Confirm Dialog
	var dialog_scene = preload("res://scene/screenshot_confirm_dialog.tscn")
	screenshot_confirm_dialog = dialog_scene.instantiate()
	add_child(screenshot_confirm_dialog)
	screenshot_confirm_dialog.screenshot_confirmed.connect(_on_screenshot_confirmed)
	screenshot_confirm_dialog.screenshot_cancelled.connect(_on_screenshot_cancelled)
	
	# 加载历史记录
	load_chat_history()
	
	# 如果历史为空，添加欢迎消息
	if chat_history.is_empty():
		add_message("你好！我是xx，来聊天吧～", false, "text")

func _on_connection_changed(status: int) -> void:
	"""连接状态变化"""
	match status:
		XxClient.CONNECTED:
			print("✅ 已连接到 MaiBot")
		XxClient.DISCONNECTED:
			print("⚠️ 与 MaiBot 断开连接")
		XxClient.CONNECTING:
			print("🔄 正在连接...")

func _on_mai_response(text: String, emotion: String, player_id: String) -> void:
	print("📥 UI收到回复: %s" % text)
	add_message(text, false, "text")

func _input(event: InputEvent) -> void:
	# ✅ 只处理鼠标事件（忽略键盘、手柄等）
	if not event is InputEventMouse:
		return
	
	# 检查鼠标是否在拖动条内
	if not drag_handle.get_global_rect().has_point(event.position):
		return
	
	# 屏蔽滚轮事件
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			get_viewport().set_input_as_handled()
			return
	
	# 鼠标按下：开始拖动
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = event.position
		else:
			is_dragging = false
		get_viewport().set_input_as_handled()
	
	# 鼠标移动：拖动窗口
	elif event is InputEventMouseMotion and is_dragging:
		var new_pos = DisplayServer.mouse_get_position() - Vector2i(drag_offset)
		
		# 限制在屏幕内
		var screen_rect = DisplayServer.screen_get_usable_rect()
		var window_size = DisplayServer.window_get_size()
		new_pos.x = clamp(new_pos.x, 0, screen_rect.size.x - window_size.x)
		new_pos.y = clamp(new_pos.y, 0, screen_rect.size.y - window_size.y)
		
		DisplayServer.window_set_position(new_pos)
		get_viewport().set_input_as_handled()

# 图片按钮点击
func _on_image_button_pressed() -> void:
	image_file_dialog.popup()  # 显示文件选择窗口

# 文件选择完成
func _on_image_file_selected(path: String) -> void:
	# 1. 在 UI 显示用户发送的图片
	add_message(path, true, "image")
	
	# 2. 发送图片到 MaiBot
	if XxClient.is_mai_connected():
		print("📤 准备发送图片: %s" % path)
		
		# 显示"识别中..."提示
		add_message("正在识别图片...", false, "text")
		
		# 发送图片
		var success: bool = XxClient.send_image("player_001", path)
		
		if not success:
			# 发送失败，显示错误提示
			add_message("❌ 图片发送失败，请检查文件格式和大小", false, "text")
	else:
		# 离线时的随机回复：50% 概率发文本，50% 概率发图片
		await get_tree().create_timer(1.0).timeout
		
		if randf() < 0.5:
			var ai_text_responses: Array[String] = [
				"好有趣的图片！",
				"这个图片很有意思~",
				"我看到了！",
				"图片已收到！",
				"让我仔细看看这张图片..."
			]
			add_message(ai_text_responses.pick_random(), false, "text")
		else:
			var ai_image_paths: Array[String] = [
				"res://scene/assets/ai_reply_1.png",
				"res://scene/assets/ai_reply_2.png",
				"res://scene/assets/ai_reply_3.png"
			]
			add_message(ai_image_paths.pick_random(), false, "image")

func _on_close_pressed() -> void:
	# 保存聊天记录
	save_chat_history()
	# 发射关闭信号
	window_closed.emit()
	self.hide()

func _on_text_submitted(_text: String) -> void:
	_on_send_pressed()

func _on_send_pressed() -> void:
	var message: String = input_field.text.strip_edges()
	if message.is_empty():
		return
	
	# 用户发送文本
	add_message(message, true, "text")
	input_field.clear()
	
	# 发送到 MaiBot
	if XxClient.is_mai_connected():
		XxClient.send_message("player_001", message)
		print("📤 UI发送: %s" % message)
	else:
		# 离线时的随机回复
		await get_tree().create_timer(1.0).timeout
		var responses = [
			"收到！不过我好像断网了...",
			"抱歉，xx暂时无法连接。",
			"让我想想...（连接中）"
		]
		add_message(responses.pick_random(), false, "text")

# 添加消息到界面和历史
func add_message(content: String, is_user: bool, type: String = "text") -> void:
	var message_data = {
		"type": type,
		"content": content,
		"is_user": is_user,
		"timestamp": Time.get_unix_time_from_system()
	}
	chat_history.append(message_data)
	if chat_history.size() > MAX_HISTORY:
		chat_history.pop_front()
	save_chat_history()
	# 创建气泡（同步，无 await）
	var bubble_scene = preload("res://scene/chat_bubble.tscn") if type == "text" else preload("res://scene/image_bubble.tscn")
	var bubble = bubble_scene.instantiate()
	# 立即添加到容器（这会触发 _ready()）
	messages_container.add_child(bubble)
	# 现在安全地设置消息
	bubble.setup_message(message_data)
	# 滚动
	scroll_to_bottom()

# 清空当前显示
func clear_display() -> void:
	for child in messages_container.get_children():
		child.queue_free()

# 滚动到最新消息
func scroll_to_bottom() -> void:
	await get_tree().process_frame
	var scroll: ScrollContainer = get_node("MessagesScroll")
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# ========== Screenshot Functions ==========

## Connect screenshot manager signals to UI update methods
func _connect_screenshot_signals() -> void:
	if screenshot_manager:
		screenshot_manager.screenshot_started.connect(_on_screenshot_started)
		screenshot_manager.screenshot_completed.connect(_on_screenshot_completed)
		screenshot_manager.screenshot_failed.connect(_on_screenshot_failed)
		screenshot_manager.screenshot_warning.connect(_on_screenshot_warning)

## Handle screenshot button press
func _on_screenshot_button_pressed() -> void:
	print("[ChatWindow] Screenshot button pressed")
	if screenshot_manager:
		# Disable button during capture
		screenshot_button.disabled = true
		# Trigger screenshot
		screenshot_manager.capture_screen()

## Handle screenshot started signal
func _on_screenshot_started() -> void:
	print("[ChatWindow] Screenshot started")
	_show_screenshot_status("正在截图...")

## Handle screenshot completed signal
func _on_screenshot_completed(file_path: String) -> void:
	print("[ChatWindow] Screenshot completed: ", file_path)
	# Re-enable button
	screenshot_button.disabled = false
	# Clear status
	_show_screenshot_status("")
	
	# 显示确认对话框
	if screenshot_confirm_dialog:
		screenshot_confirm_dialog.show_screenshot(file_path)
	else:
		push_error("Screenshot confirm dialog not initialized")

## Handle screenshot confirmed from dialog
func _on_screenshot_confirmed(file_path: String, message: String) -> void:
	print("[ChatWindow] Screenshot confirmed with message: ", message)
	
	# 检查连接状态
	if not XxClient.is_mai_connected():
		add_message("⚠️ 未连接到 MaiBot，无法发送截图", false, "text")
		return
	
	# 在聊天窗口显示用户的消息
	if not message.is_empty():
		add_message(message, true, "text")
	add_message(file_path, true, "image")
	
	# 显示识别提示
	add_message("正在识别截图...", false, "text")
	
	# 发送图文混合消息
	var success: bool = XxClient.send_image_with_text("player_001", file_path, message)
	
	if not success:
		add_message("❌ 截图发送失败，请检查连接", false, "text")

## Handle screenshot cancelled from dialog
func _on_screenshot_cancelled() -> void:
	print("[ChatWindow] Screenshot cancelled")
	add_message("📷 已取消发送截图", false, "text")

## Handle screenshot failed signal
func _on_screenshot_failed(error_message: String) -> void:
	print("[ChatWindow] Screenshot failed: ", error_message)
	# Re-enable button
	screenshot_button.disabled = false
	# Clear status
	_show_screenshot_status("")
	# Show error message in chat
	add_message("❌ 截图失败: " + error_message, false, "text")

## Handle screenshot warning signal
func _on_screenshot_warning(warning_message: String) -> void:
	print("[ChatWindow] Screenshot warning: ", warning_message)
	# Show warning message in chat
	add_message("⚠️ " + warning_message, false, "text")

## Show screenshot status in status label
func _show_screenshot_status(status: String) -> void:
	if status_label:
		status_label.text = status
		status_label.visible = not status.is_empty()

# ========== End Screenshot Functions ==========

# 保存对话历史到文件
func save_chat_history() -> void:
	var file = FileAccess.open("user://chat_history.dat", FileAccess.WRITE)
	var json_text = JSON.stringify(chat_history)
	file.store_string(json_text)
	file.close()

# 从文件加载对话历史
func load_chat_history() -> void:
	if not FileAccess.file_exists("user://chat_history.dat"):
		return
	
	var file = FileAccess.open("user://chat_history.dat", FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(json_text)
	if result is Array:
		chat_history.clear()
		for item in result:
			if item is Dictionary:
				chat_history.append(item)
		
		clear_display()
		for message in chat_history:
			if message.has("type"):
				if message.type == "text":
					var bubble_scene = preload("res://scene/chat_bubble.tscn")
					var bubble = bubble_scene.instantiate()
					messages_container.add_child(bubble)
					await bubble.tree_entered
					bubble.setup_message(message)
				elif message.type == "image":
					var bubble_scene = preload("res://scene/image_bubble.tscn")
					var bubble = bubble_scene.instantiate()
					messages_container.add_child(bubble)
					await bubble.tree_entered
					bubble.setup_message(message)
