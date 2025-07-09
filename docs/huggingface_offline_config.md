# Hugging Face 连接说明和离线配置

## 为什么程序会连接 Hugging Face？

AgenticSeek 在启动时会连接到 Hugging Face 模型库，主要原因如下：

### 1. 智能路由系统
程序使用了 **BART 大型模型** (`facebook/bart-large-mnli`) 进行零样本文本分类，这是智能路由系统的核心组件。该模型用于：
- 分析用户查询的意图
- 决定将任务分派给哪个 AI 代理（编程、文件操作、网络搜索等）
- 提高任务路由的准确性

### 2. 其他可能的模型下载
- **语言翻译模型** (MarianMT) - 用于多语言支持
- **语音转文本模型** - 如果启用了语音功能
- **内存压缩模型** - 用于对话历史管理

## 如何配置离线模式

### 方法一：设置环境变量

在 `.env` 文件中添加以下配置：

```bash
# 启用离线模式，防止下载模型
TRANSFORMERS_OFFLINE=true

# 设置模型缓存目录（可选）
TRANSFORMERS_CACHE=/path/to/your/cache
HF_HOME=/path/to/your/hf_cache
```

### 方法二：预下载模型

如果您想在离线环境中使用，可以先下载模型：

```python
# 运行一次以下代码来预下载模型
from transformers import pipeline

# 下载 BART 模型到缓存
pipeline("zero-shot-classification", model="facebook/bart-large-mnli")
```

### 方法三：使用本地模型

您可以将模型下载到本地目录，然后修改代码指向本地路径：

```python
# 在 sources/router.py 中修改
"bart": pipeline("zero-shot-classification", model="/path/to/local/bart-model")
```

## 离线模式的影响

启用离线模式后：

### ✅ 优点
- 不需要网络连接到 Hugging Face
- 启动速度更快（如果模型已缓存）
- 适合企业内网环境

### ⚠️ 限制
- 如果没有预下载模型，程序会回退到仅使用 LLM 路由器
- 任务路由准确性可能略有下降
- 首次运行仍需联网下载模型到缓存

## 模型缓存位置

默认情况下，Hugging Face 模型会缓存到：

- **macOS**: `~/.cache/huggingface/transformers/`
- **Linux**: `~/.cache/huggingface/transformers/`
- **Windows**: `C:\\Users\\{username}\\.cache\\huggingface\\transformers\\`

## 完全禁用 BART 模型

如果您想完全禁用 BART 模型以避免任何网络连接，可以：

1. 设置环境变量：
```bash
TRANSFORMERS_OFFLINE=true
```

2. 删除或注释掉 `sources/router.py` 中的 BART 模型加载代码

程序会自动回退到仅使用内置的 LLM 路由器，仍能正常工作。

## 验证离线模式

启用离线模式后，您会在日志中看到：

```
Warning: Could not load BART model (Model not found in cache). Using fallback classification.
```

这表明程序正在离线模式下运行。

## 推荐配置

### 首次使用（联网）
```bash
# .env 文件
TRANSFORMERS_OFFLINE=false
TRANSFORMERS_CACHE=./models_cache
```

### 后续使用（可离线）
```bash
# .env 文件
TRANSFORMERS_OFFLINE=true
TRANSFORMERS_CACHE=./models_cache
```

这样既能确保模型正常下载到本地缓存，又能在后续使用中避免网络连接。

## 故障排除

### 问题：模型下载失败
**解决方案**：
1. 检查网络连接
2. 检查防火墙设置
3. 尝试设置 HTTP 代理：
```bash
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
```

### 问题：离线模式下程序无法启动
**解决方案**：
1. 确保模型已预下载到缓存
2. 检查 `TRANSFORMERS_CACHE` 路径是否正确
3. 临时禁用离线模式以重新下载模型

### 问题：企业环境无法访问 Hugging Face
**解决方案**：
1. 联系 IT 部门开放 `huggingface.co` 域名
2. 使用公司内部的模型镜像站点
3. 手动下载模型文件到本地
