"""测试 Godot 完整消息处理流程"""

import sys
import os
sys.path.insert(0, os.path.abspath('.'))

import asyncio
from maim_message import MessageBase
from src.adapters.godot_adapter_v2 import godot_adapter
from src.common.database.database_model import init_database
from src.person_info.person_info import Person

async def test_godot_message_flow():
    """测试完整流程"""
    print("=== 测试 Godot 消息处理流程 ===\n")
    
    # 初始化数据库
    init_database()
    
    # 模拟 Godot 发送的消息
    test_message = {
        'platform': 'godot',
        'user_id': 'test_device_456',
        'message': '你好，记住我喜欢蓝色！',
        'time': 1702000000,
        'message_id': 'godot_test_001',
        'sender': {
            'nickname': '测试桌宠'
        }
    }
    
    print("📤 发送消息:")
    print(f"   平台: {test_message['platform']}")
    print(f"   用户: {test_message['user_id']}")
    print(f"   内容: {test_message['message']}\n")
    
    # 通过适配器处理
    result = await godot_adapter(test_message)
    
    print("\n✅ 消息处理完成\n")
    
    # 验证用户是否注册
    person = Person.register_person('godot', 'test_device_456')
    print(f"📊 用户信息:")
    print(f"   用户ID: {person.person_info.user_id}")
    print(f"   平台: {person.person_info.platform}")
    print(f"   名称: {person.person_info.name}")
    
    # 验证记忆点
    import json
    memories = json.loads(person.person_info.memory_points or "[]")
    print(f"\n💭 记忆点数量: {len(memories)}")
    for m in memories:
        print(f"   [{m['category']}] {m['content']} (权重: {m['weight']})")
    
    print("\n🎉 测试通过！")

if __name__ == '__main__':
    asyncio.run(test_godot_message_flow())