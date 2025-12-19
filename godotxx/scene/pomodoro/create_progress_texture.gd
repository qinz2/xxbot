@tool
extends EditorScript

func _run():
	# 创建圆形进度条纹理
	var size = 200
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(size / 2, size / 2)
	var outer_radius = size / 2 - 5
	var inner_radius = size / 2 - 15
	
	# 绘制圆环
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			
			if distance >= inner_radius and distance <= outer_radius:
				image.set_pixel(x, y, Color.WHITE)
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	# 保存纹理
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	ResourceSaver.save(texture, "res://scene/pomodoro/progress_circle.tres")
	print("进度条纹理已创建: res://scene/pomodoro/progress_circle.tres")