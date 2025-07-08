# AgenticSeek Docker到Podman迁移指南

## 概述

本文档分析了AgenticSeek项目中对Docker的依赖情况，并提供了使用Podman替代Docker的完整方案。

## 1. 项目中的Docker依赖分析

### 1.1 Docker相关文件

| 文件路径 | 用途 | 依赖类型 |
|---------|------|----------|
| `docker-compose.yml` | 主要的容器编排文件 | 核心依赖 |
| `Dockerfile.backend` | 后端服务容器镜像 | 核心依赖 |
| `frontend/Dockerfile.frontend` | 前端服务容器镜像 | 核心依赖 |
| `llm_server/Dockerfile` | LLM服务器容器镜像 | 可选依赖 |
| `searxng/docker-compose.yml` | 搜索引擎服务配置 | 核心依赖 |

### 1.2 Docker容器服务

#### 核心服务容器
1. **redis** - 数据缓存服务
   - 镜像: `docker.io/valkey/valkey:8-alpine`
   - 端口: 6379
   - 数据持久化: redis-data volume

2. **searxng** - 搜索引擎服务
   - 镜像: `docker.io/searxng/searxng:latest`
   - 端口: 8080 (内部), 8081 (外部)
   - 配置文件: `./searxng:/etc/searxng`

3. **frontend** - 前端React应用
   - 基于: `node:18`
   - 端口: 3000
   - 开发模式挂载: `./frontend/agentic-seek-front/src:/app/src`

4. **backend** - 后端Python API
   - 基于: `python:3.11-slim`
   - 端口: 7777, 11434, 1234, 8000
   - 工作目录挂载: `${WORK_DIR:-.}:/opt/workspace`

### 1.3 Docker功能使用

#### 容器编排功能
- **Profiles**: 使用`core`、`backend`、`full`配置组合
- **Networks**: 自定义网络`agentic-seek-net`
- **Volumes**: 数据持久化和文件挂载
- **Environment Variables**: 环境变量传递
- **Health Checks**: 服务健康检查

#### 特殊配置
- **host.docker.internal**: 容器内访问宿主机
- **extra_hosts**: 主机名映射
- **cap_add/cap_drop**: 容器权限控制
- **logging**: 日志驱动配置

### 1.4 Docker检测代码

在`api.py`中有Docker环境检测逻辑：
```python
def is_running_in_docker():
    """Detect if code is running inside a Docker container."""
    # Method 1: Check for .dockerenv file
    if os.path.exists('/.dockerenv'):
        return True
    
    # Method 2: Check cgroup
    try:
        with open('/proc/1/cgroup', 'r') as f:
            return 'docker' in f.read()
    except:
        pass
    
    return False
```

### 1.5 脚本中的Docker依赖

#### 安装脚本
- `scripts/linux_install.sh`: 安装docker-compose
- `start_services.sh`: 检查Docker守护进程和Docker Compose
- `searxng/setup_searxng.sh`: Docker容器启动和配置

#### 启动脚本功能
- Docker守护进程状态检查
- Docker Compose版本检查
- 容器启动和状态监控
- 日志查看和调试

## 2. Podman兼容性分析

### 2.1 Podman优势

| 特性 | Docker | Podman |
|------|--------|---------|
| 守护进程 | 需要Docker daemon | 无守护进程架构 |
| 根权限 | 通常需要root或docker组 | 支持Rootless运行 |
| 安全性 | 守护进程以root运行 | 用户空间运行 |
| 兼容性 | Docker API标准 | 兼容Docker API |
| 系统集成 | 独立服务 | 集成到systemd |

### 2.2 完全兼容功能

✅ **直接兼容的功能**
- 容器镜像构建和运行
- 多容器应用编排
- 网络和存储管理
- 环境变量和端口映射
- 文件挂载和数据卷
- 基本的Docker Compose功能

### 2.3 需要适配的功能

⚠️ **需要调整的功能**
- `host.docker.internal` → `host.containers.internal`
- Docker守护进程检查 → Podman服务检查
- 容器检测逻辑需要更新
- 部分Docker Compose高级功能

❌ **不完全兼容的功能**
- Docker Desktop特定功能
- 部分Docker Compose v3+ 特性
- Docker Swarm模式

## 3. Podman迁移方案

### 3.1 环境准备

#### 3.1.1 安装Podman

**macOS:**
```bash
brew install podman
podman machine init
podman machine start
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install podman podman-compose
```

**RHEL/CentOS/Fedora:**
```bash
sudo dnf install podman podman-compose
```

#### 3.1.2 配置Podman

创建Podman配置文件 `~/.config/containers/containers.conf`:
```ini
[containers]
# 网络配置
netns = "host"
userns = "host"
ipcns = "host"
utsns = "host"
cgroupns = "host"

[network]
# 网络后端
network_backend = "netavark"
```

### 3.2 文件修改方案

#### 3.2.1 Docker Compose文件适配

创建 `podman-compose.yml` (基于现有的docker-compose.yml):

```yaml
version: '3'

services:
  redis:
    container_name: redis
    profiles: ["core", "full"]
    image: docker.io/valkey/valkey:8-alpine
    command: valkey-server --save 30 1 --loglevel warning
    restart: unless-stopped
    volumes:
      - redis-data:/data
    security_opt:
      - no-new-privileges
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
        max-file: "1"
    networks:
      - agentic-seek-net

  searxng:
    container_name: searxng
    profiles: ["core", "full"]
    image: docker.io/searxng/searxng:latest
    restart: unless-stopped
    ports:
      - "8081:8080"
    volumes:
      - ./searxng:/etc/searxng:rw,z
    environment:
      - SEARXNG_BASE_URL=${SEARXNG_BASE_URL:-http://localhost:8081/}
      - SEARXNG_SECRET_KEY=${SEARXNG_SECRET_KEY}
      - UWSGI_WORKERS=5
      - UWSGI_THREADS=4
    security_opt:
      - no-new-privileges
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
        max-file: "1"
    depends_on:
      - redis
    networks:
      - agentic-seek-net

  frontend:
    container_name: frontend
    profiles: ["core", "full"]
    build:
      context: ./frontend
      dockerfile: Dockerfile.frontend
    ports:
      - "3000:3000"
    volumes:
      - ./frontend/agentic-seek-front/src:/app/src:rw,z
      - ./screenshots:/app/screenshots
    environment:
      - NODE_ENV=development
      - CHOKIDAR_USEPOLLING=true
      - REACT_APP_BACKEND_URL=http://host.containers.internal:${BACKEND_PORT:-7777}
    networks:
      - agentic-seek-net

  backend:
    container_name: backend
    profiles: ["backend", "full"]
    build:
      context: .
      dockerfile: Dockerfile.backend
    ports:
      - ${BACKEND_PORT:-7777}:${BACKEND_PORT:-7777}
      - ${OLLAMA_PORT:-11434}:${OLLAMA_PORT:-11434}
      - ${LM_STUDIO_PORT:-1234}:${LM_STUDIO_PORT:-1234}
      - ${CUSTOM_ADDITIONAL_LLM_PORT:-8000}:${CUSTOM_ADDITIONAL_LLM_PORT:-8000}
    volumes:
      - ./:/app
      - ${WORK_DIR:-.}:/opt/workspace
    command: python3 api.py
    environment:
      - SEARXNG_BASE_URL=${SEARXNG_BASE_URL:-http://searxng:8080}
      - REDIS_URL=${REDIS_BASE_URL:-redis://redis:6379/0}
      - WORK_DIR=/opt/workspace
      - BACKEND_PORT=${BACKEND_PORT}
      - PODMAN_INTERNAL_URL=http://host.containers.internal
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
      - TOGETHER_API_KEY=${TOGETHER_API_KEY}
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - HUGGINGFACE_API_KEY=${HUGGINGFACE_API_KEY}
      - DSK_DEEPSEEK_API_KEY=${DSK_DEEPSEEK_API_KEY}
    networks:
      - agentic-seek-net
    extra_hosts:
      - "host.containers.internal:host-gateway"
  
volumes:
  redis-data:
  chrome_profiles:

networks:
  agentic-seek-net:
    driver: bridge
```

**主要变化：**
1. `host.docker.internal` → `host.containers.internal`
2. 移除Docker特定的cap_add/cap_drop，使用security_opt
3. 调整环境变量名称

#### 3.2.2 容器检测逻辑更新

修改 `api.py` 中的容器检测函数：

```python
def is_running_in_container():
    """Detect if code is running inside a container (Docker or Podman)."""
    # Method 1: Check for .dockerenv file (Docker)
    if os.path.exists('/.dockerenv'):
        return True
    
    # Method 2: Check for container environment (Podman)
    if os.path.exists('/run/.containerenv'):
        return True
    
    # Method 3: Check cgroup for container indicators
    try:
        with open('/proc/1/cgroup', 'r') as f:
            content = f.read()
            return any(indicator in content for indicator in ['docker', 'containers', 'podman'])
    except:
        pass
    
    # Method 4: Check environment variables
    container_env_vars = ['CONTAINER', 'container']
    for var in container_env_vars:
        if os.getenv(var):
            return True
    
    return False
```

#### 3.2.3 启动脚本适配

创建 `start_services_podman.sh`:

```bash
#!/bin/bash

# Podman specific startup script
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Podman is installed
if ! command_exists podman; then
    echo "Error: Podman is not installed. Please install Podman first."
    echo "On macOS: brew install podman"
    echo "On Ubuntu: sudo apt install podman"
    echo "On RHEL/CentOS: sudo dnf install podman"
    exit 1
fi

# Check if podman-compose is available
if command_exists podman-compose; then
    COMPOSE_CMD="podman-compose"
elif command_exists docker-compose; then
    # Use docker-compose with podman backend
    export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
    COMPOSE_CMD="docker-compose"
else
    echo "Error: Neither podman-compose nor docker-compose is available."
    echo "Please install podman-compose or docker-compose"
    exit 1
fi

# Start Podman machine if on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! podman machine list | grep -q "Running"; then
        echo "Starting Podman machine..."
        podman machine start
    fi
fi

# Check if compose file exists
COMPOSE_FILE="podman-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Warning: $COMPOSE_FILE not found, using docker-compose.yml"
    COMPOSE_FILE="docker-compose.yml"
fi

# Start services
if [ "$1" = "full" ]; then
    echo "Starting full deployment with all services..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" --profile full up -d
else
    echo "Starting core deployment..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" --profile core up -d
fi

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 5

# Check service status
$COMPOSE_CMD -f "$COMPOSE_FILE" ps

echo "Services started successfully!"
echo "Frontend: http://localhost:3000"
echo "SearXNG: http://localhost:8081"
if [ "$1" = "full" ]; then
    echo "Backend API: http://localhost:7777"
fi
```

### 3.3 系统集成方案

#### 3.3.1 Systemd服务配置

创建 `systemd/agenticseek.service`:

```ini
[Unit]
Description=AgenticSeek Container Stack
After=podman.service
Requires=podman.service

[Service]
Type=forking
ExecStart=/usr/bin/podman-compose -f /path/to/agenticSeek/podman-compose.yml --profile full up -d
ExecStop=/usr/bin/podman-compose -f /path/to/agenticSeek/podman-compose.yml down
Restart=always
RestartSec=10
User=agenticseek
Group=agenticseek

[Install]
WantedBy=multi-user.target
```

#### 3.3.2 Rootless运行配置

配置用户子uid/gid映射 `/etc/subuid` 和 `/etc/subgid`:
```
agenticseek:100000:65536
```

启用lingering以允许用户服务在登出后继续运行:
```bash
sudo loginctl enable-linger agenticseek
```

### 3.4 网络配置

#### 3.4.1 Podman网络创建

```bash
# 创建自定义网络
podman network create agentic-seek-net

# 或使用网络配置文件
podman network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  agentic-seek-net
```

#### 3.4.2 端口映射策略

由于Podman的rootless特性，需要调整端口映射：

```bash
# 如果需要绑定1024以下的端口，配置端口映射
echo 'net.ipv4.ip_unprivileged_port_start = 80' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## 4. 迁移步骤

### 4.1 准备阶段

1. **备份现有配置**
   ```bash
   cp docker-compose.yml docker-compose.yml.backup
   cp -r searxng searxng.backup
   ```

2. **安装Podman**
   ```bash
   # 根据操作系统选择安装方式
   brew install podman  # macOS
   sudo apt install podman podman-compose  # Ubuntu
   ```

3. **验证安装**
   ```bash
   podman --version
   podman-compose --version
   ```

### 4.2 配置迁移

1. **创建Podman配置文件**
   ```bash
   mkdir -p ~/.config/containers
   # 复制上述containers.conf内容
   ```

2. **修改compose文件**
   ```bash
   cp docker-compose.yml podman-compose.yml
   # 按照上述方案修改配置
   ```

3. **更新应用代码**
   ```bash
   # 更新api.py中的容器检测逻辑
   # 更新环境变量处理
   ```

### 4.3 测试验证

1. **启动核心服务**
   ```bash
   ./start_services_podman.sh
   ```

2. **验证服务状态**
   ```bash
   podman-compose ps
   curl http://localhost:8081  # SearXNG
   curl http://localhost:3000  # Frontend
   ```

3. **测试完整功能**
   ```bash
   ./start_services_podman.sh full
   curl http://localhost:7777/api/health  # Backend
   ```

### 4.4 生产部署

1. **配置系统服务**
   ```bash
   sudo cp systemd/agenticseek.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable agenticseek
   sudo systemctl start agenticseek
   ```

2. **监控和日志**
   ```bash
   sudo systemctl status agenticseek
   podman logs -f backend
   ```

## 实际改造状态

### ✅ 已完成的改造

1. **容器编排配置**
   - 创建了 `podman-compose.yml` 文件
   - 适配了网络配置（host.containers.internal）
   - 调整了安全选项和权限配置

2. **应用代码更新**
   - 更新了 `api.py` 中的容器检测逻辑
   - 支持多种容器运行时检测（Docker、Podman）
   - 添加了容器运行时环境变量

3. **脚本和工具**
   - 创建了 `start_services_podman.sh` 启动脚本
   - 创建了 `stop_services_podman.sh` 停止脚本
   - 创建了 `install_podman.sh` 安装脚本
   - 创建了 `health_check_podman.sh` 健康检查脚本
   - 创建了 `monitor_podman.sh` 监控脚本

4. **配置文件**
   - 创建了 `.env.podman.example` 环境变量模板
   - 创建了 `podman/containers.conf` Podman配置文件
   - 创建了 `podman/agenticseek.service` Systemd服务文件

5. **文档**
   - 创建了 `README_PODMAN.md` 详细使用指南
   - 更新了 `.env.example` 添加Podman支持

### 🔧 改造要点

1. **网络配置改变**
   ```yaml
   # 原来的 Docker 配置
   - REACT_APP_BACKEND_URL=http://host.docker.internal:${BACKEND_PORT:-7777}
   
   # 新的 Podman 配置
   - REACT_APP_BACKEND_URL=http://host.containers.internal:${BACKEND_PORT:-7777}
   ```

2. **容器检测逻辑增强**
   ```python
   # 支持多种容器运行时检测
   def is_running_in_container():
       # Docker 检测
       if os.path.exists('/.dockerenv'):
           return True
       # Podman 检测
       if os.path.exists('/run/.containerenv'):
           return True
       # 环境变量检测
       if os.getenv('CONTAINER_RUNTIME'):
           return True
   ```

3. **安全配置优化**
   ```yaml
   # 使用 security_opt 替代 cap_add/cap_drop
   security_opt:
     - no-new-privileges
   ```

### 🚀 使用方法

1. **安装和启动**
   ```bash
   # 自动安装
   ./install_podman.sh
   
   # 启动服务
   ./start_services_podman.sh
   
   # 启动完整服务
   ./start_services_podman.sh full
   ```

2. **监控和维护**
   ```bash
   # 健康检查
   ./health_check_podman.sh
   
   # 监控服务
   ./monitor_podman.sh
   
   # 停止服务
   ./stop_services_podman.sh
   ```

3. **服务访问**
   - 前端: http://localhost:3000
   - 搜索: http://localhost:8081
   - 后端: http://localhost:7777

### 📋 兼容性说明

- **向后兼容**: 原有的 Docker 部署方式仍然可用
- **双模式支持**: 可以同时支持 Docker 和 Podman
- **配置独立**: Podman 配置文件独立，不影响原有配置
- **脚本分离**: 提供了独立的 Podman 脚本，与原有脚本并存

### 🔍 测试建议

1. **功能测试**
   ```bash
   # 启动服务
   ./start_services_podman.sh full
   
   # 健康检查
   ./health_check_podman.sh
   
   # 测试API
   curl http://localhost:7777/api/health
   curl http://localhost:3000
   ```

2. **性能测试**
   ```bash
   # 监控资源使用
   ./monitor_podman.sh stats
   
   # 实时监控
   ./monitor_podman.sh monitor
   ```

---

*注意：本文档基于当前版本的AgenticSeek项目分析，建议在实际迁移前进行充分测试。此改造完全兼容原有的 Docker 部署方式，用户可以根据需要选择使用 Docker 或 Podman。*
