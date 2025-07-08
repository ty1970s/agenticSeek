#!/bin/bash

# AgenticSeek 全功能验证测试脚本
# 验证所有核心功能是否正常工作

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if command -v "$1" &> /dev/null; then
        print_success "$1 已安装"
        return 0
    else
        print_error "$1 未安装"
        return 1
    fi
}

# 检查文件是否存在
check_file() {
    if [ -f "$1" ]; then
        print_success "文件存在: $1"
        return 0
    else
        print_error "文件不存在: $1"
        return 1
    fi
}

# 检查目录是否存在
check_directory() {
    if [ -d "$1" ]; then
        print_success "目录存在: $1"
        return 0
    else
        print_error "目录不存在: $1"
        return 1
    fi
}

# 检查服务是否运行
check_service() {
    local url="$1"
    local service_name="$2"
    local timeout=5
    
    if curl -sf --max-time "$timeout" "$url" > /dev/null 2>&1; then
        print_success "$service_name 服务正常 ($url)"
        return 0
    else
        print_error "$service_name 服务异常 ($url)"
        return 1
    fi
}

# 检查 Podman 容器状态
check_container() {
    local container_name="$1"
    
    if podman ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        local status=$(podman ps --filter "name=${container_name}" --format "{{.Status}}")
        print_success "容器 $container_name 运行中: $status"
        return 0
    else
        print_error "容器 $container_name 未运行"
        return 1
    fi
}

# 主验证函数
main() {
    echo "🧪 AgenticSeek 全功能验证测试"
    echo "================================="
    echo
    
    local failed_tests=0
    local total_tests=0
    
    # 1. 基础环境检查
    print_status "1. 检查基础环境..."
    ((total_tests++))
    if check_command "python3" && check_command "podman" && check_command "curl"; then
        print_success "基础环境检查通过"
    else
        print_error "基础环境检查失败"
        ((failed_tests++))
    fi
    echo
    
    # 2. 项目文件检查
    print_status "2. 检查项目文件..."
    ((total_tests++))
    local files_ok=true
    check_file "config.ini" || files_ok=false
    check_file ".env" || files_ok=false
    check_file "api.py" || files_ok=false
    check_file "podman-compose.yml" || files_ok=false
    check_file "switch_provider.sh" || files_ok=false
    check_file "PROVIDER_CONFIGURATION_GUIDE.md" || files_ok=false
    
    if [ "$files_ok" = true ]; then
        print_success "项目文件检查通过"
    else
        print_error "项目文件检查失败"
        ((failed_tests++))
    fi
    echo
    
    # 3. Python 虚拟环境检查
    print_status "3. 检查 Python 虚拟环境..."
    ((total_tests++))
    if check_directory ".venv"; then
        if [ -f ".venv/bin/activate" ]; then
            print_success "Python 虚拟环境检查通过"
        else
            print_error "虚拟环境激活脚本不存在"
            ((failed_tests++))
        fi
    else
        print_error "Python 虚拟环境检查失败"
        ((failed_tests++))
    fi
    echo
    
    # 4. Podman 容器状态检查
    print_status "4. 检查 Podman 容器状态..."
    ((total_tests++))
    local containers_ok=true
    check_container "frontend" || containers_ok=false
    check_container "searxng" || containers_ok=false
    check_container "redis" || containers_ok=false
    
    if [ "$containers_ok" = true ]; then
        print_success "Podman 容器状态检查通过"
    else
        print_error "Podman 容器状态检查失败"
        ((failed_tests++))
    fi
    echo
    
    # 5. 服务连通性检查
    print_status "5. 检查服务连通性..."
    ((total_tests++))
    local services_ok=true
    check_service "http://localhost:7777/health" "后端 API" || services_ok=false
    check_service "http://localhost:3080" "前端服务" || services_ok=false
    check_service "http://localhost:8081" "SearxNG 搜索" || services_ok=false
    
    if [ "$services_ok" = true ]; then
        print_success "服务连通性检查通过"
    else
        print_error "服务连通性检查失败"
        ((failed_tests++))
    fi
    echo
    
    # 6. Provider 配置检查
    print_status "6. 检查 Provider 配置..."
    ((total_tests++))
    local provider_ok=true
    
    if grep -q "provider_name = ollama" config.ini; then
        print_success "Provider 配置正确: ollama"
    else
        print_warning "Provider 配置可能需要调整"
        provider_ok=false
    fi
    
    if grep -q "is_local = True" config.ini; then
        print_success "本地运行模式已启用"
    else
        print_warning "is_local 配置可能需要调整"
        provider_ok=false
    fi
    
    if [ "$provider_ok" = true ]; then
        print_success "Provider 配置检查通过"
    else
        print_warning "Provider 配置检查有警告"
    fi
    echo
    
    # 7. API 功能测试
    print_status "7. 测试 API 功能..."
    ((total_tests++))
    local api_response=$(curl -s http://localhost:7777/health 2>/dev/null || echo "")
    
    if echo "$api_response" | grep -q "healthy"; then
        print_success "API 健康检查响应正常"
        echo "   响应内容: $api_response"
    else
        print_error "API 健康检查响应异常"
        echo "   响应内容: $api_response"
        ((failed_tests++))
    fi
    echo
    
    # 8. 工具脚本测试
    print_status "8. 测试工具脚本..."
    ((total_tests++))
    local scripts_ok=true
    
    # 检查脚本可执行权限
    for script in "start_services_podman.sh" "stop_services_podman.sh" "health_check_podman.sh" "switch_provider.sh"; do
        if [ -x "$script" ]; then
            print_success "脚本可执行: $script"
        else
            print_error "脚本无执行权限: $script"
            scripts_ok=false
        fi
    done
    
    if [ "$scripts_ok" = true ]; then
        print_success "工具脚本检查通过"
    else
        print_error "工具脚本检查失败"
        ((failed_tests++))
    fi
    echo
    
    # 9. 文档完整性检查
    print_status "9. 检查文档完整性..."
    ((total_tests++))
    local docs_ok=true
    
    for doc in "README.md" "README_PODMAN.md" "PROVIDER_CONFIGURATION_GUIDE.md" "MIGRATION_COMPLETE.md" "PROJECT_STATUS_SUMMARY.md"; do
        if check_file "$doc" > /dev/null 2>&1; then
            print_success "文档存在: $doc"
        else
            print_error "文档缺失: $doc"
            docs_ok=false
        fi
    done
    
    if [ "$docs_ok" = true ]; then
        print_success "文档完整性检查通过"
    else
        print_error "文档完整性检查失败"
        ((failed_tests++))
    fi
    echo
    
    # 10. 环境变量检查
    print_status "10. 检查环境变量配置..."
    ((total_tests++))
    local env_ok=true
    
    if grep -q "SEARXNG_BASE_URL" .env; then
        print_success "SEARXNG_BASE_URL 已配置"
    else
        print_error "SEARXNG_BASE_URL 未配置"
        env_ok=false
    fi
    
    if grep -q "WORK_DIR" .env; then
        print_success "WORK_DIR 已配置"
    else
        print_error "WORK_DIR 未配置"
        env_ok=false
    fi
    
    if [ "$env_ok" = true ]; then
        print_success "环境变量配置检查通过"
    else
        print_error "环境变量配置检查失败"
        ((failed_tests++))
    fi
    echo
    
    # 测试结果汇总
    echo "📊 测试结果汇总"
    echo "================================="
    local passed_tests=$((total_tests - failed_tests))
    echo "总测试项: $total_tests"
    echo "通过测试: $passed_tests"
    echo "失败测试: $failed_tests"
    echo
    
    if [ $failed_tests -eq 0 ]; then
        print_success "🎉 所有测试通过！AgenticSeek 已完全就绪。"
        echo
        echo "✨ 快速访问:"
        echo "   🌐 Web 界面: http://localhost:3080"
        echo "   🔧 API 服务: http://localhost:7777"
        echo "   🔍 搜索服务: http://localhost:8081"
        echo
        echo "🛠️ 管理工具:"
        echo "   ./switch_provider.sh     # 切换 LLM Provider"
        echo "   ./health_check_podman.sh # 健康检查"
        echo "   ./monitor_podman.sh      # 监控服务"
        echo
        return 0
    else
        print_error "❌ 有 $failed_tests 项测试失败，请检查相关问题。"
        echo
        echo "🔧 故障排除建议:"
        echo "   1. 确保所有服务已启动: ./start_services_podman.sh"
        echo "   2. 检查服务状态: ./health_check_podman.sh"
        echo "   3. 查看容器日志: podman logs <container_name>"
        echo "   4. 检查网络连接: ping localhost"
        echo
        return 1
    fi
}

# 运行主函数
main "$@"
