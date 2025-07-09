#!/bin/bash

echo "=== 前端 Backend URL 调试测试 ==="

echo "1. 检查前端容器环境变量:"
podman exec frontend env | grep REACT_APP_BACKEND_URL

echo -e "\n2. 检查前端是否可以访问后端 (从容器内):"
podman exec frontend sh -c "curl -s http://localhost:7777/health 2>/dev/null || echo 'Failed from container'"

echo -e "\n3. 检查后端是否正常 (从宿主机):"
curl -s http://localhost:7777/health || echo "Backend not accessible from host"

echo -e "\n4. 检查前端页面是否加载:"
curl -s http://localhost:3080 | head -5

echo -e "\n5. 模拟浏览器请求后端 (CORS测试):"
curl -s -H "Origin: http://localhost:3080" -H "Access-Control-Request-Method: GET" http://localhost:7777/health

echo -e "\n6. 检查前端容器状态:"
podman ps | grep frontend

echo -e "\n7. 等待前端完全加载后再次检查..."
sleep 10

echo -e "\n8. 最终测试 - 模拟前端 JavaScript 请求:"
curl -s -H "Origin: http://localhost:3080" \
     -H "Accept: application/json" \
     -H "Content-Type: application/json" \
     -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" \
     http://localhost:7777/health

echo -e "\n=== 调试完成 ==="
