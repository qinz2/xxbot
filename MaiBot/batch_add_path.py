import os
import fileinput

# 项目根目录（当前脚本所在目录）
PROJECT_ROOT = os.path.abspath(os.path.dirname(__file__))
# 要处理的目录（所有 .py 文件）
TARGET_DIRS = [
    os.path.join(PROJECT_ROOT, "src"),
    os.path.join(PROJECT_ROOT, "docs"),
    # 可添加其他需要处理的目录，比如 "tests"
]
# 要插入的代码模板（注意：根据文件所在层级自动计算退级）
PATH_CODE_TEMPLATE = '''import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "{relative_level}"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

'''

def get_relative_level(file_path):
    """计算文件相对项目根目录的退级（比如 ../../..）"""
    # 转换为相对路径
    rel_path = os.path.relpath(file_path, PROJECT_ROOT)
    # 统计目录层级
    dir_level = len(rel_path.split(os.sep)) - 1
    # 生成退级符（比如层级3 → ../../..）
    return "../" * dir_level

def process_file(file_path):
    """处理单个文件，插入路径代码"""
    # 跳过 __pycache__ 和批量脚本本身
    if "__pycache__" in file_path or file_path.endswith("batch_add_path.py"):
        return
    
    # 读取文件内容
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # 检查是否已添加过路径代码（避免重复）
    if "# 自动添加项目根目录到 Python 路径" in content:
        print(f"✅ {file_path} 已处理过，跳过")
        return
    
    # 计算当前文件需要的退级
    relative_level = get_relative_level(file_path)
    # 生成最终要插入的代码
    insert_code = PATH_CODE_TEMPLATE.format(relative_level=relative_level)
    
    # 插入代码到文件顶部
    new_content = insert_code + content
    
    # 写回文件
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    
    print(f"✅ 已处理：{file_path}")

def main():
    """批量处理所有 .py 文件"""
    print(f"📌 项目根目录：{PROJECT_ROOT}")
    print("🚀 开始批量添加路径配置...\n")
    
    for target_dir in TARGET_DIRS:
        if not os.path.exists(target_dir):
            print(f"⚠️ 目录不存在：{target_dir}，跳过")
            continue
        
        # 遍历目录下所有 .py 文件
        for root, _, files in os.walk(target_dir):
            for file in files:
                if file.endswith(".py"):
                    file_path = os.path.join(root, file)
                    process_file(file_path)
    
    print("\n🎉 批量处理完成！所有 .py 文件已添加路径配置")

if __name__ == "__main__":
    main()