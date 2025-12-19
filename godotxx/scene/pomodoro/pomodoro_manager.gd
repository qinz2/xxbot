class_name PomodoroManager
extends Node

# 信号定义
signal timer_started(session_type: PomodoroData.SessionType)
signal timer_paused()
signal timer_resumed()
signal timer_stopped()
signal session_completed(session_type: PomodoroData.SessionType)
signal time_updated(remaining_seconds: int)

# 核心属性
var runtime_state: PomodoroData.RuntimeState
var settings: PomodoroData.SettingsData
var timer: Timer

func _init():
	runtime_state = PomodoroData.RuntimeState.new()
	settings = PomodoroData.SettingsData.new()

func _ready():
	# 创建计时器
	timer = Timer.new()
	timer.wait_time = 1.0  # 每秒更新一次
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	
	# 加载设置
	load_settings()
	
	# 初始化运行时状态
	_update_session_duration()

func _on_timer_timeout():
	if runtime_state.current_state == PomodoroData.TimerState.RUNNING:
		runtime_state.remaining_time -= 1.0
		time_updated.emit(int(runtime_state.remaining_time))
		
		if runtime_state.remaining_time <= 0:
			_complete_session()

func start_timer():
	if runtime_state.current_state == PomodoroData.TimerState.STOPPED:
		runtime_state.session_start_time = Time.get_unix_time_from_system()
		_update_session_duration()
	
	runtime_state.current_state = PomodoroData.TimerState.RUNNING
	timer.start()
	timer_started.emit(runtime_state.current_session)

func pause_timer():
	if runtime_state.current_state == PomodoroData.TimerState.RUNNING:
		runtime_state.current_state = PomodoroData.TimerState.PAUSED
		timer.stop()
		timer_paused.emit()

func resume_timer():
	if runtime_state.current_state == PomodoroData.TimerState.PAUSED:
		runtime_state.current_state = PomodoroData.TimerState.RUNNING
		timer.start()
		timer_resumed.emit()

func stop_timer():
	runtime_state.current_state = PomodoroData.TimerState.STOPPED
	timer.stop()
	_update_session_duration()
	timer_stopped.emit()

func reset_session_count():
	settings.completed_sessions = 0
	save_settings()

func _complete_session():
	var completed_session = runtime_state.current_session
	session_completed.emit(completed_session)
	
	# 如果是工作会话，增加计数
	if completed_session == PomodoroData.SessionType.WORK:
		settings.completed_sessions += 1
		save_settings()
	
	# 切换到下一个会话类型
	_switch_to_next_session()
	
	# 停止计时器
	stop_timer()

func _switch_to_next_session():
	match runtime_state.current_session:
		PomodoroData.SessionType.WORK:
			# 检查是否需要长休息
			if settings.completed_sessions % settings.sessions_until_long_break == 0:
				runtime_state.current_session = PomodoroData.SessionType.LONG_BREAK
			else:
				runtime_state.current_session = PomodoroData.SessionType.SHORT_BREAK
		PomodoroData.SessionType.SHORT_BREAK, PomodoroData.SessionType.LONG_BREAK:
			runtime_state.current_session = PomodoroData.SessionType.WORK
	
	_update_session_duration()

func _update_session_duration():
	match runtime_state.current_session:
		PomodoroData.SessionType.WORK:
			runtime_state.remaining_time = settings.work_duration
			runtime_state.total_session_time = settings.work_duration
		PomodoroData.SessionType.SHORT_BREAK:
			runtime_state.remaining_time = settings.short_break_duration
			runtime_state.total_session_time = settings.short_break_duration
		PomodoroData.SessionType.LONG_BREAK:
			runtime_state.remaining_time = settings.long_break_duration
			runtime_state.total_session_time = settings.long_break_duration

func get_current_state() -> PomodoroData.TimerState:
	return runtime_state.current_state

func get_current_session() -> PomodoroData.SessionType:
	return runtime_state.current_session

func get_remaining_time() -> int:
	return int(runtime_state.remaining_time)

func get_completed_sessions() -> int:
	return settings.completed_sessions

func load_settings():
	var file = FileAccess.open("user://pomodoro_settings.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			if data is Dictionary:
				settings = PomodoroData.SettingsData.from_dict(data)
				return
	
	# 如果加载失败，使用默认设置
	settings = PomodoroData.SettingsData.new()

func save_settings():
	var file = FileAccess.open("user://pomodoro_settings.json", FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(settings.to_dict())
		file.store_string(json_string)
		file.close()
	else:
		push_error("无法保存番茄钟设置")

func update_settings(new_settings: PomodoroData.SettingsData):
	settings = new_settings
	save_settings()
	_update_session_duration()