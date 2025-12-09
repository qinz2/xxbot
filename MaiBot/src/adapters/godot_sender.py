"""
Godot 平台消息发送器
负责将 MaiBot 的回复发送到 Godot
"""
from maim_message import MessageBase
from src.common.logger import get_logger

logger = get_logger("godot_sender")


class GodotSender:
    """Godot 平台消息发送器"""
    
    def __init__(self, router):
        self.router = router
        logger.info("[GodotSender] 初始化完成")
    
    async def send_message(self, message: MessageBase) -> bool:
        """
        发送消息到 Godot
        
        Args:
            message: MessageBase 消息对象
            
        Returns:
            bool: 是否发送成功
        """
        try:
            logger.info(f"[GodotSender] 发送消息到 Godot: {message.raw_message}")
            await self.router.send_message(message)
            logger.info("[GodotSender] ✅ 消息发送成功")
            return True
        except Exception as e:
            logger.error(f"[GodotSender] ❌ 发送失败: {e}", exc_info=True)
            return False
