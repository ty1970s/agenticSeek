# AgenticSeek 数据库设计文档

## 数据库架构概述

AgenticSeek采用混合存储架构，结合内存数据库和文件系统存储，以平衡性能、持久性和隐私保护的需求。

### 存储技术选型

#### 1. Redis/Valkey (内存数据库)
- **用途**：会话缓存、任务队列、临时数据存储
- **优势**：高性能读写、支持复杂数据结构、天然过期机制
- **数据类型**：字符串、哈希、列表、集合、有序集合

#### 2. 文件系统 (持久化存储)
- **用途**：会话历史、日志文件、用户生成内容
- **格式**：JSON、纯文本、二进制文件
- **位置**：用户指定的工作目录

#### 3. SQLite (可选扩展)
- **用途**：结构化数据存储、复杂查询支持
- **场景**：大规模部署、数据分析需求
- **状态**：当前未实现，预留扩展接口

## Redis/Valkey 数据模型

### 1. 会话管理

#### 会话基本信息
```redis
# 键格式：session:{session_id}
# 数据类型：Hash
# TTL：7天

HSET session:user123 {
    "session_id": "user123",
    "created_at": "2025-06-25T10:00:00Z",
    "last_activity": "2025-06-25T10:30:00Z",
    "agent_name": "Jarvis",
    "user_preferences": "{\"language\": \"zh\", \"voice_enabled\": false}",
    "message_count": 15,
    "session_title": "Python编程助手"
}
```

#### 会话消息历史
```redis
# 键格式：session:{session_id}:messages
# 数据类型：List (LPUSH插入，LRANGE读取)
# TTL：7天

LPUSH session:user123:messages '{
    "timestamp": "2025-06-25T10:00:00Z",
    "role": "user",
    "content": "写一个快速排序算法",
    "message_id": "msg_001"
}'

LPUSH session:user123:messages '{
    "timestamp": "2025-06-25T10:00:01Z", 
    "role": "assistant",
    "content": "我来帮你写一个快速排序算法...",
    "agent_used": "code_agent",
    "reasoning": "用户需要排序算法，选择代码代理...",
    "execution_blocks": [...],
    "message_id": "msg_002"
}'
```

#### 活跃会话索引
```redis
# 键格式：active_sessions
# 数据类型：Sorted Set (按最后活动时间排序)
# TTL：无 (手动清理)

ZADD active_sessions 1719316200 user123  # timestamp score
ZADD active_sessions 1719316800 user456
```

### 2. 任务队列管理

#### Celery任务状态
```redis
# 键格式：celery:task:{task_id}
# 数据类型：Hash
# TTL：24小时

HSET celery:task:abc123 {
    "task_id": "abc123",
    "status": "processing",
    "progress": "0.65",
    "current_step": "数据分析中...",
    "started_at": "2025-06-25T10:30:00Z",
    "estimated_completion": "2025-06-25T10:35:00Z",
    "assigned_agent": "planner_agent",
    "subtasks": "[\"task1\", \"task2\", \"task3\"]"
}
```

#### 任务结果缓存
```redis
# 键格式：task_result:{task_id}
# 数据类型：String (JSON)
# TTL：1小时

SET task_result:abc123 '{
    "result": "任务执行结果...",
    "output_files": ["report.pdf", "data.csv"],
    "execution_time": 245.67,
    "resource_usage": {"cpu": 45.2, "memory": 1024}
}' EX 3600
```

### 3. 代理状态管理

#### 代理实例状态
```redis
# 键格式：agent:{agent_type}:status
# 数据类型：Hash
# TTL：5分钟

HSET agent:code_agent:status {
    "status": "ready",
    "current_task": "",
    "queue_length": 0,
    "last_activity": "2025-06-25T10:30:00Z",
    "total_requests": 1234,
    "success_rate": "0.95",
    "avg_response_time": "2.34"
}
```

#### 代理性能指标
```redis
# 键格式：agent_metrics:{agent_type}:{date}
# 数据类型：Hash
# TTL：30天

HSET agent_metrics:code_agent:20250625 {
    "requests_count": 156,
    "success_count": 148,
    "avg_response_time": 2.45,
    "max_response_time": 15.67,
    "error_count": 8,
    "total_execution_time": 383.2
}
```

### 4. 缓存策略

#### 查询结果缓存
```redis
# 键格式：cache:query:{query_hash}
# 数据类型：String (JSON)
# TTL：24小时

SET cache:query:sha256_hash '{
    "query": "写一个快速排序算法",
    "response": "这是一个快速排序的实现...",
    "agent_used": "code_agent",
    "cached_at": "2025-06-25T10:30:00Z"
}' EX 86400
```

#### LLM响应缓存
```redis
# 键格式：llm_cache:{provider}:{model}:{prompt_hash}
# 数据类型：String (JSON)
# TTL：1小时

SET llm_cache:ollama:deepseek-r1:hash123 '{
    "prompt": "系统提示词...",
    "response": "LLM回复...",
    "reasoning": "推理过程...",
    "tokens_used": 1234,
    "response_time": 3.45
}' EX 3600

# 私有DeepSeek服务器缓存示例
SET llm_cache:deepseek-private:deepseek-chat:hash456 '{
    "prompt": "系统提示词...",
    "response": "私有DeepSeek服务器回复...",
    "reasoning": "推理过程...",
    "tokens_used": 2048,
    "response_time": 2.1,
    "server_endpoint": "https://your-private-deepseek.com/v1"
}' EX 3600
```

### 5. 系统监控数据

#### 实时统计
```redis
# 键格式：stats:realtime
# 数据类型：Hash
# TTL：无 (持续更新)

HSET stats:realtime {
    "active_sessions": 12,
    "total_requests_today": 5678,
    "avg_response_time_5min": 2.34,
    "system_load": 0.65,
    "memory_usage": 68.5
}
```

#### 每日统计
```redis
# 键格式：stats:daily:{date}
# 数据类型：Hash  
# TTL：90天

HSET stats:daily:20250625 {
    "total_requests": 8901,
    "unique_sessions": 234,
    "agent_usage": "{\"code_agent\": 3456, \"browser_agent\": 2345}",
    "avg_response_time": 2.67,
    "error_rate": 0.02,
    "peak_concurrent_users": 56
}
```

## 文件系统存储设计

### 1. 目录结构

```
{WORK_DIR}/
├── sessions/                    # 会话持久化存储
│   ├── 2025/06/25/             # 按日期组织
│   │   ├── user123.json        # 会话历史文件
│   │   └── user456.json
│   └── metadata/               # 会话元数据
│       └── sessions_index.json
├── generated_files/            # AI生成的文件
│   ├── code/                   # 代码文件
│   │   ├── python/
│   │   ├── java/
│   │   └── c/
│   ├── documents/              # 文档文件
│   └── media/                  # 媒体文件
├── logs/                       # 系统日志
│   ├── app.log                 # 应用日志
│   ├── agent_router.log        # 路由日志
│   ├── code_agent.log          # 代理日志
│   └── error.log               # 错误日志
├── cache/                      # 文件缓存
│   ├── web_pages/              # 网页缓存
│   └── downloads/              # 下载文件
└── backups/                    # 备份文件
    ├── sessions/               # 会话备份
    └── configs/                # 配置备份
```

### 2. 会话持久化格式

#### 会话文件 (user123.json)
```json
{
    "session_metadata": {
        "session_id": "user123",
        "created_at": "2025-06-25T10:00:00Z",
        "last_updated": "2025-06-25T15:30:00Z",
        "total_messages": 45,
        "agents_used": ["casual_agent", "code_agent", "browser_agent"],
        "user_preferences": {
            "language": "zh",
            "voice_enabled": false,
            "theme": "dark"
        }
    },
    "conversation_history": [
        {
            "message_id": "msg_001",
            "timestamp": "2025-06-25T10:00:00Z",
            "role": "user",
            "content": "你好，我需要帮助写一个Python程序",
            "metadata": {
                "input_method": "text",
                "language_detected": "zh"
            }
        },
        {
            "message_id": "msg_002", 
            "timestamp": "2025-06-25T10:00:05Z",
            "role": "assistant",
            "content": "你好！我很乐意帮助你编写Python程序。请告诉我具体需要什么功能？",
            "metadata": {
                "agent_used": "casual_agent",
                "reasoning": "用户问候并表达编程需求，但未明确具体要求，使用对话代理收集更多信息",
                "response_time": 2.34,
                "tokens_used": 156
            }
        },
        {
            "message_id": "msg_003",
            "timestamp": "2025-06-25T10:01:00Z", 
            "role": "user",
            "content": "我想要一个计算斐波那契数列的函数"
        },
        {
            "message_id": "msg_004",
            "timestamp": "2025-06-25T10:01:15Z",
            "role": "assistant", 
            "content": "我来为你写一个斐波那契数列函数。我会提供几种不同的实现方式：",
            "metadata": {
                "agent_used": "code_agent",
                "reasoning": "用户明确要求编程功能，路由到代码代理",
                "execution_blocks": [
                    {
                        "tool": "python",
                        "code": "def fibonacci_recursive(n):\n    if n <= 1:\n        return n\n    return fibonacci_recursive(n-1) + fibonacci_recursive(n-2)",
                        "output": "函数定义成功",
                        "execution_time": 0.123,
                        "success": true
                    }
                ],
                "files_created": ["fibonacci.py"],
                "response_time": 4.56
            }
        }
    ]
}
```

#### 会话索引文件 (sessions_index.json)
```json
{
    "index_metadata": {
        "last_updated": "2025-06-25T15:30:00Z",
        "total_sessions": 1234,
        "retention_days": 90
    },
    "sessions": [
        {
            "session_id": "user123",
            "created_at": "2025-06-25T10:00:00Z",
            "last_activity": "2025-06-25T15:30:00Z",
            "message_count": 45,
            "file_path": "2025/06/25/user123.json",
            "file_size": 125678,
            "tags": ["programming", "python", "fibonacci"],
            "summary": "用户学习Python编程，实现了斐波那契数列等算法"
        }
    ]
}
```

### 3. 生成文件管理

#### 代码文件元数据
```json
{
    "file_metadata": {
        "file_path": "generated_files/code/python/fibonacci.py",
        "created_at": "2025-06-25T10:01:15Z", 
        "session_id": "user123",
        "message_id": "msg_004",
        "agent_used": "code_agent",
        "language": "python",
        "description": "斐波那契数列递归实现",
        "tags": ["algorithm", "recursion", "math"],
        "size_bytes": 256,
        "last_modified": "2025-06-25T10:01:15Z"
    },
    "execution_history": [
        {
            "timestamp": "2025-06-25T10:01:15Z",
            "input": "fibonacci_recursive(10)",
            "output": "55",
            "execution_time": 0.001,
            "success": true
        }
    ]
}
```

## 数据库操作接口

### 1. Redis操作封装

```python
import redis
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional

class RedisManager:
    def __init__(self, host='localhost', port=6379, db=0):
        self.redis_client = redis.Redis(host=host, port=port, db=db, decode_responses=True)
    
    # 会话管理
    def create_session(self, session_id: str, metadata: Dict) -> bool:
        """创建新会话"""
        pipeline = self.redis_client.pipeline()
        
        # 设置会话基本信息
        pipeline.hset(f"session:{session_id}", mapping=metadata)
        pipeline.expire(f"session:{session_id}", timedelta(days=7))
        
        # 添加到活跃会话索引
        pipeline.zadd("active_sessions", {session_id: datetime.now().timestamp()})
        
        return pipeline.execute()
    
    def add_message(self, session_id: str, message: Dict) -> bool:
        """添加消息到会话"""
        message_json = json.dumps(message, ensure_ascii=False)
        
        pipeline = self.redis_client.pipeline()
        pipeline.lpush(f"session:{session_id}:messages", message_json)
        pipeline.expire(f"session:{session_id}:messages", timedelta(days=7))
        
        # 更新会话活动时间
        pipeline.zadd("active_sessions", {session_id: datetime.now().timestamp()})
        pipeline.hincrby(f"session:{session_id}", "message_count", 1)
        
        return pipeline.execute()
    
    def get_session_messages(self, session_id: str, limit: int = 50) -> List[Dict]:
        """获取会话消息"""
        messages = self.redis_client.lrange(f"session:{session_id}:messages", 0, limit-1)
        return [json.loads(msg) for msg in reversed(messages)]
    
    # 缓存管理
    def cache_query_result(self, query_hash: str, result: Dict, ttl: int = 86400) -> bool:
        """缓存查询结果"""
        cache_key = f"cache:query:{query_hash}"
        result_json = json.dumps(result, ensure_ascii=False)
        return self.redis_client.setex(cache_key, ttl, result_json)
    
    def get_cached_result(self, query_hash: str) -> Optional[Dict]:
        """获取缓存的查询结果"""
        cache_key = f"cache:query:{query_hash}"
        result = self.redis_client.get(cache_key)
        return json.loads(result) if result else None
    
    # 任务管理
    def update_task_status(self, task_id: str, status_data: Dict) -> bool:
        """更新任务状态"""
        return self.redis_client.hset(f"celery:task:{task_id}", mapping=status_data)
    
    def get_task_status(self, task_id: str) -> Optional[Dict]:
        """获取任务状态"""
        return self.redis_client.hgetall(f"celery:task:{task_id}")
```

### 2. 文件系统操作封装

```python
import os
import json
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

class FileSystemManager:
    def __init__(self, work_dir: str):
        self.work_dir = Path(work_dir)
        self.sessions_dir = self.work_dir / "sessions"
        self.generated_files_dir = self.work_dir / "generated_files"
        self.logs_dir = self.work_dir / "logs"
        
        # 确保目录存在
        self.sessions_dir.mkdir(parents=True, exist_ok=True)
        self.generated_files_dir.mkdir(parents=True, exist_ok=True)
        self.logs_dir.mkdir(parents=True, exist_ok=True)
    
    def save_session_history(self, session_data: Dict) -> bool:
        """保存会话历史到文件"""
        session_id = session_data["session_metadata"]["session_id"]
        date_path = datetime.now().strftime("%Y/%m/%d")
        
        session_dir = self.sessions_dir / date_path
        session_dir.mkdir(parents=True, exist_ok=True)
        
        file_path = session_dir / f"{session_id}.json"
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(session_data, f, ensure_ascii=False, indent=2)
            return True
        except Exception as e:
            print(f"Failed to save session {session_id}: {e}")
            return False
    
    def load_session_history(self, session_id: str, date: str = None) -> Optional[Dict]:
        """从文件加载会话历史"""
        if not date:
            date = datetime.now().strftime("%Y/%m/%d")
        
        file_path = self.sessions_dir / date / f"{session_id}.json"
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return None
    
    def save_generated_file(self, content: str, filename: str, 
                          session_id: str, language: str = "text") -> str:
        """保存AI生成的文件"""
        # 根据语言创建子目录
        lang_dir = self.generated_files_dir / "code" / language
        lang_dir.mkdir(parents=True, exist_ok=True)
        
        # 生成唯一文件名
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        safe_filename = f"{timestamp}_{filename}"
        file_path = lang_dir / safe_filename
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            # 保存文件元数据
            metadata = {
                "file_path": str(file_path),
                "created_at": datetime.now().isoformat(),
                "session_id": session_id,
                "language": language,
                "size_bytes": len(content.encode('utf-8'))
            }
            
            metadata_path = file_path.with_suffix(f"{file_path.suffix}.meta")
            with open(metadata_path, 'w', encoding='utf-8') as f:
                json.dump(metadata, f, ensure_ascii=False, indent=2)
            
            return str(file_path)
        except Exception as e:
            print(f"Failed to save file {filename}: {e}")
            return ""
```

## 数据安全和隐私

### 1. 数据加密
- **静态数据加密**：敏感文件使用AES-256加密存储
- **传输加密**：Redis连接使用TLS/SSL
- **密钥管理**：采用环境变量或专用密钥管理服务

### 2. 数据脱敏
- **个人信息**：自动检测和脱敏个人身份信息
- **敏感代码**：密码、API密钥等敏感信息不存储
- **日志清理**：定期清理包含敏感信息的日志

### 3. 访问控制
- **会话隔离**：严格的会话边界，防止数据泄露
- **权限检查**：基于会话ID的访问权限验证
- **审计日志**：记录所有数据访问操作

## 备份和恢复策略

### 1. 自动备份
```python
def backup_redis_data():
    """备份Redis数据"""
    # 使用Redis BGSAVE命令
    redis_client.bgsave()
    
    # 备份关键数据到文件
    backup_data = {
        "active_sessions": redis_client.zrange("active_sessions", 0, -1, withscores=True),
        "agent_stats": redis_client.hgetall("stats:realtime"),
        "backup_timestamp": datetime.now().isoformat()
    }
    
    backup_path = work_dir / "backups" / f"redis_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(backup_path, 'w') as f:
        json.dump(backup_data, f, indent=2)

def backup_session_files():
    """备份会话文件"""
    backup_dir = work_dir / "backups" / "sessions" / datetime.now().strftime("%Y%m%d")
    backup_dir.mkdir(parents=True, exist_ok=True)
    
    # 压缩最近7天的会话文件
    import shutil
    shutil.make_archive(str(backup_dir / "sessions"), 'zip', str(sessions_dir))
```

### 2. 数据恢复
```python
def restore_session_data(backup_file: str):
    """从备份恢复会话数据"""
    with open(backup_file, 'r') as f:
        backup_data = json.load(f)
    
    # 恢复活跃会话索引
    for session_id, score in backup_data["active_sessions"]:
        redis_client.zadd("active_sessions", {session_id: score})
    
    # 恢复统计数据
    redis_client.hmset("stats:realtime", backup_data["agent_stats"])
```

## 监控和维护

### 1. 数据库监控
```python
def monitor_redis_health():
    """监控Redis健康状态"""
    info = redis_client.info()
    metrics = {
        "used_memory": info["used_memory"],
        "connected_clients": info["connected_clients"],
        "ops_per_sec": info["instantaneous_ops_per_sec"],
        "keyspace_hits": info["keyspace_hits"],
        "keyspace_misses": info["keyspace_misses"]
    }
    return metrics

def monitor_disk_usage():
    """监控磁盘使用情况"""
    import shutil
    
    total, used, free = shutil.disk_usage(work_dir)
    return {
        "total_gb": total // (1024**3),
        "used_gb": used // (1024**3), 
        "free_gb": free // (1024**3),
        "usage_percent": (used / total) * 100
    }
```

### 2. 数据清理
```python
def cleanup_expired_data():
    """清理过期数据"""
    # 清理过期会话
    cutoff_time = datetime.now() - timedelta(days=7)
    expired_sessions = redis_client.zrangebyscore(
        "active_sessions", 0, cutoff_time.timestamp()
    )
    
    for session_id in expired_sessions:
        redis_client.delete(f"session:{session_id}")
        redis_client.delete(f"session:{session_id}:messages")
        redis_client.zrem("active_sessions", session_id)
    
    # 清理临时文件
    temp_dir = work_dir / "cache"
    for file_path in temp_dir.glob("**/*"):
        if file_path.is_file() and file_path.stat().st_mtime < cutoff_time.timestamp():
            file_path.unlink()
```

---

*文档版本：v1.0*  
*更新日期：2025年6月25日*  
*维护者：AgenticSeek数据团队*
