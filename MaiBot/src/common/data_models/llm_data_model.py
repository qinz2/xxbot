import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

from dataclasses import dataclass
from typing import Optional, List, TYPE_CHECKING

from . import BaseDataModel

if TYPE_CHECKING:
    from src.common.data_models.message_data_model import ReplySetModel
    from src.llm_models.payload_content.tool_option import ToolCall


@dataclass
class LLMGenerationDataModel(BaseDataModel):
    content: Optional[str] = None
    reasoning: Optional[str] = None
    model: Optional[str] = None
    tool_calls: Optional[List["ToolCall"]] = None
    prompt: Optional[str] = None
    selected_expressions: Optional[List[int]] = None
    reply_set: Optional["ReplySetModel"] = None
