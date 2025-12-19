class_name RealWeatherAPI
extends Node

# 真实天气API - 集成免费开源天气服务

# 信号定义
signal weather_received(weather_data: Dictionary)
signal forecast_received(forecast_data: Array)
signal error_occurred(message: String)

# HTTP请求节点
var http_request: HTTPRequest
var geocoding_request: HTTPRequest

# API配置 - 使用完全免费的服务
var current_api_provider: String = "wttr"

# 免费API URLs - 无需API密钥
var api_urls: Dictionary = {
	"wttr": {
		"current": "https://wttr.in"
	},
	"open_meteo": {
		"current": "https://api.open-meteo.com/v1/forecast",
		"geocoding": "https://geocoding-api.open-meteo.com/v1/search"
	},
	"7timer": {
		"current": "http://www.7timer.info/bin/api.pl"
	}
}

# 城市坐标缓存
var city_coordinates: Dictionary = {}

func _ready():
	# 创建HTTP请求节点
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	http_request.timeout = 10.0
	
	# 创建地理编码请求节点
	geocoding_request = HTTPRequest.new()
	add_child(geocoding_request)
	geocoding_request.request_completed.connect(_on_geocoding_completed)
	geocoding_request.timeout = 10.0
	
	# 加载城市坐标缓存
	load_city_cache()

# 获取当前天气
func get_current_weather(city_name: String) -> void:
	if city_name.is_empty():
		error_occurred.emit("请输入城市名称")
		return
	
	match current_api_provider:
		"wttr":
			_fetch_wttr_weather(city_name)
		"open_meteo":
			# 检查是否已有城市坐标
			if city_coordinates.has(city_name):
				var coords = city_coordinates[city_name]
				_fetch_open_meteo_weather(coords.lat, coords.lon, city_name)
			else:
				# 先获取城市坐标
				_fetch_city_coordinates(city_name)
		"7timer":
			_fetch_7timer_weather(city_name)
		_:
			error_occurred.emit("不支持的API提供商")

# 使用wttr.in API获取天气数据
func _fetch_wttr_weather(city_name: String) -> void:
	var url = "%s/%s?format=j1&lang=zh" % [
		api_urls["wttr"]["current"],
		city_name.uri_encode()
	]
	
	# 存储城市名称以便后续使用
	http_request.set_meta("city_name", city_name)
	http_request.set_meta("api_provider", "wttr")
	
	var error = http_request.request(url)
	if error != OK:
		error_occurred.emit("网络请求失败: " + str(error))

# 使用7Timer! API获取天气数据
func _fetch_7timer_weather(city_name: String) -> void:
	# 7Timer需要坐标，这里简化处理，使用一些主要城市的坐标
	var city_coords = {
		"北京": {"lat": 39.9042, "lon": 116.4074},
		"上海": {"lat": 31.2304, "lon": 121.4737},
		"广州": {"lat": 23.1291, "lon": 113.2644},
		"深圳": {"lat": 22.5431, "lon": 114.0579},
		"杭州": {"lat": 30.2741, "lon": 120.1551},
		"南京": {"lat": 32.0603, "lon": 118.7969}
	}
	
	if not city_coords.has(city_name):
		error_occurred.emit("7Timer暂不支持该城市，请尝试其他城市")
		return
	
	var coords = city_coords[city_name]
	var url = "%s?lon=%f&lat=%f&product=civillight&output=json" % [
		api_urls["7timer"]["current"],
		coords.lon,
		coords.lat
	]
	
	http_request.set_meta("city_name", city_name)
	http_request.set_meta("api_provider", "7timer")
	
	var error = http_request.request(url)
	if error != OK:
		error_occurred.emit("网络请求失败: " + str(error))

# 获取城市坐标（地理编码）- 仅用于Open-Meteo
func _fetch_city_coordinates(city_name: String) -> void:
	var url = "%s?name=%s&count=1&language=zh&format=json" % [
		api_urls["open_meteo"]["geocoding"],
		city_name.uri_encode()
	]
	
	# 保存原始城市名称
	geocoding_request.set_meta("original_city_name", city_name)
	
	var error = geocoding_request.request(url)
	if error != OK:
		error_occurred.emit("网络请求失败: " + str(error))

# 使用Open-Meteo API获取天气数据
func _fetch_open_meteo_weather(latitude: float, longitude: float, city_name: String) -> void:
	var url = "%s?latitude=%.4f&longitude=%.4f&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m&timezone=auto" % [
		api_urls["open_meteo"]["current"],
		latitude,
		longitude
	]
	
	# 存储城市名称以便后续使用
	http_request.set_meta("city_name", city_name)
	http_request.set_meta("api_provider", "open_meteo")
	
	var error = http_request.request(url)
	if error != OK:
		error_occurred.emit("网络请求失败: " + str(error))

# 处理地理编码响应
func _on_geocoding_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("网络连接失败")
		return
	
	if response_code != 200:
		error_occurred.emit("无法找到该城市")
		return
	
	# 解析JSON
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		error_occurred.emit("地理编码数据解析失败")
		return
	
	var data = json.data
	if not data.has("results") or data["results"].size() == 0:
		error_occurred.emit("找不到该城市")
		return
	
	var city_info = data["results"][0]
	var api_city_name = city_info.get("name", "未知城市")
	var latitude = city_info.get("latitude", 0.0)
	var longitude = city_info.get("longitude", 0.0)
	
	# 获取用户输入的原始城市名称
	var original_city_name = geocoding_request.get_meta("original_city_name", api_city_name)
	
	# 缓存城市坐标（使用原始输入的城市名称作为键）
	city_coordinates[original_city_name] = {"lat": latitude, "lon": longitude}
	save_city_cache()
	
	# 获取天气数据（使用原始城市名称）
	_fetch_open_meteo_weather(latitude, longitude, original_city_name)

# 处理天气数据响应
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("网络连接失败")
		return
	
	if response_code != 200:
		_handle_api_error(response_code, body)
		return
	
	# 解析JSON
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		error_occurred.emit("数据解析失败")
		return
	
	var data = json.data
	var api_provider = http_request.get_meta("api_provider", "unknown")
	
	# 根据API提供商解析数据
	match api_provider:
		"wttr":
			_parse_wttr_data(data)
		"open_meteo":
			_parse_open_meteo_data(data)
		"7timer":
			_parse_7timer_data(data)
		_:
			error_occurred.emit("未知的API提供商")

# 解析wttr.in数据
func _parse_wttr_data(data: Dictionary) -> void:
	if not data.has("current_condition") or not data.has("nearest_area"):
		error_occurred.emit("天气数据格式错误")
		return
	
	var current = data["current_condition"][0]
	var area_info = data["nearest_area"][0]
	var city_name = http_request.get_meta("city_name", "未知城市")
	
	# 优先使用用户输入的城市名称，确保显示正确
	# 如果API返回了更准确的地名，可以选择使用
	if area_info.has("areaName") and area_info["areaName"].size() > 0:
		var api_area_name = area_info["areaName"][0].get("value", "")
		# 只有当API返回的名称不为空且看起来更准确时才使用
		if not api_area_name.is_empty() and api_area_name.length() > 1:
			# 保持用户输入的城市名称，但可以在调试时显示API返回的名称
			print("用户输入: %s, API返回: %s" % [city_name, api_area_name])
	
	var weather_data = {
		"city": city_name,
		"temperature": float(current.get("temp_C", 0.0)),
		"feels_like": float(current.get("FeelsLikeC", 0.0)),
		"humidity": int(current.get("humidity", 0)),
		"pressure": float(current.get("pressure", 0.0)),
		"description": str(current.get("lang_zh", [{"value": "未知"}])[0].get("value", "未知")),
		"wind_speed": float(current.get("windspeedKmph", 0.0)) / 3.6,  # 转换为m/s
		"wind_direction": int(current.get("winddirDegree", 0)),
		"visibility": float(current.get("visibility", 0.0)),
		"api_provider": "wttr.in (免费准确)"
	}
	
	weather_received.emit(weather_data)

# 解析7Timer数据
func _parse_7timer_data(data: Dictionary) -> void:
	if not data.has("dataseries") or data["dataseries"].size() == 0:
		error_occurred.emit("天气数据格式错误")
		return
	
	var current = data["dataseries"][0]
	var city_name = http_request.get_meta("city_name", "未知城市")
	
	# 7Timer使用特殊的天气代码
	var weather_code = str(current.get("weather", ""))
	var weather_description = _get_7timer_weather_description(weather_code)
	
	var weather_data = {
		"city": city_name,
		"temperature": float(current.get("temp2m", 0.0)),
		"humidity": int(current.get("rh2m", 0)),
		"description": weather_description,
		"wind_speed": float(current.get("wind10m", {}).get("speed", 0.0)),
		"wind_direction": int(current.get("wind10m", {}).get("direction", 0)),
		"api_provider": "7Timer! (数值预报)"
	}
	
	weather_received.emit(weather_data)

# 解析Open-Meteo数据
func _parse_open_meteo_data(data: Dictionary) -> void:
	if not data.has("current"):
		error_occurred.emit("天气数据格式错误")
		return
	
	var current = data["current"]
	var city_name = http_request.get_meta("city_name", "未知城市")
	
	# 获取天气代码对应的描述
	var weather_code = int(current.get("weather_code", 0))
	var weather_description = _get_weather_description(weather_code)
	
	var weather_data = {
		"city": city_name,
		"temperature": float(current.get("temperature_2m", 0.0)),
		"humidity": int(current.get("relative_humidity_2m", 0)),
		"description": weather_description,
		"wind_speed": float(current.get("wind_speed_10m", 0.0)),
		"wind_direction": int(current.get("wind_direction_10m", 0)),
		"api_provider": "Open-Meteo (免费开源)"
	}
	
	weather_received.emit(weather_data)

# 根据7Timer天气代码获取中文描述
func _get_7timer_weather_description(code: String) -> String:
	match code:
		"clear": return "晴天"
		"pcloudy": return "少云"
		"mcloudy": return "多云"
		"cloudy": return "阴天"
		"humid": return "潮湿"
		"lightrain": return "小雨"
		"oshower": return "阵雨"
		"ishower": return "间歇性阵雨"
		"lightsnow": return "小雪"
		"rain": return "雨"
		"snow": return "雪"
		"rainsnow": return "雨夹雪"
		"ts": return "雷暴"
		"tsrain": return "雷阵雨"
		_: return "未知天气"

# 根据WMO天气代码获取中文描述
func _get_weather_description(code: int) -> String:
	match code:
		0: return "晴天"
		1: return "基本晴朗"
		2: return "部分多云"
		3: return "阴天"
		45: return "雾"
		48: return "雾凇"
		51: return "小毛毛雨"
		53: return "毛毛雨"
		55: return "大毛毛雨"
		56: return "冻毛毛雨"
		57: return "大冻毛毛雨"
		61: return "小雨"
		63: return "中雨"
		65: return "大雨"
		66: return "冻雨"
		67: return "大冻雨"
		71: return "小雪"
		73: return "中雪"
		75: return "大雪"
		77: return "雪粒"
		80: return "小阵雨"
		81: return "阵雨"
		82: return "大阵雨"
		85: return "小阵雪"
		86: return "大阵雪"
		95: return "雷暴"
		96: return "雷暴伴小冰雹"
		99: return "雷暴伴大冰雹"
		_: return "未知天气"

# 处理API错误
func _handle_api_error(response_code: int, body: PackedByteArray) -> void:
	var error_message = "API请求失败 (%d)" % response_code
	
	match response_code:
		401:
			error_message = "API密钥无效，请检查设置"
		403:
			error_message = "API访问被拒绝"
		404:
			error_message = "找不到该城市"
		429:
			error_message = "API请求次数超限，请稍后再试"
		500:
			error_message = "天气服务暂时不可用"
	
	error_occurred.emit(error_message)

# 保存城市坐标缓存
func save_city_cache() -> void:
	var file = FileAccess.open("user://weather_city_cache.json", FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(city_coordinates)
		file.store_string(json_string)
		file.close()

# 加载城市坐标缓存
func load_city_cache() -> void:
	var file = FileAccess.open("user://weather_city_cache.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			if data is Dictionary:
				city_coordinates = data

# 获取API状态
func get_api_status() -> Dictionary:
	var provider_names = {
		"wttr": "wttr.in (免费准确)",
		"open_meteo": "Open-Meteo (免费开源)",
		"7timer": "7Timer! (数值预报)"
	}
	
	return {
		"current_provider": provider_names.get(current_api_provider, current_api_provider),
		"api_key_configured": true,  # 免费API，无需密钥
		"available_providers": provider_names.values(),
		"description": "使用完全免费的天气API，无需注册或API密钥"
	}

# 切换API提供商
func switch_api_provider(provider: String) -> void:
	if api_urls.has(provider):
		current_api_provider = provider
		print("已切换到API提供商: ", provider)

# 测试API连接
func test_api_connection() -> void:
	get_current_weather("北京")  # 使用北京测试连接

# 清除城市缓存
func clear_city_cache() -> void:
	city_coordinates.clear()
	save_city_cache()
