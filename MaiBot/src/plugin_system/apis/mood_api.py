import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

import asyncio
from typing import Optional

from src.common.logger import get_logger
from src.mood.mood_manager import mood_manager

logger = get_logger("mood_api")


async def get_mood_by_chat_id(chat_id: str) -> Optional[float]:
    chat_mood = mood_manager.get_mood_by_chat_id(chat_id)
    mood = asyncio.create_task(chat_mood.get_mood())
    return mood
