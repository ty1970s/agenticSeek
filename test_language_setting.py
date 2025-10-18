#!/usr/bin/env python3
"""
测试语言设置功能的脚本
"""

import sys
import os
import asyncio
import requests
import json

# 添加项目根目录到路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def test_language_setting():
    """测试语言设置功能"""
    print("🌍 测试语言设置功能...")
    
    backend_url = "http://localhost:7777"
    
    # 测试不同语言的查询
    test_cases = [
        {
            "query": "What is Python?",
            "language": "zh-CN",
            "description": "英文查询，要求中文回复"
        },
        {
            "query": "什么是人工智能？", 
            "language": "en",
            "description": "中文查询，要求英文回复"
        },
        {
            "query": "Hello world",
            "language": "ja",
            "description": "英文查询，要求日文回复"
        },
        {
            "query": "How to learn programming?",
            "language": "auto",
            "description": "自动检测语言"
        }
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n📋 测试案例 {i}: {test_case['description']}")
        print(f"   查询: {test_case['query']}")
        print(f"   设定语言: {test_case['language']}")
        
        try:
            # 发送请求
            response = requests.post(
                f"{backend_url}/query",
                json={
                    "query": test_case["query"],
                    "tts_enabled": False,
                    "response_language": test_case["language"]
                },
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                print(f"   ✅ 回复: {data.get('answer', '无回复')[:100]}...")
            else:
                print(f"   ❌ 错误: HTTP {response.status_code}")
                
        except requests.exceptions.RequestException as e:
            print(f"   ❌ 请求失败: {e}")
        
        except Exception as e:
            print(f"   ❌ 未知错误: {e}")
        
        # 等待一下再进行下一个测试
        if i < len(test_cases):
            print("   等待 3 秒...")
            import time
            time.sleep(3)

def test_health_check():
    """测试后端健康状态"""
    print("🔍 检查后端健康状态...")
    
    try:
        response = requests.get("http://localhost:7777/health", timeout=5)
        if response.status_code == 200:
            print("✅ 后端服务正常运行")
            return True
        else:
            print(f"❌ 后端服务状态异常: HTTP {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ 无法连接到后端服务: {e}")
        print("💡 请确保后端服务已启动 (python api.py)")
        return False

if __name__ == "__main__":
    print("🚀 开始测试语言设置功能")
    print("=" * 60)
    
    # 先检查后端健康状态
    if not test_health_check():
        sys.exit(1)
    
    # 测试语言设置功能
    test_language_setting()
    
    print("\n" + "=" * 60)
    print("✅ 语言设置功能测试完成！")
