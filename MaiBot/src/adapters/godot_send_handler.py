import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

"""
Godot 发送处理器
拦截发送到 Godot 平台的消息，通过 Router 发送
"""
from maim_message import MessageBase
from src.common.logger import get_logger
from src.chat.message_receive.message import MessageSending

logger = get_logger("godot_sender")

# 全局 Router 引用
_router = None


def set_router(router):
    """设置全局 Router 引用"""
    global _router
    _router = router
    logger.info("[Godot发送器] Router 引用已设置")


async def send_to_godot(message: MessageSending) -> bool:
    """
    发送消息到 Godot
    这个函数会被 monkey patch 到 uni_message_sender 中
    
    Args:
        message: MessageSending 对象
        
    Returns:
        bool: 是否发送成功
    """
    try:
        if _router is None:
            logger.error("[Godot发送器] Router 未设置")
            return False
        
        # 检查是否是 Godot 平台
        if message.message_info.platform != "godot":
            # 不是 Godot 平台，使用默认发送方式
            from src.common.message.api import get_global_api
            await get_global_api().send_message(message)
            return True
        
        logger.info(f"[Godot发送器] 发送消息到 Godot")
        logger.info(f"[Godot发送器] 消息ID: {message.message_info.message_id}")
        logger.info(f"[Godot发送器] 内容: {message.processed_plain_text[:50]}...")
        
        # 转换为 MessageBase
        message_base = MessageBase(
            message_info=message.message_info,
            message_segment=message.message_segment,
            raw_message=message.processed_plain_text
        )
        
        # 通过 Router 发送
        await _router.send_message(message_base)
        
        logger.info("[Godot发送器] ✅ 消息已发送到 Godot")
        return True
        
    except Exception as e:
        logger.error(f"[Godot发送器] ❌ 发送失败: {e}", exc_info=True)
        return False
