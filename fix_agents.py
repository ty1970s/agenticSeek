#!/usr/bin/env python3
"""
AgenticSeek 代理修复和测试脚本
修复 Code Agent 超时问题并测试代理协作
"""

import time
import requests
import json
import sys
import subprocess
from pathlib import Path
from datetime import datetime

def test_ollama_with_timeout():
    """测试 Ollama 模型的超时机制"""
    print("🧪 测试 Ollama 超时机制...")
    
    test_prompt = {
        "model": "deepseek-r1:8b",
        "messages": [
            {"role": "user", "content": "请生成一个复杂的Python脚本，包含多个类和函数，用于处理文件操作、数据分析和网络请求。"}
        ],
        "stream": False,
        "options": {
            "num_predict": 2000,
            "temperature": 0.7
        }
    }
    
    start_time = time.time()
    try:
        print("发送请求到 Ollama...")
        response = requests.post(
            "http://localhost:11434/api/chat",
            json=test_prompt,
            timeout=60  # 1分钟超时用于测试
        )
        end_time = time.time()
        
        if response.status_code == 200:
            result = response.json()
            response_time = end_time - start_time
            content = result.get("message", {}).get("content", "")
            print(f"✅ 模型响应成功 (用时: {response_time:.2f}秒)")
            print(f"   响应长度: {len(content)} 字符")
            return True
        else:
            print(f"❌ 模型响应异常: {response.status_code}")
            return False
            
    except requests.exceptions.Timeout:
        print("⏰ 模型响应超时 (预期行为)")
        return True  # 超时也是正常的测试结果
    except Exception as e:
        print(f"❌ 模型测试失败: {e}")
        return False

def restart_backend():
    """重启后端服务"""
    print("🔄 重启后端服务...")
    
    try:
        # 停止服务
        print("停止服务...")
        result = subprocess.run(["./stop_services.sh"], cwd=".", capture_output=True, text=True)
        if result.returncode != 0:
            print(f"⚠️  停止服务时有警告: {result.stderr}")
        
        time.sleep(2)
        
        # 启动服务
        print("启动服务...")
        result = subprocess.run(["./start_services.sh"], cwd=".", capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ 服务重启成功")
            return True
        else:
            print(f"❌ 服务启动失败: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"❌ 重启服务失败: {e}")
        return False

def clear_ollama_cache():
    """清理 Ollama 模型缓存"""
    print("🧹 清理 Ollama 模型缓存...")
    
    try:
        # 设置模型保持时间为0，强制卸载
        payload = {
            "model": "deepseek-r1:8b",
            "keep_alive": 0
        }
        
        response = requests.post(
            "http://localhost:11434/api/generate",
            json=payload,
            timeout=10
        )
        
        if response.status_code == 200:
            print("✅ 模型缓存清理成功")
            return True
        else:
            print(f"⚠️  清理缓存响应: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ 清理缓存失败: {e}")
        return False

def test_simple_agent_task():
    """测试简单的代理任务"""
    print("🎯 测试简单代理任务...")
    
    try:
        payload = {
            "query": "写一个简单的Python函数，计算两个数的和",
            "language": "zh-CN"
        }
        
        print("发送简单任务到后端...")
        response = requests.post(
            "http://localhost:7777/chat",
            json=payload,
            timeout=120  # 2分钟超时
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ 简单任务完成")
            print(f"   响应: {result.get('answer', '')[:200]}...")
            return True
        else:
            print(f"❌ 任务失败: {response.status_code}")
            return False
            
    except requests.exceptions.Timeout:
        print("⏰ 任务超时 - 这可能表明仍有问题")
        return False
    except Exception as e:
        print(f"❌ 任务测试失败: {e}")
        return False

def monitor_logs_realtime():
    """实时监控日志"""
    print("📊 启动实时日志监控...")
    print("请在另一个终端窗口测试功能，观察日志输出")
    print("按 Ctrl+C 停止监控")
    
    try:
        subprocess.run(["./show_logs.py", "--follow", "--all"], cwd=".")
    except KeyboardInterrupt:
        print("\n监控已停止")

def main():
    print("🔧 AgenticSeek 代理修复和测试工具")
    print("=" * 50)
    
    while True:
        print("\n可用选项:")
        print("1. 🧪 测试 Ollama 超时机制")
        print("2. 🔄 重启后端服务")
        print("3. 🧹 清理 Ollama 缓存")
        print("4. 🎯 测试简单代理任务")
        print("5. 📊 实时监控日志")
        print("6. 🔄 全套修复流程")
        print("0. 退出")
        
        choice = input("\n请选择操作 (0-6): ").strip()
        
        if choice == "0":
            print("👋 再见！")
            break
        elif choice == "1":
            test_ollama_with_timeout()
        elif choice == "2":
            restart_backend()
        elif choice == "3":
            clear_ollama_cache()
        elif choice == "4":
            test_simple_agent_task()
        elif choice == "5":
            monitor_logs_realtime()
        elif choice == "6":
            print("🔄 执行全套修复流程...")
            clear_ollama_cache()
            time.sleep(2)
            restart_backend()
            time.sleep(5)
            test_ollama_with_timeout()
            time.sleep(2)
            test_simple_agent_task()
        else:
            print("❌ 无效选择，请重试")

if __name__ == "__main__":
    main()
