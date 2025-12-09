"""
Godot 平台适配器 V2
模仿 Napcat 的做法：只负责消息格式转换，让 MaiBot 自动处理
"""
from maim_message import MessageBase
from src.chat.message_receive.bot import chat_bot
from src.common.logger import get_logger

logger = get_logger("godot_adapter")


async def godot_adapter(message) -> MessageBase:
    """
    Godot 平台适配器
    模仿 Napcat 的做法：只负责消息格式转换，让 MaiBot 自动处理
    """
    try:
        logger.info("=" * 80)
        logger.info("[Godot适配器] >>>>>> 收到消息 <<<<<<")
        logger.info("=" * 80)
        
        # 1. 转换为 MessageBase 对象
        if isinstance(message, dict):
            logger.info("[Godot适配器] 消息是字典，转换为 MessageBase")
            message_obj = MessageBase.from_dict(message)
        else:
            logger.info("[Godot适配器] 消息已经是 MessageBase 对象")
            message_obj = message
        
        logger.info(f"[Godot适配器] 消息ID: {message_obj.message_info.message_id}")
        logger.info(f"[Godot适配器] 平台: {message_obj.message_info.platform}")
        logger.info(f"[Godot适配器] 原始消息: {message_obj.raw_message}")
        
        # 2. 发送到 MaiBot 的标准消息处理流程
        # 让 chat_bot.message_process 自动处理（包括生成回复和发送）
        logger.info("[Godot适配器] 发送到 MaiBot 处理...")
        await chat_bot.message_process(message_obj.to_dict())
        
        logger.info("[Godot适配器] ✅ 消息已提交到 MaiBot 处理")
        logger.info("=" * 80)
        
        # 3. 返回原消息（MaiBot 会自动通过 send_api 发送回复）
        return message_obj
        
    except Exception as e:
        logger.error(f"[Godot适配器] 错误: {e}", exc_info=True)
        # 返回原消息，避免中断
        return message if isinstance(message, MessageBase) else MessageBase.from_dict(message)
