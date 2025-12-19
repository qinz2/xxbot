extends Window

## Screenshot confirmation dialog
## Allows user to preview screenshot and add optional message before sending

@onready var preview_image: TextureRect = $Panel/VBoxContainer/PreviewContainer/PreviewImage
@onready var message_input: TextEdit = $Panel/VBoxContainer/MessageInput
@onready var send_button: Button = $Panel/VBoxContainer/ButtonContainer/SendButton
@onready var cancel_button: Button = $Panel/VBoxContainer/ButtonContainer/CancelButton

signal screenshot_confirmed(file_path: String, message: String)
signal screenshot_cancelled()

var current_screenshot_path: String = ""

func _ready() -> void:
	# 连接按钮信号
	send_button.pressed.connect(_on_send_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	close_requested.connect(_on_cancel_pressed)
	
	# 设置窗口属性
	always_on_top = true

## Show dialog with screenshot preview
func show_screenshot(file_path: String) -> void:
	current_screenshot_path = file_path
	
	# 加载截图
	var image = Image.load_from_file(file_path)
	if image == null:
		push_error("无法加载截图: " + file_path)
		return
	
	# 创建纹理
	var texture = ImageTexture.create_from_image(image)
	preview_image.texture = texture
	
	# 清空输入框
	message_input.text = ""
	
	# 显示对话框
	popup_centered()
	
	# 聚焦到输入框
	message_input.grab_focus()

func _on_send_pressed() -> void:
	var message = message_input.text.strip_edges()
	screenshot_confirmed.emit(current_screenshot_path, message)
	hide()

func _on_cancel_pressed() -> void:
	screenshot_cancelled.emit()
	hide()
