"""
数据库迁移脚本：添加Godot平台支持
运行方式: python -m MaiBot.scripts.migrate_to_godot
"""

from peewee import *
from MaiBot.src.common.database.database_model import db, PersonInfo, ChatStreams

def migrate_database():
    """迁移数据库以支持Godot平台"""
    print(" 开始数据库迁移...")
    
    try:
        # 连接数据库
        db.connect(reuse_if_open=True)
        
        # 检查现有数据
        print("检查现有数据...")
        total_persons = PersonInfo.select().count()
        total_streams = ChatStreams.select().count()
        print(f"   现有用户数: {total_persons}")
        print(f"   现有聊天流: {total_streams}")
        
        # 验证平台字段
        print("验证平台字段...")
        platforms = PersonInfo.select(PersonInfo.platform).distinct()
        for p in platforms:
            print(f"   发现平台: {p.platform}")
        
        # 创建索引（如果不存在）
        print("创建索引...")
        try:
            db.execute_sql(
                'CREATE INDEX IF NOT EXISTS '
                'person_info_platform_user_id '
                'ON person_info (platform, user_id)'
            )
            print("   ✓ 索引创建成功")
        except Exception as e:
            print(f"   ! 索引已存在或创建失败: {e}")
        
        print("迁移完成！数据库已准备好支持Godot平台")
        
    except Exception as e:
        print(f"迁移失败: {e}")
        raise
    finally:
        if not db.is_closed():
            db.close()

if __name__ == "__main__":
    migrate_database()
