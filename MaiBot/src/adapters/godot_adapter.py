import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

"""
Godot 平台适配器
处理 Godot 前端的消息和数据流
"""

import json
import time
from typing import Dict, Any, Optional
from MaiBot.src.person_info.person_info import Person, get_person_id
from MaiBot.src.common.database.database_model import ChatStreams, Messages
from MaiBot.src.memory_system.memory_utils import parse_message_for_memory

class GodotAdapter:
    """Godot 平台适配器"""
    
    def __init__(self):
        self.platform = "godot"
    
    def process_message(self, message_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        处理来自 Godot 的消息
        
        Args:
            message_data: Godot 发送的消息数据
                {
                    'user_id': '设备唯一标识',
                    'text': '消息内容',
                    'time': 时间戳,
                    'device_name': '设备名称'（可选）
                }
        
        Returns:
            处理结果
        """
        try:
            # 1. 解析消息
            user_id = message_data.get('user_id')
            content = message_data.get('text', '')
            device_name = message_data.get('device_name')
            
            if not user_id:
                return {'error': '缺少 user_id'}
            
            # 2. 注册或获取用户
            person = Person.register_person(
                platform=self.platform,
                user_id=user_id,
                name=device_name,
                device_name=device_name
            )
            
            # 3. 保存到聊天流
            stream = self._get_or_create_stream(user_id)
            
            # 4. 保存消息
            message = Messages.create(
                stream_id=stream.stream_id,
                role='user',
                content=content,
                timestamp=time.time()
            )
            
            # 5. 提取记忆点（如果消息重要）
            self._extract_memory_points(person, content)
            
            # 6. 更新最后交互时间
            person.person_info.last_interaction = time.time()
            person.person_info.save()
            
            return {
                'success': True,
                'person_id': get_person_id(self.platform, user_id),
                'message_id': message.id
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def _get_or_create_stream(self, user_id: str) -> ChatStreams:
        """获取或创建聊天流"""
        try:
            stream = ChatStreams.get(
                (ChatStreams.platform == self.platform) &
                (ChatStreams.user_id == user_id)
            )
        except ChatStreams.DoesNotExist:
            stream = ChatStreams.create(
                platform=self.platform,
                user_id=user_id,
                group_id=None,
                stream_id=f"godot_{user_id}_{int(time.time())}",
                create_time=time.time()
            )
        return stream
    
    def _extract_memory_points(self, person: Person, content: str) -> None:
        """
        从消息中提取记忆点
        
        简单规则：
        - 包含"喜欢"、"讨厌"等词 -> preference
        - 包含"记住"、"重要"等词 -> important
        - 否则 -> general
        """
        content_lower = content.lower()
        
        if any(word in content_lower for word in ['喜欢', '爱', '最爱', '偏好']):
            person.add_memory_point(content, category='preference', weight=1.0)
        
        elif any(word in content_lower for word in ['讨厌', '不喜欢', '不要']):
            person.add_memory_point(content, category='preference', weight=0.9)
        
        elif any(word in content_lower for word in ['记住', '重要', '一定要']):
            person.add_memory_point(content, category='important', weight=0.9)
        
        elif any(word in content_lower for word in ['我的名字', '我叫', '我是']):
            person.add_memory_point(content, category='important', weight=1.0)
        
        elif len(content) > 20:  # 较长的消息可能包含事件
            person.add_memory_point(content, category='event', weight=0.7)
    
    def get_person_context(self, user_id: str) -> Dict[str, Any]:
        """
        获取用户的上下文信息（用于生成回复）
        
        Returns:
            {
                'person_info': '用户基本信息',
                'recent_memory': '最近的记忆',
                'preferences': '用户偏好'
            }
        """
        try:
            person = Person.register_person(
                platform=self.platform,
                user_id=user_id
            )
            
            # 解析记忆点
            import json
            memory_points = json.loads(person.person_info.memory_points or "[]")
            
            # 分类整理
            preferences = [m for m in memory_points if m['category'] == 'preference']
            important = [m for m in memory_points if m['category'] == 'important']
            recent = sorted(memory_points, key=lambda x: x['timestamp'], reverse=True)[:5]
            
            return {
                'person_info': person.person_info.person_info or '新用户',
                'recent_memory': [m['content'] for m in recent],
                'preferences': [m['content'] for m in preferences],
                'important_facts': [m['content'] for m in important]
            }
            
        except Exception as e:
            return {'error': str(e)}

# 全局实例
godot_adapter = GodotAdapter()