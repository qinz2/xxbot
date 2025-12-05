extends Control

# 修复：重命名变量避免冲突
@onready var chat_ui: chat = $chat
@onready var xx_0: XX_0 = $XX_0
@onready var enter: enterword = $enter

var chat_window: Control = null

func _ready() -> void:
	get_tree().root.set_transparent_background(true)
	
	# 使用XxClient（单例名）
	XxClient.message_received.connect(_on_mai_response)
	XxClient.connection_changed.connect(_on_connection_changed)
	
	if enter.has_signal("text_submitted"):
		enter.text_submitted.connect(_on_enterword_submitted)

func _on_enterword_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	
	if chat_window == null:
		chat_window = preload("res://scene/chat_window.tscn").instantiate()
		add_child(chat_window)
		chat_window.hide()
	
	chat_window.add_message(text, true)
	
	# 修复：使用方法名
	if XxClient.is_mai_connected():
		XxClient.send_message("player_001", text)
		chat_ui.text = "xx思考中..."  # 修复变量名
	else:
		var sentences = ["在这里输出一个句子", "在这里输出另一个句子", "在这里输出一个很长的句子"]
		var random_sentence = sentences.pick_random()
		chat_ui.text = random_sentence  # 修复变量名
		chat_ui.play_chat()  # 修复变量名
		chat_window.add_message(random_sentence, false)
	
	enter.text = ""
	enter.grab_focus()

func _on_mai_response(text: String, emotion: String, player_id: String) -> void:
	chat_ui.text = text  # 修复变量名
	chat_ui.play_chat()  # 修复变量名
	
	if chat_window and is_instance_valid(chat_window):
		chat_window.add_message(text, false)

func _on_connection_changed(status: int) -> void:
	match status:
		XxClient.CONNECTED:
			print("✅ 主窗口: xx已连接")
		XxClient.DISCONNECTED:
			print("⚠️ 主窗口: xx断开连接")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		clear_chat_history()
		get_tree().quit()

func _on_xx_0_reset() -> void:
	chat_ui.reset()  # 修复变量名
	enter.hide()

func _on_xx_0_chatmode() -> void:
	enter.show()
	enter.grab_focus()

func _on_open_chat_window() -> void:
	if chat_window == null:
		chat_window = preload("res://scene/chat_window.tscn").instantiate()
		add_child(chat_window)
		# 修复：只在创建时连接一次
		chat_window.window_closed.connect(_on_chat_window_closed)
	
	chat_window.show()
	
	var screen_size = DisplayServer.screen_get_size()
	var window_pos = Vector2i(
		(screen_size.x - 600) / 2,
		(screen_size.y - 900) / 2
	)
	DisplayServer.window_set_position(window_pos)

func _on_chat_window_closed() -> void:
	if xx_0.has_method("_switch_to_reset_animation"):
		xx_0._switch_to_reset_animation()

func clear_chat_history() -> void:
	if FileAccess.file_exists("user://chat_history.dat"):
		DirAccess.remove_absolute("user://chat_history.dat")
	
	if chat_window != null and is_instance_valid(chat_window):
		chat_window.chat_history.clear()
		chat_window.clear_display()
