extends Node

# ✅ Godot 作为 WebSocket 服务器，Router 作为客户端连接
const WS_PORT = 8765
const WS_PATH = "/ws"

# 图片配置常量
const MAX_IMAGE_SIZE_MB: int = 5  # 降低到 5MB
const MAX_IMAGE_DIMENSION: int = 1024  # 降低到 1024（WebSocket 缓冲区限制）
const SUPPORTED_IMAGE_FORMATS: Array[String] = ["png", "jpg", "jpeg", "bmp", "webp"]
const JPEG_QUALITY: float = 0.8  # JPEG 压缩质量（0.0-1.0）

var tcp_server: TCPServer = null
var peers: Array[WebSocketPeer] = []
var message_counter: int = 0

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
	var payload: Dictionary = _construct_message_payload(player_id, content)
	
	if not _validate_message_structure(payload):
		push_error("❌ 消息结构验证失败")
		return false
	
	if peers.is_empty():
		push_warning("⚠️ 没有连接的客户端")
		return false
	
	var json_str: String = JSON.stringify(payload)
	print("📤 发送到xxBot: %s" % content)
	print("📋 消息结构: %s" % json_str)
	
	var success: bool = false
	for peer in peers:
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			var error: int = peer.send_text(json_str)
			if error == OK:
				success = true
			else:
				push_error("❌ 发送失败: 错误码 %d" % error)
	
	return success


func send_image_with_text(player_id: String, image_path: String, text_message: String = "") -> bool:
	"""发送图文混合消息到所有连接的客户端（Router）
	
	Args:
		player_id: 玩家ID
		image_path: 图片文件路径
		text_message: 可选的文字说明
	
	Returns:
		bool: 发送是否成功
	"""
	# 1. 验证文件存在
	if not FileAccess.file_exists(image_path):
		push_error("❌ 图片文件不存在: %s" % image_path)
		return false
	
	# 2. 验证文件格式
	var file_extension: String = image_path.get_extension().to_lower()
	if not file_extension in SUPPORTED_IMAGE_FORMATS:
		push_error("❌ 不支持的图片格式: %s（支持: %s）" % [file_extension, ", ".join(SUPPORTED_IMAGE_FORMATS)])
		return false
	
	# 3. 加载图片
	var image: Image = Image.load_from_file(image_path)
	if image == null:
		push_error("❌ 无法加载图片（格式不支持或文件损坏）: %s" % image_path)
		return false
	
	print("📷 图片加载成功: %dx%d" % [image.get_width(), image.get_height()])
	
	# 4. 压缩图片（如果需要）
	image = _compress_image_if_needed(image)
	
	# 5. 转换为 JPEG buffer
	var jpeg_buffer: PackedByteArray = image.save_jpg_to_buffer(JPEG_QUALITY)
	if jpeg_buffer.size() == 0:
		push_error("❌ 图片编码失败")
		return false
	
	# 6. 检查文件大小
	var size_mb: float = jpeg_buffer.size() / 1024.0 / 1024.0
	if size_mb > MAX_IMAGE_SIZE_MB:
		push_error("❌ 图片文件过大: %.2f MB（最大: %d MB）" % [size_mb, MAX_IMAGE_SIZE_MB])
		return false
	
	print("📦 图片编码成功: %.2f MB" % size_mb)
	
	# 7. 转换为 base64
	var base64_string: String = Marshalls.raw_to_base64(jpeg_buffer)
	var base64_size_mb: float = base64_string.length() / 1024.0 / 1024.0
	print("🔐 base64 编码完成: %.2f MB (%d 字符)" % [base64_size_mb, base64_string.length()])
	
	# 8. 检查 base64 大小
	if base64_size_mb > 3.0:
		push_error("❌ 编码后数据过大: %.2f MB（建议 < 3 MB）" % base64_size_mb)
		return false
	
	# 9. 构建图文混合消息 payload
	var payload: Dictionary = _construct_mixed_payload(player_id, base64_string, text_message)
	
	# 10. 验证消息结构
	if not _validate_message_structure(payload):
		push_error("❌ 消息结构验证失败")
		return false
	
	# 11. 检查连接
	if peers.is_empty():
		push_warning("⚠️ 没有连接的客户端")
		return false
	
	# 12. 发送
	var json_str: String = JSON.stringify(payload)
	var json_size_mb: float = json_str.length() / 1024.0 / 1024.0
	print("📤 发送图文消息到 xxBot (消息大小: %.2f MB)..." % json_size_mb)
	
	var success: bool = false
	for peer in peers:
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			peer.set_outbound_buffer_size(32 * 1024 * 1024)
			
			var error: int = peer.send_text(json_str)
			if error == OK:
				success = true
				print("✅ 图文消息发送成功")
			elif error == ERR_OUT_OF_MEMORY:
				push_error("❌ 发送失败: 数据过大")
			else:
				push_error("❌ 发送失败: 错误码 %d" % error)
	
	return success


func send_image(player_id: String, image_path: String) -> bool:
	"""发送图片消息到所有连接的客户端（Router）
	
	Args:
		player_id: 玩家ID
		image_path: 图片文件路径（支持绝对路径和 res:// 路径）
	
	Returns:
		bool: 发送是否成功
	"""
	# 1. 验证文件存在
	if not FileAccess.file_exists(image_path):
		push_error("❌ 图片文件不存在: %s" % image_path)
		return false
	
	# 2. 验证文件格式
	var file_extension: String = image_path.get_extension().to_lower()
	if not file_extension in SUPPORTED_IMAGE_FORMATS:
		push_error("❌ 不支持的图片格式: %s（支持: %s）" % [file_extension, ", ".join(SUPPORTED_IMAGE_FORMATS)])
		return false
	
	# 3. 加载图片
	var image: Image = Image.load_from_file(image_path)
	if image == null:
		push_error("❌ 无法加载图片（格式不支持或文件损坏）: %s" % image_path)
		return false
	
	print("📷 图片加载成功: %dx%d" % [image.get_width(), image.get_height()])
	
	# 4. 压缩图片（如果需要）
	image = _compress_image_if_needed(image)
	
	# 5. 转换为 JPEG buffer（比 PNG 小很多）
	var jpeg_buffer: PackedByteArray = image.save_jpg_to_buffer(JPEG_QUALITY)
	if jpeg_buffer.size() == 0:
		push_error("❌ 图片编码失败")
		return false
	
	# 6. 检查文件大小
	var size_mb: float = jpeg_buffer.size() / 1024.0 / 1024.0
	if size_mb > MAX_IMAGE_SIZE_MB:
		push_error("❌ 图片文件过大: %.2f MB（最大: %d MB）" % [size_mb, MAX_IMAGE_SIZE_MB])
		return false
	
	print("📦 图片编码成功: %.2f MB" % size_mb)
	
	# 7. 转换为 base64
	var base64_string: String = Marshalls.raw_to_base64(jpeg_buffer)
	var base64_size_mb: float = base64_string.length() / 1024.0 / 1024.0
	print("🔐 base64 编码完成: %.2f MB (%d 字符)" % [base64_size_mb, base64_string.length()])
	
	# 8. 检查 base64 大小（WebSocket 缓冲区限制）
	# Godot WebSocket 默认缓冲区约 16MB，留一些余量
	if base64_size_mb > 3.0:
		push_error("❌ 编码后数据过大: %.2f MB（建议 < 3 MB）" % base64_size_mb)
		push_error("💡 提示: 请选择更小的图片或降低图片质量")
		return false
	
	# 9. 构建图片消息 payload
	var payload: Dictionary = _construct_image_payload(player_id, base64_string)
	
	# 10. 验证消息结构
	if not _validate_message_structure(payload):
		push_error("❌ 消息结构验证失败")
		return false
	
	# 11. 检查连接
	if peers.is_empty():
		push_warning("⚠️ 没有连接的客户端")
		return false
	
	# 12. 发送
	var json_str: String = JSON.stringify(payload)
	var json_size_mb: float = json_str.length() / 1024.0 / 1024.0
	print("📤 发送图片到 xxBot (消息大小: %.2f MB)..." % json_size_mb)
	
	var success: bool = false
	for peer in peers:
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			# 设置较大的发送缓冲区
			peer.set_outbound_buffer_size(32 * 1024 * 1024)  # 32MB
			
			var error: int = peer.send_text(json_str)
			if error == OK:
				success = true
				print("✅ 图片发送成功")
			elif error == ERR_OUT_OF_MEMORY:
				push_error("❌ 发送失败: 数据过大，超出 WebSocket 缓冲区")
				push_error("💡 提示: 请选择更小的图片（建议 < 1MB）")
			else:
				push_error("❌ 发送失败: 错误码 %d" % error)
	
	return success


func _compress_image_if_needed(image: Image) -> Image:
	"""如果图片过大，自动压缩
	
	Args:
		image: 原始图片
	
	Returns:
		Image: 压缩后的图片（如果需要）或原图片
	"""
	var width: int = image.get_width()
	var height: int = image.get_height()
	
	if width <= MAX_IMAGE_DIMENSION and height <= MAX_IMAGE_DIMENSION:
		return image
	
	# 计算缩放比例
	var scale: float = MAX_IMAGE_DIMENSION / float(max(width, height))
	var new_width: int = int(width * scale)
	var new_height: int = int(height * scale)
	
	print("📐 压缩图片: %dx%d → %dx%d" % [width, height, new_width, new_height])
	
	# 调整图片大小（Godot 4.x 使用 resize 方法）
	image.resize(new_width, new_height, Image.INTERPOLATE_LANCZOS)
	
	return image

func _construct_message_payload(player_id: String, content: String) -> Dictionary:
	"""构造标准的文本消息 payload
	
	Args:
		player_id: 玩家ID
		content: 文本内容
	
	Returns:
		Dictionary: 消息 payload
	"""
	var message_id: String = "godot_txt_%d_%d" % [Time.get_unix_time_from_system(), message_counter]
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
				"accept_format": ["text", "image"]
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


func _construct_mixed_payload(player_id: String, base64_data: String, text_message: String = "") -> Dictionary:
	"""构造图文混合消息 payload
	
	Args:
		player_id: 玩家ID
		base64_data: base64 编码的图片数据
		text_message: 可选的文字说明
	
	Returns:
		Dictionary: 消息 payload
	"""
	var message_id: String = "godot_mixed_%d_%d" % [Time.get_unix_time_from_system(), message_counter]
	message_counter += 1
	
	# 构建消息段列表
	var segments: Array = []
	
	# 如果有文字，先添加文字段
	if not text_message.is_empty():
		segments.append({
			"type": "text",
			"data": text_message
		})
	
	# 添加图片段
	segments.append({
		"type": "image",
		"data": base64_data
	})
	
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
				"content_format": ["text", "image"] if not text_message.is_empty() else ["image"],
				"accept_format": ["text", "image"]
			},
			"template_info": null,
			"additional_config": null
		},
		"message_segment": {
			"type": "seglist",
			"data": segments
		},
		"raw_message": null
	}


func _construct_image_payload(player_id: String, base64_data: String) -> Dictionary:
	"""构造图片消息 payload
	
	Args:
		player_id: 玩家ID
		base64_data: base64 编码的图片数据
	
	Returns:
		Dictionary: 消息 payload
	"""
	var message_id: String = "godot_img_%d_%d" % [Time.get_unix_time_from_system(), message_counter]
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
				"content_format": ["image"],
				"accept_format": ["text", "image"]
			},
			"template_info": null,
			"additional_config": null
		},
		"message_segment": {
			"type": "image",
			"data": base64_data
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
