extends Node

const WS_URL = "ws://127.0.0.1:8765/ws"

var socket = WebSocketPeer.new()
var connection_status = DISCONNECTED
var pending_messages: Array[Dictionary] = []
var message_counter = 0


enum {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	ERROR
}

signal message_received(text: String, emotion: String, player_id: String)
signal connection_changed(status: int)

func _ready():
	print("🚀 xxClient 单例已初始化")
	await get_tree().create_timer(1.0).timeout
	connect_to_mai()

func connect_to_mai():
	if connection_status != DISCONNECTED:
		return
	
	print("🔄 xxClient: 正在连接...")
	connection_status = CONNECTING
	connection_changed.emit(CONNECTING)
	
	var tls_options = TLSOptions.client_unsafe()
	socket.connect_to_url(WS_URL, tls_options)

func send_message(player_id: String, content: String) -> void:
	var message_id = "godot_" + str(Time.get_unix_time_from_system()) + "_" + str(message_counter)
	message_counter += 1
	
	var payload = {
		"message_info": {
			"platform": "godot",
			"message_id": message_id,
			"time": Time.get_unix_time_from_system(),
			"user_info": {
				"platform": "godot",
				"user_id": player_id,
				"user_nickname": "Player_" + player_id,
				"user_cardname": null
			},
			"group_info": null,
			"format_info": {
				"content_format": ["text"],
				"accept_format": ["text"]
			},
			"template_info": null,
			"additional_config": null
		},
		"message_segment": {
			"type": "seglist",
			"data": [
				{
					"type": "text",
					"data": content
				}
			]
		},
		"raw_message": null
	}
	
	if connection_status == CONNECTED:
		socket.send_text(JSON.stringify(payload))
		print("📤 发送到xxBot: %s" % content)
	else:
		pending_messages.append(payload)
		push_warning("xxBot未连接，消息已加入队列")

# ✅ 终极修复：不依赖 get_available_packet_count()
func _process(delta):
	socket.poll()
	var state = socket.get_ready_state()
	
	match state:
		WebSocketPeer.STATE_OPEN:
			if connection_status != CONNECTED:
				connection_status = CONNECTED
				connection_changed.emit(CONNECTED)
				print("✅ xxClient: 已连接!")
				_send_pending_messages()
			
			# ✅ 持续轮询读取，直到没有数据
			while true:
				var packet = socket.get_packet()
				if packet.size() == 0:
					break  # 没有数据，退出
				
				print("📦 收到数据包！大小: %d 字节" % packet.size())
				var response_text = packet.get_string_from_utf8()
				print("📜 原始响应: %s" % response_text)
				
				var response = JSON.parse_string(response_text)
				if response and response.has("message_segment"):
					var seg_data = response.message_segment
					if seg_data and seg_data.has("data") and seg_data.data.size() > 0:
						var first_seg = seg_data.data[0]
						if first_seg.has("data"):
							var reply_text = first_seg.data
							print("✅ 提取回复: %s" % reply_text)
							message_received.emit(reply_text, "neutral", "player_001")
							print("🚀 信号已触发")
		
		WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
			if connection_status != DISCONNECTED:
				connection_status = DISCONNECTED
				connection_changed.emit(DISCONNECTED)
				print("⚠️ xxClient: 连接断开")
		
		WebSocketPeer.STATE_CONNECTING:
			pass

func _send_pending_messages():
	while not pending_messages.is_empty():
		var msg = pending_messages.pop_front()
		socket.send_text(JSON.stringify(msg))
		print("📤 发送队列消息")

func is_mai_connected() -> bool:
	return connection_status == CONNECTED

func get_connection_status() -> int:
	return connection_status
