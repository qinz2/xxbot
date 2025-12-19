extends Node

# 简单的天气功能测试

func _ready():
	print("开始测试天气功能...")
	test_weather_manager()
	get_tree().quit()

func test_weather_manager():
	print("\n=== 创建天气管理器 ===")
	var weather_manager = SimpleWeatherManager.new()
	add_child(weather_manager)
	
	# 连接信号
	weather_manager.weather_updated.connect(_on_weather_updated)
	weather_manager.error_occurred.connect(_on_error_occurred)
	
	print("天气管理器创建成功")
	
	# 测试季节性温度
	print("\n=== 测试季节性温度范围 ===")
	test_seasonal_temperatures(weather_manager)
	
	# 测试天气查询
	print("\n=== 测试天气查询 ===")
	weather_manager.get_weather("北京")
	
	# 等待一下让信号处理完成
	await get_tree().create_timer(0.1).timeout
	
	# 测试收藏功能
	print("\n=== 测试收藏功能 ===")
	weather_manager.add_favorite_city("上海")
	weather_manager.add_favorite_city("广州")
	var favorites = weather_manager.get_favorite_cities()
	print("收藏城市: ", favorites)
	
	# 测试API状态
	print("\n=== 测试API状态 ===")
	var api_status = weather_manager.get_api_status()
	print("API状态: ", api_status)

func test_seasonal_temperatures(weather_manager: SimpleWeatherManager):
	var months = [1, 3, 6, 9, 12]  # 冬、春、夏、秋、冬
	var season_names = {1: "冬季", 3: "春季", 6: "夏季", 9: "秋季", 12: "冬季"}
	
	for month in months:
		var temp_range = weather_manager._get_seasonal_temperature_range(month)
		var weather_types = weather_manager._get_seasonal_weather_types(month)
		
		print("月份 %d (%s):" % [month, season_names[month]])
		print("  温度范围: %.1f°C - %.1f°C" % [temp_range.min, temp_range.max])
		print("  天气类型: %s" % str(weather_types))
		
		# 生成一个样本温度
		var sample_temp = randf_range(temp_range.min, temp_range.max)
		print("  样本温度: %.1f°C" % sample_temp)

func _on_weather_updated(weather_data: Dictionary):
	print("\n收到天气数据:")
	print("  城市: %s" % weather_data.get("city", "未知"))
	print("  温度: %.1f°C" % weather_data.get("temperature", 0.0))
	print("  湿度: %d%%" % weather_data.get("humidity", 0))
	print("  天气: %s" % weather_data.get("description", "未知"))
	print("  风速: %.1f m/s" % weather_data.get("wind_speed", 0.0))
	print("  数据源: %s" % weather_data.get("api_provider", "未知"))

func _on_error_occurred(message: String):
	print("\n错误信息: %s" % message)