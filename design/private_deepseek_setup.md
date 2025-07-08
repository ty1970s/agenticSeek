# 私有化DeepSeek服务器配置指南

## 概述

AgenticSeek现在支持连接到私有化部署的DeepSeek服务器。这允许您在自己的基础设施上运行DeepSeek模型，同时保持与OpenAI API的兼容性。

## 配置步骤

### 1. 环境变量配置

在`.env`文件中添加私有DeepSeek服务器配置：

```bash
# 私有DeepSeek服务器API密钥（可选，取决于您的服务器配置）
DEEPSEEK_PRIVATE_API_KEY='your-private-server-api-key'

# 或者如果您的私有服务器不需要API密钥，可以留空
DEEPSEEK_PRIVATE_API_KEY=''
```

### 2. config.ini配置

更新您的`config.ini`文件以使用私有DeepSeek服务器：

```ini
[MAIN]
is_local = True
provider_name = deepseek-private
provider_model = deepseek-chat
provider_server_address = your-deepseek-server.com:8000
agent_name = Jarvis
recover_last_session = True
save_session = True
speak = False
listen = False
jarvis_personality = False
languages = en zh

[BROWSER]
headless_browser = True
stealth_mode = True
```

### 3. 支持的服务器地址格式

私有DeepSeek provider支持多种服务器地址格式：

```bash
# 带协议的完整URL
provider_server_address = https://your-deepseek-server.com/v1

# 不带协议的地址（自动添加http://）
provider_server_address = your-deepseek-server.com:8000

# IP地址格式
provider_server_address = 192.168.1.100:8000

# 本地服务器
provider_server_address = localhost:8000
provider_server_address = 127.0.0.1:8000
```

## 私有DeepSeek服务器要求

### API兼容性

您的私有DeepSeek服务器必须提供OpenAI兼容的API端点：

- **Chat Completions端点**: `POST /v1/chat/completions`
- **请求格式**: 与OpenAI Chat Completions API相同
- **响应格式**: 与OpenAI Chat Completions API相同

### 示例API请求

```bash
curl -X POST "https://your-deepseek-server.com/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {
        "role": "user", 
        "content": "Hello, how are you?"
      }
    ],
    "temperature": 0.7,
    "max_tokens": 4096
  }'
```

### 支持的模型

常见的DeepSeek模型名称：
- `deepseek-chat`
- `deepseek-coder`
- `deepseek-math`
- 或您的私有部署中配置的自定义模型名

## Docker环境配置

如果您在Docker容器中运行AgenticSeek，需要确保网络连通性：

### docker-compose.yml示例

```yaml
services:
  backend:
    # ...other configurations
    environment:
      - DEEPSEEK_PRIVATE_API_KEY=${DEEPSEEK_PRIVATE_API_KEY}
    extra_hosts:
      - "your-deepseek-server.com:192.168.1.100"  # 如果需要自定义主机解析
```

### 网络访问

确保Docker容器能够访问您的私有DeepSeek服务器：

1. **同一网络**: 如果服务器在同一Docker网络中
2. **主机网络**: 使用`host.docker.internal`访问主机服务
3. **外部服务器**: 确保防火墙和网络策略允许访问

## 安全建议

### 1. HTTPS配置
建议在生产环境中使用HTTPS：

```ini
provider_server_address = https://your-deepseek-server.com
```

### 2. API密钥管理
- 使用强随机生成的API密钥
- 定期轮换API密钥
- 在环境变量中存储密钥，不要硬编码

### 3. 网络安全
- 配置防火墙规则限制访问
- 使用VPN或专用网络连接
- 实施IP白名单

## 故障排除

### 常见错误和解决方案

#### 1. 连接错误
```
Cannot connect to private DeepSeek server at http://your-server:8000/v1
```

**解决方案**:
- 检查服务器地址是否正确
- 确认服务器正在运行
- 验证网络连通性：`ping your-server`
- 检查端口是否开放：`telnet your-server 8000`

#### 2. 认证错误
```
Authentication failed for private DeepSeek server
```

**解决方案**:
- 检查`DEEPSEEK_PRIVATE_API_KEY`环境变量
- 确认API密钥有效
- 检查服务器是否需要认证

#### 3. API端点错误
```
Private DeepSeek server API endpoint not found
```

**解决方案**:
- 确认服务器支持OpenAI兼容API
- 检查端点路径是否为`/v1/chat/completions`
- 验证服务器配置

#### 4. 超时错误
```
Request to private DeepSeek server timed out
```

**解决方案**:
- 检查服务器负载
- 增加请求超时时间
- 优化模型配置降低响应时间

### 调试步骤

1. **测试连接**:
```bash
curl -I http://your-deepseek-server.com:8000/v1/models
```

2. **验证API**:
```bash
curl -X POST http://your-deepseek-server.com:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"test"}]}'
```

3. **检查日志**:
查看AgenticSeek日志文件中的详细错误信息：
```bash
tail -f logs/provider.log
```

## 性能优化

### 1. 缓存配置
私有DeepSeek响应会自动缓存在Redis中，TTL为1小时。

### 2. 连接池
系统会复用HTTP连接以提高性能。

### 3. 超时设置
默认请求超时为30秒，可以根据需要调整：

```python
# 在llm_provider.py中的deepseek_private_fn方法中调整
response = client.chat.completions.create(
    model=self.model,
    messages=history,
    timeout=60  # 调整超时时间
)
```

## 示例配置

### 完整配置示例

`.env`文件：
```bash
DEEPSEEK_PRIVATE_API_KEY='sk-your-private-key-here'
```

`config.ini`文件：
```ini
[MAIN]
is_local = True
provider_name = deepseek-private
provider_model = deepseek-chat
provider_server_address = https://deepseek.yourcompany.com:8000
agent_name = Jarvis
recover_last_session = True
save_session = True
speak = False
listen = False
jarvis_personality = False
languages = en zh

[BROWSER]
headless_browser = True
stealth_mode = True
```

### 验证配置

运行以下Python代码验证配置：

```python
from sources.llm_provider import Provider

# 创建provider实例
provider = Provider(
    provider_name="deepseek-private",
    model="deepseek-chat", 
    server_address="your-server.com:8000",
    is_local=True
)

# 测试连接
try:
    response = provider.respond([
        {"role": "user", "content": "Hello, this is a test message."}
    ])
    print("Success! Response:", response)
except Exception as e:
    print("Error:", str(e))
```

---

*文档版本：v1.0*  
*更新日期：2025年6月25日*  
*维护者：AgenticSeek团队*
