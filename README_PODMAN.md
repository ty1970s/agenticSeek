# AgenticSeek Podman 部署指南

## 概述

AgenticSeek 现在支持使用 Podman 作为容器运行时，提供了更安全、更灵活的容器化部署方案。

## 前置条件

### 系统要求
- macOS 10.15+ 或 Linux (Ubuntu 20.04+, RHEL 8+, CentOS 8+)
- Python 3.10+
- Podman 3.0+
- podman-compose 或 docker-compose

### 安装依赖

#### macOS
```bash
# 使用 Homebrew 安装
brew install podman podman-compose

# 初始化和启动 Podman machine
podman machine init
podman machine start
```

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y podman podman-compose
```

#### RHEL/CentOS/Fedora
```bash
sudo dnf install -y podman podman-compose
```

## 快速开始

### 1. 自动安装（推荐）

```bash
# 克隆项目
git clone https://github.com/Fosowl/agenticSeek.git
cd agenticSeek

# 运行 Podman 安装脚本
./install_podman.sh
```

### 2. 手动安装

```bash
# 1. 安装 Podman（见上面的安装依赖）

# 2. 配置环境文件
cp .env.podman.example .env
# 编辑 .env 文件，设置必要的配置

# 3. 安装 Python 依赖
pip install -r requirements.txt

# 4. 启动服务
./start_services_podman.sh
```

## 服务管理

### 启动服务

```bash
# 启动核心服务（前端 + 搜索）
./start_services_podman.sh

# 启动完整服务（包括后端）
./start_services_podman.sh full
```

### 停止服务

```bash
# 停止所有服务
./stop_services_podman.sh

# 停止并清理镜像
./stop_services_podman.sh --clean-images

# 停止并清理所有数据
./stop_services_podman.sh --clean-all
```

### 查看服务状态

```bash
# 查看运行的容器
podman ps

# 查看服务日志
podman logs -f backend
podman logs -f frontend
podman logs -f searxng

# 使用 compose 查看所有服务
podman-compose -f podman-compose.yml logs -f
```

## 配置选项

### 环境变量

主要的环境变量配置：

```bash
# 基础服务配置
SEARXNG_BASE_URL="http://searxng:8080"
REDIS_BASE_URL="redis://redis:6379/0"
WORK_DIR="/path/to/your/workspace"
BACKEND_PORT="7777"

# 容器运行时配置
CONTAINER_RUNTIME="podman"
PODMAN_INTERNAL_URL="http://host.containers.internal"

# API 密钥
OPENAI_API_KEY='your-key-here'
DEEPSEEK_API_KEY='your-key-here'
# ... 其他 API 密钥
```

### Podman 特定配置

在 `podman/containers.conf` 中可以配置：

```ini
[containers]
# 网络配置
netns = "host"
userns = "host"

[network]
# 网络后端
network_backend = "netavark"

[machine]
# Podman machine 配置 (macOS)
cpus = 2
memory = 2048
disk_size = 10
```

## 服务访问

启动成功后，可以通过以下地址访问服务：

- **前端界面**: http://localhost:3080
- **搜索服务**: http://localhost:8081  
- **后端 API**: http://localhost:7777 (仅在 full 模式下)
- **健康检查**: http://localhost:7777/api/health

## 网络配置

### 容器间通信

Podman 使用自定义网络 `agentic-seek-net` 来实现容器间通信：

```bash
# 查看网络
podman network ls

# 查看网络详情
podman network inspect agentic-seek-net
```

### 主机访问

容器内可以通过 `host.containers.internal` 访问主机服务。

## 数据持久化

### 数据卷

- `redis-data`: Redis 数据持久化
- `chrome_profiles`: Chrome 配置文件

### 文件挂载

- 工作目录: `${WORK_DIR}:/opt/workspace`
- 前端源码: `./frontend/agentic-seek-front/src:/app/src`
- 截图目录: `./screenshots:/app/screenshots`

## 故障排除

### 常见问题

1. **Podman machine 未启动 (macOS)**
   ```bash
   podman machine start
   ```

2. **权限问题 (Linux)**
   ```bash
   # 检查用户命名空间
   podman unshare cat /proc/self/uid_map
   
   # 重置用户命名空间
   podman system reset
   ```

3. **网络连接问题**
   ```bash
   # 重建网络
   podman network rm agentic-seek-net
   podman network create agentic-seek-net
   ```

4. **容器启动失败**
   ```bash
   # 查看详细日志
   podman logs -f backend
   
   # 检查容器状态
   podman inspect backend
   ```

### 调试命令

```bash
# 进入容器调试
podman exec -it backend /bin/bash

# 查看资源使用
podman stats

# 查看系统信息
podman info
```

## 性能优化

### 资源限制

在 compose 文件中添加资源限制：

```yaml
services:
  backend:
    # ... 其他配置
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1'
        reservations:
          memory: 1G
          cpus: '0.5'
```

### 存储优化

```bash
# 清理未使用的镜像
podman image prune -f

# 清理未使用的容器
podman container prune -f

# 清理未使用的卷
podman volume prune -f
```

## 生产部署

### Systemd 服务

```bash
# 复制服务文件
sudo cp podman/agenticseek.service /etc/systemd/system/

# 编辑服务文件中的路径
sudo systemctl edit agenticseek.service

# 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable agenticseek
sudo systemctl start agenticseek
```

### 监控

```bash
# 查看服务状态
sudo systemctl status agenticseek

# 查看服务日志
sudo journalctl -u agenticseek -f
```

## 与 Docker 的区别

| 特性 | Docker | Podman |
|------|--------|---------|
| 守护进程 | 需要 Docker daemon | 无守护进程 |
| 权限 | 通常需要 root 权限 | 支持 rootless |
| 安全性 | 守护进程运行 | 用户空间运行 |
| 兼容性 | Docker API | 兼容 Docker API |
| 系统集成 | 独立服务 | 集成到 systemd |

## 迁移指南

如果您之前使用 Docker，可以按照以下步骤迁移到 Podman：

1. **备份现有配置**
   ```bash
   cp docker-compose.yml docker-compose.yml.backup
   ```

2. **安装 Podman**
   ```bash
   ./install_podman.sh
   ```

3. **迁移配置**
   ```bash
   cp .env.podman.example .env
   # 编辑 .env 文件
   ```

4. **启动服务**
   ```bash
   ./start_services_podman.sh full
   ```

5. **验证功能**
   ```bash
   curl http://localhost:3080
   curl http://localhost:7777/api/health
   ```

## 支持和贡献

如果您在使用 Podman 版本时遇到问题：

1. 查看 [troubleshooting guide](design/docker_to_podman_migration.md)
2. 提交 [issue](https://github.com/Fosowl/agenticSeek/issues)
3. 参与 [discussions](https://github.com/Fosowl/agenticSeek/discussions)

---

*注意：Podman 支持仍在积极开发中，如果遇到问题，请随时报告给我们。*
