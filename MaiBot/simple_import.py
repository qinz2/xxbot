#!/usr/bin/env python3
"""
简化版数据导入脚本 - 从 MongoDB 备份导入数据到 SQLite
"""
import os
import json
import sqlite3
from pathlib import Path
import bson
from datetime import datetime
import uuid

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

def create_database():
    """创建 SQLite 数据库和表"""
    db_path = "data/MaiBot.db"
    
    # 确保 data 目录存在
    os.makedirs("data", exist_ok=True)
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 创建所有表
    tables = {
        'chat_streams': '''
            CREATE TABLE IF NOT EXISTS chat_streams (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                stream_id TEXT UNIQUE,
                create_time REAL,
                group_platform TEXT,
                group_id TEXT,
                group_name TEXT,
                last_active_time REAL,
                platform TEXT,
                user_platform TEXT,
                user_id TEXT,
                user_nickname TEXT,
                user_cardname TEXT
            )
        ''',
        'llm_usage': '''
            CREATE TABLE IF NOT EXISTS llm_usage (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                model_name TEXT,
                model_assign_name TEXT,
                model_api_provider TEXT,
                user_id TEXT,
                request_type TEXT,
                endpoint TEXT,
                prompt_tokens INTEGER,
                completion_tokens INTEGER,
                total_tokens INTEGER,
                cost REAL,
                time_cost REAL,
                status TEXT,
                timestamp DATETIME
            )
        ''',
        'emoji': '''
            CREATE TABLE IF NOT EXISTS emoji (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                full_path TEXT UNIQUE,
                format TEXT,
                emoji_hash TEXT,
                description TEXT,
                query_count INTEGER DEFAULT 0,
                is_registered INTEGER DEFAULT 0,
                is_banned INTEGER DEFAULT 0,
                emotion TEXT,
                record_time REAL,
                register_time REAL,
                usage_count INTEGER DEFAULT 0,
                last_used_time REAL
            )
        ''',
        'messages': '''
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                message_id TEXT,
                time REAL,
                chat_id TEXT,
                reply_to TEXT,
                interest_value REAL,
                key_words TEXT,
                key_words_lite TEXT,
                is_mentioned INTEGER,
                is_at INTEGER,
                reply_probability_boost REAL,
                chat_info_stream_id TEXT,
                chat_info_platform TEXT,
                chat_info_user_platform TEXT,
                chat_info_user_id TEXT,
                chat_info_user_nickname TEXT,
                chat_info_user_cardname TEXT,
                chat_info_group_platform TEXT,
                chat_info_group_id TEXT,
                chat_info_group_name TEXT,
                chat_info_create_time REAL,
                chat_info_last_active_time REAL,
                user_platform TEXT,
                user_id TEXT,
                user_nickname TEXT,
                user_cardname TEXT,
                processed_plain_text TEXT,
                display_message TEXT,
                priority_mode TEXT,
                priority_info TEXT,
                additional_config TEXT,
                is_emoji INTEGER DEFAULT 0,
                is_picid INTEGER DEFAULT 0,
                is_command INTEGER DEFAULT 0,
                is_notify INTEGER DEFAULT 0,
                selected_expressions TEXT
            )
        ''',
        'images': '''
            CREATE TABLE IF NOT EXISTS images (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                image_id TEXT DEFAULT '',
                emoji_hash TEXT,
                description TEXT,
                path TEXT UNIQUE,
                count INTEGER DEFAULT 1,
                timestamp REAL,
                type TEXT,
                vlm_processed INTEGER DEFAULT 0
            )
        ''',
        'image_descriptions': '''
            CREATE TABLE IF NOT EXISTS image_descriptions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT,
                image_description_hash TEXT,
                description TEXT,
                timestamp REAL
            )
        ''',
        'online_time': '''
            CREATE TABLE IF NOT EXISTS online_time (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                duration INTEGER,
                start_timestamp DATETIME,
                end_timestamp DATETIME
            )
        ''',
        'person_info': '''
            CREATE TABLE IF NOT EXISTS person_info (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                is_known INTEGER DEFAULT 0,
                person_id TEXT UNIQUE,
                person_name TEXT,
                name_reason TEXT,
                platform TEXT,
                user_id TEXT,
                nickname TEXT,
                group_nick_name TEXT,
                memory_points TEXT,
                know_times REAL,
                know_since REAL,
                last_know REAL
            )
        ''',
        'expression': '''
            CREATE TABLE IF NOT EXISTS expression (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                situation TEXT,
                style TEXT,
                context TEXT,
                up_content TEXT,
                content_list TEXT,
                count INTEGER DEFAULT 1,
                last_active_time REAL,
                chat_id TEXT,
                create_date REAL
            )
        ''',
        'jargon': '''
            CREATE TABLE IF NOT EXISTS jargon (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                content TEXT,
                raw_content TEXT,
                type TEXT,
                translation TEXT,
                meaning TEXT,
                chat_id TEXT,
                is_global INTEGER DEFAULT 0,
                count INTEGER DEFAULT 0,
                is_jargon INTEGER,
                last_inference_count INTEGER,
                is_complete INTEGER DEFAULT 0,
                inference_with_context TEXT,
                inference_content_only TEXT
            )
        ''',
        'chat_history': '''
            CREATE TABLE IF NOT EXISTS chat_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                chat_id TEXT,
                start_time REAL,
                end_time REAL,
                original_text TEXT,
                participants TEXT,
                theme TEXT,
                keywords TEXT,
                summary TEXT,
                count INTEGER DEFAULT 0,
                forget_times INTEGER DEFAULT 0
            )
        ''',
        'thinking_back': '''
            CREATE TABLE IF NOT EXISTS thinking_back (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                chat_id TEXT,
                question TEXT,
                context TEXT,
                found_answer INTEGER DEFAULT 0,
                answer TEXT,
                thinking_steps TEXT,
                create_time REAL,
                update_time REAL
            )
        ''',
        'action_records': '''
            CREATE TABLE IF NOT EXISTS action_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                action_id TEXT,
                time REAL,
                action_reasoning TEXT,
                action_name TEXT,
                action_data TEXT,
                action_done INTEGER DEFAULT 0,
                action_build_into_prompt INTEGER DEFAULT 0,
                action_prompt_display TEXT,
                chat_id TEXT,
                chat_info_stream_id TEXT,
                chat_info_platform TEXT
            )
        '''
    }
    
    for table_name, create_sql in tables.items():
        cursor.execute(create_sql)
        print(f"✅ 创建表: {table_name}")
    
    conn.commit()
    return conn

def import_data():
    """导入所有数据"""
    backup_dir = Path("../backup/MegBot")
    
    if not backup_dir.exists():
        print(f"❌ 备份目录不存在: {backup_dir}")
        return False
    
    print("开始导入数据...")
    
    # 创建数据库
    conn = create_database()
    cursor = conn.cursor()
    
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
            print(f"\n导入 {filename}...")
            try:
                count = import_func(cursor, file_path)
                print(f"✅ {filename} 导入成功，共 {count} 条记录")
            except Exception as e:
                print(f"❌ {filename} 导入失败: {e}")
        else:
            print(f"⚠️ 文件不存在: {filename}")
    
    conn.commit()
    conn.close()
    print("\n🎉 数据导入完成!")
    return True

def import_chat_streams(cursor, file_path):
    """导入聊天流数据"""
    documents = read_bson_file(file_path)
    count = 0
    
    for doc in documents:
        try:
            group_info = doc.get('group_info', {})
            user_info = doc.get('user_info', {})
            
            cursor.execute('''
                INSERT OR REPLACE INTO chat_streams (
                    stream_id, create_time, group_platform, group_id, group_name,
                    last_active_time, platform, user_platform, user_id, user_nickname, user_cardname
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                doc.get('stream_id', ''),
                doc.get('create_time', 0.0),
                group_info.get('platform'),
                group_info.get('group_id'),
                group_info.get('group_name'),
                doc.get('last_active_time', 0.0),
                doc.get('platform', ''),
                user_info.get('platform', ''),
                user_info.get('user_id', ''),
                user_info.get('user_nickname', ''),
                user_info.get('user_cardname', '')
            ))
            count += 1
        except Exception as e:
            print(f"导入 chat_streams 记录失败: {e}")
    
    return count

def import_llm_usage(cursor, file_path):
    """导入 LLM 使用记录"""
    documents = read_bson_file(file_path)
    count = 0
    
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
            
            cursor.execute('''
                INSERT INTO llm_usage (
                    model_name, model_assign_name, model_api_provider, user_id, request_type,
                    endpoint, prompt_tokens, completion_tokens, total_tokens, cost,
                    time_cost, status, timestamp
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                doc.get('model_name', ''),
                doc.get('model_assign_name'),
                doc.get('model_api_provider'),
                doc.get('user_id', ''),
                doc.get('request_type', ''),
                doc.get('endpoint', ''),
                doc.get('prompt_tokens', 0),
                doc.get('completion_tokens', 0),
                doc.get('total_tokens', 0),
                doc.get('cost', 0.0),
                doc.get('time_cost'),
                doc.get('status', ''),
                timestamp
            ))
            count += 1
        except Exception as e:
            print(f"导入 llm_usage 记录失败: {e}")
    
    return count

def import_emoji(cursor, file_path):
    """导入表情包数据"""
    documents = read_bson_file(file_path)
    count = 0
    
    for doc in documents:
        try:
            # 处理 emotion 列表
            emotion = doc.get('emotion', [])
            if isinstance(emotion, list):
                emotion = json.dumps(emotion)
            
            cursor.execute('''
                INSERT OR REPLACE INTO emoji (
                    full_path, format, emoji_hash, description, query_count,
                    is_registered, is_banned, emotion, record_time, register_time,
                    usage_count, last_used_time
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                doc.get('full_path', ''),
                doc.get('format', ''),
                doc.get('emoji_hash', ''),
                doc.get('description', ''),
                doc.get('query_count', 0),
                int(doc.get('is_registered', False)),
                int(doc.get('is_banned', False)),
                emotion,
                doc.get('record_time', 0.0),
                doc.get('register_time'),
                doc.get('usage_count', 0),
                doc.get('last_used_time')
            ))
            count += 1
        except Exception as e:
            print(f"导入 emoji 记录失败: {e}")
    
    return count

def import_messages(cursor, file_path):
    """导入消息数据"""
    documents = read_bson_file(file_path)
    count = 0
    
    for doc in documents:
        try:
            chat_info = doc.get('chat_info', {})
            user_info = doc.get('user_info', {})
            
            cursor.execute('''
                INSERT INTO messages (
                    message_id, time, chat_id, reply_to, interest_value, key_words, key_words_lite,
                    is_mentioned, is_at, reply_probability_boost, chat_info_stream_id,
                    chat_info_platform, chat_info_user_platform, chat_info_user_id,
                    chat_info_user_nickname, chat_info_user_cardname, chat_info_group_platform,
                    chat_info_group_id, chat_info_group_name, chat_info_create_time,
                    chat_info_last_active_time, user_platform, user_id, user_nickname,
                    user_cardname, processed_plain_text, display_message, priority_mode,
                    priority_info, additional_config, is_emoji, is_picid, is_command,
                    is_notify, selected_expressions
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                str(doc.get('message_id', '')),
                doc.get('time', 0.0),
                doc.get('chat_id', ''),
                doc.get('reply_to'),
                doc.get('interest_value'),
                doc.get('key_words'),
                doc.get('key_words_lite'),
                doc.get('is_mentioned'),
                doc.get('is_at'),
                doc.get('reply_probability_boost'),
                chat_info.get('stream_id', ''),
                chat_info.get('platform', ''),
                chat_info.get('user_platform', ''),
                chat_info.get('user_id', ''),
                chat_info.get('user_nickname', ''),
                chat_info.get('user_cardname'),
                chat_info.get('group_platform'),
                chat_info.get('group_id'),
                chat_info.get('group_name'),
                chat_info.get('create_time', 0.0),
                chat_info.get('last_active_time', 0.0),
                user_info.get('platform'),
                user_info.get('user_id'),
                user_info.get('user_nickname'),
                user_info.get('user_cardname'),
                doc.get('processed_plain_text'),
                doc.get('display_message'),
                doc.get('priority_mode'),
                doc.get('priority_info'),
                doc.get('additional_config'),
                int(doc.get('is_emoji', False)),
                int(doc.get('is_picid', False)),
                int(doc.get('is_command', False)),
                int(doc.get('is_notify', False)),
                doc.get('selected_expressions')
            ))
            count += 1
        except Exception as e:
            print(f"导入 messages 记录失败: {e}")
    
    return count

def import_images(cursor, file_path):
    """导入图片数据"""
    documents = read_bson_file(file_path)
    count = 0
    
    for doc in documents:
        try:
            cursor.execute('''
                INSERT OR REPLACE INTO images (
                    image_id, emoji_hash, description, path, count, timestamp, type, vlm_processed
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                doc.get('image_id', str(uuid.uuid4())),
                doc.get('emoji_hash', ''),
                doc.get('description'),
                doc.get('path', ''),
                doc.get('count', 1),
                doc.get('timestamp', 0.0),
                doc.get('type', ''),
                int(doc.get('vlm_processed', False))
            ))
            count += 1
        except Exception as e:
            print(f"导入 images 记录失败: {e}")
    
    return count

def import_image_descriptions(cursor, file_path):
    """导入图片描述数据"""
    documents = read_bson_file(file_path)
    count = 0
    
    for doc in documents:
        try:
            cursor.execute('''
                INSERT INTO image_descriptions (
                    type, image_description_hash, description, timestamp
                ) VALUES (?, ?, ?, ?)
            ''', (
                doc.get('type', ''),
                doc.get('image_description_hash', ''),
                doc.get('description', ''),
                doc.get('timestamp', 0.0)
            ))
            count += 1
        except Exception as e:
            print(f"导入 image_descriptions 记录失败: {e}")
    
    return count

def import_online_time(cursor, file_path):
    """导入在线时间数据"""
    documents = read_bson_file(file_path)
    count = 0
    
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
            
            cursor.execute('''
                INSERT INTO online_time (
                    timestamp, duration, start_timestamp, end_timestamp
                ) VALUES (?, ?, ?, ?)
            ''', (
                timestamp_str,
                doc.get('duration', 0),
                start_timestamp,
                end_timestamp
            ))
            count += 1
        except Exception as e:
            print(f"导入 online_time 记录失败: {e}")
    
    return count

def import_person_info(cursor, file_path):
    """导入人员信息数据"""
    documents = read_bson_file(file_path)
    count = 0
    
    for doc in documents:
        try:
            # 处理 group_nick_name 列表
            group_nick_name = doc.get('group_nick_name', [])
            if isinstance(group_nick_name, list):
                group_nick_name = json.dumps(group_nick_name)
            
            cursor.execute('''
                INSERT OR REPLACE INTO person_info (
                    is_known, person_id, person_name, name_reason, platform, user_id,
                    nickname, group_nick_name, memory_points, know_times, know_since, last_know
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                int(doc.get('is_known', False)),
                doc.get('person_id', ''),
                doc.get('person_name'),
                doc.get('name_reason'),
                doc.get('platform', ''),
                doc.get('user_id', ''),
                doc.get('nickname'),
                group_nick_name,
                doc.get('memory_points'),
                doc.get('know_times'),
                doc.get('know_since'),
                doc.get('last_know')
            ))
            count += 1
        except Exception as e:
            print(f"导入 person_info 记录失败: {e}")
    
    return count

if __name__ == "__main__":
    print("MongoDB 备份数据导入工具")
    print("=" * 50)
    
    if import_data():
        print("✅ 数据导入成功完成!")
    else:
        print("❌ 数据导入失败!")