extends Panel
@onready var message_label: Label = $MessageLabel

func setup_message(text: String, is_user: bool) -> void:
	await ready
	message_label.text = text
	
	# 设置样式区分用户和AI
	if is_user:
		# 用户消息 - 靠右，蓝色
		self.set_position(Vector2(80, self.position.y))
		message_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_RIGHT)
		# 设置背景颜色
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.6, 1, 0.2)  # 半透明蓝色
		add_theme_stylebox_override("panel", style)
	else:
		# AI消息 - 靠左，灰色
		self.set_position(Vector2(10, self.position.y))
		message_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_LEFT)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.9, 0.9, 0.9, 0.2)  # 半透明灰色
		add_theme_stylebox_override("panel", style)
