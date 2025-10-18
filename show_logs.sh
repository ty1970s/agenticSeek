#!/bin/bash

# AgenticSeek 后台日志显示脚本
# 用于实时显示所有后台服务的日志信息

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/.logs"
MAIN_LOG="$SCRIPT_DIR/agenticseek.log"

# 日志文件列表
LOG_NAMES=(backend browser browser_agent code_agent language memory planner_agent provider router tools main)

# 获取日志文件路径的函数
get_log_file() {
    local log_name="$1"
    case "$log_name" in
        "backend") echo "$LOG_DIR/backend.log" ;;
        "browser") echo "$LOG_DIR/browser.log" ;;
        "browser_agent") echo "$LOG_DIR/browser_agent.log" ;;
        "code_agent") echo "$LOG_DIR/code_agent.log" ;;
        "language") echo "$LOG_DIR/language.log" ;;
        "memory") echo "$LOG_DIR/memory.log" ;;
        "planner_agent") echo "$LOG_DIR/planner_agent.log" ;;
        "provider") echo "$LOG_DIR/provider.log" ;;
        "router") echo "$LOG_DIR/router.log" ;;
        "tools") echo "$LOG_DIR/tools.log" ;;
        "main") echo "$MAIN_LOG" ;;
        *) echo "" ;;
    esac
}

# 打印帮助信息
print_help() {
    echo -e "${GREEN}AgenticSeek 日志查看工具${NC}"
    echo
    echo "用法: $0 [选项] [日志名称]"
    echo
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -l, --list     列出所有可用的日志文件"
    echo "  -a, --all      显示所有日志文件（默认）"
    echo "  -f, --follow   实时跟踪日志（类似 tail -f）"
    echo "  -n, --lines N  显示最后 N 行（默认50行）"
    echo "  -c, --clear    清空屏幕后显示日志"
    echo
    echo "可用的日志名称:"
    for log_name in "${LOG_NAMES[@]}"; do
        echo "  - $log_name"
    done
    echo
    echo "示例:"
    echo "  $0                    # 显示所有日志文件的最后50行"
    echo "  $0 -f backend         # 实时跟踪后端日志"
    echo "  $0 -n 100 browser     # 显示浏览器日志的最后100行"
    echo "  $0 -a -f              # 实时跟踪所有日志文件"
}

# 列出所有日志文件
list_logs() {
    echo -e "${GREEN}可用的日志文件:${NC}"
    echo
    for log_name in "${LOG_NAMES[@]}"; do
        log_file=$(get_log_file "$log_name")
        if [[ -f "$log_file" ]]; then
            file_size=$(du -h "$log_file" | cut -f1)
            file_lines=$(wc -l < "$log_file" 2>/dev/null || echo "0")
            echo -e "  ${CYAN}$log_name${NC}: $log_file (${YELLOW}$file_size${NC}, ${BLUE}$file_lines 行${NC})"
        else
            echo -e "  ${CYAN}$log_name${NC}: $log_file ${RED}(文件不存在)${NC}"
        fi
    done
}

# 检查日志文件是否存在
check_log_exists() {
    local log_name="$1"
    local log_file=$(get_log_file "$log_name")
    
    if [[ -z "$log_file" ]]; then
        echo -e "${RED}错误: 未知的日志名称 '$log_name'${NC}" >&2
        echo "使用 -l 选项查看可用的日志文件" >&2
        return 1
    fi
    
    if [[ ! -f "$log_file" ]]; then
        echo -e "${YELLOW}警告: 日志文件 '$log_file' 不存在${NC}" >&2
        return 1
    fi
    
    return 0
}

# 显示单个日志文件
show_single_log() {
    local log_name="$1"
    local lines="$2"
    local follow="$3"
    
    if ! check_log_exists "$log_name"; then
        return 1
    fi
    
    local log_file=$(get_log_file "$log_name")
    echo -e "${GREEN}=== $log_name 日志 ($log_file) ===${NC}"
    
    if [[ "$follow" == "true" ]]; then
        tail -f -n "$lines" "$log_file"
    else
        tail -n "$lines" "$log_file"
    fi
}

# 显示所有日志文件
show_all_logs() {
    local lines="$1"
    local follow="$2"
    
    if [[ "$follow" == "true" ]]; then
        # 实时跟踪所有日志文件
        echo -e "${GREEN}实时跟踪所有日志文件...${NC}"
        echo -e "${YELLOW}按 Ctrl+C 退出${NC}"
        echo
        
        # 构建 tail 命令参数
        local tail_files=()
        for log_name in "${LOG_NAMES[@]}"; do
            local log_file=$(get_log_file "$log_name")
            if [[ -f "$log_file" ]]; then
                tail_files+=("$log_file")
            fi
        done
        
        if [[ ${#tail_files[@]} -eq 0 ]]; then
            echo -e "${RED}没有找到任何日志文件${NC}"
            return 1
        fi
        
        tail -f -n "$lines" "${tail_files[@]}"
    else
        # 显示所有日志文件的最后几行
        for log_name in "${LOG_NAMES[@]}"; do
            local log_file=$(get_log_file "$log_name")
            if [[ -f "$log_file" ]]; then
                echo -e "${GREEN}=== $log_name 日志 ($log_file) ===${NC}"
                tail -n "$lines" "$log_file"
                echo
            fi
        done
    fi
}

# 主函数
main() {
    local show_help=false
    local list_logs_only=false
    local show_all=true
    local follow=false
    local lines=50
    local clear_screen=false
    local log_name=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help=true
                shift
                ;;
            -l|--list)
                list_logs_only=true
                shift
                ;;
            -a|--all)
                show_all=true
                shift
                ;;
            -f|--follow)
                follow=true
                shift
                ;;
            -n|--lines)
                lines="$2"
                if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
                    echo -e "${RED}错误: 行数必须是正整数${NC}" >&2
                    exit 1
                fi
                shift 2
                ;;
            -c|--clear)
                clear_screen=true
                shift
                ;;
            -*)
                echo -e "${RED}错误: 未知选项 '$1'${NC}" >&2
                echo "使用 -h 或 --help 查看帮助信息" >&2
                exit 1
                ;;
            *)
                if [[ -n "$log_name" ]]; then
                    echo -e "${RED}错误: 只能指定一个日志名称${NC}" >&2
                    exit 1
                fi
                log_name="$1"
                show_all=false
                shift
                ;;
        esac
    done
    
    # 处理帮助选项
    if [[ "$show_help" == "true" ]]; then
        print_help
        exit 0
    fi
    
    # 处理列出日志选项
    if [[ "$list_logs_only" == "true" ]]; then
        list_logs
        exit 0
    fi
    
    # 清空屏幕
    if [[ "$clear_screen" == "true" ]]; then
        clear
    fi
    
    # 检查日志目录是否存在
    if [[ ! -d "$LOG_DIR" ]]; then
        echo -e "${YELLOW}警告: 日志目录 '$LOG_DIR' 不存在${NC}" >&2
        echo "请确保 AgenticSeek 已经运行过至少一次" >&2
    fi
    
    # 显示日志
    if [[ "$show_all" == "true" ]]; then
        show_all_logs "$lines" "$follow"
    else
        show_single_log "$log_name" "$lines" "$follow"
    fi
}

# 信号处理
trap 'echo -e "\n${YELLOW}日志显示已停止${NC}"; exit 0' INT TERM

# 运行主函数
main "$@"
