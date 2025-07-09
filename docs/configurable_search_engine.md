# 配置浏览器默认搜索引擎

## 简介

AgenticSeek 现在支持配置浏览器的默认搜索网站。您可以选择 Google、Bing、DuckDuckGo 或任何其他搜索引擎作为默认页面。

## 配置方法

### 1. 通过 config.ini 文件配置

编辑项目根目录下的 `config.ini` 文件，在 `[BROWSER]` 部分添加或修改 `default_search_url` 参数：

```ini
[BROWSER]
headless_browser = True
stealth_mode = False
default_search_url = https://www.bing.com
```

### 2. 支持的搜索引擎示例

#### Google (默认)
```ini
default_search_url = https://www.google.com
```

#### Bing
```ini
default_search_url = https://www.bing.com
```

#### DuckDuckGo
```ini
default_search_url = https://duckduckgo.com
```

#### Baidu (百度)
```ini
default_search_url = https://www.baidu.com
```

#### Yandex
```ini
default_search_url = https://yandex.com
```

#### 其他搜索引擎
您可以使用任何有效的URL作为默认搜索页面：
```ini
default_search_url = https://searx.example.com
```

### 3. 通过环境变量配置 (可选)

您也可以在 `.env` 文件中添加示例配置（这些是注释，仅作参考）：

```bash
# Browser configuration examples
# DEFAULT_SEARCH_URL="https://www.google.com"
# DEFAULT_SEARCH_URL="https://www.bing.com"
# DEFAULT_SEARCH_URL="https://duckduckgo.com"
```

## 应用配置

配置修改后，需要重新启动服务：

### 重启 API 服务器
```bash
# 停止当前服务
pkill -f "python api.py"

# 重新启动
python api.py
```

### 重启 CLI 客户端
```bash
python cli.py
```

## 验证配置

启动服务后，浏览器将自动导航到您配置的默认搜索页面。您可以在日志中看到类似以下的信息：

```
Browser initialized with default URL: https://www.bing.com
```

## 注意事项

1. **URL 格式**: 确保提供完整的 URL，包括 `https://` 或 `http://` 前缀
2. **网络访问**: 确保配置的URL可以正常访问
3. **无头模式**: 在无头模式下运行时，仍然会导航到默认页面，但不会显示界面
4. **搜索功能**: 这个配置只影响浏览器的初始页面，不影响搜索工具的功能

## 故障排除

如果配置不生效：

1. 检查 `config.ini` 文件格式是否正确
2. 确保重新启动了服务
3. 检查日志文件中的错误信息
4. 验证URL是否可以访问

## 示例配置文件

完整的 `config.ini` 示例：

```ini
[MAIN]
is_local = True
provider_name = ollama
provider_model = deepseek-r1:8b
provider_server_address = 127.0.0.1:11434
agent_name = Jarvis
recover_last_session = False
save_session = False
speak = False
listen = False
jarvis_personality = False
languages = en

[BROWSER]
headless_browser = True
stealth_mode = False
default_search_url = https://www.bing.com
```

这样配置后，浏览器将使用 Bing 作为默认搜索引擎。
