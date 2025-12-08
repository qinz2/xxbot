import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

from src.chat.emoji_system.emoji_manager import get_emoji_manager
from src.chat.message_receive.chat_stream import get_chat_manager
from src.chat.message_receive.storage import MessageStorage


__all__ = [
    "get_emoji_manager",
    "get_chat_manager",
    "MessageStorage",
]
