extends Node

# 测试免费天气API功能

func _ready():
	print("🌤️ 测试免费天气API功能...")
	test_free_weather_api()

func test_free_weather_api():
	print("\n=== 创建免费天气API ===")
	var weather_api = RealWeatherAPI.new()
	add_child(weather_api)
	
	# 连接信号
	weather_api.weather_received.connect(_on_weather_received)
	weather_api.error_occurred.connect(_on_error_occurred)
	
	print("✅ 免费天气API创建成功")
	
	# 测试API状态
	print("\n=== 测试API状态 ===")
	var status = weather_api.get_api_status()
	print("API提供商: %s" % status.current_provider)
	print("API状态: %s" % status.description)
	print("需要密钥: %s" % ("否" if status.api_key_configured else "是"))
	
	# 测试天气查询
	print("\n=== 测试天气查询 ===")
	print("正在查询北京天气...")
	weather_api.get_current_weather("北京")
	
	# 等待响应
	await get_tree().create_timer(5.0).timeout
	
	print("\n正在查询上海天气...")
	weather_api.get_current_weather("上海")
	
	# 等待响应
	await get_tree().create_timer(5.0).timeout
	
	print("\n=== 测试完成 ===")
	get_tree().quit()

func _on_weather_received(weather_data: Dictionary):
	print("\n🎉 收到天气数据:")
	print("  🏙️ 城市: %s" % weather_data.get("city", "未知"))
	print("  🌡️ 温度: %.1f°C" % weather_data.get("temperature", 0.0))
	print("  💧 湿度: %d%%" % weather_data.get("humidity", 0))
	print("  ☁️ 天气: %s" % weather_data.get("description", "未知"))
	print("  💨 风速: %.1f m/s" % weather_data.get("wind_speed", 0.0))
	print("  📡 数据源: %s" % weather_data.get("api_provider", "未知"))

func _on_error_occurred(message: String):
	print("\n❌ 错误: %s" % message)
