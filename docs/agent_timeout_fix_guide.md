# AgenticSeek 代理超时问题修复指南

## 问题描述

在使用 AgenticSeek 时发现 **Planner Agent 将任务分配给 Code Agent 后，Code Agent 没有持续工作** 的问题。经过诊断发现，主要原因是：

1. **DeepSeek-R1 推理模型处理复杂任务时耗时较长**
2. **Ollama 客户端缺少超时机制**
3. **Code Agent 在等待 LLM 响应时被无限阻塞**

## 已实施的修复方案

### 1. Ollama 客户端超时机制 (`sources/llm_provider.py`)

**修复内容：**
- 为 Ollama 客户端添加了 5 分钟超时配置
- 使用 `httpx.Timeout` 配置连接和请求超时
- 添加了信号处理机制 (Unix 系统) 和手动超时检查
- 改进了错误处理和日志记录

**关键代码：**
```python
# 配置超时
timeout_seconds = 300  # 5 minutes timeout for complex reasoning tasks
timeout_config = httpx.Timeout(timeout_seconds, connect=30.0)
client = OllamaClient(host=host, timeout=timeout_config)
```

### 2. Code Agent 异步超时保护 (`sources/agents/code_agent.py`)

**修复内容：**
- 为 Code Agent 的 LLM 请求添加 `asyncio.wait_for` 超时保护
- 设置 5 分钟超时限制
- 改进了错误处理和用户友好的错误消息

**关键代码：**
```python
# Add timeout protection for LLM request
answer, reasoning = await asyncio.wait_for(
    self.llm_request(), 
    timeout=300.0  # 5 minutes timeout
)
```

## 配置优化建议

### 1. 模型选择优化

对于不同场景建议使用不同模型：

```ini
# config.ini 配置示例

# 快速响应场景（简单任务）
provider_model = llama3.2:3b

# 平衡性能场景（一般任务）
provider_model = deepseek-r1:8b

# 复杂推理场景（复杂任务）- 需要更长超时
provider_model = deepseek-r1:32b
```

### 2. 超时配置调优

根据硬件性能和任务复杂度调整超时时间：

**低性能设备：**
```python
timeout_seconds = 180  # 3 minutes
```

**高性能设备：**
```python
timeout_seconds = 600  # 10 minutes
```

**复杂推理任务：**
```python
timeout_seconds = 900  # 15 minutes
```

### 3. 环境变量配置

在 `.env` 文件中添加以下配置：

```bash
# Ollama 超时配置
OLLAMA_REQUEST_TIMEOUT=300
OLLAMA_CONNECT_TIMEOUT=30

# Agent 超时配置
AGENT_LLM_TIMEOUT=300
AGENT_MAX_RETRIES=3

# 性能优化
OLLAMA_NUM_PARALLEL=1
OLLAMA_KEEP_ALIVE=5m
```

## 使用工具和脚本

### 1. 代理状态监控
```bash
# 诊断代理状态
./monitor_agents.py

# 持续监控
./monitor_agents.py
# 选择持续监控选项
```

### 2. 修复和测试工具
```bash
# 运行修复脚本
./fix_agents.py

# 选择全套修复流程 (选项 6)
```

### 3. 日志监控
```bash
# 实时查看特定代理日志
./show_logs.py --follow code_agent
./show_logs.py --follow planner_agent

# 搜索错误信息
./show_logs.py --search "timeout|error|failed"
```

## 故障排除步骤

### 步骤 1: 清理和重启
```bash
# 1. 清理 Ollama 缓存
curl -X POST http://localhost:11434/api/generate -d '{"model":"deepseek-r1:8b","keep_alive":0}'

# 2. 重启服务
./stop_services.sh
sleep 2
./start_services.sh
```

### 步骤 2: 测试基础功能
```bash
# 测试 Ollama 连接
curl http://localhost:11434/api/tags

# 测试后端健康状态
curl http://localhost:7777/health
```

### 步骤 3: 使用简化任务测试
发送简单任务而不是复杂任务：
- ✅ "写一个简单的 Hello World 程序"
- ❌ "创建一个复杂的机器学习部署系统"

### 步骤 4: 监控日志输出
```bash
# 在一个终端监控日志
./show_logs.py --follow --all

# 在另一个终端发送请求
curl -X POST http://localhost:7777/chat \
  -H "Content-Type: application/json" \
  -d '{"query":"写一个简单的Python函数","language":"zh-CN"}'
```

## 性能优化建议

### 1. 硬件优化
- **CPU**: 推理模型对 CPU 性能要求较高
- **内存**: 8B 模型建议至少 16GB RAM
- **存储**: 使用 SSD 提高模型加载速度

### 2. Ollama 配置优化
```bash
# 在 ~/.ollama/config.yaml 中配置
# (需要重启 Ollama)
max_loaded_models: 1
keep_alive: "5m"
num_parallel: 1
```

### 3. 模型量化选择
- `Q4_K_M`: 平衡质量和速度（推荐）
- `Q8_0`: 更高质量但更慢
- `Q2_K`: 更快但质量较低

## 预防措施

### 1. 任务复杂度控制
- 将复杂任务分解为多个简单步骤
- 避免一次性请求生成大量代码
- 使用渐进式的任务分配

### 2. 监控和告警
```bash
# 设置 cron 任务定期检查
*/5 * * * * /path/to/agenticSeek/monitor_agents.py --silent --alert
```

### 3. 备用模型配置
在 `config.ini` 中配置备用模型：
```ini
# 主模型
provider_model = deepseek-r1:8b

# 如果主模型超时，可以手动切换到更快的模型
# provider_model = llama3.2:3b
```

## 常见问题解答

**Q: 为什么选择 5 分钟超时？**
A: 基于 DeepSeek-R1 模型的推理特性，复杂任务可能需要 2-4 分钟，5 分钟提供了合理的缓冲。

**Q: 如果任务仍然超时怎么办？**
A: 1) 简化任务描述 2) 使用更快的模型 3) 增加超时时间 4) 分解任务

**Q: 修复后性能是否会下降？**
A: 不会。超时机制只在异常情况下生效，正常情况下不影响性能。

**Q: 如何调整超时时间？**
A: 修改 `sources/llm_provider.py` 中的 `timeout_seconds` 变量。

## 版本兼容性

- ✅ Ollama >= 0.1.0
- ✅ Python >= 3.8
- ✅ httpx >= 0.24.0
- ✅ asyncio (Python 标准库)

## 联系支持

如果问题仍然存在，请：
1. 运行 `./monitor_agents.py` 收集诊断信息
2. 保存相关日志文件
3. 记录复现步骤
4. 提交问题报告
