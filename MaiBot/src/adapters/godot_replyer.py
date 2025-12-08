import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

"""
Godot 平台专用的 Replyer
继承自 PrivateReplyer，但不发送消息，而是返回回复内容
"""
import asyncio
from typing import Tuple, Optional
from src.chat.replyer.private_generator import PrivateReplyer
from src.common.logger import get_logger

logger = get_logger("godot_replyer")


class GodotReplyer(PrivateReplyer):
    """
    Godot 平台专用的回复生成器
    与标准 PrivateReplyer 的区别：
    1. 不通过 send_api 发送消息
    2. 直接返回生成的回复内容
    """
    
    async def generate_and_return_reply(
        self,
        extra_info: str = "",
        reply_reason: str = "",
    ) -> Tuple[bool, Optional[str]]:
        """
        生成回复并返回文本内容（不发送）
        
        Returns:
            Tuple[bool, Optional[str]]: (是否成功, 回复文本)
        """
        try:
            logger.info("[GodotReplyer] 开始生成回复...")
            
            # 调用父类的 generate_reply_with_context 生成回复
            success, llm_response = await self.generate_reply_with_context(
                extra_info=extra_info,
                reply_reason=reply_reason,
            )
            
            if not success or llm_response is None:
                logger.error("[GodotReplyer] 生成回复失败")
                return False, None
            
            # 提取回复文本
            reply_text = llm_response.content
            if not reply_text:
                logger.warning("[GodotReplyer] 回复内容为空")
                return False, None
            
            logger.info(f"[GodotReplyer] ✅ 成功生成回复: {reply_text}")
            return True, reply_text
            
        except Exception as e:
            logger.error(f"[GodotReplyer] 生成回复时出错: {e}", exc_info=True)
            return False, None
