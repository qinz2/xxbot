class_name SimpleWeatherManager
extends Node

# 简单的天气管理器 - 避免复杂的类型系统

# 信号定义
signal weather_updated(weather_info: Dictionary)
signal error_occurred(message: String)

# 简单的数据存储
var current_weather: Dictionary = {}
var favorite_cities: Array = []

# 真实天气API
var real_weather_api: RealWeatherAPI
var use_real_api: bool = true  # 默认使用真实API，因为是免费的

func _ready():
	# 创建真实天气API
	real_weather_api = RealWeatherAPI.new()
	add_child(real_weather_api)
	
	# 连接真实API信号
	real_weather_api.weather_received.connect(_on_real_weather_received)
	real_weather_api.error_occurred.connect(_on_real_api_error)
	
	# 加载设置
	load_settings()
	
	print("SimpleWeatherManager 初始化完成")

# 获取天气信息
func get_weather(city_name: String) -> void:
	if city_name.is_empty():
		error_occurred.emit("城市名称不能为空")
		return
	
	if use_real_api:
		# 使用真实API
		real_weather_api.get_current_weather(city_name)
	else:
		# 使用模拟数据
		_get_simulated_weather(city_name)

# 获取模拟天气数据
func _get_simulated_weather(city_name: String) -> void:
	# 模拟天气数据 - 根据当前季节调整温度范围
	var current_month = Time.get_date_dict_from_system().month
	var temp_range = _get_seasonal_temperature_range(current_month)
	var seasonal_weather = _get_seasonal_weather_types(current_month)
	
	var weather_data = {
		"city": city_name,
		"temperature": randf_range(temp_range.min, temp_range.max),
		"humidity": randi_range(30, 80),
		"description": seasonal_weather.pick_random(),
		"wind_speed": randf_range(0.0, 8.0),
		"api_provider": "模拟数据"
	}
	
	current_weather = weather_data
	weather_updated.emit(weather_data)

# 添加收藏城市
func add_favorite_city(city_name: String) -> void:
	if city_name.is_empty():
		error_occurred.emit("城市名称不能为空")
		return
	
	if city_name in favorite_cities:
		error_occurred.emit("城市已在收藏列表中")
		return
	
	favorite_cities.append(city_name)
	save_favorites()

# 移除收藏城市
func remove_favorite_city(city_name: String) -> void:
	var index = favorite_cities.find(city_name)
	if index >= 0:
		favorite_cities.remove_at(index)
		save_favorites()

# 获取收藏城市列表
func get_favorite_cities() -> Array:
	return favorite_cities.duplicate()

# 保存收藏列表
func save_favorites() -> void:
	var file = FileAccess.open("user://weather_favorites.json", FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify({"favorites": favorite_cities})
		file.store_string(json_string)
		file.close()

# 加载收藏列表
func load_favorites() -> void:
	var file = FileAccess.open("user://weather_favorites.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			if data is Dictionary and data.has("favorites"):
				favorite_cities = data["favorites"]

# 获取当前天气信息
func get_current_weather() -> Dictionary:
	return current_weather

# 清除所有数据
func clear_all_data() -> void:
	current_weather.clear()
	favorite_cities.clear()
	save_favorites()

# 根据月份获取季节性温度范围
func _get_seasonal_temperature_range(month: int) -> Dictionary:
	match month:
		12, 1, 2:  # 冬季
			return {"min": -5.0, "max": 8.0}
		3, 4, 5:   # 春季
			return {"min": 8.0, "max": 22.0}
		6, 7, 8:   # 夏季
			return {"min": 22.0, "max": 35.0}
		9, 10, 11: # 秋季
			return {"min": 10.0, "max": 25.0}
		_:
			return {"min": 0.0, "max": 20.0}

# 根据月份获取季节性天气类型
func _get_seasonal_weather_types(month: int) -> Array:
	match month:
		12, 1, 2:  # 冬季
			return ["晴天", "多云", "阴天", "小雪", "雾霾", "霜冻"]
		3, 4, 5:   # 春季
			return ["晴天", "多云", "小雨", "阴天", "微风", "温暖"]
		6, 7, 8:   # 夏季
			return ["晴天", "多云", "雷阵雨", "炎热", "闷热", "大雨"]
		9, 10, 11: # 秋季
			return ["晴天", "多云", "小雨", "阴天", "凉爽", "干燥"]
		_:
			return ["晴天", "多云", "阴天"]

# 真实API回调函数
func _on_real_weather_received(weather_data: Dictionary) -> void:
	current_weather = weather_data
	weather_updated.emit(weather_data)

func _on_real_api_error(message: String) -> void:
	error_occurred.emit(message)

# 切换数据源（真实API vs 模拟数据）
func toggle_data_source() -> void:
	use_real_api = not use_real_api
	save_settings()
	print("数据源已切换到: ", "真实API" if use_real_api else "模拟数据")

# 获取API状态
func get_api_status() -> Dictionary:
	var status = real_weather_api.get_api_status()
	status["use_real_api"] = use_real_api
	return status

# 保存设置
func save_settings() -> void:
	var settings = {
		"use_real_api": use_real_api,
		"favorites": favorite_cities
	}
	
	var file = FileAccess.open("user://weather_manager_settings.json", FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(settings)
		file.store_string(json_string)
		file.close()

# 加载设置
func load_settings() -> void:
	var file = FileAccess.open("user://weather_manager_settings.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var settings = json.data
			if settings is Dictionary:
				use_real_api = settings.get("use_real_api", false)
				favorite_cities = settings.get("favorites", [])
