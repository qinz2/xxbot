#!/usr/bin/env python3
"""
从 MongoDB 备份导入数据到 SQLite 数据库

设计要点：
1. 流式读取 BSON：按文档长度前缀逐条从文件读取并解码，避免把整个备份文件一次性读入内存。
2. 事务控制与回滚：每个 .bson 文件在单个 SQLite 事务内导入，任一记录失败则整文件回滚，
   保证数据库不会留下半截迁移数据。
3. 完整性校验：导入后核对「读取文档数 == 写入行数」，不一致即视为失败并回滚。
4. 时间戳解析：正确处理 BSON 解码得到的 datetime 对象（此前错误地回退为 datetime.now()）。
"""
import os
import sys
import json
import sqlite3
from pathlib import Path
from datetime import datetime
import bson
import uuid

# 添加项目根目录到 Python 路径
sys.path.append(str(Path(__file__).parent))

from src.common.database.database_model import *
from src.common.database.database import db


def _parse_bson_datetime(value):
    """把 BSON 中的时间字段统一解析为 datetime。

    BSON 二进制解码后，时间字段本就是 Python datetime 对象；
    同时也兼容 Extended-JSON 的 {"$date": ...} 与 Unix 时间戳两种历史格式。
    无法解析时返回 None，由调用方决定默认值。
    """
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value)
    if isinstance(value, dict) and "$date" in value:
        return datetime.fromisoformat(value["$date"].replace("Z", "+00:00"))
    return None


def read_bson_file(file_path, max_errors: int = 10):
    """流式读取并解码 BSON 文件，返回文档列表。

    不把整个文件读入内存：先读 4 字节长度前缀，再按需读取对应长度的文档体，
    逐条解码。遇到少量损坏文档时跳过并继续，连续错误过多则停止，避免无限卡死。
    """
    documents = []
    errors = 0
    with open(file_path, "rb") as f:
        while True:
            len_bytes = f.read(4)
            if len(len_bytes) < 4:
                break  # 已到文件尾部
            doc_length = int.from_bytes(len_bytes, "little")
            if doc_length < 5:
                # 长度非法且无法定位下一条，停止读取
                break
            # BSON 文档含 4 字节长度前缀，需连同前缀一起传给 bson.decode
            doc_bytes = len_bytes + f.read(doc_length - 4)
            if len(doc_bytes) < doc_length:
                break  # 文件被截断
            try:
                doc = bson.decode(doc_bytes)
                documents.append(doc)
            except Exception as e:
                errors += 1
                print(f"解码 BSON 文档出错（第 {errors} 次）: {e}")
                if errors >= max_errors:
                    print("BSON 解码错误过多，停止读取该文件。")
                    break
    return documents


def convert_mongodb_to_sqlite():
    """将 MongoDB 备份数据转换并导入到 SQLite"""
    backup_dir = Path("../backup/MegBot")

    if not backup_dir.exists():
        print(f"备份目录不存在: {backup_dir}")
        return False

    print("开始导入数据...")

    # 确保数据库连接
    db.connect(reuse_if_open=True)

    # 创建所有表
    print("创建数据库表...")
    create_tables()

    # 导入各个表的数据
    import_functions = {
        "chat_streams.bson": import_chat_streams,
        "llm_usage.bson": import_llm_usage,
        "emoji.bson": import_emoji,
        "messages.bson": import_messages,
        "images.bson": import_images,
        "image_descriptions.bson": import_image_descriptions,
        "online_time.bson": import_online_time,
        "person_info.bson": import_person_info,
    }

    overall_ok = True
    for filename, import_func in import_functions.items():
        file_path = backup_dir / filename
        if not file_path.exists():
            print(f"⚠️ 文件不存在: {filename}")
            continue

        print(f"导入 {filename}...")
        try:
            # 单文件事务：任一记录失败则整文件回滚，保证不留下半截数据
            with db.atomic():
                documents = read_bson_file(file_path)
                n_docs = len(documents)
                n_rows = import_func(documents)
                # 完整性校验：读取数 != 写入数即视为失败并回滚
                if n_rows != n_docs:
                    raise RuntimeError(
                        f"完整性校验失败：读取 {n_docs} 条，实际写入 {n_rows} 条"
                    )
            print(f"✅ {filename} 导入成功（{n_rows}/{n_docs}）")
        except Exception as e:
            overall_ok = False
            print(f"❌ {filename} 导入失败，已回滚: {e}")

    db.close()
    if overall_ok:
        print("数据导入完成!")
    else:
        print("数据导入完成，但部分文件失败（已回滚），请检查上方日志。")
    return overall_ok


def import_chat_streams(documents):
    """导入聊天流数据，返回成功写入的行数"""
    count = 0
    for doc in documents:
        try:
            group_info = doc.get("group_info", {})
            ChatStreams.create(
                stream_id=doc.get("stream_id", ""),
                create_time=doc.get("create_time", 0.0),
                group_platform=group_info.get("platform"),
                group_id=group_info.get("group_id"),
                group_name=group_info.get("group_name"),
                last_active_time=doc.get("last_active_time", 0.0),
                platform=doc.get("platform", ""),
                user_platform=doc.get("user_info", {}).get("platform", ""),
                user_id=doc.get("user_info", {}).get("user_id", ""),
                user_nickname=doc.get("user_info", {}).get("user_nickname", ""),
                user_cardname=doc.get("user_info", {}).get("user_cardname", ""),
            )
            count += 1
        except Exception as e:
            raise RuntimeError(f"导入 chat_streams 记录失败 (stream_id={doc.get('stream_id')}): {e}")
    return count


def import_llm_usage(documents):
    """导入 LLM 使用记录，返回成功写入的行数"""
    count = 0
    for doc in documents:
        try:
            timestamp = _parse_bson_datetime(doc.get("timestamp"))
            if timestamp is None:
                timestamp = datetime.now()
            LLMUsage.create(
                model_name=doc.get("model_name", ""),
                model_assign_name=doc.get("model_assign_name"),
                model_api_provider=doc.get("model_api_provider"),
                user_id=doc.get("user_id", ""),
                request_type=doc.get("request_type", ""),
                endpoint=doc.get("endpoint", ""),
                prompt_tokens=doc.get("prompt_tokens", 0),
                completion_tokens=doc.get("completion_tokens", 0),
                total_tokens=doc.get("total_tokens", 0),
                cost=doc.get("cost", 0.0),
                time_cost=doc.get("time_cost"),
                status=doc.get("status", ""),
                timestamp=timestamp,
            )
            count += 1
        except Exception as e:
            raise RuntimeError(f"导入 llm_usage 记录失败: {e}")
    return count


def import_emoji(documents):
    """导入表情包数据，返回成功写入的行数"""
    count = 0
    for doc in documents:
        try:
            emotion = doc.get("emotion", [])
            if isinstance(emotion, list):
                emotion = json.dumps(emotion)
            Emoji.create(
                full_path=doc.get("full_path", ""),
                format=doc.get("format", ""),
                emoji_hash=doc.get("emoji_hash", ""),
                description=doc.get("description", ""),
                query_count=doc.get("query_count", 0),
                is_registered=doc.get("is_registered", False),
                is_banned=doc.get("is_banned", False),
                emotion=emotion,
                record_time=doc.get("record_time", 0.0),
                register_time=doc.get("register_time"),
                usage_count=doc.get("usage_count", 0),
                last_used_time=doc.get("last_used_time"),
            )
            count += 1
        except Exception as e:
            raise RuntimeError(f"导入 emoji 记录失败: {e}")
    return count


def import_messages(documents):
    """导入消息数据，返回成功写入的行数"""
    count = 0
    for doc in documents:
        try:
            chat_info = doc.get("chat_info", {})
            user_info = doc.get("user_info", {})
            Messages.create(
                message_id=str(doc.get("message_id", "")),
                time=doc.get("time", 0.0),
                chat_id=doc.get("chat_id", ""),
                reply_to=doc.get("reply_to"),
                interest_value=doc.get("interest_value"),
                key_words=doc.get("key_words"),
                key_words_lite=doc.get("key_words_lite"),
                is_mentioned=doc.get("is_mentioned"),
                is_at=doc.get("is_at"),
                reply_probability_boost=doc.get("reply_probability_boost"),

                # chat_info 字段
                chat_info_stream_id=chat_info.get("stream_id", ""),
                chat_info_platform=chat_info.get("platform", ""),
                chat_info_user_platform=chat_info.get("user_platform", ""),
                chat_info_user_id=chat_info.get("user_id", ""),
                chat_info_user_nickname=chat_info.get("user_nickname", ""),
                chat_info_user_cardname=chat_info.get("user_cardname"),
                chat_info_group_platform=chat_info.get("group_platform"),
                chat_info_group_id=chat_info.get("group_id"),
                chat_info_group_name=chat_info.get("group_name"),
                chat_info_create_time=chat_info.get("create_time", 0.0),
                chat_info_last_active_time=chat_info.get("last_active_time", 0.0),

                # user_info 字段
                user_platform=user_info.get("platform"),
                user_id=user_info.get("user_id"),
                user_nickname=user_info.get("user_nickname"),
                user_cardname=user_info.get("user_cardname"),

                processed_plain_text=doc.get("processed_plain_text"),
                display_message=doc.get("display_message"),
                priority_mode=doc.get("priority_mode"),
                priority_info=doc.get("priority_info"),
                additional_config=doc.get("additional_config"),
                is_emoji=doc.get("is_emoji", False),
                is_picid=doc.get("is_picid", False),
                is_command=doc.get("is_command", False),
                is_notify=doc.get("is_notify", False),
                selected_expressions=doc.get("selected_expressions"),
            )
            count += 1
        except Exception as e:
            raise RuntimeError(f"导入 messages 记录失败 (message_id={doc.get('message_id')}): {e}")
    return count


def import_images(documents):
    """导入图片数据，返回成功写入的行数"""
    count = 0
    for doc in documents:
        try:
            Images.create(
                image_id=doc.get("image_id", str(uuid.uuid4())),
                emoji_hash=doc.get("emoji_hash", ""),
                description=doc.get("description"),
                path=doc.get("path", ""),
                count=doc.get("count", 1),
                timestamp=doc.get("timestamp", 0.0),
                type=doc.get("type", ""),
                vlm_processed=doc.get("vlm_processed", False),
            )
            count += 1
        except Exception as e:
            raise RuntimeError(f"导入 images 记录失败: {e}")
    return count


def import_image_descriptions(documents):
    """导入图片描述数据，返回成功写入的行数"""
    count = 0
    for doc in documents:
        try:
            ImageDescriptions.create(
                type=doc.get("type", ""),
                image_description_hash=doc.get("image_description_hash", ""),
                description=doc.get("description", ""),
                timestamp=doc.get("timestamp", 0.0),
            )
            count += 1
        except Exception as e:
            raise RuntimeError(f"导入 image_descriptions 记录失败: {e}")
    return count


def import_online_time(documents):
    """导入在线时间数据，返回成功写入的行数"""
    count = 0
    for doc in documents:
        try:
            timestamp = doc.get("timestamp")
            timestamp_str = timestamp.isoformat() if isinstance(timestamp, datetime) else (
                timestamp["$date"] if isinstance(timestamp, dict) and "$date" in timestamp else str(timestamp)
            )

            start_timestamp = _parse_bson_datetime(doc.get("start_timestamp"))
            if start_timestamp is None:
                start_timestamp = datetime.now()
            end_timestamp = _parse_bson_datetime(doc.get("end_timestamp"))
            if end_timestamp is None:
                end_timestamp = datetime.now()

            OnlineTime.create(
                timestamp=timestamp_str,
                duration=doc.get("duration", 0),
                start_timestamp=start_timestamp,
                end_timestamp=end_timestamp,
            )
            count += 1
        except Exception as e:
            raise RuntimeError(f"导入 online_time 记录失败: {e}")
    return count


def import_person_info(documents):
    """导入人员信息数据，返回成功写入的行数"""
    count = 0
    for doc in documents:
        try:
            group_nick_name = doc.get("group_nick_name", [])
            if isinstance(group_nick_name, list):
                group_nick_name = json.dumps(group_nick_name)
            PersonInfo.create(
                is_known=doc.get("is_known", False),
                person_id=doc.get("person_id", ""),
                person_name=doc.get("person_name"),
                name_reason=doc.get("name_reason"),
                platform=doc.get("platform", ""),
                user_id=doc.get("user_id", ""),
                nickname=doc.get("nickname"),
                group_nick_name=group_nick_name,
                memory_points=doc.get("memory_points"),
                know_times=doc.get("know_times"),
                know_since=doc.get("know_since"),
                last_know=doc.get("last_know"),
            )
            count += 1
        except Exception as e:
            raise RuntimeError(f"导入 person_info 记录失败 (person_id={doc.get('person_id')}): {e}")
    return count


if __name__ == "__main__":
    print("MongoDB 备份数据导入工具")
    print("=" * 50)

    if convert_mongodb_to_sqlite():
        print("✅ 数据导入成功完成!")
    else:
        print("❌ 数据导入失败!")
