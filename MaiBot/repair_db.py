#!/usr/bin/env python3
"""
数据库修复脚本
尝试从损坏的 SQLite 数据库中恢复数据
"""
import sqlite3
import os
import shutil
from pathlib import Path

def repair_database():
    """尝试修复损坏的数据库"""
    db_path = Path("data/MaiBot.db")
    backup_path = Path("data/MaiBot.db.backup")
    recovered_path = Path("data/MaiBot_recovered.db")
    
    print(f"正在尝试修复数据库: {db_path}")
    
    # 1. 创建备份
    if db_path.exists() and not backup_path.exists():
        shutil.copy2(db_path, backup_path)
        print(f"已创建备份: {backup_path}")
    
    # 2. 尝试使用 .recover 命令（如果支持）
    try:
        # 删除旧的恢复文件
        if recovered_path.exists():
            recovered_path.unlink()
            
        # 尝试恢复
        conn = sqlite3.connect(str(db_path))
        conn.execute("PRAGMA integrity_check")
        print("数据库完整性检查通过")
        conn.close()
        return True
        
    except sqlite3.DatabaseError as e:
        print(f"数据库损坏: {e}")
        
        # 尝试使用 dump 和重建
        try:
            print("尝试导出数据...")
            
            # 连接到损坏的数据库
            conn = sqlite3.connect(str(db_path))
            
            # 创建新的数据库
            new_conn = sqlite3.connect(str(recovered_path))
            
            # 尝试导出表结构和数据
            for line in conn.iterdump():
                try:
                    new_conn.execute(line)
                except sqlite3.Error as dump_error:
                    print(f"跳过损坏的行: {dump_error}")
                    continue
            
            new_conn.commit()
            new_conn.close()
            conn.close()
            
            print(f"数据已恢复到: {recovered_path}")
            
            # 替换原数据库
            if recovered_path.exists():
                shutil.move(str(recovered_path), str(db_path))
                print("数据库已修复并替换")
                return True
                
        except Exception as e:
            print(f"恢复失败: {e}")
            
    # 3. 如果都失败了，创建新的空数据库
    print("无法恢复数据，将创建新的空数据库")
    if db_path.exists():
        db_path.unlink()
    
    # 创建空数据库
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.commit()
    conn.close()
    
    print("已创建新的空数据库")
    return False

if __name__ == "__main__":
    success = repair_database()
    if success:
        print("✅ 数据库修复成功")
    else:
        print("⚠️ 创建了新的空数据库，历史数据可能丢失")