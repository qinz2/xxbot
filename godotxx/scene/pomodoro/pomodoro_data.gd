class_name PomodoroData
extends RefCounted

# 计时器状态枚举
enum TimerState {
	STOPPED,
	RUNNING,
	PAUSED
}

# 会话类型枚举
enum SessionType {
	WORK,
	SHORT_BREAK,
	LONG_BREAK
}

# 闹钟数据类
class AlarmData:
	var id: String
	var name: String
	var time: String  # "HH:MM" 格式
	var enabled: bool
	var repeat_days: Array[int]  # 0=周日, 1=周一, ..., 6=周六
	var snooze_count: int
	
	func _init(p_id: String = "", p_name: String = "", p_time: String = "07:00", p_enabled: bool = true):
		id = p_id if p_id != "" else "alarm_" + str(Time.get_unix_time_from_system())
		name = p_name
		time = p_time
		enabled = p_enabled
		repeat_days = []
		snooze_count = 0
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"time": time,
			"enabled": enabled,
			"repeat_days": repeat_days,
			"snooze_count": snooze_count
		}
	
	static func from_dict(data: Dictionary) -> AlarmData:
		var alarm = AlarmData.new()
		alarm.id = data.get("id", "")
		alarm.name = data.get("name", "")
		alarm.time = data.get("time", "07:00")
		alarm.enabled = data.get("enabled", true)
		alarm.repeat_days = data.get("repeat_days", [])
		alarm.snooze_count = data.get("snooze_count", 0)
		return alarm

# 设置数据类
class SettingsData:
	var work_duration: int = 25 * 60  # 25分钟
	var short_break_duration: int = 5 * 60  # 5分钟
	var long_break_duration: int = 15 * 60  # 15分钟
	var sessions_until_long_break: int = 4
	var sound_enabled: bool = true
	var notification_enabled: bool = true
	var completed_sessions: int = 0
	var last_session_date: String = ""
	var alarms: Array[AlarmData] = []
	
	func to_dict() -> Dictionary:
		var alarms_array = []
		for alarm in alarms:
			alarms_array.append(alarm.to_dict())
		
		return {
			"work_duration": work_duration,
			"short_break_duration": short_break_duration,
			"long_break_duration": long_break_duration,
			"sessions_until_long_break": sessions_until_long_break,
			"sound_enabled": sound_enabled,
			"notification_enabled": notification_enabled,
			"completed_sessions": completed_sessions,
			"last_session_date": last_session_date,
			"alarms": alarms_array
		}
	
	static func from_dict(data: Dictionary) -> SettingsData:
		var settings = SettingsData.new()
		settings.work_duration = data.get("work_duration", 25 * 60)
		settings.short_break_duration = data.get("short_break_duration", 5 * 60)
		settings.long_break_duration = data.get("long_break_duration", 15 * 60)
		settings.sessions_until_long_break = data.get("sessions_until_long_break", 4)
		settings.sound_enabled = data.get("sound_enabled", true)
		settings.notification_enabled = data.get("notification_enabled", true)
		settings.completed_sessions = data.get("completed_sessions", 0)
		settings.last_session_date = data.get("last_session_date", "")
		
		# 加载闹钟数据
		var alarms_data = data.get("alarms", [])
		for alarm_dict in alarms_data:
			settings.alarms.append(AlarmData.from_dict(alarm_dict))
		
		return settings

# 运行时状态数据类
class RuntimeState:
	var current_state: TimerState = TimerState.STOPPED
	var current_session: SessionType = SessionType.WORK
	var remaining_time: float = 0.0
	var session_start_time: int = 0
	var total_session_time: int = 0
	
	func _init():
		reset_to_work_session()
	
	func reset_to_work_session():
		current_state = TimerState.STOPPED
		current_session = SessionType.WORK
		remaining_time = 25 * 60  # 默认25分钟
		session_start_time = 0
		total_session_time = 25 * 60