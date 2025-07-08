# AgenticSeek Provider 配置指南

## 可用的 Provider 选项

AgenticSeek 支持以下 `provider_name` 选项，每个 provider 都有其特定的配置要求和使用场景：

### 本地/私有部署 Providers

#### 1. `ollama`
- **描述**: 本地 Ollama 服务器
- **配置示例**:
  ```ini
  provider_name = ollama
  provider_model = deepseek-r1:14b
  provider_server_address = 127.0.0.1:11434
  is_local = True
  ```
- **环境变量**: 可选设置 `OLLAMA_BASE_URL`
- **特点**: 
  - 支持自动模型下载
  - 完全本地运行，隐私安全
  - 需要先安装并启动 Ollama 服务

#### 2. `server`
- **描述**: 自定义的远程 LLM 服务器
- **配置示例**:
  ```ini
  provider_name = server
  provider_model = your-model-name
  provider_server_address = 192.168.1.100:5000
  is_local = True
  ```
- **特点**: 
  - 支持自定义协议的 LLM 服务器
  - 需要实现 `/setup`, `/generate`, `/get_updated_sentence` 接口

#### 3. `lm-studio`
- **描述**: LM Studio 本地服务器
- **配置示例**:
  ```ini
  provider_name = lm-studio
  provider_model = your-local-model
  provider_server_address = 127.0.0.1:1234
  is_local = True
  ```
- **特点**: 
  - 兼容 OpenAI API 格式
  - 本地运行，支持多种模型格式

#### 4. `deepseek-private`
- **描述**: 私有部署的 DeepSeek 服务器
- **配置示例**:
  ```ini
  provider_name = deepseek-private
  provider_model = deepseek-chat
  provider_server_address = your-private-server.com:8000
  is_local = True
  ```
- **环境变量**: 
  - `DEEPSEEK_PRIVATE_BASE_URL`: 私有服务器 URL
  - `DEEPSEEK_PRIVATE_API_KEY`: API 密钥（如需要）
- **特点**: 
  - 支持私有/企业级 DeepSeek 部署
  - 兼容 OpenAI API 格式

### 云端 API Providers

#### 5. `openai`
- **描述**: OpenAI 官方 API
- **配置示例**:
  ```ini
  provider_name = openai
  provider_model = gpt-4
  provider_server_address = 
  is_local = False
  ```
- **环境变量**: `OPENAI_API_KEY`
- **特点**: 
  - 需要 OpenAI API 密钥
  - 数据会发送到 OpenAI 服务器

#### 6. `deepseek`
- **描述**: DeepSeek 官方 API
- **配置示例**:
  ```ini
  provider_name = deepseek
  provider_model = deepseek-chat
  provider_server_address = 
  is_local = False
  ```
- **环境变量**: `DEEPSEEK_API_KEY`
- **特点**: 
  - 使用 DeepSeek 官方 API
  - 性价比较高的选择

#### 7. `google`
- **描述**: Google AI (Gemini) API
- **配置示例**:
  ```ini
  provider_name = google
  provider_model = gemini-pro
  provider_server_address = 
  is_local = False
  ```
- **环境变量**: `GOOGLE_API_KEY`
- **特点**: 
  - Google 的 Gemini 模型系列
  - 支持多模态能力

#### 8. `together`
- **描述**: Together AI API
- **配置示例**:
  ```ini
  provider_name = together
  provider_model = meta-llama/Llama-2-70b-chat-hf
  provider_server_address = 
  is_local = False
  ```
- **环境变量**: `TOGETHER_API_KEY`
- **特点**: 
  - 提供多种开源模型
  - 支持自定义模型部署

#### 9. `openrouter`
- **描述**: OpenRouter API 聚合服务
- **配置示例**:
  ```ini
  provider_name = openrouter
  provider_model = anthropic/claude-3-opus
  provider_server_address = 
  is_local = False
  ```
- **环境变量**: `OPENROUTER_API_KEY`
- **特点**: 
  - 聚合多家 AI 服务商
  - 一个 API 访问多种模型

#### 10. `huggingface`
- **描述**: Hugging Face Inference API
- **配置示例**:
  ```ini
  provider_name = huggingface
  provider_model = microsoft/DialoGPT-large
  provider_server_address = 
  is_local = False
  ```
- **环境变量**: `HUGGINGFACE_API_KEY`
- **特点**: 
  - 访问 Hugging Face 托管的模型
  - 支持大量开源模型

### 特殊 Providers

#### 11. `dsk_deepseek`
- **描述**: 非官方的免费 DeepSeek API (xtekky/deepseek4free)
- **配置示例**:
  ```ini
  provider_name = dsk_deepseek
  provider_model = deepseek-chat
  provider_server_address = 
  is_local = False
  ```
- **环境变量**: `DSK_DEEPSEEK_API_KEY`
- **特点**: 
  - 第三方免费接口
  - 可能不稳定，需自行配置

#### 12. `test`
- **描述**: 测试用 Provider
- **配置示例**:
  ```ini
  provider_name = test
  provider_model = test-model
  provider_server_address = 
  is_local = True
  ```
- **特点**: 
  - 返回预设的测试响应
  - 用于开发和调试

## 配置注意事项

### 安全性警告
使用以下 providers 时数据会发送到云端服务器：
- `openai`
- `deepseek` 
- `dsk_deepseek`
- `together`
- `google`
- `openrouter`
- `huggingface`

### 环境变量设置
在 `.env` 文件中设置相应的 API 密钥：

```bash
# OpenAI
OPENAI_API_KEY=your_openai_key_here

# DeepSeek
DEEPSEEK_API_KEY=your_deepseek_key_here

# Google AI
GOOGLE_API_KEY=your_google_key_here

# Together AI
TOGETHER_API_KEY=your_together_key_here

# OpenRouter
OPENROUTER_API_KEY=your_openrouter_key_here

# Hugging Face
HUGGINGFACE_API_KEY=your_huggingface_key_here

# DSK DeepSeek (第三方)
DSK_DEEPSEEK_API_KEY=your_dsk_key_here

# 私有 DeepSeek 服务器
DEEPSEEK_PRIVATE_API_KEY=your_private_key_here
DEEPSEEK_PRIVATE_BASE_URL=https://your-private-server.com/v1

# Ollama 自定义 URL
OLLAMA_BASE_URL=http://your-ollama-server:11434
```

### 切换 Provider 步骤

1. **修改 config.ini**:
   ```ini
   [MAIN]
   provider_name = 你选择的provider
   provider_model = 对应的模型名称
   provider_server_address = 服务器地址（本地provider）
   is_local = True/False
   ```

2. **设置环境变量** (如果是云端 API):
   - 在 `.env` 文件中添加相应的 API 密钥

3. **重启服务**:
   ```bash
   # 如果使用 Podman
   ./stop_services_podman.sh
   ./start_services_podman.sh
   
   # 如果本地运行后端
   # 重启 api.py 进程
   ```

4. **测试连接**:
   ```bash
   # 运行健康检查
   ./health_check_podman.sh
   
   # 或者测试前后端连通性
   ./test_frontend_backend_v2.sh
   ```

## 推荐配置

### 开发/测试环境
- **本地**: `ollama` + `deepseek-r1:14b`
- **测试**: `test` provider

### 生产环境
- **隐私优先**: 私有部署的 `ollama` 或 `deepseek-private`
- **性能优先**: `deepseek` 或 `openai`
- **成本优先**: `dsk_deepseek` (风险自负)

### 多模态需求
- `google` (Gemini) 或 `openai` (GPT-4V)

当前配置状态显示您正在使用 `ollama` provider，这是一个很好的本地化选择！
