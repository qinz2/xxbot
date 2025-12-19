extends Node

# 测试城市名称显示功能

func _ready():
	print("🏙️ 测试城市名称显示功能...")
	test_city_name_preservation()

func test_city_name_preservation():
	print("\n=== 测试城市名称保持功能 ===")
	
	# 创建天气管理器
	var weather_manager = SimpleWeatherManager.new()
	add_child(weather_manager)
	
	# 连接信号
	weather_manager.weather_updated.connect(_on_weather_updated)
	weather_manager.error_occurred.connect(_on_error_occurred)
	
	print("✅ 天气管理器创建成功")
	
	# 测试不同的城市名称
	var test_cities = ["北京", "上海", "广州", "深圳", "杭州"]
	
	for city in test_cities:
		print("\n🔍 测试城市: %s" % city)
		weather_manager.get_weather(city)
		
		# 等待响应
		await get_tree().create_timer(3.0).timeout
	
	print("\n=== 测试完成 ===")
	get_tree().quit()

func _on_weather_updated(weather_data: Dictionary):
	var input_city = weather_data.get("city", "未知")
	var api_provider = weather_data.get("api_provider", "未知")
	
	print("✅ 城市名称显示测试:")
	print("   📍 显示的城市: %s" % input_city)
	print("   📡 数据源: %s" % api_provider)
	print("   🌡️ 温度: %.1f°C" % weather_data.get("temperature", 0.0))
	
	# 验证城市名称是否正确显示
	if input_city != "未知" and input_city.length() > 0:
		print("   ✅ 城市名称显示正常")
	else:
		print("   ❌ 城市名称显示异常")

func _on_error_occurred(message: String):
	print("❌ 错误: %s" % message)
