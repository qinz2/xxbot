extends Control

@onready var messages_container: VBoxContainer = $MessagesScroll/MessagesContainer
@onready var input_field: LineEdit = $InputArea/InputField
@onready var send_button: Button = $InputArea/SendButton
@onready var close_button: Button = $CloseButton

signal window_closed

var chat_history: Array[Dictionary] = []
const MAX_HISTORY: int = 50

func _ready() -> void:
	print("✅ ChatWindow UI 初始化")
	
	# ✅ 修复信号连接（关键修复）
	if XxClient.message_received.is_connected(_on_mai_response):
		XxClient.message_received.disconnect(_on_mai_response)
		print("🔄 已断开旧信号连接")
	
	XxClient.message_received.connect(_on_mai_response)
	XxClient.connection_changed.connect(_on_connection_changed)
	send_button.pressed.connect(_on_send_pressed)
	input_field.text_submitted.connect(_on_send_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	print("  📍 messages_container:", messages_container)
	print("  📍 input_field:", input_field)
	
	load_chat_history()
	
	if chat_history.is_empty():
		add_message("你好！我是xx，来聊天吧～", false)

func _on_connection_changed(status: int) -> void:
	"""连接状态变化"""
	match status:
		XxClient.CONNECTED:
			print("✅ 已连接到 MaiBot")
		XxClient.DISCONNECTED:
			print("⚠️ 与 MaiBot 断开连接")
		XxClient.CONNECTING:
			print("🔄 正在连接...")

func _on_close_pressed() -> void:
	save_chat_history()
	window_closed.emit()
	self.hide()

func _on_send_pressed(_submitted_text: String = "") -> void:
	var message: String = input_field.text.strip_edges()
	if message.is_empty():
		return
	
	add_message(message, true)
	input_field.clear()
	
	if XxClient.is_mai_connected():
		XxClient.send_message("player_001", message)
		print("📤 UI发送: %s" % message)  # ✅ 调试
	else:
		await get_tree().create_timer(1.0).timeout
		var responses = [
			"收到！不过我好像断网了...",
			"抱歉，xx暂时无法连接。",
            "让我想想...（连接中）"
		]
		add_message(responses.pick_random(), false)

func _on_mai_response(text: String, emotion: String, player_id: String) -> void:
	print("📥 UI收到回复: %s" % text)  # ✅ 调试
	add_message(text, false)

func add_message(text: String, is_user: bool) -> void:
	var message_data = {
		"text": text,
		"is_user": is_user,
		"timestamp": Time.get_unix_time_from_system()
	}
	chat_history.append(message_data)
	
	if chat_history.size() > MAX_HISTORY:
		chat_history.pop_front()
	
	save_chat_history()
	
	var bubble_scene = preload("res://scene/chat_bubble.tscn")
	var bubble = bubble_scene.instantiate()
	bubble.setup_message(text, is_user)
	messages_container.add_child(bubble)
	
	scroll_to_bottom()

func clear_display() -> void:
	for child in messages_container.get_children():
		child.queue_free()

func scroll_to_bottom() -> void:
	await get_tree().process_frame
	var scroll: ScrollContainer = get_node("MessagesScroll")
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func save_chat_history() -> void:
	var file = FileAccess.open("user://chat_history.dat", FileAccess.WRITE)
	file.store_string(JSON.stringify(chat_history))
	file.close()

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
			var bubble_scene = preload("res://scene/chat_bubble.tscn")
			var bubble = bubble_scene.instantiate()
			bubble.setup_message(message["text"], message["is_user"])
			messages_container.add_child(bubble)
