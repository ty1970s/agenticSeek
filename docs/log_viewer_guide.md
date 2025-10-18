# AgenticSeek 日志查看工具

AgenticSeek 项目提供了两个强大的日志查看工具，帮助您监控和调试系统运行状态。

## 工具说明

### 1. show_logs.sh (Bash 脚本)
基于 Bash 的轻量级日志查看工具，支持彩色输出和实时跟踪。

### 2. show_logs.py (Python 脚本)
功能更丰富的 Python 日志查看器，支持高级搜索、过滤和美化显示。

## 快速开始

### 查看所有日志文件
```bash
# 使用 Bash 脚本
./show_logs.sh

# 使用 Python 脚本
./show_logs.py
```

### 列出可用的日志文件
```bash
# 使用 Bash 脚本
./show_logs.sh -l

# 使用 Python 脚本
./show_logs.py --list
```

### 实时跟踪日志
```bash
# 跟踪所有日志
./show_logs.sh -f

# 跟踪特定日志
./show_logs.sh -f backend
./show_logs.py --follow backend
```

## 可用的日志类型

- **backend**: 后端服务日志
- **browser**: 浏览器操作日志
- **browser_agent**: 浏览器代理日志
- **code_agent**: 代码代理日志
- **language**: 语言处理日志
- **memory**: 内存管理日志
- **planner_agent**: 规划代理日志
- **provider**: 提供商日志
- **router**: 路由器日志
- **tools**: 工具日志
- **main**: 主程序日志

## 常用命令示例

### Bash 脚本 (show_logs.sh)

```bash
# 显示帮助信息
./show_logs.sh -h

# 显示最后100行日志
./show_logs.sh -n 100

# 清空屏幕后显示日志
./show_logs.sh -c

# 实时跟踪后端日志
./show_logs.sh -f backend

# 显示特定日志的最后50行
./show_logs.sh browser
```

### Python 脚本 (show_logs.py)

```bash
# 显示帮助信息
./show_logs.py -h

# 列出所有日志文件及其状态
./show_logs.py --list

# 显示所有日志的最后100行
./show_logs.py --all --lines 100

# 只显示ERROR级别的日志
./show_logs.py --level ERROR backend

# 搜索包含特定关键词的日志行
./show_logs.py --search "error"
./show_logs.py --search "exception" backend

# 实时跟踪所有日志
./show_logs.py --follow --all

# 清空屏幕后显示日志
./show_logs.py --clear backend
```

## 高级功能 (仅 Python 版本)

### 日志级别过滤
```bash
# 只显示错误日志
./show_logs.py --level ERROR

# 只显示警告及以上级别
./show_logs.py --level WARNING
```

### 日志搜索
```bash
# 在所有日志中搜索关键词
./show_logs.py --search "connection"

# 在特定日志中搜索
./show_logs.py --search "timeout" backend

# 使用正则表达式搜索
./show_logs.py --search "error.*connection"
```

### 美化显示
Python 版本支持 Rich 库的美化显示，安装后可获得更好的视觉效果：
```bash
pip install rich
```

## 日志文件位置

- 主日志文件: `./agenticseek.log`
- 分类日志目录: `./.logs/`
  - `backend.log` - 后端服务日志
  - `browser.log` - 浏览器日志
  - `browser_agent.log` - 浏览器代理日志
  - `code_agent.log` - 代码代理日志
  - `language.log` - 语言处理日志
  - `memory.log` - 内存管理日志
  - `planner_agent.log` - 规划代理日志
  - `provider.log` - 提供商日志
  - `router.log` - 路由器日志
  - `tools.log` - 工具日志

## 故障排除

### 权限问题
如果脚本无法执行，请检查权限：
```bash
chmod +x show_logs.sh
chmod +x show_logs.py
```

### 日志文件不存在
如果提示日志文件不存在，请确保：
1. AgenticSeek 已经运行过至少一次
2. 日志记录功能已启用
3. 当前目录正确

### Python 依赖
Python 脚本的基本功能不需要额外依赖，但推荐安装 Rich 库以获得更好的显示效果：
```bash
pip install rich
```

## 使用技巧

1. **快速诊断**: 使用 `--search "error"` 快速找到错误信息
2. **性能监控**: 实时跟踪 `backend` 和 `router` 日志来监控性能
3. **调试特定功能**: 根据功能模块查看对应的日志文件
4. **历史分析**: 使用 `--lines` 参数查看更多历史记录
5. **组合使用**: 结合不同参数来精确获取所需信息

## 注意事项

- 实时跟踪模式下，使用 `Ctrl+C` 退出
- 大型日志文件可能影响显示性能，建议使用适当的行数限制
- 搜索功能支持正则表达式，但要注意转义特殊字符
- 日志文件使用 UTF-8 编码，如有乱码请检查系统编码设置
