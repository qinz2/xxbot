import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

import os
from peewee import SqliteDatabase
from rich.traceback import install

install(extra_lines=3)


# 定义数据库文件路径
ROOT_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
_DB_DIR = os.path.join(ROOT_PATH, "data")
_DB_FILE = os.path.join(_DB_DIR, "MaiBot.db")

# 确保数据库目录存在
os.makedirs(_DB_DIR, exist_ok=True)

# 全局 Peewee SQLite 数据库访问点
db = SqliteDatabase(
    _DB_FILE,
    pragmas={
        "journal_mode": "wal",  # WAL模式提高并发性能
        "cache_size": -64 * 1000,  # 64MB缓存
        "foreign_keys": 1,
        "ignore_check_constraints": 0,
        "synchronous": 0,  # 异步写入提高性能
        "busy_timeout": 1000,  # 1秒超时而不是3秒
    },
)
