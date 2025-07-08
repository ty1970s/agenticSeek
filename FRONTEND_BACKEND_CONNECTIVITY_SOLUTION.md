# AgenticSeek 前端后端连接性解决方案

## 问题描述
在Podman环境中，前端容器运行的React应用无法连接到在本地虚拟环境中运行的后端API服务，导致前端显示"System offline. Deploy backend first."错误。

## 解决方案

### 1. 网络配置
- **前端容器**: 使用桥接网络模式 (agentic-seek-net)
- **端口映射**: 3080:3000 (宿主机:容器)
- **后端服务**: 运行在宿主机本地虚拟环境 (localhost:7777)

### 2. 环境变量配置
```yaml
environment:
  - REACT_APP_BACKEND_URL=http://localhost:7777
```

### 3. CORS配置验证
后端API已正确配置CORS中间件:
```python
api.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## 关键理解

### React应用运行位置
- React应用运行在**用户的浏览器**中，而不是容器内部
- JavaScript代码从浏览器发起API请求到 `http://localhost:7777`
- 这就是为什么使用 `localhost` 而不是 `host.containers.internal` 的原因

### 网络流程
1. 用户浏览器访问 `http://localhost:3080` (前端容器)
2. 前端容器提供React应用静态文件
3. 浏览器中的JavaScript代码调用 `http://localhost:7777` (后端API)
4. 后端API运行在宿主机上，可以直接被浏览器访问

## 测试验证

### 服务状态
- ✅ 后端API: http://localhost:7777 (运行在虚拟环境)
- ✅ 前端界面: http://localhost:3080 (运行在Podman容器)
- ✅ SearxNG: http://localhost:8081 (运行在Podman容器)
- ✅ Redis: localhost:6379 (运行在Podman容器)

### 连接测试
```bash
# 测试后端健康状态
curl http://localhost:7777/health

# 测试前端页面
curl http://localhost:3080

# 测试CORS
curl -H "Origin: http://localhost:3080" http://localhost:7777/health

# 运行完整测试
./test_frontend_backend_v2.sh
```

## 故障排查

### 如果前端仍显示 "System offline"

1. **检查后端是否运行**:
   ```bash
   curl http://localhost:7777/health
   ```

2. **检查前端环境变量**:
   ```bash
   podman exec frontend printenv | grep REACT_APP_BACKEND_URL
   ```

3. **浏览器开发者工具**:
   - 打开 http://localhost:3080
   - 按 F12 打开开发者工具
   - 查看控制台(Console)和网络(Network)选项卡
   - 查找CORS错误或连接失败信息

4. **强制重新构建前端**:
   ```bash
   podman stop frontend
   podman compose -f podman-compose.yml up -d frontend --force-recreate
   ```

## 架构优势

这种混合部署架构具有以下优势:
- **开发友好**: 后端可以直接在本地调试
- **容器隔离**: 前端、搜索、缓存服务容器化
- **网络简化**: 避免复杂的容器间网络配置
- **性能优化**: 减少不必要的网络跳转

## 最终配置文件

### podman-compose.yml (前端部分)
```yaml
frontend:
  container_name: frontend
  profiles: ["core", "full"]
  build:
    context: ./frontend
    dockerfile: Dockerfile.frontend
  ports:
    - "3080:3000"
  volumes:
    - ./frontend/agentic-seek-front/src:/app/src:rw,z
    - ./screenshots:/app/screenshots
  environment:
    - NODE_ENV=development
    - CHOKIDAR_USEPOLLING=true
    - REACT_APP_BACKEND_URL=http://localhost:7777
  networks:
    - agentic-seek-net
```

连接性问题已成功解决！🎉
