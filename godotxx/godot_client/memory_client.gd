extends Node

# Python 后端地址
var backend_url = "http://localhost:5000"
var user_id = ""  # 设备唯一标识

func _ready():
    # 生成或加载设备ID
    user_id = _get_or_create_device_id()
    print("设备ID: ", user_id)

func _get_or_create_device_id() -> String:
    """获取或创建设备唯一标识"""
    var config = ConfigFile.new()
    var config_path = "user://device_id.cfg"
    
    if config.load(config_path) == OK:
        return config.get_value("device", "id", "")
    
    # 生成新ID
    var new_id = OS.get_unique_id()
    if new_id == "":
        # 如果系统不支持，生成随机ID
        randomize()
        new_id = "godot_" + str(randi() % 1000000)
    
    config.set_value("device", "id", new_id)
    config.save(config_path)
    return new_id

func send_message(text: String):
    """发送消息到后端"""
    var data = {
        "user_id": user_id,
        "text": text,
        "time": Time.get_unix_time_from_system(),
        "device_name": OS.get_name()
    }
    
    _http_post("/api/godot/message", data)

func get_user_context():
    """获取用户上下文"""
    var url = backend_url + "/api/godot/context?user_id=" + user_id
    _http_get(url)

func _http_post(endpoint: String, data: Dictionary):
    """发送POST请求"""
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_request_completed)
    
    var json = JSON.stringify(data)
    var headers = ["Content-Type: application/json"]
    http.request(backend_url + endpoint, headers, HTTPClient.METHOD_POST, json)

func _http_get(url: String):
    """发送GET请求"""
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_request_completed)
    http.request(url)

func _on_request_completed(result, response_code, headers, body):
    """请求完成回调"""
    if response_code == 200:
        var json = JSON.new()
        var parse_result = json.parse(body.get_string_from_utf8())
        if parse_result == OK:
            print("后端响应: ", json.data)
            emit_signal("response_received", json.data)
    else:
        print("请求失败: ", response_code)

signal response_received(data)