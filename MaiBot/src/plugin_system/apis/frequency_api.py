import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

from src.common.logger import get_logger
from src.chat.frequency_control.frequency_control import frequency_control_manager
from src.config.config import global_config

logger = get_logger("frequency_api")


def get_current_talk_value(chat_id: str) -> float:
    return frequency_control_manager.get_or_create_frequency_control(
        chat_id
    ).get_talk_frequency_adjust() * global_config.chat.get_talk_value(chat_id)


def set_talk_frequency_adjust(chat_id: str, talk_frequency_adjust: float) -> None:
    frequency_control_manager.get_or_create_frequency_control(chat_id).set_talk_frequency_adjust(talk_frequency_adjust)


def get_talk_frequency_adjust(chat_id: str) -> float:
    return frequency_control_manager.get_or_create_frequency_control(chat_id).get_talk_frequency_adjust()
