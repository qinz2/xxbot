extends Panel

@onready var image_display: TextureRect = $ImageDisplay

func setup_message(message_data: Dictionary) -> void:
	var image = Image.load_from_file(message_data.content)

	# 创建纹理
	var texture = ImageTexture.create_from_image(image)

	# 设置到显示节点
	image_display.texture = texture
	
	# 设置样式
	if message_data.is_user:
		self.set_position(Vector2(80, self.position.y))
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.6, 1, 0.2)
		add_theme_stylebox_override("panel", style)
	else:
		self.set_position(Vector2(10, self.position.y))
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.9, 0.9, 0.9, 0.2)
		add_theme_stylebox_override("panel", style)
