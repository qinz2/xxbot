#!/usr/bin/env python3
"""
从 MongoDB 备份导入数据到 SQLite 数据库
"""
import os
import sys
import json
import sqlite3
from pathlib import Path
import bson
from datetime import datetime
import uuid

# 添加项目根目录到 Python 路径
sys.path.append(str(Path(__file__).parent))

from src.common.database.database_model import *
from src.common.database.database import db

def read_bson_file(file_path):
    """读取 BSON 文件并返回文档列表"""
    documents = []
    try:
        with open(file_path, 'rb') as f:
            data = f.read()
            offset = 0
            while offset < len(data):
                try:
                    # 读取文档长度（前4个字节）
                    if offset + 4 > len(data):
                        break
                    doc_length = int.from_bytes(data[offset:offset+4], 'little')
                    
                    # 读取完整文档
                    if offset + doc_length > len(data):
                        break
                    doc_data = data[offset:offset+doc_length]
                    
                    # 解码文档
                    doc = bson.decode(doc_data)
                    documents.append(doc)
                    
                    offset += doc_length
                except Exception as e:
                    print(f"读取 BSON 文档时出错: {e}")
                    break
    except Exception as e:
        print(f"读取文件 {file_path} 时出错: {e}")
    
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
        'chat_streams.bson': import_chat_streams,
        'llm_usage.bson': import_llm_usage,
        'emoji.bson': import_emoji,
        'messages.bson': import_messages,
        'images.bson': import_images,
        'image_descriptions.bson': import_image_descriptions,
        'online_time.bson': import_online_time,
        'person_info.bson': import_person_info,
    }
    
    for filename, import_func in import_functions.items():
        file_path = backup_dir / filename
        if file_path.exists():
            print(f"导入 {filename}...")
            try:
                import_func(file_path)
                print(f"✅ {filename} 导入成功")
            except Exception as e:
                print(f"❌ {filename} 导入失败: {e}")
        else:
            print(f"⚠️ 文件不存在: {filename}")
    
    db.close()
    print("数据导入完成!")
    return True

def import_chat_streams(file_path):
    """导入聊天流数据"""
    documents = read_bson_file(file_path)
    
    for doc in documents:
        try:
            # 处理 group_info
            group_info = doc.get('group_info', {})
            
            ChatStreams.create(
                stream_id=doc.get('stream_id', ''),
                create_time=doc.get('create_time', 0.0),
                group_platform=group_info.get('platform'),
                group_id=group_info.get('group_id'),
                group_name=group_info.get('group_name'),
                last_active_time=doc.get('last_active_time', 0.0),
                platform=doc.get('platform', ''),
                user_platform=doc.get('user_info', {}).get('platform', ''),
                user_id=doc.get('user_info', {}).get('user_id', ''),
                user_nickname=doc.get('user_info', {}).get('user_nickname', ''),
                user_cardname=doc.get('user_info', {}).get('user_cardname', '')
            )
        except Exception as e:
            print(f"导入 chat_streams 记录失败: {e}")

def import_llm_usage(file_path):
    """导入 LLM 使用记录"""
    documents = read_bson_file(file_path)
    
    for doc in documents:
        try:
            # 处理时间戳
            timestamp = doc.get('timestamp')
            if isinstance(timestamp, dict) and '$date' in timestamp:
                timestamp = datetime.fromisoformat(timestamp['$date'].replace('Z', '+00:00'))
            elif isinstance(timestamp, (int, float)):
                timestamp = datetime.fromtimestamp(timestamp)
            else:
                timestamp = datetime.now()
            
            LLMUsage.create(
                model_name=doc.get('model_name', ''),
                model_assign_name=doc.get('model_assign_name'),
                model_api_provider=doc.get('model_api_provider'),
                user_id=doc.get('user_id', ''),
                request_type=doc.get('request_type', ''),
                endpoint=doc.get('endpoint', ''),
                prompt_tokens=doc.get('prompt_tokens', 0),
                completion_tokens=doc.get('completion_tokens', 0),
                total_tokens=doc.get('total_tokens', 0),
                cost=doc.get('cost', 0.0),
                time_cost=doc.get('time_cost'),
                status=doc.get('status', ''),
                timestamp=timestamp
            )
        except Exception as e:
            print(f"导入 llm_usage 记录失败: {e}")

def import_emoji(file_path):
    """导入表情包数据"""
    documents = read_bson_file(file_path)
    
    for doc in documents:
        try:
            # 处理 emotion 列表
            emotion = doc.get('emotion', [])
            if isinstance(emotion, list):
                emotion = json.dumps(emotion)
            
            Emoji.create(
                full_path=doc.get('full_path', ''),
                format=doc.get('format', ''),
                emoji_hash=doc.get('emoji_hash', ''),
                description=doc.get('description', ''),
                query_count=doc.get('query_count', 0),
                is_registered=doc.get('is_registered', False),
                is_banned=doc.get('is_banned', False),
                emotion=emotion,
                record_time=doc.get('record_time', 0.0),
                register_time=doc.get('register_time'),
                usage_count=doc.get('usage_count', 0),
                last_used_time=doc.get('last_used_time')
            )
        except Exception as e:
            print(f"导入 emoji 记录失败: {e}")

def import_messages(file_path):
    """导入消息数据"""
    documents = read_bson_file(file_path)
    
    for doc in documents:
        try:
            # 处理嵌套的 chat_info
            chat_info = doc.get('chat_info', {})
            user_info = doc.get('user_info', {})
            
            Messages.create(
                message_id=str(doc.get('message_id', '')),
                time=doc.get('time', 0.0),
                chat_id=doc.get('chat_id', ''),
                reply_to=doc.get('reply_to'),
                interest_value=doc.get('interest_value'),
                key_words=doc.get('key_words'),
                key_words_lite=doc.get('key_words_lite'),
                is_mentioned=doc.get('is_mentioned'),
                is_at=doc.get('is_at'),
                reply_probability_boost=doc.get('reply_probability_boost'),
                
                # chat_info 字段
                chat_info_stream_id=chat_info.get('stream_id', ''),
                chat_info_platform=chat_info.get('platform', ''),
                chat_info_user_platform=chat_info.get('user_platform', ''),
                chat_info_user_id=chat_info.get('user_id', ''),
                chat_info_user_nickname=chat_info.get('user_nickname', ''),
                chat_info_user_cardname=chat_info.get('user_cardname'),
                chat_info_group_platform=chat_info.get('group_platform'),
                chat_info_group_id=chat_info.get('group_id'),
                chat_info_group_name=chat_info.get('group_name'),
                chat_info_create_time=chat_info.get('create_time', 0.0),
                chat_info_last_active_time=chat_info.get('last_active_time', 0.0),
                
                # user_info 字段
                user_platform=user_info.get('platform'),
                user_id=user_info.get('user_id'),
                user_nickname=user_info.get('user_nickname'),
                user_cardname=user_info.get('user_cardname'),
                
                processed_plain_text=doc.get('processed_plain_text'),
                display_message=doc.get('display_message'),
                priority_mode=doc.get('priority_mode'),
                priority_info=doc.get('priority_info'),
                additional_config=doc.get('additional_config'),
                is_emoji=doc.get('is_emoji', False),
                is_picid=doc.get('is_picid', False),
                is_command=doc.get('is_command', False),
                is_notify=doc.get('is_notify', False),
                selected_expressions=doc.get('selected_expressions')
            )
        except Exception as e:
            print(f"导入 messages 记录失败: {e}")

def import_images(file_path):
    """导入图片数据"""
    documents = read_bson_file(file_path)
    
    for doc in documents:
        try:
            Images.create(
                image_id=doc.get('image_id', str(uuid.uuid4())),
                emoji_hash=doc.get('emoji_hash', ''),
                description=doc.get('description'),
                path=doc.get('path', ''),
                count=doc.get('count', 1),
                timestamp=doc.get('timestamp', 0.0),
                type=doc.get('type', ''),
                vlm_processed=doc.get('vlm_processed', False)
            )
        except Exception as e:
            print(f"导入 images 记录失败: {e}")

def import_image_descriptions(file_path):
    """导入图片描述数据"""
    documents = read_bson_file(file_path)
    
    for doc in documents:
        try:
            ImageDescriptions.create(
                type=doc.get('type', ''),
                image_description_hash=doc.get('image_description_hash', ''),
                description=doc.get('description', ''),
                timestamp=doc.get('timestamp', 0.0)
            )
        except Exception as e:
            print(f"导入 image_descriptions 记录失败: {e}")

def import_online_time(file_path):
    """导入在线时间数据"""
    documents = read_bson_file(file_path)
    
    for doc in documents:
        try:
            # 处理时间戳
            timestamp = doc.get('timestamp')
            if isinstance(timestamp, dict) and '$date' in timestamp:
                timestamp_str = timestamp['$date']
            else:
                timestamp_str = str(timestamp)
            
            start_timestamp = doc.get('start_timestamp')
            if isinstance(start_timestamp, dict) and '$date' in start_timestamp:
                start_timestamp = datetime.fromisoformat(start_timestamp['$date'].replace('Z', '+00:00'))
            else:
                start_timestamp = datetime.now()
            
            end_timestamp = doc.get('end_timestamp')
            if isinstance(end_timestamp, dict) and '$date' in end_timestamp:
                end_timestamp = datetime.fromisoformat(end_timestamp['$date'].replace('Z', '+00:00'))
            else:
                end_timestamp = datetime.now()
            
            OnlineTime.create(
                timestamp=timestamp_str,
                duration=doc.get('duration', 0),
                start_timestamp=start_timestamp,
                end_timestamp=end_timestamp
            )
        except Exception as e:
            print(f"导入 online_time 记录失败: {e}")

def import_person_info(file_path):
    """导入人员信息数据"""
    documents = read_bson_file(file_path)
    
    for doc in documents:
        try:
            # 处理 group_nick_name 列表
            group_nick_name = doc.get('group_nick_name', [])
            if isinstance(group_nick_name, list):
                group_nick_name = json.dumps(group_nick_name)
            
            PersonInfo.create(
                is_known=doc.get('is_known', False),
                person_id=doc.get('person_id', ''),
                person_name=doc.get('person_name'),
                name_reason=doc.get('name_reason'),
                platform=doc.get('platform', ''),
                user_id=doc.get('user_id', ''),
                nickname=doc.get('nickname'),
                group_nick_name=group_nick_name,
                memory_points=doc.get('memory_points'),
                know_times=doc.get('know_times'),
                know_since=doc.get('know_since'),
                last_know=doc.get('last_know')
            )
        except Exception as e:
            print(f"导入 person_info 记录失败: {e}")

if __name__ == "__main__":
    print("MongoDB 备份数据导入工具")
    print("=" * 50)
    
    if convert_mongodb_to_sqlite():
        print("✅ 数据导入成功完成!")
    else:
        print("❌ 数据导入失败!")