#!/bin/bash

echo "=== AgenticSeek 前端后端连接测试 (更新版) ==="

echo "1. 后端健康检查:"
BACKEND_STATUS=$(curl -s http://localhost:7777/health)
echo "   $BACKEND_STATUS"

echo -e "\n2. 前端页面测试:"
FRONTEND_STATUS=$(curl -s http://localhost:3080 | head -n 1)
echo "   $FRONTEND_STATUS"

echo -e "\n3. 前端环境变量检查:"
BACKEND_URL=$(podman exec frontend printenv | grep REACT_APP_BACKEND_URL)
echo "   $BACKEND_URL"

echo -e "\n4. CORS 测试:"
echo "   测试 GET 请求到后端:"
curl -s -H "Origin: http://localhost:3080" http://localhost:7777/health
echo ""
echo "   测试带 CORS 头的请求:"
curl -s -H "Origin: http://localhost:3080" -H "Access-Control-Request-Method: GET" http://localhost:7777/health

echo -e "\n5. 容器状态:"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAMES|frontend|redis|searxng)"

echo -e "\n6. 从浏览器角度测试 (模拟前端请求):"
curl -s -H "Accept: application/json" -H "Content-Type: application/json" http://localhost:7777/health
echo ""

echo -e "\n=== 建议 ==="
echo "1. 在浏览器中访问: http://localhost:3080"
echo "2. 打开开发者工具查看控制台和网络选项卡"
echo "3. 查看是否有 CORS 错误或连接错误"
echo "4. 如果显示 'System offline'，检查浏览器控制台中的错误信息"
