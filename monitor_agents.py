#!/usr/bin/env python3
"""
AgenticSeek 代理状态监控脚本
用于诊断代理之间的协作问题
"""

import time
import requests
import json
import sys
from pathlib import Path
from datetime import datetime, timedelta
import subprocess
import threading

class AgentMonitor:
    def __init__(self):
        self.script_dir = Path(__file__).parent
        self.log_dir = self.script_dir / ".logs"
        
    def check_ollama_status(self):
        """检查 Ollama 服务状态"""
        try:
            # 检查服务状态
            response = requests.get("http://localhost:11434/api/tags", timeout=5)
            if response.status_code == 200:
                print("✅ Ollama 服务正常运行")
                
                # 检查当前运行的模型
                ps_response = requests.get("http://localhost:11434/api/ps", timeout=5)
                if ps_response.status_code == 200:
                    models = ps_response.json().get("models", [])
                    if models:
                        for model in models:
                            expires_at = model.get("expires_at", "")
                            print(f"🤖 运行中的模型: {model['name']}")
                            print(f"   到期时间: {expires_at}")
                            print(f"   VRAM 使用: {model.get('size_vram', 0) / (1024**3):.2f} GB")
                    else:
                        print("⚠️  没有模型正在运行")
                return True
        except requests.exceptions.RequestException as e:
            print(f"❌ Ollama 服务连接失败: {e}")
            return False
    
    def get_last_log_time(self, log_file):
        """获取日志文件的最后一行时间"""
        try:
            if not log_file.exists():
                return None
                
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                if not lines:
                    return None
                
                # 找到最后一行有时间戳的记录
                for line in reversed(lines):
                    if line.strip() and line.startswith('2025-'):
                        timestamp_str = line.split(' ')[0] + ' ' + line.split(' ')[1].split(',')[0]
                        try:
                            return datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
                        except:
                            continue
            return None
        except Exception as e:
            print(f"读取日志文件 {log_file} 出错: {e}")
            return None
    
    def check_agent_status(self):
        """检查各个代理的状态"""
        print("\n📊 代理状态检查:")
        print("-" * 50)
        
        agents = {
            "planner_agent": self.log_dir / "planner_agent.log",
            "code_agent": self.log_dir / "code_agent.log",
            "backend": self.log_dir / "backend.log",
            "router": self.log_dir / "router.log"
        }
        
        current_time = datetime.now()
        
        for agent_name, log_file in agents.items():
            last_time = self.get_last_log_time(log_file)
            if last_time:
                time_diff = current_time - last_time
                status_emoji = "🟢" if time_diff.seconds < 60 else "🟡" if time_diff.seconds < 300 else "🔴"
                print(f"{status_emoji} {agent_name:15} | 最后活动: {last_time.strftime('%H:%M:%S')} ({time_diff.seconds}秒前)")
            else:
                print(f"⚫ {agent_name:15} | 无日志记录")
    
    def test_ollama_response(self):
        """测试 Ollama 模型响应"""
        print("\n🧪 测试 Ollama 模型响应...")
        
        test_prompt = {
            "model": "deepseek-r1:8b",
            "messages": [
                {"role": "user", "content": "简单回答：1+1等于多少？"}
            ],
            "stream": False,
            "options": {
                "num_predict": 50,
                "temperature": 0.1
            }
        }
        
        start_time = time.time()
        try:
            response = requests.post(
                "http://localhost:11434/api/chat",
                json=test_prompt,
                timeout=30
            )
            end_time = time.time()
            
            if response.status_code == 200:
                result = response.json()
                response_time = end_time - start_time
                content = result.get("message", {}).get("content", "")
                print(f"✅ 模型响应正常 (用时: {response_time:.2f}秒)")
                print(f"   响应内容: {content[:100]}...")
                return True
            else:
                print(f"❌ 模型响应异常: {response.status_code}")
                return False
                
        except requests.exceptions.Timeout:
            print("❌ 模型响应超时 (30秒)")
            return False
        except Exception as e:
            print(f"❌ 模型测试失败: {e}")
            return False
    
    def check_backend_health(self):
        """检查后端健康状态"""
        print("\n🏥 检查后端健康状态...")
        
        try:
            response = requests.get("http://localhost:7777/health", timeout=10)
            if response.status_code == 200:
                print("✅ 后端服务健康")
                return True
            else:
                print(f"❌ 后端服务异常: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ 后端服务连接失败: {e}")
            return False
    
    def get_stuck_processes(self):
        """检查可能卡住的进程"""
        print("\n🔍 检查可能卡住的进程...")
        
        try:
            # 检查 Python 进程
            result = subprocess.run(
                ["ps", "aux"], 
                capture_output=True, 
                text=True
            )
            
            lines = result.stdout.split('\n')
            python_processes = []
            
            for line in lines:
                if 'python' in line.lower() and 'agenticseek' in line:
                    parts = line.split()
                    if len(parts) >= 11:
                        pid = parts[1]
                        cpu = parts[2]
                        mem = parts[3]
                        time = parts[9]
                        cmd = ' '.join(parts[10:])
                        python_processes.append({
                            'pid': pid,
                            'cpu': cpu,
                            'mem': mem,
                            'time': time,
                            'cmd': cmd
                        })
            
            if python_processes:
                for proc in python_processes:
                    print(f"🐍 Python 进程 PID:{proc['pid']} CPU:{proc['cpu']}% MEM:{proc['mem']}% TIME:{proc['time']}")
                    print(f"   命令: {proc['cmd'][:80]}...")
            else:
                print("⚠️  未找到相关 Python 进程")
                
        except Exception as e:
            print(f"❌ 进程检查失败: {e}")
    
    def suggest_solutions(self):
        """提供解决方案建议"""
        print("\n💡 可能的解决方案:")
        print("-" * 50)
        print("1. 🔄 重启服务:")
        print("   ./stop_services.sh && ./start_services.sh")
        print()
        print("2. 🧹 清理 Ollama 模型缓存:")
        print("   curl -X POST http://localhost:11434/api/generate -d '{\"model\":\"deepseek-r1:8b\",\"keep_alive\":0}'")
        print()
        print("3. ⏱️  检查模型配置 (在 config.ini 中):")
        print("   - 考虑使用更小的模型进行测试")
        print("   - 增加超时设置")
        print()
        print("4. 📊 实时监控日志:")
        print("   ./show_logs.py --follow code_agent")
        print("   ./show_logs.py --follow planner_agent")
        print()
        print("5. 🐛 调试模式:")
        print("   检查 code_agent.py 中的 max_attempts 和超时设置")
    
    def monitor_continuous(self, interval=10):
        """持续监控"""
        print(f"\n🔄 开始持续监控 (每 {interval} 秒检查一次)...")
        print("按 Ctrl+C 停止监控")
        
        try:
            while True:
                print(f"\n{'='*60}")
                print(f"监控时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                print("="*60)
                
                self.check_ollama_status()
                self.check_agent_status()
                self.check_backend_health()
                
                print(f"\n⏰ 等待 {interval} 秒后继续监控...")
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\n\n👋 监控已停止")

def main():
    monitor = AgentMonitor()
    
    print("🔍 AgenticSeek 代理状态诊断")
    print("=" * 50)
    
    # 基本状态检查
    monitor.check_ollama_status()
    monitor.check_agent_status()
    monitor.check_backend_health()
    monitor.test_ollama_response()
    monitor.get_stuck_processes()
    monitor.suggest_solutions()
    
    # 询问是否进行持续监控
    print("\n❓ 是否要进行持续监控？(y/n): ", end="")
    if input().lower().startswith('y'):
        monitor.monitor_continuous()

if __name__ == "__main__":
    main()
