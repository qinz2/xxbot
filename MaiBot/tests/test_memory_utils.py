"""测试 memory_utils 中的 Godot 支持函数"""

import sys
import os
sys.path.insert(0, os.path.abspath('.'))

from src.memory_system.memory_utils import (
    parse_message_for_memory,
    parse_godot_timestamp,
    extract_godot_memory_keywords,
    calculate_godot_memory_similarity
)

def test_parse_godot_message():
    """测试消息解析"""
    print("=== 测试 Godot 消息解析 ===")
    
    message = {
        'user_id': 'test_device_123',
        'text': '你好，我喜欢蓝色',
        'time': 1702000000
    }
    
    parsed = parse_message_for_memory(message, 'godot')
    
    print(f"✓ 用户ID: {parsed['user_id']}")
    print(f"✓ 内容: {parsed['content']}")
    print(f"✓ 时间戳: {parsed['timestamp']}")
    print(f"✓ 平台: {parsed['platform']}")
    assert parsed['platform'] == 'godot'
    assert parsed['user_id'] == 'test_device_123'
    print("✅ 消息解析测试通过\n")


def test_extract_keywords():
    """测试关键词提取函数"""
    print("=== 测试关键词提取 ===")
    # 完整测试用例（包含 event 分类）
    test_cases = [
        ("我喜欢蓝色", "preference", 0.8, False),
        ("记住我的生日是1月1日", "important", 0.9, True),  # 匹配函数的 important 分类
        ("明天有个会议", "event", 0.95, True),             # 新增 event 用例
        ("我想要一个苹果", "demand", 0.7, False),
        ("随便说点什么", "general", 0.5, False)
    ]
    
    for content, expected_category, expected_weight, expected_important in test_cases:
        result = extract_godot_memory_keywords(content)
        
        print(f"\n内容: {content}")
        print(f"  分类: {result['category']} (预期: {expected_category})")
        print(f"  权重: {result['weight']}")
        print(f"  关键词: {result['keywords']}")
        print(f"  重要: {result['is_important']}")
        
        # 断言验证
        assert result['category'] == expected_category, f"分类不匹配: {result['category']} != {expected_category}"
        assert result['weight'] == expected_weight, f"权重不匹配: {result['weight']} != {expected_weight}"
        assert result['is_important'] == expected_important, f"重要性不匹配: {result['is_important']} != {expected_important}"
    
    print("\n✅ 关键词提取测试通过")


def test_similarity():
    """测试相似度计算"""
    print("=== 测试相似度计算 ===")
    
    query = "你知道我喜欢什么颜色吗"
    memory1 = "我喜欢蓝色"
    memory2 = "今天天气很好"
    
    sim1 = calculate_godot_memory_similarity(query, memory1, 'preference')
    sim2 = calculate_godot_memory_similarity(query, memory2, 'general')
    
    print(f"查询: {query}")
    print(f"记忆1: {memory1} -> 相似度: {sim1:.2f}")
    print(f"记忆2: {memory2} -> 相似度: {sim2:.2f}")
    
    assert sim1 > sim2, "相关记忆的相似度应该更高"
    print("✅ 相似度计算测试通过\n")


if __name__ == '__main__':
    test_parse_godot_message()
    test_extract_keywords()
    test_similarity()
    print("🎉 所有测试通过！")