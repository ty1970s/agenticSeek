# Ollama 配置指南

## 概述

AgenticSeek支持灵活的Ollama配置，可以连接到本地或远程Ollama服务器。通过`OLLAMA_BASE_URL`环境变量，您可以自定义Ollama服务器的地址。

## 配置方式

### 1. 环境变量配置

在`.env`文件中设置Ollama服务器地址：

```bash
# 本地Ollama服务器 (默认)
OLLAMA_BASE_URL="http://localhost:11434"

# 远程Ollama服务器
OLLAMA_BASE_URL="http://192.168.1.100:11434"

# Docker容器中的Ollama
OLLAMA_BASE_URL="http://ollama:11434"

# HTTPS连接 (如果支持)
OLLAMA_BASE_URL="https://your-ollama-server.com:11434"
```

### 2. 配置优先级

Ollama连接地址的优先级顺序：

1. **OLLAMA_BASE_URL环境变量** (最高优先级)
2. 本地模式：`http://localhost:11434`
3. 远程模式：使用`server_address`参数

### 3. 代码实现

```python
def ollama_fn(self, history, verbose=False):
    """
    Use local or remote Ollama server to generate text.
    """
    thought = ""
    
    # Check for custom OLLAMA_BASE_URL from environment
    custom_base_url = os.getenv("OLLAMA_BASE_URL")
    if custom_base_url:
        host = custom_base_url
    else:
        host = f"{self.internal_url}:11434" if self.is_local else f"http://{self.server_address}"
    
    client = OllamaClient(host=host)
    # ... 其余代码
```

## 使用场景

### 1. 本地开发

```bash
# 使用默认本地Ollama
OLLAMA_BASE_URL="http://localhost:11434"
```

### 2. Docker部署

```bash
# 连接到Docker容器中的Ollama
OLLAMA_BASE_URL="http://ollama:11434"
```

### 3. 远程服务器

```bash
# 连接到远程Ollama服务器
OLLAMA_BASE_URL="http://192.168.1.100:11434"
```

### 4. 负载均衡

```bash
# 通过负载均衡器访问Ollama集群
OLLAMA_BASE_URL="http://ollama-lb.internal:11434"
```

## 故障排除

### 1. 连接失败

如果出现连接错误：

```
Ollama connection failed at http://localhost:11434. Check if the server is running.
```

**解决方案：**
1. 检查Ollama服务器是否运行：`ollama serve`
2. 验证端口是否正确：`netstat -tlnp | grep 11434`
3. 检查防火墙设置
4. 验证`OLLAMA_BASE_URL`配置是否正确

### 2. 模型下载

如果模型不存在，系统会自动下载：

```
Downloading llama2:7b...
```

**说明：**
- 首次使用模型时会自动下载
- 下载过程可能需要几分钟到几小时
- 确保有足够的磁盘空间

### 3. 网络配置

对于远程Ollama服务器：

```bash
# 确保Ollama服务器绑定到所有接口
OLLAMA_HOST=0.0.0.0 ollama serve

# 或设置环境变量
export OLLAMA_HOST=0.0.0.0
ollama serve
```

## 安全考虑

### 1. 网络安全

- 在生产环境中，建议使用HTTPS连接
- 配置适当的防火墙规则
- 限制对Ollama服务器的访问

### 2. 访问控制

- 考虑在Ollama前加入认证代理
- 使用VPN或专用网络连接
- 监控访问日志

## 性能优化

### 1. 网络延迟

- 尽量使用本地或低延迟网络连接
- 考虑缓存机制减少重复请求

### 2. 负载分布

- 使用多个Ollama实例进行负载分布
- 配置健康检查和故障转移

## 示例配置

### Docker Compose示例

```yaml
version: '3.8'
services:
  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0

  agenticseek:
    build: .
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    depends_on:
      - ollama
```

### Kubernetes示例

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: agenticseek-config
data:
  OLLAMA_BASE_URL: "http://ollama-service:11434"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agenticseek
spec:
  template:
    spec:
      containers:
      - name: agenticseek
        image: agenticseek:latest
        envFrom:
        - configMapRef:
            name: agenticseek-config
```

## 总结

通过`OLLAMA_BASE_URL`环境变量，AgenticSeek提供了灵活的Ollama服务器配置选项。这使得系统可以适应各种部署场景，从本地开发到分布式生产环境。

配置要点：
- 设置正确的`OLLAMA_BASE_URL`
- 确保网络连通性
- 注意安全和性能考虑
- 使用适当的故障排除方法
