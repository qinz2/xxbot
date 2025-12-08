import sys
import os

# 自动添加项目根目录到 Python 路径
current_file_dir = os.path.dirname(os.path.abspath(__file__))
# 计算相对项目根目录的层级（自动适配）
relative_level = "../../"
project_root = os.path.abspath(os.path.join(current_file_dir, relative_level))
sys.path.insert(0, project_root)

import hashlib
import asyncio
import json
import time
import random
import math

from json_repair import repair_json
from typing import Union, Optional

from src.common.logger import get_logger
from src.common.database.database import db
from src.common.database.database_model import PersonInfo
from src.llm_models.utils_model import LLMRequest
from src.config.config import global_config, model_config
from src.chat.message_receive.chat_stream import get_chat_manager


logger = get_logger("person_info")

relation_selection_model = LLMRequest(
    model_set=model_config.model_task_config.utils_small, request_type="relation_selection"
)


def get_person_id(platform: str, user_id: str, group_id: str = None) -> str:
    """
    生成统一的人物ID
    Args:
        platform: 平台名称 (qq/godot/telegram等)
        user_id: 用户ID
        group_id: 群组ID（可选）
    Returns:
        统一格式的person_id
    """
    # 验证平台
    valid_platforms = ['qq', 'godot', 'telegram', 'discord']
    if platform not in valid_platforms:
        raise ValueError(f"不支持的平台: {platform}")
    
    # Godot 平台特殊处理
    if platform == 'godot':
        # Godot 使用设备唯一标识作为 user_id
        # 格式: godot_设备ID
        return f"godot_{user_id}"
    
    # 原有逻辑
    if group_id:
        return f"{platform}_{group_id}_{user_id}"
    else:
        return f"{platform}_{user_id}"


def get_person_id_by_person_name(person_name: str) -> str:
    """根据用户名获取用户ID"""
    try:
        record = PersonInfo.get_or_none(PersonInfo.person_name == person_name)
        return record.person_id if record else ""
    except Exception as e:
        logger.error(f"根据用户名 {person_name} 获取用户ID时出错 (Peewee): {e}")
        return ""


def is_person_known(person_id: str = None, user_id: str = None, platform: str = None, person_name: str = None) -> bool:  # type: ignore
    if person_id:
        person = PersonInfo.get_or_none(PersonInfo.person_id == person_id)
        return person.is_known if person else False
    elif user_id and platform:
        person_id = get_person_id(platform, user_id)
        person = PersonInfo.get_or_none(PersonInfo.person_id == person_id)
        return person.is_known if person else False
    elif person_name:
        person_id = get_person_id_by_person_name(person_name)
        person = PersonInfo.get_or_none(PersonInfo.person_id == person_id)
        return person.is_known if person else False
    else:
        return False


def get_category_from_memory(memory_point: str) -> Optional[str]:
    """从记忆点中获取分类"""
    # 按照最左边的:符号进行分割，返回分割后的第一个部分作为分类
    if not isinstance(memory_point, str):
        return None
    parts = memory_point.split(":", 1)
    return parts[0].strip() if len(parts) > 1 else None


def get_weight_from_memory(memory_point: str) -> float:
    """从记忆点中获取权重"""
    # 按照最右边的:符号进行分割，返回分割后的最后一个部分作为权重
    if not isinstance(memory_point, str):
        return -math.inf
    parts = memory_point.rsplit(":", 1)
    if len(parts) <= 1:
        return -math.inf
    try:
        return float(parts[-1].strip())
    except Exception:
        return -math.inf


def get_memory_content_from_memory(memory_point: str) -> str:
    """从记忆点中获取记忆内容"""
    # 按:进行分割，去掉第一段和最后一段，返回中间部分作为记忆内容
    if not isinstance(memory_point, str):
        return ""
    parts = memory_point.split(":")
    return ":".join(parts[1:-1]).strip() if len(parts) > 2 else ""


def extract_categories_from_response(response: str) -> list[str]:
    """从response中提取所有<>包裹的内容"""
    if not isinstance(response, str):
        return []

    import re

    pattern = r"<([^<>]+)>"
    matches = re.findall(pattern, response)
    return matches


def calculate_string_similarity(s1: str, s2: str) -> float:
    """
    计算两个字符串的相似度

    Args:
        s1: 第一个字符串
        s2: 第二个字符串

    Returns:
        float: 相似度，范围0-1，1表示完全相同
    """
    if s1 == s2:
        return 1.0

    if not s1 or not s2:
        return 0.0

    # 计算Levenshtein距离

    distance = levenshtein_distance(s1, s2)
    max_len = max(len(s1), len(s2))

    # 计算相似度：1 - (编辑距离 / 最大长度)
    similarity = 1 - (distance / max_len if max_len > 0 else 0)
    return similarity


def levenshtein_distance(s1: str, s2: str) -> int:
    """
    计算两个字符串的编辑距离

    Args:
        s1: 第一个字符串
        s2: 第二个字符串

    Returns:
        int: 编辑距离
    """
    if len(s1) < len(s2):
        return levenshtein_distance(s2, s1)

    if len(s2) == 0:
        return len(s1)

    previous_row = range(len(s2) + 1)
    for i, c1 in enumerate(s1):
        current_row = [i + 1]
        for j, c2 in enumerate(s2):
            insertions = previous_row[j + 1] + 1
            deletions = current_row[j] + 1
            substitutions = previous_row[j] + (c1 != c2)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row

    return previous_row[-1]


class Person:
    # 新添加的方法
    def add_memory_point(self, content: str, category: str = "general", 
                    weight: float = 1.0) -> None:
        """
        添加记忆点
        Args:
            content: 记忆内容
            category: 记忆分类 (general/preference/important/event)
            weight: 权重 (0.0-1.0)
        """
        import json
        
        # Godot 平台的记忆分类权重
        if self.person_info.platform == 'godot':
            category_weights = {
                'preference': 1.0,    # 用户偏好最重要
                'important': 0.9,     # 重要事件
                'event': 0.7,         # 一般事件
                'general': 0.5        # 日常对话
            }
            weight = category_weights.get(category, 0.5)
        
        # 获取现有记忆点
        try:
            memory_points = json.loads(self.person_info.memory_points or "[]")
        except:
            memory_points = []
        
        # 添加新记忆点
        new_point = {
            'content': content,
            'category': category,
            'weight': weight,
            'timestamp': time.time()
        }
        memory_points.append(new_point)
        
        # 限制记忆点数量（保留最近100个）
        if len(memory_points) > 100:
            # 按权重和时间排序，保留重要的
            memory_points.sort(key=lambda x: (x['weight'], x['timestamp']), reverse=True)
            memory_points = memory_points[:100]
        
        # 保存
        self.person_info.memory_points = json.dumps(memory_points, ensure_ascii=False)
        self.person_info.save()

    @classmethod
    def register_person(cls, platform: str, user_id: str, name: str = None, 
                   group_id: str = None, **kwargs) -> 'Person':
        """
        注册新用户或获取现有用户
        Args:
            platform: 平台名称
            user_id: 用户ID
           name: 用户昵称
            group_id: 群组ID
          **kwargs: 其他平台特定信息
        """
        person_id = get_person_id(platform, user_id, group_id)
    
        # 尝试从数据库获取
        try:
            person_info = PersonInfo.get(
                (PersonInfo.platform == platform) & 
                (PersonInfo.user_id == user_id)
         )
            print(f"✓ 找到现有用户: {person_id}")
        
        except PersonInfo.DoesNotExist:
            # 创建新用户
            print(f"🆕 注册新用户: {person_id}")
        
            # Godot 平台特殊初始化
            if platform == 'godot':
                default_name = kwargs.get('device_name', f'Godot用户_{user_id[:8]}')
                person_info = PersonInfo.create(
                    user_id=user_id,
                    platform=platform,
                    name=name or default_name,
                    nick_name=name or default_name,
                    person_info="",  # 将逐步积累
                    memory_points="[]",  # 空记忆点列表
                    last_interaction=time.time(),
                    create_time=time.time()
                )
            else:
                # 原有平台逻辑
                person_info = PersonInfo.create(
                    user_id=user_id,
                    platform=platform,
                    name=name or f"用户_{user_id}",
                    nick_name=name,
                    person_info="",
                    memory_points="[]",
                    last_interaction=time.time(),
                    create_time=time.time()
                )
    
        return cls(person_info)

    def __init__(self, platform: str = "", user_id: str = "", person_id: str = "", person_name: str = ""):
        if platform == global_config.bot.platform and user_id == global_config.bot.qq_account:
            self.is_known = True
            self.person_id = get_person_id(platform, user_id)
            self.user_id = user_id
            self.platform = platform
            self.nickname = global_config.bot.nickname
            self.person_name = global_config.bot.nickname
            self.group_nick_name: list[dict[str, str]] = []
            return

        self.user_id = ""
        self.platform = ""

        if person_id:
            self.person_id = person_id
        elif person_name:
            self.person_id = get_person_id_by_person_name(person_name)
            if not self.person_id:
                self.is_known = False
                logger.warning(f"根据用户名 {person_name} 获取用户ID时，不存在用户{person_name}")
                return
        elif platform and user_id:
            self.person_id = get_person_id(platform, user_id)
            self.user_id = user_id
            self.platform = platform
        else:
            logger.error("Person 初始化失败，缺少必要参数")
            raise ValueError("Person 初始化失败，缺少必要参数")

        if not is_person_known(person_id=self.person_id):
            self.is_known = False
            logger.debug(f"用户 {platform}:{user_id}:{person_name}:{person_id} 尚未认识")
            self.person_name = f"未知用户{self.person_id[:4]}"
            return
            # raise ValueError(f"用户 {platform}:{user_id}:{person_name}:{person_id} 尚未认识")

        self.is_known = False

        # 初始化默认值
        self.nickname = ""
        self.person_name: Optional[str] = None
        self.name_reason: Optional[str] = None
        self.know_times = 0
        self.know_since = None
        self.last_know: Optional[float] = None
        self.memory_points = []
        self.group_nick_name: list[dict[str, str]] = []  # 群昵称列表，存储 {"group_id": str, "group_nick_name": str}

        # 从数据库加载数据
        self.load_from_database()

    def del_memory(self, category: str, memory_content: str, similarity_threshold: float = 0.95):
        """
        删除指定分类和记忆内容的记忆点

        Args:
            category: 记忆分类
            memory_content: 要删除的记忆内容
            similarity_threshold: 相似度阈值，默认0.95（95%）

        Returns:
            int: 删除的记忆点数量
        """
        if not self.memory_points:
            return 0

        deleted_count = 0
        memory_points_to_keep = []

        for memory_point in self.memory_points:
            # 跳过None值
            if memory_point is None:
                continue
            # 解析记忆点
            parts = memory_point.split(":", 2)  # 最多分割2次，保留记忆内容中的冒号
            if len(parts) < 3:
                # 格式不正确，保留原样
                memory_points_to_keep.append(memory_point)
                continue

            memory_category = parts[0].strip()
            memory_text = parts[1].strip()
            _memory_weight = parts[2].strip()

            # 检查分类是否匹配
            if memory_category != category:
                memory_points_to_keep.append(memory_point)
                continue

            # 计算记忆内容的相似度
            similarity = calculate_string_similarity(memory_content, memory_text)

            # 如果相似度达到阈值，则删除（不添加到保留列表）
            if similarity >= similarity_threshold:
                deleted_count += 1
                logger.debug(f"删除记忆点: {memory_point} (相似度: {similarity:.4f})")
            else:
                memory_points_to_keep.append(memory_point)

        # 更新memory_points
        self.memory_points = memory_points_to_keep

        # 同步到数据库
        if deleted_count > 0:
            self.sync_to_database()
            logger.info(f"成功删除 {deleted_count} 个记忆点，分类: {category}")

        return deleted_count

    def get_all_category(self):
        category_list = []
        for memory in self.memory_points:
            if memory is None:
                continue
            category = get_category_from_memory(memory)
            if category and category not in category_list:
                category_list.append(category)
        return category_list

    def get_memory_list_by_category(self, category: str):
        memory_list = []
        for memory in self.memory_points:
            if memory is None:
                continue
            if get_category_from_memory(memory) == category:
                memory_list.append(memory)
        return memory_list

    def get_random_memory_by_category(self, category: str, num: int = 1):
        memory_list = self.get_memory_list_by_category(category)
        if len(memory_list) < num:
            return memory_list
        return random.sample(memory_list, num)

    def add_group_nick_name(self, group_id: str, group_nick_name: str):
        """
        添加或更新群昵称

        Args:
            group_id: 群号
            group_nick_name: 群昵称
        """
        if not group_id or not group_nick_name:
            return

        # 检查是否已存在该群号的记录
        for item in self.group_nick_name:
            if item.get("group_id") == group_id:
                # 更新现有记录
                item["group_nick_name"] = group_nick_name
                self.sync_to_database()
                logger.debug(f"更新用户 {self.person_id} 在群 {group_id} 的群昵称为 {group_nick_name}")
                return

        # 添加新记录
        self.group_nick_name.append({"group_id": group_id, "group_nick_name": group_nick_name})
        self.sync_to_database()
        logger.debug(f"添加用户 {self.person_id} 在群 {group_id} 的群昵称 {group_nick_name}")

    def load_from_database(self):
        """从数据库加载个人信息数据"""
        try:
            # 查询数据库中的记录
            record = PersonInfo.get_or_none(PersonInfo.person_id == self.person_id)

            if record:
                self.user_id = record.user_id or ""
                self.platform = record.platform or ""
                self.is_known = record.is_known or False
                self.nickname = record.nickname or ""
                self.person_name = record.person_name or self.nickname
                self.name_reason = record.name_reason or None
                self.know_times = record.know_times or 0

                # 处理points字段（JSON格式的列表）
                if record.memory_points:
                    try:
                        loaded_points = json.loads(record.memory_points)
                        # 过滤掉None值，确保数据质量
                        if isinstance(loaded_points, list):
                            self.memory_points = [point for point in loaded_points if point is not None]
                        else:
                            self.memory_points = []
                    except (json.JSONDecodeError, TypeError):
                        logger.warning(f"解析用户 {self.person_id} 的points字段失败，使用默认值")
                        self.memory_points = []
                else:
                    self.memory_points = []

                # 处理group_nick_name字段（JSON格式的列表）
                if record.group_nick_name:
                    try:
                        loaded_group_nick_names = json.loads(record.group_nick_name)
                        # 确保是列表格式
                        if isinstance(loaded_group_nick_names, list):
                            self.group_nick_name = loaded_group_nick_names
                        else:
                            self.group_nick_name = []
                    except (json.JSONDecodeError, TypeError):
                        logger.warning(f"解析用户 {self.person_id} 的group_nick_name字段失败，使用默认值")
                        self.group_nick_name = []
                else:
                    self.group_nick_name = []

                logger.debug(f"已从数据库加载用户 {self.person_id} 的信息")
            else:
                self.sync_to_database()
                logger.info(f"用户 {self.person_id} 在数据库中不存在，使用默认值并创建")

        except Exception as e:
            logger.error(f"从数据库加载用户 {self.person_id} 信息时出错: {e}")
            # 出错时保持默认值

    def sync_to_database(self):
        """将所有属性同步回数据库"""
        if not self.is_known:
            return
        try:
            # 准备数据
            data = {
                "person_id": self.person_id,
                "is_known": self.is_known,
                "platform": self.platform,
                "user_id": self.user_id,
                "nickname": self.nickname,
                "person_name": self.person_name,
                "name_reason": self.name_reason,
                "know_times": self.know_times,
                "know_since": self.know_since,
                "last_know": self.last_know,
                "memory_points": json.dumps(
                    [point for point in self.memory_points if point is not None], ensure_ascii=False
                )
                if self.memory_points
                else json.dumps([], ensure_ascii=False),
                "group_nick_name": json.dumps(self.group_nick_name, ensure_ascii=False)
                if self.group_nick_name
                else json.dumps([], ensure_ascii=False),
            }

            # 检查记录是否存在
            record = PersonInfo.get_or_none(PersonInfo.person_id == self.person_id)

            if record:
                # 更新现有记录
                for field, value in data.items():
                    if hasattr(record, field):
                        setattr(record, field, value)
                record.save()
                logger.debug(f"已同步用户 {self.person_id} 的信息到数据库")
            else:
                # 创建新记录
                PersonInfo.create(**data)
                logger.debug(f"已创建用户 {self.person_id} 的信息到数据库")

        except Exception as e:
            logger.error(f"同步用户 {self.person_id} 信息到数据库时出错: {e}")

    async def build_relationship(self, chat_content: str = "", info_type=""):
        if not self.is_known:
            return ""
        # 构建points文本

        nickname_str = ""
        if self.person_name != self.nickname:
            nickname_str = f"(ta在{self.platform}上的昵称是{self.nickname})"

        relation_info = ""

        points_text = ""
        category_list = self.get_all_category()

        if chat_content:
            prompt = f"""当前聊天内容：
{chat_content}

分类列表：
{category_list}
**要求**：请你根据当前聊天内容，从以下分类中选择一个与聊天内容相关的分类，并用<>包裹输出，不要输出其他内容，不要输出引号或[]，严格用<>包裹：
例如:
<分类1><分类2><分类3>......
如果没有相关的分类，请输出<none>"""

            response, _ = await relation_selection_model.generate_response_async(prompt)
            # print(prompt)
            # print(response)
            category_list = extract_categories_from_response(response)
            if "none" not in category_list:
                for category in category_list:
                    random_memory = self.get_random_memory_by_category(category, 2)
                    if random_memory:
                        random_memory_str = "\n".join(
                            [get_memory_content_from_memory(memory) for memory in random_memory]
                        )
                        points_text = f"有关 {category} 的内容：{random_memory_str}"
                        break
        elif info_type:
            prompt = f"""你需要获取用户{self.person_name}的 **{info_type}** 信息。

现有信息类别列表：
{category_list}
**要求**：请你根据**{info_type}**，从以下分类中选择一个与**{info_type}**相关的分类，并用<>包裹输出，不要输出其他内容，不要输出引号或[]，严格用<>包裹：
例如:
<分类1><分类2><分类3>......
如果没有相关的分类，请输出<none>"""
            response, _ = await relation_selection_model.generate_response_async(prompt)
            # print(prompt)
            # print(response)
            category_list = extract_categories_from_response(response)
            if "none" not in category_list:
                for category in category_list:
                    random_memory = self.get_random_memory_by_category(category, 3)
                    if random_memory:
                        random_memory_str = "\n".join(
                            [get_memory_content_from_memory(memory) for memory in random_memory]
                        )
                        points_text = f"有关 {category} 的内容：{random_memory_str}"
                        break
        else:
            for category in category_list:
                random_memory = self.get_random_memory_by_category(category, 1)[0]
                if random_memory:
                    points_text = f"有关 {category} 的内容：{get_memory_content_from_memory(random_memory)}"
                    break

        points_info = ""
        if points_text:
            points_info = f"你还记得有关{self.person_name}的内容：{points_text}"

        if not (nickname_str or points_info):
            return ""
        relation_info = f"{self.person_name}:{nickname_str}{points_info}"

        return relation_info


class PersonInfoManager:
    def __init__(self):
        self.person_name_list = {}
        self.qv_name_llm = LLMRequest(model_set=model_config.model_task_config.utils, request_type="relation.qv_name")
        try:
            db.connect(reuse_if_open=True)
            # 设置连接池参数
            if hasattr(db, "execute_sql"):
                # 设置SQLite优化参数
                db.execute_sql("PRAGMA cache_size = -64000")  # 64MB缓存
                db.execute_sql("PRAGMA temp_store = memory")  # 临时存储在内存中
                db.execute_sql("PRAGMA mmap_size = 268435456")  # 256MB内存映射
            db.create_tables([PersonInfo], safe=True)
        except Exception as e:
            logger.error(f"数据库连接或 PersonInfo 表创建失败: {e}")

        # 初始化时读取所有person_name
        try:
            for record in PersonInfo.select(PersonInfo.person_id, PersonInfo.person_name).where(
                PersonInfo.person_name.is_null(False)
            ):
                if record.person_name:
                    self.person_name_list[record.person_id] = record.person_name
            logger.debug(f"已加载 {len(self.person_name_list)} 个用户名称 (Peewee)")
        except Exception as e:
            logger.error(f"从 Peewee 加载 person_name_list 失败: {e}")

    @staticmethod
    def _extract_json_from_text(text: str) -> dict:
        """从文本中提取JSON数据的高容错方法"""
        try:
            fixed_json = repair_json(text)
            if isinstance(fixed_json, str):
                parsed_json = json.loads(fixed_json)
            else:
                parsed_json = fixed_json

            if isinstance(parsed_json, list) and parsed_json:
                parsed_json = parsed_json[0]

            if isinstance(parsed_json, dict):
                return parsed_json

        except Exception as e:
            logger.warning(f"JSON提取失败: {e}")

        logger.warning(f"无法从文本中提取有效的JSON字典: {text}")
        logger.info(f"文本: {text}")
        return {"nickname": "", "reason": ""}

    async def _generate_unique_person_name(self, base_name: str) -> str:
        """生成唯一的 person_name，如果存在重复则添加数字后缀"""
        # 处理空昵称的情况
        if not base_name or base_name.isspace():
            base_name = "空格"

        # 检查基础名称是否已存在
        if base_name not in self.person_name_list.values():
            return base_name

        # 如果存在，添加数字后缀
        counter = 1
        while True:
            new_name = f"{base_name}[{counter}]"
            if new_name not in self.person_name_list.values():
                return new_name
            counter += 1

    async def qv_person_name(
        self, person_id: str, user_nickname: str, user_cardname: str, user_avatar: str, request: str = ""
    ):
        """给某个用户取名"""
        if not person_id:
            logger.debug("取名失败：person_id不能为空")
            return None

        person = Person(person_id=person_id)
        old_name = person.person_name
        old_reason = person.name_reason

        max_retries = 8
        current_try = 0
        existing_names_str = ""
        current_name_set = set(self.person_name_list.values())

        while current_try < max_retries:
            bot_name = global_config.bot.nickname

            qv_name_prompt = f"你是{bot_name}，一个伪装成人类的AI，你不能让别人发现这一点，"
            qv_name_prompt += f"现在你想给一个用户取一个昵称，用户的qq昵称是{user_nickname}，"
            qv_name_prompt += f"用户的qq群昵称名是{user_cardname}，"
            if user_avatar:
                qv_name_prompt += f"用户的qq头像是{user_avatar}，"
            if old_name:
                qv_name_prompt += f"你之前叫他{old_name}，是因为{old_reason}，"

            qv_name_prompt += f"\n其他取名的要求是：{request}，不要太浮夸，简短，"
            qv_name_prompt += "\n请根据以上用户信息，想想你叫他什么比较好，不要太浮夸，请最好使用用户的qq昵称或群昵称原文，可以稍作修改，优先使用原文。优先使用用户的qq昵称或者群昵称原文。"

            if existing_names_str:
                qv_name_prompt += f"\n请注意，以下名称已被你尝试过或已知存在，请避免：{existing_names_str}。\n"

            if len(current_name_set) < 50 and current_name_set:
                qv_name_prompt += f"已知的其他昵称有: {', '.join(list(current_name_set)[:10])}等。\n"

            qv_name_prompt += "请用json给出你的想法，并给出理由，示例如下："
            qv_name_prompt += """{
                "nickname": "昵称",
                "reason": "理由"
            }"""
            response, _ = await self.qv_name_llm.generate_response_async(qv_name_prompt)
            # logger.info(f"取名提示词：{qv_name_prompt}\n取名回复：{response}")
            result = self._extract_json_from_text(response)

            if not result or not result.get("nickname"):
                logger.error("生成的昵称为空或结果格式不正确，重试中...")
                current_try += 1
                continue

            generated_nickname = result["nickname"]

            is_duplicate = False
            if generated_nickname in current_name_set:
                is_duplicate = True
                logger.info(f"尝试给用户{user_nickname} {person_id} 取名，但是 {generated_nickname} 已存在，重试中...")
            else:

                def _db_check_name_exists_sync(name_to_check):
                    return PersonInfo.select().where(PersonInfo.person_name == name_to_check).exists()

                if await asyncio.to_thread(_db_check_name_exists_sync, generated_nickname):
                    is_duplicate = True
                    current_name_set.add(generated_nickname)

            if not is_duplicate:
                person.person_name = generated_nickname
                person.name_reason = result.get("reason", "未提供理由")
                person.sync_to_database()

                logger.info(
                    f"成功给用户{user_nickname} {person_id} 取名 {generated_nickname}，理由：{result.get('reason', '未提供理由')}"
                )

                self.person_name_list[person_id] = generated_nickname
                return result
            else:
                if existing_names_str:
                    existing_names_str += "、"
                existing_names_str += generated_nickname
                logger.debug(f"生成的昵称 {generated_nickname} 已存在，重试中...")
                current_try += 1

        # 如果多次尝试后仍未成功，使用唯一的 user_nickname 作为默认值
        unique_nickname = await self._generate_unique_person_name(user_nickname)
        logger.warning(f"在{max_retries}次尝试后未能生成唯一昵称，使用默认昵称 {unique_nickname}")
        person.person_name = unique_nickname
        person.name_reason = "使用用户原始昵称作为默认值"
        person.sync_to_database()
        self.person_name_list[person_id] = unique_nickname
        return {"nickname": unique_nickname, "reason": "使用用户原始昵称作为默认值"}


person_info_manager = PersonInfoManager()


async def store_person_memory_from_answer(person_name: str, memory_content: str, chat_id: str) -> None:
    """将人物信息存入person_info的memory_points
    
    Args:
        person_name: 人物名称
        memory_content: 记忆内容
        chat_id: 聊天ID
    """
    try:
        # 从chat_id获取chat_stream
        chat_stream = get_chat_manager().get_stream(chat_id)
        if not chat_stream:
            logger.warning(f"无法获取chat_stream for chat_id: {chat_id}")
            return
        
        platform = chat_stream.platform
        
        # 尝试从person_name查找person_id
        # 首先尝试通过person_name查找
        person_id = get_person_id_by_person_name(person_name)
        
        if not person_id:
            # 如果通过person_name找不到，尝试从chat_stream获取user_info
            if chat_stream.user_info:
                user_id = chat_stream.user_info.user_id
                person_id = get_person_id(platform, user_id)
            else:
                logger.warning(f"无法确定person_id for person_name: {person_name}, chat_id: {chat_id}")
                return
        
        # 创建或获取Person对象
        person = Person(person_id=person_id)
        
        if not person.is_known:
            logger.warning(f"用户 {person_name} (person_id: {person_id}) 尚未认识，无法存储记忆")
            return
        
        # 确定记忆分类（可以根据memory_content判断，这里使用通用分类）
        category = "其他"  # 默认分类，可以根据需要调整
        
        # 记忆点格式：category:content:weight
        weight = "1.0"  # 默认权重
        memory_point = f"{category}:{memory_content}:{weight}"
        
        # 添加到memory_points
        if not person.memory_points:
            person.memory_points = []
        
        # 检查是否已存在相似的记忆点（避免重复）
        is_duplicate = False
        for existing_point in person.memory_points:
            if existing_point and isinstance(existing_point, str):
                parts = existing_point.split(":", 2)
                if len(parts) >= 2:
                    existing_content = parts[1].strip()
                    # 简单相似度检查（如果内容相同或非常相似，则跳过）
                    if existing_content == memory_content or memory_content in existing_content or existing_content in memory_content:
                        is_duplicate = True
                        break
        
        if not is_duplicate:
            person.memory_points.append(memory_point)
            person.sync_to_database()
            logger.info(f"成功添加记忆点到 {person_name} (person_id: {person_id}): {memory_point}")
        else:
            logger.debug(f"记忆点已存在，跳过: {memory_point}")
    
    except Exception as e:
        logger.error(f"存储人物记忆失败: {e}")
