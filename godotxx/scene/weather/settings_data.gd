class_name SettingsData
extends RefCounted

# 天气设置数据
var favorite_cities: Array = []
var auto_refresh_interval: int = 1800  # 30分钟
var temperature_unit: String = "celsius"  # celsius 或 fahrenheit
var language: String = "zh_cn"
var api_timeout: float = 10.0
var max_favorites: int = 10

func _init():
	favorite_cities = []

func to_dict() -> Dictionary:
	var cities_data = []
	for city in favorite_cities:
		if city != null and city.has_method("to_dict"):
			cities_data.append(city.to_dict())
	
	return {
		"favorite_cities": cities_data,
		"auto_refresh_interval": auto_refresh_interval,
		"temperature_unit": temperature_unit,
		"language": language,
		"api_timeout": api_timeout,
		"max_favorites": max_favorites
	}

static func from_dict(data: Dictionary) -> SettingsData:
	var settings = SettingsData.new()
	
	# 加载收藏城市
	var cities_data = data.get("favorite_cities", [])
	for city_data in cities_data:
		if city_data is Dictionary:
			var city = CityInfo.from_dict(city_data)
			settings.favorite_cities.append(city)
	
	settings.auto_refresh_interval = data.get("auto_refresh_interval", 1800)
	settings.temperature_unit = data.get("temperature_unit", "celsius")
	settings.language = data.get("language", "zh_cn")
	settings.api_timeout = data.get("api_timeout", 10.0)
	settings.max_favorites = data.get("max_favorites", 10)
	
	return settings

func add_favorite_city(city: CityInfo) -> bool:
	if city == null or not city.is_valid():
		return false
	
	# 检查是否已存在
	for existing_city in favorite_cities:
		if existing_city.id == city.id:
			return false
	
	# 检查数量限制
	if favorite_cities.size() >= max_favorites:
		return false
	
	favorite_cities.append(city)
	return true

func remove_favorite_city(city_id: String) -> bool:
	for i in range(favorite_cities.size()):
		if favorite_cities[i].id == city_id:
			favorite_cities.remove_at(i)
			return true
	return false

func find_favorite_city(city_id: String) -> CityInfo:
	for city in favorite_cities:
		if city.id == city_id:
			return city
	return null

func is_city_favorite(city_id: String) -> bool:
	return find_favorite_city(city_id) != null

func get_favorites_count() -> int:
	return favorite_cities.size()

func can_add_more_favorites() -> bool:
	return favorite_cities.size() < max_favorites

func clear_favorites() -> void:
	favorite_cities.clear()

func is_valid() -> bool:
	return auto_refresh_interval > 0 and api_timeout > 0 and max_favorites > 0
