# AgenticSeek API 设计文档

## API 概述

AgenticSeek提供基于FastAPI的RESTful API服务，支持同步和异步任务处理。API设计遵循RESTful规范，提供清晰的资源路径和HTTP方法映射。

## 基础信息

- **Base URL**: `http://localhost:7777` (开发环境)
- **API版本**: v0.1.0
- **内容类型**: `application/json`
- **字符编码**: UTF-8

## 认证和安全

### 认证方式
当前版本主要用于本地部署，暂未实现复杂的认证机制。在生产环境中建议添加：
- JWT Token认证
- API密钥验证
- 请求速率限制

### CORS配置
支持跨域请求，配置了适当的CORS头：
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## 核心API端点

### 1. 查询处理 API

#### POST /api/query
处理用户查询请求，返回AI助手的响应。

**请求格式**：
```json
{
    "query": "string",          // 用户查询内容
    "session_id": "string",     // 可选，会话ID
    "stream": false,            // 可选，是否流式响应
    "context": {}               // 可选，额外上下文信息
}
```

**响应格式**：
```json
{
    "response": "string",       // AI助手回复
    "reasoning": "string",      // 推理过程（如果可用）
    "agent_used": "string",     // 使用的代理类型
    "execution_time": 1.23,     // 执行时间（秒）
    "session_id": "string",     // 会话ID
    "status": "success|error",  // 执行状态
    "blocks_executed": [        // 执行的工具块
        {
            "tool": "python",
            "code": "print('hello')",
            "output": "hello",
            "success": true
        }
    ]
}
```

**示例请求**：
```bash
curl -X POST "http://localhost:7777/api/query" \
     -H "Content-Type: application/json" \
     -d '{
       "query": "写一个计算斐波那契数列的Python函数",
       "session_id": "user123"
     }'
```

#### POST /api/query/stream
流式查询处理，支持实时响应输出。

**请求格式**：同 `/api/query`

**响应格式**：Server-Sent Events (SSE)
```javascript
data: {"type": "thinking", "content": "正在思考..."}
data: {"type": "response", "content": "我来帮你写一个函数..."}
data: {"type": "code_execution", "tool": "python", "code": "def fibonacci(n):..."}
data: {"type": "result", "output": "函数执行成功"}
data: {"type": "done", "final_response": "完整回复"}
```

### 2. 会话管理 API

#### GET /api/sessions
获取所有会话列表。

**响应格式**：
```json
{
    "sessions": [
        {
            "session_id": "string",
            "created_at": "2025-06-25T10:00:00Z",
            "last_activity": "2025-06-25T10:30:00Z",
            "message_count": 15,
            "title": "Python编程助手"
        }
    ]
}
```

#### GET /api/sessions/{session_id}
获取特定会话的详细信息。

**响应格式**：
```json
{
    "session_id": "string",
    "created_at": "2025-06-25T10:00:00Z",
    "messages": [
        {
            "timestamp": "2025-06-25T10:00:00Z",
            "role": "user",
            "content": "你好"
        },
        {
            "timestamp": "2025-06-25T10:00:01Z",
            "role": "assistant",
            "content": "你好！我是AgenticSeek助手，有什么可以帮助你的吗？",
            "agent_used": "casual_agent"
        }
    ]
}
```

#### DELETE /api/sessions/{session_id}
删除指定会话。

**响应格式**：
```json
{
    "message": "Session deleted successfully",
    "session_id": "string"
}
```

### 3. 代理管理 API

#### GET /api/agents
获取可用代理列表及其状态。

**响应格式**：
```json
{
    "agents": [
        {
            "name": "Jarvis",
            "type": "casual_agent",
            "role": "casual",
            "status": "ready",
            "description": "日常对话代理",
            "tools": []
        },
        {
            "name": "Coder",
            "type": "code_agent", 
            "role": "code",
            "status": "ready",
            "description": "编程助手代理",
            "tools": ["python", "bash", "c", "go", "java"]
        }
    ]
}
```

#### GET /api/agents/{agent_type}/status
获取特定代理的详细状态。

**响应格式**：
```json
{
    "agent_type": "code_agent",
    "status": "ready|busy|error",
    "current_task": "string",      // 当前执行的任务
    "queue_length": 3,             // 队列中的任务数
    "last_activity": "2025-06-25T10:30:00Z",
    "performance_stats": {
        "avg_response_time": 2.34,
        "success_rate": 0.95,
        "total_requests": 1234
    }
}
```

### 4. 工具管理 API

#### GET /api/tools
获取可用工具列表。

**响应格式**：
```json
{
    "tools": [
        {
            "name": "python",
            "type": "interpreter",
            "description": "Python代码解释器",
            "supported_features": ["code_execution", "file_save"],
            "safety_level": "sandboxed"
        },
        {
            "name": "web_search",
            "type": "api",
            "description": "网页搜索工具",
            "supported_features": ["search", "extract"],
            "safety_level": "safe"
        }
    ]
}
```

#### POST /api/tools/{tool_name}/execute
直接执行特定工具（调试用）。

**请求格式**：
```json
{
    "content": "print('Hello, World!')",  // 工具执行内容
    "parameters": {                       // 可选参数
        "save_path": "test.py",
        "timeout": 30
    }
}
```

**响应格式**：
```json
{
    "tool": "python",
    "execution_time": 0.123,
    "success": true,
    "output": "Hello, World!",
    "error": null,
    "saved_files": ["test.py"]
}
```

### 5. 系统状态 API

#### GET /api/health
系统健康检查。

**响应格式**：
```json
{
    "status": "healthy|degraded|unhealthy",
    "timestamp": "2025-06-25T10:30:00Z",
    "services": {
        "llm_provider": "healthy",
        "database": "healthy", 
        "search_engine": "healthy",
        "browser": "healthy"
    },
    "version": "0.1.0"
}
```

#### GET /api/stats
系统统计信息。

**响应格式**：
```json
{
    "uptime": 86400,                    // 系统运行时间（秒）
    "total_requests": 5678,             // 总请求数
    "active_sessions": 12,              // 活跃会话数
    "avg_response_time": 2.34,          // 平均响应时间
    "agent_usage": {
        "casual_agent": 45,
        "code_agent": 123,
        "browser_agent": 67,
        "file_agent": 34,
        "planner_agent": 23
    },
    "resource_usage": {
        "cpu_percent": 35.2,
        "memory_percent": 68.5,
        "disk_usage_gb": 12.3
    }
}
```

### 6. 配置管理 API

#### GET /api/config
获取当前系统配置。

**响应格式**：
```json
{
    "llm_provider": {
        "name": "ollama",
        "model": "deepseek-r1:14b",
        "server_address": "127.0.0.1:11434",
        "is_local": true
    },
    "features": {
        "speech_to_text": false,
        "text_to_speech": false,
        "jarvis_personality": false,
        "session_recovery": false
    },
    "browser": {
        "headless": true,
        "stealth_mode": false
    },
    "languages": ["en"]
}
```

#### PUT /api/config
更新系统配置。

**请求格式**：
```json
{
    "llm_provider": {
        "name": "ollama",
        "model": "qwen2.5:14b"
    },
    "features": {
        "text_to_speech": true
    }
}
```

## 异步任务 API

### Celery任务队列集成

#### POST /api/tasks/submit
提交长时间运行的任务。

**请求格式**：
```json
{
    "task_type": "complex_analysis",
    "query": "分析这个大型数据集并生成报告",
    "parameters": {
        "data_source": "file://data.csv",
        "output_format": "pdf"
    }
}
```

**响应格式**：
```json
{
    "task_id": "celery-task-uuid",
    "status": "pending",
    "estimated_time": 300,  // 预估时间（秒）
    "submitted_at": "2025-06-25T10:30:00Z"
}
```

#### GET /api/tasks/{task_id}
查询任务状态。

**响应格式**：
```json
{
    "task_id": "celery-task-uuid",
    "status": "pending|processing|completed|failed",
    "progress": 0.65,       // 进度 0.0-1.0
    "current_step": "数据分析中...",
    "result": null,         // 完成时包含结果
    "error": null,          // 失败时包含错误信息
    "started_at": "2025-06-25T10:30:00Z",
    "completed_at": null
}
```

## WebSocket API

### 实时通信

#### WS /ws/chat/{session_id}
建立WebSocket连接进行实时聊天。

**连接参数**：
- `session_id`: 会话标识符

**消息格式**：

客户端发送：
```json
{
    "type": "user_message",
    "content": "用户输入的内容",
    "timestamp": "2025-06-25T10:30:00Z"
}
```

服务器发送：
```json
{
    "type": "agent_response|thinking|tool_execution|error",
    "content": "响应内容",
    "agent": "code_agent",
    "timestamp": "2025-06-25T10:30:01Z",
    "metadata": {
        "tool": "python",
        "execution_time": 1.23
    }
}
```

## 错误处理

### 错误响应格式

所有API错误响应遵循统一格式：

```json
{
    "error": {
        "code": "ERROR_CODE",
        "message": "Human-readable error message",
        "details": {
            "field": "Additional error details",
            "suggestion": "How to fix this error"
        },
        "timestamp": "2025-06-25T10:30:00Z",
        "request_id": "unique-request-id"
    }
}
```

### 常见错误码

| 错误码 | HTTP状态码 | 描述 |
|--------|------------|------|
| `INVALID_QUERY` | 400 | 查询内容无效或为空 |
| `AGENT_NOT_FOUND` | 404 | 指定的代理不存在 |
| `TOOL_EXECUTION_FAILED` | 500 | 工具执行失败 |
| `LLM_PROVIDER_ERROR` | 502 | LLM服务不可用 |
| `SESSION_NOT_FOUND` | 404 | 会话不存在 |
| `RATE_LIMIT_EXCEEDED` | 429 | 请求频率过高 |
| `RESOURCE_EXHAUSTED` | 503 | 系统资源不足 |

## API客户端示例

### Python客户端

```python
import requests
import json

class AgenticSeekClient:
    def __init__(self, base_url="http://localhost:7777"):
        self.base_url = base_url
        self.session = requests.Session()
    
    def query(self, text, session_id=None):
        """发送查询请求"""
        data = {"query": text}
        if session_id:
            data["session_id"] = session_id
        
        response = self.session.post(
            f"{self.base_url}/api/query",
            json=data
        )
        return response.json()
    
    def get_agents(self):
        """获取代理列表"""
        response = self.session.get(f"{self.base_url}/api/agents")
        return response.json()
    
    def health_check(self):
        """健康检查"""
        response = self.session.get(f"{self.base_url}/api/health")
        return response.json()

# 使用示例
client = AgenticSeekClient()
result = client.query("写一个快速排序算法")
print(result["response"])
```

### JavaScript客户端

```javascript
class AgenticSeekClient {
    constructor(baseUrl = 'http://localhost:7777') {
        this.baseUrl = baseUrl;
    }
    
    async query(text, sessionId = null) {
        const data = { query: text };
        if (sessionId) data.session_id = sessionId;
        
        const response = await fetch(`${this.baseUrl}/api/query`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        return await response.json();
    }
    
    async streamQuery(text, onUpdate) {
        const response = await fetch(`${this.baseUrl}/api/query/stream`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query: text })
        });
        
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        
        while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            
            const chunk = decoder.decode(value);
            const lines = chunk.split('\n');
            
            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    const data = JSON.parse(line.slice(6));
                    onUpdate(data);
                }
            }
        }
    }
}

// 使用示例
const client = new AgenticSeekClient();
const result = await client.query('Hello, AgenticSeek!');
console.log(result.response);
```

## API版本控制

### 版本策略
- 使用语义化版本号 (Semantic Versioning)
- 主要版本变更：不兼容的API修改
- 次要版本变更：向后兼容的功能添加
- 补丁版本变更：向后兼容的问题修复

### 版本声明
- API版本在响应头中声明：`API-Version: 0.1.0`
- 客户端可通过请求头指定版本：`Accept-Version: 0.1.0`

## 性能和限制

### 请求限制
- 默认请求大小限制：10MB
- 查询文本长度限制：50,000字符
- 并发请求限制：100个/IP
- 速率限制：1000请求/小时/IP

### 超时设置
- API响应超时：30秒
- 工具执行超时：300秒
- WebSocket连接超时：3600秒

### 缓存策略
- 相同查询24小时内缓存结果
- 代理状态信息缓存60秒
- 系统配置缓存5分钟

---

*文档版本：v1.0*  
*更新日期：2025年6月25日*  
*维护者：AgenticSeek API团队*
