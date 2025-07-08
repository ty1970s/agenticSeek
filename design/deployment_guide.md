# AgenticSeek 部署指南

## 部署概述

AgenticSeek支持多种部署方式，从本地开发环境到生产级分布式部署。本指南详细介绍了各种部署场景的配置和最佳实践。

## 部署架构选择

### 1. 单机本地部署 (开发/个人使用)
- **适用场景**：个人开发、学习、小规模使用
- **资源需求**：8GB+ RAM, 4核+ CPU, 50GB+ 存储
- **特点**：简单快速、完全本地化、隐私保护

### 2. Docker容器化部署 (推荐)
- **适用场景**：开发测试、小团队使用
- **资源需求**：16GB+ RAM, 8核+ CPU, 100GB+ 存储
- **特点**：环境隔离、易于扩展、配置标准化

### 3. Kubernetes集群部署 (企业级)
- **适用场景**：大规模生产环境、高可用需求
- **资源需求**：集群级别资源配置
- **特点**：高可用、自动扩缩、服务发现

## 本地开发部署

### 1. 环境准备

#### 系统要求
```bash
# 操作系统：
- macOS 10.15+ 
- Ubuntu 20.04+
- Windows 10/11 (WSL2推荐)

# 软件依赖：
- Python 3.10.x (严格版本要求)
- Git 2.20+
- Docker Engine 20.10+
- Docker Compose V2
```

#### 依赖安装
```bash
# macOS
brew install python@3.10 git docker docker-compose

# Ubuntu
sudo apt update
sudo apt install python3.10 python3.10-venv git docker.io docker-compose-plugin

# 验证安装
python3.10 --version  # Python 3.10.x
git --version         # git version 2.x
docker --version      # Docker version 20.x
docker compose version # Docker Compose version v2.x
```

### 2. 项目初始化

```bash
# 1. 克隆项目
git clone https://github.com/Fosowl/agenticSeek.git
cd agenticSeek

# 2. 环境配置
cp .env.example .env

# 3. 编辑环境变量
vim .env
```

#### 环境变量配置 (.env)
```bash
# 基础配置
SEARXNG_BASE_URL="http://127.0.0.1:8080"
REDIS_BASE_URL="redis://redis:6379/0"
WORK_DIR="/path/to/your/workspace"  # 修改为实际路径

# LLM服务端口
OLLAMA_PORT="11434"
OLLAMA_BASE_URL="http://localhost:11434"  # Ollama服务器基础URL
LM_STUDIO_PORT="1234"
CUSTOM_ADDITIONAL_LLM_PORT="11435"
BACKEND_PORT="7777"

# API密钥 (可选，本地LLM不需要)
OPENAI_API_KEY=""
DEEPSEEK_API_KEY=""
ANTHROPIC_API_KEY=""
GOOGLE_API_KEY=""
TOGETHER_API_KEY=""
OPENROUTER_API_KEY=""

# 搜索引擎密钥
SEARXNG_SECRET_KEY="$(openssl rand -hex 32)"
```

### 3. 应用配置

#### config.ini 配置
```ini
[MAIN]
is_local = True
provider_name = ollama
provider_model = deepseek-r1:14b
provider_server_address = 127.0.0.1:11434
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

### 4. 启动服务

#### 方式一：Docker Compose (推荐)
```bash
# 启动核心服务 (SearxNG + Redis + Frontend)
docker compose --profile core up -d

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 停止服务
docker compose --profile core down
```

#### 方式二：手动启动
```bash
# 1. 安装Python依赖
python3.10 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# 2. 启动Docker服务
docker compose --profile core up -d

# 3. 启动后端API
python api.py

# 4. 启动前端 (新终端)
cd frontend/agentic-seek-front
npm install
npm start
```

### 5. 本地LLM配置

#### Ollama配置
```bash
# 安装Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# 启动Ollama服务
ollama serve

# 下载模型 (新终端)
ollama pull deepseek-r1:14b
# 或其他推荐模型：
ollama pull qwen2.5:14b
ollama pull magistral:7b
```

#### LM Studio配置
```bash
# 1. 下载并安装LM Studio
# 访问：https://lmstudio.ai/

# 2. 在LM Studio中下载模型
# 推荐模型：deepseek-r1, qwen2.5, magistral

# 3. 启动本地服务器
# 在LM Studio中点击"Start Server"
# 默认端口：1234
```

## Docker容器化部署

### 1. 生产环境配置

#### docker-compose.prod.yml
```yaml
version: '3.8'

services:
  # 反向代理
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - backend
      - frontend
    restart: unless-stopped

  # 前端服务
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.prod
    expose:
      - "3000"
    environment:
      - NODE_ENV=production
      - REACT_APP_BACKEND_URL=https://api.yourdomain.com
    restart: unless-stopped

  # 后端服务
  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend
    expose:
      - "7777"
    environment:
      - SEARXNG_BASE_URL=http://searxng:8080
      - REDIS_URL=redis://redis:6379/0
      - WORK_DIR=/opt/workspace
    volumes:
      - ./data:/opt/workspace
      - ./logs:/app/logs
    depends_on:
      - redis
      - searxng
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7777/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # 搜索引擎
  searxng:
    image: searxng/searxng:latest
    expose:
      - "8080"
    volumes:
      - ./searxng:/etc/searxng:rw
    environment:
      - SEARXNG_BASE_URL=http://searxng:8080/
      - SEARXNG_SECRET_KEY=${SEARXNG_SECRET_KEY}
    depends_on:
      - redis
    restart: unless-stopped

  # 缓存和队列
  redis:
    image: valkey/valkey:8-alpine
    command: valkey-server --save 60 1 --loglevel warning
    volumes:
      - redis-data:/data
    expose:
      - "6379"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "valkey-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

  # 任务队列
  celery-worker:
    build:
      context: .
      dockerfile: Dockerfile.backend
    command: celery -A api.celery_app worker --loglevel=info
    environment:
      - SEARXNG_BASE_URL=http://searxng:8080
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - ./data:/opt/workspace
    depends_on:
      - redis
      - searxng
    restart: unless-stopped

  # 任务监控
  celery-flower:
    build:
      context: .
      dockerfile: Dockerfile.backend
    command: celery -A api.celery_app flower --port=5555
    ports:
      - "5555:5555"
    environment:
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - redis
    restart: unless-stopped

volumes:
  redis-data:
    driver: local

networks:
  default:
    name: agenticseek-prod
```

### 2. Nginx反向代理配置

#### nginx.conf
```nginx
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server backend:7777;
    }
    
    upstream frontend {
        server frontend:3000;
    }
    
    # 后端API服务
    server {
        listen 80;
        server_name api.yourdomain.com;
        
        # HTTPS重定向
        return 301 https://$server_name$request_uri;
    }
    
    server {
        listen 443 ssl http2;
        server_name api.yourdomain.com;
        
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        
        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket支持
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            # 超时设置
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
        
        # 流式响应支持
        location /api/query/stream {
            proxy_pass http://backend;
            proxy_buffering off;
            proxy_cache off;
        }
    }
    
    # 前端服务
    server {
        listen 80;
        server_name yourdomain.com www.yourdomain.com;
        return 301 https://$server_name$request_uri;
    }
    
    server {
        listen 443 ssl http2;
        server_name yourdomain.com www.yourdomain.com;
        
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        
        location / {
            proxy_pass http://frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # 静态资源缓存
        location /static/ {
            proxy_pass http://frontend;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

### 3. 生产环境启动

```bash
# 1. 环境准备
cp .env.example .env.prod
# 编辑生产环境配置

# 2. SSL证书配置
mkdir ssl
# 将SSL证书文件放入ssl目录

# 3. 启动生产服务
docker compose -f docker-compose.prod.yml up -d

# 4. 验证服务状态
docker compose -f docker-compose.prod.yml ps
curl -k https://api.yourdomain.com/api/health

# 5. 查看日志
docker compose -f docker-compose.prod.yml logs -f backend
```

## Kubernetes集群部署

### 1. 命名空间配置

#### namespace.yaml
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: agenticseek
  labels:
    name: agenticseek
```

### 2. ConfigMap配置

#### configmap.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: agenticseek-config
  namespace: agenticseek
data:
  config.ini: |
    [MAIN]
    is_local = False
    provider_name = openai
    provider_model = gpt-4
    provider_server_address = https://api.openai.com
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
  
  nginx.conf: |
    # Nginx配置内容...
---
apiVersion: v1
kind: Secret
metadata:
  name: agenticseek-secrets
  namespace: agenticseek
type: Opaque
data:
  # Base64编码的密钥
  openai-api-key: <base64-encoded-key>
  redis-password: <base64-encoded-password>
```

### 3. 存储配置

#### storage.yaml
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: agenticseek-data
  namespace: agenticseek
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: fast-ssd
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data
  namespace: agenticseek
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: fast-ssd
```

### 4. 服务部署

#### redis-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: agenticseek
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: valkey/valkey:8-alpine
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: redis-data
          mountPath: /data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1"
      volumes:
      - name: redis-data
        persistentVolumeClaim:
          claimName: redis-data
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: agenticseek
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
```

#### backend-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: agenticseek
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: agenticseek/backend:latest
        ports:
        - containerPort: 7777
        env:
        - name: REDIS_URL
          value: "redis://redis-service:6379/0"
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: agenticseek-secrets
              key: openai-api-key
        volumeMounts:
        - name: config-volume
          mountPath: /app/config.ini
          subPath: config.ini
        - name: data-volume
          mountPath: /opt/workspace
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
        livenessProbe:
          httpGet:
            path: /api/health
            port: 7777
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health
            port: 7777
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config-volume
        configMap:
          name: agenticseek-config
      - name: data-volume
        persistentVolumeClaim:
          claimName: agenticseek-data
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: agenticseek
spec:
  selector:
    app: backend
  ports:
  - port: 7777
    targetPort: 7777
  type: ClusterIP
```

### 5. Ingress配置

#### ingress.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: agenticseek-ingress
  namespace: agenticseek
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
spec:
  tls:
  - hosts:
    - api.yourdomain.com
    - yourdomain.com
    secretName: agenticseek-tls
  rules:
  - host: api.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 7777
  - host: yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 3000
```

### 6. 自动扩缩配置

#### hpa.yaml
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: agenticseek
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 7. 部署脚本

#### deploy.sh
```bash
#!/bin/bash

set -e

# 检查kubectl连接
kubectl cluster-info

# 创建命名空间
kubectl apply -f namespace.yaml

# 部署配置
kubectl apply -f configmap.yaml
kubectl apply -f storage.yaml

# 部署服务
kubectl apply -f redis-deployment.yaml
kubectl apply -f searxng-deployment.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f frontend-deployment.yaml

# 配置网络
kubectl apply -f ingress.yaml

# 配置自动扩缩
kubectl apply -f hpa.yaml

# 等待部署完成
kubectl rollout status deployment/backend -n agenticseek
kubectl rollout status deployment/frontend -n agenticseek

echo "Deployment completed successfully!"
echo "Check status with: kubectl get pods -n agenticseek"
```

## 监控和日志

### 1. Prometheus监控配置

#### prometheus-config.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: agenticseek
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    
    scrape_configs:
    - job_name: 'agenticseek-backend'
      static_configs:
      - targets: ['backend-service:7777']
      metrics_path: '/metrics'
    
    - job_name: 'redis'
      static_configs:
      - targets: ['redis-service:6379']
```

### 2. Grafana仪表板

#### grafana-dashboard.json
```json
{
  "dashboard": {
    "title": "AgenticSeek Monitoring",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "Requests/sec"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph", 
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      },
      {
        "title": "Agent Usage",
        "type": "pie",
        "targets": [
          {
            "expr": "agent_requests_total",
            "legendFormat": "{{agent_type}}"
          }
        ]
      }
    ]
  }
}
```

### 3. 日志聚合 (ELK Stack)

#### filebeat-config.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: agenticseek
data:
  filebeat.yml: |
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*agenticseek*.log
      processors:
        - add_kubernetes_metadata:
            host: ${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"
    
    output.elasticsearch:
      hosts: ["elasticsearch:9200"]
    
    setup.kibana:
      host: "kibana:5601"
```

## 安全配置

### 1. 网络安全

#### network-policy.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: agenticseek-network-policy
  namespace: agenticseek
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: nginx-ingress
    ports:
    - protocol: TCP
      port: 7777
  
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 6379  # Redis
    - protocol: TCP
      port: 8080  # SearxNG
    - protocol: TCP
      port: 443   # HTTPS
```

### 2. RBAC配置

#### rbac.yaml
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: agenticseek-sa
  namespace: agenticseek
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: agenticseek-role
  namespace: agenticseek
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: agenticseek-rolebinding
  namespace: agenticseek
subjects:
- kind: ServiceAccount
  name: agenticseek-sa
  namespace: agenticseek
roleRef:
  kind: Role
  name: agenticseek-role
  apiGroup: rbac.authorization.k8s.io
```

## 备份和恢复

### 1. 数据备份策略

#### backup-cronjob.yaml
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: data-backup
  namespace: agenticseek
spec:
  schedule: "0 2 * * *"  # 每天凌晨2点
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: agenticseek/backup:latest
            command:
            - /bin/bash
            - -c
            - |
              # 备份Redis数据
              redis-cli --rdb /backup/redis-$(date +%Y%m%d).rdb
              
              # 备份文件数据
              tar -czf /backup/files-$(date +%Y%m%d).tar.gz /opt/workspace
              
              # 上传到云存储
              aws s3 cp /backup/ s3://agenticseek-backups/ --recursive
            volumeMounts:
            - name: backup-volume
              mountPath: /backup
            - name: data-volume
              mountPath: /opt/workspace
          volumes:
          - name: backup-volume
            emptyDir: {}
          - name: data-volume
            persistentVolumeClaim:
              claimName: agenticseek-data
          restartPolicy: OnFailure
```

### 2. 灾难恢复流程

```bash
#!/bin/bash
# disaster-recovery.sh

# 1. 停止服务
kubectl scale deployment backend --replicas=0 -n agenticseek

# 2. 从备份恢复数据
kubectl create job --from=cronjob/data-backup restore-job -n agenticseek

# 3. 等待恢复完成
kubectl wait --for=condition=complete job/restore-job -n agenticseek

# 4. 重启服务
kubectl scale deployment backend --replicas=3 -n agenticseek

# 5. 验证服务健康
kubectl rollout status deployment/backend -n agenticseek
```

## 性能优化

### 1. 资源限制调优

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"

# 根据实际负载调整：
# - CPU密集型任务增加CPU限制
# - 内存密集型任务增加内存限制
# - 长时间运行任务设置合适的requests
```

### 2. 缓存优化

```yaml
env:
- name: REDIS_CACHE_TTL
  value: "3600"  # 1小时缓存
- name: REDIS_MAX_CONNECTIONS
  value: "100"   # 最大连接数
- name: ENABLE_QUERY_CACHE
  value: "true"  # 启用查询缓存
```

## 故障排除

### 1. 常见问题诊断

```bash
# 检查Pod状态
kubectl get pods -n agenticseek

# 查看Pod日志
kubectl logs -f deployment/backend -n agenticseek

# 检查服务连接
kubectl port-forward svc/backend-service 7777:7777 -n agenticseek
curl http://localhost:7777/api/health

# 检查资源使用
kubectl top pods -n agenticseek
kubectl describe pod <pod-name> -n agenticseek
```

### 2. 性能问题调试

```bash
# 检查响应时间
time curl -X POST http://localhost:7777/api/query \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'

# 检查内存使用
kubectl exec -it <backend-pod> -n agenticseek -- \
  python -c "import psutil; print(f'Memory: {psutil.virtual_memory().percent}%')"

# 检查Redis连接
kubectl exec -it <redis-pod> -n agenticseek -- redis-cli info clients
```

---

*文档版本：v1.0*  
*更新日期：2025年6月25日*  
*维护者：AgenticSeek运维团队*
