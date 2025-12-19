class_name SimpleWeatherUI
extends Control

# 简单的天气UI

# 信号
signal weather_window_closed

# UI节点引用
@onready var title_label: Label = $MainContainer/TitleBar/TitleContainer/Title
@onready var close_button: Button = $MainContainer/TitleBar/TitleContainer/CloseButton
@onready var search_input: LineEdit = $MainContainer/SearchContainer/SearchInput
@onready var search_button: Button = $MainContainer/SearchContainer/SearchButton
@onready var weather_info: Label = $MainContainer/WeatherInfo
@onready var favorites_list: ItemList = $MainContainer/FavoritesList
@onready var add_favorite_button: Button = $MainContainer/ButtonContainer/AddFavoriteButton
@onready var remove_favorite_button: Button = $MainContainer/ButtonContainer/RemoveFavoriteButton
@onready var settings_button: Button = $MainContainer/ButtonContainer/SettingsButton


# 天气管理器
var weather_manager: SimpleWeatherManager

func _ready():
	# 创建天气管理器
	weather_manager = SimpleWeatherManager.new()
	add_child(weather_manager)
	
	# 连接信号
	close_button.pressed.connect(_on_close_pressed)
	search_button.pressed.connect(_on_search_pressed)
	search_input.text_submitted.connect(_on_search_submitted)
	add_favorite_button.pressed.connect(_on_add_favorite_pressed)
	remove_favorite_button.pressed.connect(_on_remove_favorite_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	
	# 连接天气管理器信号
	weather_manager.weather_updated.connect(_on_weather_updated)
	weather_manager.error_occurred.connect(_on_error_occurred)
	
	# 加载收藏列表
	weather_manager.load_favorites()
	_update_favorites_display()
	
	# 设置初始状态
	weather_info.text = "请输入城市名称搜索天气"


func _on_close_pressed():
	weather_window_closed.emit()

func _on_search_pressed():
	var city_name = search_input.text.strip_edges()
	if not city_name.is_empty():
		weather_manager.get_weather(city_name)

func _on_search_submitted(text: String):
	var city_name = text.strip_edges()
	if not city_name.is_empty():
		weather_manager.get_weather(city_name)

func _on_add_favorite_pressed():
	var city_name = search_input.text.strip_edges()
	if not city_name.is_empty():
		weather_manager.add_favorite_city(city_name)
		_update_favorites_display()

func _on_remove_favorite_pressed():
	var selected_items = favorites_list.get_selected_items()
	if selected_items.size() > 0:
		var index = selected_items[0]
		var city_name = favorites_list.get_item_text(index)
		weather_manager.remove_favorite_city(city_name)
		_update_favorites_display()

func _on_weather_updated(weather_data: Dictionary):
	var temp = weather_data.get("temperature", 0.0)
	var temp_desc = ""
	if temp < 0:
		temp_desc = " (严寒)"
	elif temp < 10:
		temp_desc = " (寒冷)"
	elif temp < 20:
		temp_desc = " (凉爽)"
	elif temp < 30:
		temp_desc = " (温暖)"
	else:
		temp_desc = " (炎热)"
	
	var current_date = Time.get_date_string_from_system()
	var api_provider = weather_data.get("api_provider", "未知")
	
	var info_text = "📍 城市: %s\n🌡️ 温度: %.1f°C%s\n💧 湿度: %d%%\n☁️ 天气: %s\n💨 风速: %.1f m/s\n📅 日期: %s\n🔗 数据源: %s" % [
		weather_data.get("city", "未知"),
		temp,
		temp_desc,
		weather_data.get("humidity", 0),
		weather_data.get("description", "未知"),
		weather_data.get("wind_speed", 0.0),
		current_date,
		api_provider
	]
	
	# 如果有额外信息，显示更多详情
	if weather_data.has("feels_like"):
		info_text += "\n🌡️ 体感温度: %.1f°C" % weather_data.get("feels_like", 0.0)
	if weather_data.has("pressure"):
		info_text += "\n🔽 气压: %d hPa" % weather_data.get("pressure", 0)
	if weather_data.has("visibility"):
		info_text += "\n👁️ 能见度: %.1f km" % weather_data.get("visibility", 0.0)
	
	weather_info.text = info_text

func _on_error_occurred(message: String):
	weather_info.text = "错误: " + message

func _update_favorites_display():
	favorites_list.clear()
	var favorites = weather_manager.get_favorite_cities()
	for city in favorites:
		favorites_list.add_item(city)

func _on_settings_pressed():
	_show_api_settings_dialog()

func _show_api_settings_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "天气数据源设置"
	dialog.size = Vector2(500, 400)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	# API状态显示
	var status = weather_manager.get_api_status()
	var status_text = Label.new()
	status_text.text = "🌤️ 当前数据源: %s\n📡 API提供商: %s\n✅ 状态: %s" % [
		"真实天气数据" if status.use_real_api else "模拟数据",
		status.current_provider,
		status.description
	]
	status_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_text)
	
	# 添加间距
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer1)
	
	# API提供商选择
	var provider_label = Label.new()
	provider_label.text = "🔧 选择天气API提供商："
	vbox.add_child(provider_label)
	
	var provider_buttons = VBoxContainer.new()
	vbox.add_child(provider_buttons)
	
	# wttr.in按钮
	var wttr_button = Button.new()
	wttr_button.text = "🌟 wttr.in (推荐) - 准确度高，支持中文"
	wttr_button.pressed.connect(func():
		weather_manager.real_weather_api.switch_api_provider("wttr")
		dialog.queue_free()

		weather_info.text = "已切换到wttr.in API！数据更准确。"
	)
	provider_buttons.add_child(wttr_button)
	
	# Open-Meteo按钮
	var meteo_button = Button.new()
	meteo_button.text = "🌍 Open-Meteo - 开源免费，全球覆盖"
	meteo_button.pressed.connect(func():
		weather_manager.real_weather_api.switch_api_provider("open_meteo")
		dialog.queue_free()

		weather_info.text = "已切换到Open-Meteo API！"
	)
	provider_buttons.add_child(meteo_button)
	
	# 7Timer按钮
	var timer_button = Button.new()
	timer_button.text = "📊 7Timer! - 数值预报，专业准确"
	timer_button.pressed.connect(func():
		weather_manager.real_weather_api.switch_api_provider("7timer")
		dialog.queue_free()
	
		weather_info.text = "已切换到7Timer! API！仅支持主要城市。"
	)
	provider_buttons.add_child(timer_button)
	
	# 添加间距
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer2)
	
	# 数据源切换
	var toggle_button = Button.new()
	toggle_button.text = "🔄 切换到真实数据" if not status.use_real_api else "🔄 切换到模拟数据"
	toggle_button.pressed.connect(func(): 
		weather_manager.toggle_data_source()
		dialog.queue_free()

		weather_info.text = "数据源已切换！请重新搜索天气。"
	)
	vbox.add_child(toggle_button)
	
	# API对比信息
	var info_label = Label.new()
	info_label.text = """📊 API对比：

🌟 wttr.in: 准确度最高，支持中文城市名
🌍 Open-Meteo: 开源透明，全球覆盖
📊 7Timer!: 数值预报，专业气象数据

全部完全免费，无需注册！"""
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)
	
	add_child(dialog)
	dialog.popup_centered()



# 显示加载状态
func show_loading_state():
	weather_info.text = "加载中..."

# 隐藏加载状态
func hide_loading_state():
	pass

# 显示错误信息
func show_error_message(message: String):
	weather_info.text = "错误: " + message

# 显示当前天气
func display_current_weather(weather_data):
	if weather_data is Dictionary:
		_on_weather_updated(weather_data)

# 显示预报（暂时不实现）
func display_forecast(forecast_data):
	pass

# 更新搜索结果（暂时不实现）
func update_search_results(cities):
	pass

# 更新收藏列表
func update_favorites_list(favorites):
	favorites_list.clear()
	for city in favorites:
		if city is String:
			favorites_list.add_item(city)
		elif city is Dictionary and city.has("name"):
			favorites_list.add_item(city["name"])
