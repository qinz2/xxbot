import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

import hashlib


def get_sha256(string: str) -> str:
    """获取字符串的SHA256值"""
    sha256 = hashlib.sha256()
    sha256.update(string.encode("utf-8"))
    return sha256.hexdigest()
