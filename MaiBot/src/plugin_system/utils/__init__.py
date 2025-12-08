import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

"""
插件系统工具模块

提供插件开发和管理的实用工具
"""

from .manifest_utils import (
    ManifestValidator,
    # ManifestGenerator,
    # validate_plugin_manifest,
    # generate_plugin_manifest,
)

__all__ = [
    "ManifestValidator",
    # "ManifestGenerator",
    # "validate_plugin_manifest",
    # "generate_plugin_manifest",
]
