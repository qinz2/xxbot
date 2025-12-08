import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

"""
Godot 前端 API 接口
提供 RESTful API 供 Godot 调用
"""

from flask import Flask, request, jsonify
from MaiBot.src.adapters.godot_adapter import godot_adapter

app = Flask(__name__)

@app.route('/api/godot/message', methods=['POST'])
def receive_message():
    """接收 Godot 发送的消息"""
    try:
        data = request.get_json()
        result = godot_adapter.process_message(data)
        return jsonify(result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/godot/context', methods=['GET'])
def get_context():
    """获取用户上下文"""
    try:
        user_id = request.args.get('user_id')
        if not user_id:
            return jsonify({'error': '缺少 user_id'}), 400
        
        context = godot_adapter.get_person_context(user_id)
        return jsonify(context)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/godot/memory/add', methods=['POST'])
def add_memory():
    """手动添加记忆点"""
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        content = data.get('content')
        category = data.get('category', 'general')
        
        from MaiBot.src.person_info.person_info import Person
        person = Person.register_person('godot', user_id)
        person.add_memory_point(content, category)
        
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # 初始化数据库
    from MaiBot.src.common.database.database_model import init_database
    init_database()
    
    # 启动服务器
    print("🚀 Godot API 服务器启动在 http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)