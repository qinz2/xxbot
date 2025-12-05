import time
import uuid
from maim_message import MessageBase, Seg, BaseMessageInfo, UserInfo, GroupInfo, FormatInfo
from src.chat.message_receive.bot import chat_bot
from src.common.logger import get_logger

logger = get_logger("godot_adapter")


async def godot_adapter(message: MessageBase) -> MessageBase:
    """
    Godot 平台适配器
    接收 MessageBase → 调用 chat_bot → 返回 MessageBase
    """
    logger.info(f"[Godot适配器] 收到消息: {message.to_dict()}")

    try:
        # 1. 提取文本内容
        content = ""
        if message.message_segment and message.message_segment.data:
            for seg in message.message_segment.data:
                if seg.type == "text":
                    content = seg.data
                    break

        if not content:
            raise ValueError("消息中没有找到文本内容")

        # 2. 构建 chat_bot 需要的内部格式
        # 注意：字段必须与 message_receive 模块期望的完全一致
        internal_msg = {
            "message_id": message.message_info.message_id,
            "platform": "godot",  # 平台标识
            "user_id": message.message_info.user_info.user_id,
            "group_id": message.message_info.group_info.group_id if message.message_info.group_info else None,
            "message": [{"type": "text", "data": {"text": content}}],
            "time": int(message.message_info.time),
            "raw_message": content,
            "sender": {
                "user_id": message.message_info.user_info.user_id,
                "nickname": message.message_info.user_info.user_nickname or "Godot玩家",
                "role": "member"
            },
            "message_type": "group" if message.message_info.group_info else "private"
        }

        # 3. 调用 chat_bot 处理
        response = await chat_bot.message_process(internal_msg)

        # 4. 构建回复 MessageBase
        reply_segment = Seg("seglist", [
            Seg("text", response.get("reply", "xx不造该说啥..."))
        ])

        # 复用并更新 message_info
        reply_info = message.message_info
        reply_info.message_id = f"godot_resp_{uuid.uuid4().hex}"
        reply_info.time = time.time()

        return MessageBase(
            message_info=reply_info,
            message_segment=reply_segment,
            raw_message=response.get("reply", "")
        )

    except Exception as e:
        logger.error(f"Godot适配器处理失败: {e}", exc_info=True)

        # 返回错误响应
        error_segment = Seg("seglist", [
            Seg("text", "xx出错了...")
        ])

        return MessageBase(
            message_info=message.message_info,
            message_segment=error_segment,
            raw_message="error"
        )