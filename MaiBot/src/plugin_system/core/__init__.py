import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

"""
插件核心管理模块

提供插件的加载、注册和管理功能
"""

from src.plugin_system.core.plugin_manager import plugin_manager
from src.plugin_system.core.component_registry import component_registry
from src.plugin_system.core.events_manager import events_manager
from src.plugin_system.core.global_announcement_manager import global_announcement_manager

__all__ = [
    "plugin_manager",
    "component_registry",
    "events_manager",
    "global_announcement_manager",
]
