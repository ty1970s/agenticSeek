#!/bin/bash

# AgenticSeek Provider 配置切换脚本
# 快速切换不同的 LLM provider 配置

set -e

CONFIG_FILE="config.ini"
BACKUP_DIR="config_backups"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 显示当前配置
show_current_config() {
    echo "🔍 当前配置:"
    echo "=================================="
    if [ -f "$CONFIG_FILE" ]; then
        grep "provider_name\|provider_model\|provider_server_address\|is_local" "$CONFIG_FILE" | sed 's/^/  /'
    else
        echo "  配置文件不存在!"
    fi
    echo "=================================="
    echo
}

# 备份当前配置
backup_config() {
    if [ -f "$CONFIG_FILE" ]; then
        timestamp=$(date +"%Y%m%d_%H%M%S")
        backup_file="$BACKUP_DIR/config_backup_$timestamp.ini"
        cp "$CONFIG_FILE" "$backup_file"
        echo "✅ 配置已备份到: $backup_file"
    fi
}

# 更新配置函数
update_config() {
    local provider_name="$1"
    local provider_model="$2"
    local provider_server_address="$3"
    local is_local="$4"
    
    backup_config
    
    # 使用 sed 更新配置
    sed -i.tmp "s/^provider_name = .*/provider_name = $provider_name/" "$CONFIG_FILE"
    sed -i.tmp "s/^provider_model = .*/provider_model = $provider_model/" "$CONFIG_FILE"
    sed -i.tmp "s/^provider_server_address = .*/provider_server_address = $provider_server_address/" "$CONFIG_FILE"
    sed -i.tmp "s/^is_local = .*/is_local = $is_local/" "$CONFIG_FILE"
    
    # 删除临时文件
    rm -f "$CONFIG_FILE.tmp"
    
    echo "✅ 配置已更新为: $provider_name"
}

# 显示菜单
show_menu() {
    echo "🤖 AgenticSeek Provider 配置切换器"
    echo "=================================="
    echo "请选择要切换的 provider:"
    echo
    echo "本地 Providers:"
    echo "  1) Ollama (推荐) - 本地运行，隐私安全"
    echo "  2) LM Studio - 本地服务器"
    echo "  3) DeepSeek Private - 私有部署服务器"
    echo "  4) Custom Server - 自定义服务器"
    echo
    echo "云端 API Providers:"
    echo "  5) OpenAI - GPT-4/GPT-3.5"
    echo "  6) DeepSeek API - 官方API"
    echo "  7) Google AI - Gemini模型"
    echo "  8) Together AI - 开源模型聚合"
    echo "  9) OpenRouter - 多provider聚合"
    echo " 10) Hugging Face - HF推理API"
    echo
    echo "特殊 Providers:"
    echo " 11) DSK DeepSeek - 非官方免费接口"
    echo " 12) Test - 测试用provider"
    echo
    echo "其他选项:"
    echo "  0) 显示当前配置"
    echo "  b) 恢复备份"
    echo "  q) 退出"
    echo
}

# 恢复备份
restore_backup() {
    echo "📁 可用的配置备份:"
    echo "=================================="
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo "  没有找到备份文件"
        return
    fi
    
    ls -la "$BACKUP_DIR"/*.ini 2>/dev/null | nl -v0
    echo
    echo -n "请输入要恢复的备份编号 (或按回车取消): "
    read backup_choice
    
    if [ -z "$backup_choice" ]; then
        echo "取消恢复操作"
        return
    fi
    
    backup_file=$(ls "$BACKUP_DIR"/*.ini 2>/dev/null | sed -n "$((backup_choice + 1))p")
    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        cp "$backup_file" "$CONFIG_FILE"
        echo "✅ 配置已从备份恢复: $(basename "$backup_file")"
    else
        echo "❌ 无效的备份编号"
    fi
}

# 检查.env文件中的API密钥
check_api_keys() {
    local provider="$1"
    local env_file=".env"
    
    case "$provider" in
        "openai")
            if ! grep -q "OPENAI_API_KEY=" "$env_file" 2>/dev/null || grep -q "OPENAI_API_KEY=$" "$env_file" 2>/dev/null; then
                echo "⚠️  警告: 请在 .env 文件中设置 OPENAI_API_KEY"
            fi
            ;;
        "deepseek")
            if ! grep -q "DEEPSEEK_API_KEY=" "$env_file" 2>/dev/null || grep -q "DEEPSEEK_API_KEY=$" "$env_file" 2>/dev/null; then
                echo "⚠️  警告: 请在 .env 文件中设置 DEEPSEEK_API_KEY"
            fi
            ;;
        "google")
            if ! grep -q "GOOGLE_API_KEY=" "$env_file" 2>/dev/null || grep -q "GOOGLE_API_KEY=$" "$env_file" 2>/dev/null; then
                echo "⚠️  警告: 请在 .env 文件中设置 GOOGLE_API_KEY"
            fi
            ;;
        "together")
            if ! grep -q "TOGETHER_API_KEY=" "$env_file" 2>/dev/null || grep -q "TOGETHER_API_KEY=$" "$env_file" 2>/dev/null; then
                echo "⚠️  警告: 请在 .env 文件中设置 TOGETHER_API_KEY"
            fi
            ;;
        "openrouter")
            if ! grep -q "OPENROUTER_API_KEY=" "$env_file" 2>/dev/null || grep -q "OPENROUTER_API_KEY=$" "$env_file" 2>/dev/null; then
                echo "⚠️  警告: 请在 .env 文件中设置 OPENROUTER_API_KEY"
            fi
            ;;
        "huggingface")
            if ! grep -q "HUGGINGFACE_API_KEY=" "$env_file" 2>/dev/null || grep -q "HUGGINGFACE_API_KEY=$" "$env_file" 2>/dev/null; then
                echo "⚠️  警告: 请在 .env 文件中设置 HUGGINGFACE_API_KEY"
            fi
            ;;
        "dsk_deepseek")
            if ! grep -q "DSK_DEEPSEEK_API_KEY=" "$env_file" 2>/dev/null || grep -q "DSK_DEEPSEEK_API_KEY=$" "$env_file" 2>/dev/null; then
                echo "⚠️  警告: 请在 .env 文件中设置 DSK_DEEPSEEK_API_KEY"
            fi
            ;;
    esac
}

# 主循环
main() {
    echo "🚀 AgenticSeek Provider 配置切换器"
    echo
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 错误: 找不到 config.ini 文件"
        echo "请确保你在 AgenticSeek 项目目录中运行此脚本"
        exit 1
    fi
    
    while true; do
        show_current_config
        show_menu
        echo -n "请选择 (1-12, 0, b, q): "
        read choice
        echo
        
        case "$choice" in
            0)
                show_current_config
                ;;
            1)
                echo "配置 Ollama provider..."
                echo -n "输入模型名称 (默认: deepseek-r1:14b): "
                read model
                model=${model:-"deepseek-r1:14b"}
                echo -n "输入服务器地址 (默认: 127.0.0.1:11434): "
                read address
                address=${address:-"127.0.0.1:11434"}
                update_config "ollama" "$model" "$address" "True"
                ;;
            2)
                echo "配置 LM Studio provider..."
                echo -n "输入模型名称: "
                read model
                echo -n "输入服务器地址 (默认: 127.0.0.1:1234): "
                read address
                address=${address:-"127.0.0.1:1234"}
                update_config "lm-studio" "$model" "$address" "True"
                ;;
            3)
                echo "配置 DeepSeek Private provider..."
                echo -n "输入模型名称 (默认: deepseek-chat): "
                read model
                model=${model:-"deepseek-chat"}
                echo -n "输入私有服务器地址: "
                read address
                update_config "deepseek-private" "$model" "$address" "True"
                ;;
            4)
                echo "配置 Custom Server provider..."
                echo -n "输入模型名称: "
                read model
                echo -n "输入服务器地址: "
                read address
                update_config "server" "$model" "$address" "True"
                ;;
            5)
                echo "配置 OpenAI provider..."
                echo -n "输入模型名称 (默认: gpt-4): "
                read model
                model=${model:-"gpt-4"}
                update_config "openai" "$model" "" "False"
                check_api_keys "openai"
                ;;
            6)
                echo "配置 DeepSeek API provider..."
                update_config "deepseek" "deepseek-chat" "" "False"
                check_api_keys "deepseek"
                ;;
            7)
                echo "配置 Google AI provider..."
                echo -n "输入模型名称 (默认: gemini-pro): "
                read model
                model=${model:-"gemini-pro"}
                update_config "google" "$model" "" "False"
                check_api_keys "google"
                ;;
            8)
                echo "配置 Together AI provider..."
                echo -n "输入模型名称 (例: meta-llama/Llama-2-70b-chat-hf): "
                read model
                update_config "together" "$model" "" "False"
                check_api_keys "together"
                ;;
            9)
                echo "配置 OpenRouter provider..."
                echo -n "输入模型名称 (例: anthropic/claude-3-opus): "
                read model
                update_config "openrouter" "$model" "" "False"
                check_api_keys "openrouter"
                ;;
            10)
                echo "配置 Hugging Face provider..."
                echo -n "输入模型名称 (例: microsoft/DialoGPT-large): "
                read model
                update_config "huggingface" "$model" "" "False"
                check_api_keys "huggingface"
                ;;
            11)
                echo "配置 DSK DeepSeek provider..."
                update_config "dsk_deepseek" "deepseek-chat" "" "False"
                check_api_keys "dsk_deepseek"
                echo "⚠️  注意: 这是非官方的第三方接口，可能不稳定"
                ;;
            12)
                echo "配置 Test provider..."
                update_config "test" "test-model" "" "True"
                ;;
            "b")
                restore_backup
                ;;
            "q")
                echo "👋 再见!"
                exit 0
                ;;
            *)
                echo "❌ 无效选择，请重试"
                ;;
        esac
        
        echo
        echo "按回车键继续..."
        read
        clear
    done
}

# 运行主程序
main "$@"
