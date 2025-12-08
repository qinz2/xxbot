import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

"""
插件系统API模块

提供了插件开发所需的各种API
"""

# 导入所有API模块
from src.plugin_system.apis import (
    chat_api,
    component_manage_api,
    config_api,
    database_api,
    emoji_api,
    generator_api,
    llm_api,
    message_api,
    person_api,
    plugin_manage_api,
    send_api,
    tool_api,
    frequency_api,
    mood_api,
    auto_talk_api,
)
from .logging_api import get_logger
from .plugin_register_api import register_plugin

# 导出所有API模块，使它们可以通过 apis.xxx 方式访问
__all__ = [
    "chat_api",
    "component_manage_api",
    "config_api",
    "database_api",
    "emoji_api",
    "generator_api",
    "llm_api",
    "message_api",
    "person_api",
    "plugin_manage_api",
    "send_api",
    "get_logger",
    "register_plugin",
    "tool_api",
    "frequency_api",
    "mood_api",
    "auto_talk_api",
]
