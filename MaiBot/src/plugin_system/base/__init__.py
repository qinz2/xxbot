import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

"""
插件基础类模块

提供插件开发的基础类和类型定义
"""

from .base_plugin import BasePlugin
from .base_action import BaseAction
from .base_tool import BaseTool
from .base_command import BaseCommand
from .base_events_handler import BaseEventHandler
from .component_types import (
    ComponentType,
    ActionActivationType,
    ChatMode,
    ComponentInfo,
    ActionInfo,
    CommandInfo,
    ToolInfo,
    PluginInfo,
    PythonDependency,
    EventHandlerInfo,
    EventType,
    MaiMessages,
    ToolParamType,
    CustomEventHandlerResult,
    ReplyContentType,
    ReplyContent,
    ForwardNode,
    ReplySetModel,
)
from .config_types import ConfigField

__all__ = [
    "BasePlugin",
    "BaseAction",
    "BaseCommand",
    "BaseTool",
    "ComponentType",
    "ActionActivationType",
    "ChatMode",
    "ComponentInfo",
    "ActionInfo",
    "CommandInfo",
    "ToolInfo",
    "PluginInfo",
    "PythonDependency",
    "ConfigField",
    "EventHandlerInfo",
    "EventType",
    "BaseEventHandler",
    "MaiMessages",
    "ToolParamType",
    "CustomEventHandlerResult",
    "ReplyContentType",
    "ReplyContent",
    "ForwardNode",
    "ReplySetModel",
]
