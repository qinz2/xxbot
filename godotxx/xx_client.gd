extends Node

# ✅ Godot 作为 WebSocket 服务器，Router 作为客户端连接
const WS_PORT = 8765
const WS_PATH = "/ws"

var tcp_server: TCPServer = null
var peers: Array[WebSocketPeer] = []
var message_counter = 0

enum {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	ERROR
}

signal message_received(text: String, emotion: String, player_id: String)
signal connection_changed(status: int)
signal connection_error(error_message: String)

func _ready():
	print("🚀 xxClient 单例已初始化（WebSocket 服务器模式）")
	
	# 创建心跳定时器（用于调试）
	var heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = 5.0
	heartbeat_timer.timeout.connect(_on_heartbeat)
	add_child(heartbeat_timer)
	heartbeat_timer.start()
	
	await get_tree().create_timer(0.5).timeout
	start_server()

func _on_heartbeat():
	"""心跳检测，用于调试"""
	print("💓 心跳: WebSocket服务器运行中，客户端数量=%d" % peers.size())

func start_server():
	"""启动 WebSocket 服务器"""
	print("🔄 xxClient: 启动 WebSocket 服务器，监听端口 %d..." % WS_PORT)
	
	tcp_server = TCPServer.new()
	var error = tcp_server.listen(WS_PORT, "127.0.0.1")
	
	if error != OK:
		push_error("❌ 无法启动服务器: 错误码 %d" % error)
		connection_error.emit("服务器启动失败")
		return
	
	print("✅ xxClient: WebSocket 服务器已启动，监听 ws://127.0.0.1:%d%s" % [WS_PORT, WS_PATH])
	connection_changed.emit(CONNECTED)

func send_message(player_id: String, content: String) -> bool:
	"""发送文本消息到所有连接的客户端（Router）"""
	var payload = _construct_message_payload(player_id, content)
	
	if not _validate_message_structure(payload):
		push_error("❌ 消息结构验证失败")
		return false
	
	if peers.is_empty():
		push_warning("⚠️ 没有连接的客户端")
		return false
	
	var json_str = JSON.stringify(payload)
	print("📤 发送到xxBot: %s" % content)
	print("📋 消息结构: %s" % json_str)
	
	var success = false
	for peer in peers:
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			var error = peer.send_text(json_str)
			if error == OK:
				success = true
			else:
				push_error("❌ 发送失败: 错误码 %d" % error)
	
	return success

func _construct_message_payload(player_id: String, content: String) -> Dictionary:
	"""构造标准的消息payload"""
	var message_id = "godot_" + str(Time.get_unix_time_from_system()) + "_" + str(message_counter)
	message_counter += 1
	
	return {
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

# ✅ WebSocket 服务器模式：接受连接并处理消息
func _process(delta):
	if tcp_server == null:
		return
	
	# 检查新的连接
	if tcp_server.is_connection_available():
		var tcp_peer = tcp_server.take_connection()
		var ws_peer = WebSocketPeer.new()
		ws_peer.accept_stream(tcp_peer)
		peers.append(ws_peer)
		print("✅ 新客户端已连接！当前客户端数量: %d" % peers.size())
	
	# 处理所有已连接的客户端
	var i = 0
	while i < peers.size():
		var peer = peers[i]
		peer.poll()
		var state = peer.get_ready_state()
		
		match state:
			WebSocketPeer.STATE_OPEN:
				# 读取消息
				while peer.get_available_packet_count() > 0:
					var packet = peer.get_packet()
					if packet.size() > 0:
						print("📦 收到数据包！大小: %d 字节" % packet.size())
						var response_text = packet.get_string_from_utf8()
						print("📜 原始响应: %s" % response_text)
						
						var response = JSON.parse_string(response_text)
						print("🔍 JSON解析结果类型: ", typeof(response))
						
						if response == null:
							push_error("❌ JSON解析失败")
							continue
						
						if not response is Dictionary:
							push_error("❌ 响应不是字典类型")
							continue
						
						print("🔍 响应字典keys: ", response.keys())
						
						if response.has("message_segment"):
							print("✅ 响应包含 message_segment")
							var reply_text = _extract_text_from_message(response)
							if reply_text != "":
								print("✅ 提取回复: %s" % reply_text)
								message_received.emit(reply_text, "neutral", "player_001")
								print("🚀 信号已触发")
							else:
								push_warning("⚠️ 无法从消息中提取文本内容")
						else:
							push_warning("⚠️ 响应缺少 message_segment 字段")
				i += 1
			
			WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
				print("⚠️ 客户端断开连接")
				peers.remove_at(i)
				# 不增加 i，因为数组已经移除了元素
			
			_:
				i += 1

func _extract_text_from_message(response: Dictionary) -> String:
	"""从消息响应中提取文本内容，处理各种可能的结构"""
	print("🔍 开始提取文本，响应keys: ", response.keys())
	
	if not response.has("message_segment"):
		push_warning("消息缺少 message_segment 字段")
		return ""
	
	var seg_data = response.message_segment
	print("🔍 message_segment类型: ", typeof(seg_data))
	print("🔍 message_segment内容: ", seg_data)
	
	if not seg_data.has("type"):
		push_warning("message_segment 缺少 type 字段")
		return ""
	
	# 情况1: message_segment 直接是 text 类型
	if seg_data.type == "text":
		print("✅ message_segment 直接是 text 类型")
		if seg_data.has("data"):
			var data = seg_data.data
			if data is String:
				print("✅ 直接提取到字符串: ", data)
				return data
			else:
				print("⚠️ text data 不是字符串，类型: ", typeof(data))
		return ""
	
	# 情况2: message_segment 是 seglist 类型
	if seg_data.type == "seglist":
		print("✅ message_segment 是 seglist 类型")
		if not seg_data.has("data"):
			push_warning("seglist 缺少 data 字段")
			return ""
		
		var segments = seg_data.data
		print("🔍 segments类型: ", typeof(segments))
		print("🔍 segments是数组: ", segments is Array)
		
		if not segments is Array or segments.size() == 0:
			push_warning("seglist.data 不是数组或为空")
			return ""
		
		print("🔍 segments长度: ", segments.size())
		
		# 遍历所有segment，找到第一个text类型的
		for i in range(segments.size()):
			var seg = segments[i]
			print("🔍 处理segment[%d]: %s" % [i, seg])
			
			if not seg is Dictionary:
				print("⚠️ segment不是字典")
				continue
			
			if seg.has("type"):
				print("🔍 segment类型: ", seg.type)
			
			if seg.has("type") and seg.type == "text":
				if seg.has("data"):
					var data = seg.data
					print("🔍 text segment的data类型: ", typeof(data))
					print("🔍 text segment的data内容: ", data)
					
					# data可能是字符串或字典
					if data is String:
						print("✅ 提取到字符串: ", data)
						return data
					elif data is Dictionary and data.has("data"):
						print("✅ 提取到嵌套字符串: ", data.data)
						return data.data
					else:
						print("⚠️ text segment的data格式未知，类型码: ", typeof(data))
		
		print("❌ 未找到text类型的segment")
		return ""
	
	print("⚠️ 未知的 message_segment 类型: ", seg_data.type)
	return ""

func _validate_message_structure(msg: Dictionary) -> bool:
	"""验证消息结构是否完整"""
	if not msg.has("message_info"):
		push_error("消息缺少 message_info")
		return false
	if not msg.has("message_segment"):
		push_error("消息缺少 message_segment")
		return false
	
	var msg_info = msg.message_info
	if not msg_info.has("message_id"):
		push_error("message_info 缺少 message_id")
		return false
	if not msg_info.has("user_info"):
		push_error("message_info 缺少 user_info")
		return false
	
	var msg_segment = msg.message_segment
	if not msg_segment.has("type"):
		push_error("message_segment 缺少 type")
		return false
	if not msg_segment.has("data"):
		push_error("message_segment 缺少 data")
		return false
	
	return true

func stop_server():
	"""停止 WebSocket 服务器"""
	if tcp_server != null:
		tcp_server.stop()
		tcp_server = null
	
	for peer in peers:
		peer.close()
	peers.clear()
	
	print("👋 服务器已停止")
	connection_changed.emit(DISCONNECTED)

func is_mai_connected() -> bool:
	return peers.size() > 0

func get_connection_status() -> int:
	if tcp_server != null and peers.size() > 0:
		return CONNECTED
	elif tcp_server != null:
		return CONNECTING
	else:
		return DISCONNECTED
