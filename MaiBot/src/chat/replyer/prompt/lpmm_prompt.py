import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

from src.chat.utils.prompt_builder import Prompt
# from src.memory_system.memory_activator import MemoryActivator


def init_lpmm_prompt():
    Prompt(
        """
你是一个专门获取知识的助手。你的名字是{bot_name}。现在是{time_now}。
群里正在进行的聊天内容：
{chat_history}

现在，{sender}发送了内容:{target_message},你想要回复ta。
请仔细分析聊天内容，考虑以下几点：
1. 内容中是否包含需要查询信息的问题
2. 是否有明确的知识获取指令

If you need to use the search tool, please directly call the function "lpmm_search_knowledge". If you do not need to use any tool, simply output "No tool needed".
""",
        name="lpmm_get_knowledge_prompt",
    )
