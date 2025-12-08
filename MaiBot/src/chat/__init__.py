import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

"""
MaiBot模块系统
包含聊天、情绪、记忆、日程等功能模块
"""

from src.chat.message_receive.chat_stream import get_chat_manager
from src.chat.emoji_system.emoji_manager import get_emoji_manager

# 导出主要组件供外部使用
__all__ = [
    "get_chat_manager",
    "get_emoji_manager",
]
