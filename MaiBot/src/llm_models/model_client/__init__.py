import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

from src.config.config import model_config

used_client_types = {provider.client_type for provider in model_config.api_providers}

if "openai" in used_client_types:
    from . import openai_client  # noqa: F401
if "gemini" in used_client_types:
    from . import gemini_client  # noqa: F401
