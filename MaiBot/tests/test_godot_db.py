"""测试 Godot 平台数据库功能"""

import sys
import os
sys.path.insert(0, os.path.abspath('.'))

from src.person_info.person_info import Person, get_person_id
from src.common.database.database_model import init_database

def test_godot_person():
    """测试 Godot 用户注册"""
    print("=== 测试 Godot 用户注册 ===")
    
    # 初始化数据库
    init_database()
    
    # 注册用户
    person = Person.register_person(
        platform='godot',
        user_id='test_device_123',
        name='测试设备',
        device_name='我的电脑'
    )
    
    print(f"✓ 用户ID: {person.person_info.user_id}")
    print(f"✓ 平台: {person.person_info.platform}")
    print(f"✓ 名称: {person.person_info.name}")
    
    # 添加记忆点
    person.add_memory_point("我喜欢蓝色", category='preference')
    person.add_memory_point("记住我的生日是1月1日", category='important')
    
    print(f"✓ 记忆点已添加")
    
    # 获取记忆点
    import json
    memories = json.loads(person.person_info.memory_points)
    print(f"✓ 当前记忆点数量: {len(memories)}")
    for m in memories:
        print(f"  - [{m['category']}] {m['content']}")
    
    print("\n测试通过！✨")

if __name__ == '__main__':
    test_godot_person()