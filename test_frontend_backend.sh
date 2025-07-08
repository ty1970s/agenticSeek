#!/bin/bash

echo "=== AgenticSeek 前端后端连接测试 ==="

echo "1. 测试后端健康状态:"
curl -s http://localhost:7777/health && echo " ✅ 后端正常"

echo -e "\n2. 测试前端页面:"
curl -s http://localhost:3080 | head -n 1 && echo " ✅ 前端页面正常"

echo -e "\n3. 检查前端容器环境变量:"
podman exec frontend printenv | grep REACT_APP_BACKEND_URL

echo -e "\n4. 从前端容器内测试后端连接:"
podman exec frontend curl -s http://localhost:7777/health 2>/dev/null && echo " ✅ 容器内可连接后端" || echo " ❌ 容器内无法连接后端"

echo -e "\n5. 检查 React 应用日志 (查找错误):"
podman logs frontend --tail 20 | grep -i error || echo "无错误日志"

echo -e "\n=== 测试完成 ==="
echo "请在浏览器中访问 http://localhost:3080 验证前端是否显示 'System online'"
